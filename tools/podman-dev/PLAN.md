# Podman dev environment: audit + implementation plan

Status: **planning artifact** — written 2026-08-09, before implementation. The
`checks/` directory next to this file contains the success/failure scripts the
implementation loop must turn green (`checks/run-checks.sh`).

Goal: replace the VSCode-only `.devcontainer/` + `install.sh` setup with a
plain rootless-podman workflow (no docker-compose, no VSCode dependency) that
runs pgeu-system with the PgUS skin (`pgusweb`) correctly — including skin
static assets, which the current setup handles with a manual symlink hack.

---

## 1. Audit of the current dev-container work

Fork-specific commits: `8c4ed15d` (devcontainer, install.sh, SETUP.md),
`bbb41a54` (SETUP.md update), plus the pycryptodomex 3.6.1→3.7.0 bump inside
`8c4ed15d`. The settings-loading scheme (`5232fad8`, `1183cf87`) is upstream
work the fork pulled in — and it is the right foundation to build on (its
commit message says it exists "to ease building docker images").

### Findings

1. **VSCode lock-in (the core problem).** `devcontainer.json` drives
   everything: image build, `docker-compose.yml` startup, port forwarding
   (`forwardPorts`), and attach. The app container's command is
   `sleep infinity` — nothing runs unless an IDE attaches and a human runs
   `install.sh` + `runserver` by hand.
2. **DB bootstrap in `install.sh` is broken as shipped.**
   - `createuser -U postgres -s postgresqleu`: the postgres image is started
     with `POSTGRES_USER=postgresqleu`, so no `postgres` role exists, and the
     role it tries to create already exists.
   - `createdb -U postgresqleu postgresqleu`: DB already created by
     `POSTGRES_DB`.
   - The image requires password auth for TCP (scram), but neither the script
     (`PGPASSWORD`) nor the generated `local_settings.py` (`PASSWORD` key)
     supplies `postgresqleu`'s password — so psql prompts interactively and
     Django's DB connection can only have worked with manual fixes.
   - `127.0.01` typo (×3) — parses as 127.0.0.1 by accident.
   - No `set -e`, not idempotent (re-runs half-fail).
3. **Vestigial uwsgi config.** `install.sh` generates `devserver-uwsgi.ini`
   with `home=` pointing at `tools/devsetup/venv_dev`, but installs packages
   globally with pip3 and never creates that venv. The template also maps
   admin static to a `python2.7` site-packages path. SETUP.md then says to use
   `runserver` — so the generated ini is dead weight, and with it the
   `static-map` mechanism that is the *correct* way to serve skin media.
4. **Skin static assets are hand-waved.** SETUP.md: symlink `pgusweb` media
   into the tree and hide it from git. This is the known-wrong workaround for
   the missing `static-map=/media/pgus=…` (SETUP.md itself says the correct
   way is configuring uwsgi).
5. **Port confusion.** `forwardPorts: [5000, 5432]`, `SITEBASE`
   `http://localhost:8012/`, `runserver` defaults to 8000, uwsgi template
   binds 8012. Nothing lines up; nothing documents which port to use.
6. **Unpinned/mismatched versions.** `postgres:latest` (now 18) vs
   `postgresql-client-17` in the app image; base image is bullseye-era
   (`devcontainers/python:1-3.11-bullseye`) while upstream targets bookworm.
7. **Login is quietly broken when the skin is enabled.**
   `pgusweb/code/skin_settings.py` sets `ENABLE_PG_COMMUNITY_AUTH=True`,
   which loads after `local_settings.py`. Without `PGAUTH_KEY`/
   `PGAUTH_REDIRECT` (never set in the dev flow) community auth can't work,
   and the `testuser` superuser created by `install.sh` can't log in through
   it. Nothing in SETUP.md addresses this.

## 2. How the skin interacts with the web server (what the plan must honor)

Settings load order (all in `postgresqleu/settings.py:306-354`):

```
defaults → pgeu_system_global_settings (PYTHONPATH)
         → postgresqleu/local_settings.py   (or pgeu_system_settings if absent)
         → $SYSTEM_SKIN_DIRECTORY/code/skin_settings.py
         → $SYSTEM_SKIN_DIRECTORY/code/skin_local_settings.py
         → pgeu_system_override_settings (PYTHONPATH)   ← only stage that beats the skin
```

`SYSTEM_SKIN_DIRECTORY` (absolute path) is the single glue variable. Setting
it gives you, automatically:

- **Django templates**: `$SKIN/template/` prepended to template DIRS —
  `pgusweb/template/base.html` shadows pgeu's `base.html` and reskins every
  backend page; `pages/*.html` become URLs via the `static_fallback` catch-all
  view (`/aboutus/` → `pages/aboutus.html`).
- **Jinja templates**: `$SKIN/template.jinja/` for conference sites.
- **Code**: `$SKIN/code/` pushed onto `sys.path` (`skin_settings`,
  `skin_urls.PRELOAD_URLS` — prepended to *all* urlpatterns —, and
  `pgusinvoices` loaded by name).

What it does **not** give you: static assets. `STATIC_URL='/media/'`,
`STATICFILES_DIRS=('media/',)` (relative → CWD must be repo root), and the
skin's `media/` is never added. Skin templates hardcode `/media/pgus/...`.
Production serves these with uwsgi `static-map`; that's the piece the podman
setup must implement (three maps: core `/media`, skin `/media/pgus`, admin
`/media/admin`).

Other constraints discovered:

- Process CWD **must** be the pgeu-system repo root (relative `template/`,
  `media/`, `docs/` paths) → `chdir` in uwsgi ini.
- DejaVu fonts expected at `/usr/share/fonts/truetype/ttf-dejavu`
  (`FONTROOT`), `libcairo2` for cairosvg, pgcrypto extension in a `pgcrypto`
  schema.
- A stray `postgresqleu/local_settings.py` silently changes the load order
  (and any ImportError *inside* it is swallowed) — the podman flow must not
  create one, and checks fail if one exists.
- Skin sets `SITEBASE=https://postgresql.us`, `ENABLE_PG_COMMUNITY_AUTH=True`
  etc. **after** local/global settings — dev values must be applied in
  `pgeu_system_override_settings`, not in stage-1/2 config.

## 3. Target architecture

Rootless podman (5.8.2, netavark, Fedora/SELinux host), no compose. One pod
so the app reaches the DB on `127.0.0.1` exactly like the old
`network_mode: service:db` did:

```
pod pgeu-dev  (publishes 8012→8012, optionally 5432 for host psql)
├── pgeu-db   postgres:17-bookworm
│             volume pgeu-pgdata:/var/lib/postgresql/data
│             initdb.d SQL creates pgcrypto schema+extension
│             healthcheck: pg_isready
└── pgeu-app  built from tools/podman-dev/Containerfile
              mounts: pgeu-system → /app:z   pgusweb → /skin:z
              default rootless userns (container root == host user,
              so bind-mount edits keep host ownership)
              entrypoint: wait-for-db → migrate → ensure superuser → exec uwsgi
```

uwsgi serves everything (no runserver, no symlinks):

```ini
[uwsgi]
http = 0.0.0.0:8012
module = postgresqleu.wsgi:application
chdir = /app                      ; CWD requirement
py-autoreload = 1                 ; edit-reload dev loop
processes = 2
threads = 3
static-map = /media=/app/media
static-map = /media/pgus=/skin/media/pgus     ; replaces the symlink hack
static-map = /media/admin=/opt/django-admin-static   ; symlinked at image build
```

(`/opt/django-admin-static` is created in the Containerfile via
`ln -s $(python3 -c 'import django, os; print(os.path.join(os.path.dirname(django.__file__), "contrib/admin/static/admin"))') /opt/django-admin-static`
— fixes the stale `python2.7` path.)

### Configuration via the upstream module scheme (no files written into the tree)

`tools/podman-dev/config/` goes on `PYTHONPATH` (container env) and provides:

- `pgeu_system_global_settings.py` — stage 1: `DATABASES` (127.0.0.1, user
  `postgresqleu`, password set to match `POSTGRES_PASSWORD`), `SECRET_KEY`,
  `SERVER_EMAIL`, `SYSTEM_SKIN_DIRECTORY = '/skin'`.
- `pgeu_system_override_settings.py` — stage 5, beats the skin: `DEBUG=True`,
  `SITEBASE='http://localhost:8012/'`, `ALLOWED_HOSTS=['*']`,
  `SESSION_COOKIE_SECURE=False`, `CSRF_COOKIE_SECURE=False`,
  `ENABLE_PG_COMMUNITY_AUTH=False` (so the seeded `testuser`/`testpass`
  superuser can log in with plain Django auth).

This uses the mechanism upstream built for containers, keeps the working tree
clean (no generated `local_settings.py`), and survives `git pull`.

### Files to create (implementation phase)

```
tools/podman-dev/
  Containerfile              python:3.11-slim-bookworm base; apt: build-essential,
                             libjpeg-dev zlib1g-dev libpng-dev libffi-dev libssl-dev,
                             libcairo2, fonts-dejavu-core (+FONTROOT compat, see risks),
                             postgresql-client; pip: dev_requirements(+full), uwsgi
  uwsgi.ini                  as above
  entrypoint.sh              wait-for-db, migrate, idempotent createsuperuser, exec uwsgi
  config/pgeu_system_global_settings.py
  config/pgeu_system_override_settings.py
  initdb/10-pgcrypto.sql     CREATE SCHEMA pgcrypto; CREATE EXTENSION pgcrypto SCHEMA pgcrypto;
                             GRANT USAGE ON SCHEMA pgcrypto TO PUBLIC;
  up.sh / down.sh / reset.sh / logs.sh / shell.sh    thin podman wrappers
  checks/                    ALREADY WRITTEN — the loop's success criteria
```

`up.sh` sketch (the whole "orchestration"):

```sh
podman build -t localhost/pgeu-dev-app -f tools/podman-dev/Containerfile .
podman pod create --name pgeu-dev -p 8012:8012 -p 127.0.0.1:5433:5432
podman run -d --pod pgeu-dev --name pgeu-db \
  -e POSTGRES_USER=postgresqleu -e POSTGRES_DB=postgresqleu -e POSTGRES_PASSWORD=postgresqleu \
  -v pgeu-pgdata:/var/lib/postgresql/data \
  -v ./tools/podman-dev/initdb:/docker-entrypoint-initdb.d:z,ro \
  --health-cmd 'pg_isready -U postgresqleu' docker.io/library/postgres:17-bookworm
podman run -d --pod pgeu-dev --name pgeu-app \
  -v "$PGEU_DIR":/app:z -v "$PGUSWEB_DIR":/skin:z \
  -e PYTHONPATH=/app/tools/podman-dev/config \
  -e DJANGO_SUPERUSER_USERNAME=testuser -e DJANGO_SUPERUSER_PASSWORD=testpass \
  -e DJANGO_SUPERUSER_EMAIL=admin@example.com \
  localhost/pgeu-dev-app
```

`reset.sh` = down + `podman volume rm pgeu-pgdata`. `down.sh` =
`podman pod rm -f pgeu-dev`. Optionally generate quadlet units later; not in
scope.

### Implementation order (for the build loop)

1. Containerfile + image builds → check 10 green.
2. initdb SQL + pod/up scripts → checks 20, 30 (db part) green.
3. config modules + entrypoint (migrate, superuser) → check 30 fully green.
4. uwsgi.ini + static maps → checks 40–60 green.
5. Auth override + dev ergonomics → checks 70, 80 green.
6. Update SETUP.md; either delete `.devcontainer/` + `install.sh` or rewrite
   devcontainer.json to reuse this Containerfile (decision for Kevin; default:
   delete `install.sh`, keep a thin devcontainer pointing at the same image).

## 4. Known risks / decisions for the loop

- **Ancient pins vs Python 3.11**: `Pillow==5.4.1`, `MarkupSafe==1.1.0`,
  `Jinja2<2.11`, `reportlab<3.7` predate 3.11 and may fail to build in the
  slim image (the fork already had to bump pycryptodomex for the same
  reason). Mitigation, in order of preference: install the exact apt build
  deps and try; if a pin won't build, bump it minimally in the fork's
  `dev_requirements.txt` (precedent exists) and note it for upstreaming.
  Do NOT silently switch Django/Jinja2 majors — templates and deploystatic
  depend on 2.x Jinja behavior.
- **fonts-dejavu path**: bookworm installs to
  `/usr/share/fonts/truetype/dejavu/`, but `FONTROOT` defaults to
  `.../ttf-dejavu`. Either symlink `ttf-dejavu → dejavu` in the image or set
  `FONTROOT` in the override module. Check 30 does not cover this; invoice
  PDF generation will (manual test, or add a check later).
- **SELinux**: use `:z` (shared) on the two source mounts — both repos also
  get touched by host tools; `:Z` would relabel exclusively.
- ~~**`--userns=keep-id`**~~ RESOLVED: per-container `--userns` is rejected
  when joining a pod with an infra container. Not needed anyway — default
  rootless mapping makes container root the host user, which gives correct
  bind-mount ownership for both repos.
- **Port 5432 collision**: host runs postgres 18 tooling; publish DB on
  127.0.0.1:5433 to avoid clashing with any host postgres.
- **Stray `postgresqleu/local_settings.py`** from the old flow must be
  deleted (check 00 fails otherwise) — it loads at stage 2 and fights the
  module-based config.
- **Sandbox note for agent-driven loops**: podman on this host needs
  `/run/user/1000` writable; Claude-run checks require sandbox-off Bash or an
  allowlist entry for `podman`/`tools/podman-dev/checks`.

## 5. Implementation notes (added 2026-08-09, after the build)

Implemented same day; all checks green. Deviations from the plan above:

- **Dependency pins**: as predicted, `Pillow==5.4.1` was unbuildable —
  it forced pip to backtrack reportlab to source builds needing `ft2build.h`.
  Bumped in `tools/devsetup/dev_requirements.txt`: `Pillow==9.5.0` (required
  by reportlab 3.6.13, the first with cp311 wheels) and `MarkupSafe==2.0.1`
  (last release with `soft_unicode` for Jinja2 2.10). Candidates for
  upstreaming. Also added `libfreetype6-dev` to the image.
- **keep-id dropped** (see resolved risk above).
- **IPv6**: host `localhost` resolves to `::1`; pasta forwards it, but a
  `0.0.0.0`-only uwsgi bind leaves the v6 path dead (connections hang, no
  fallback). uwsgi now binds `[::]:8012` (dual-stack, accepts v4 too — and
  binding both separately fails with EADDRINUSE).
- **MIME types**: slim image lacks `/etc/mime.types`; without it uwsgi serves
  CSS as octet-stream and browsers ignore it. `media-types` package added;
  check 60 now asserts `text/css`.
- **DB host port**: 5433 was taken on this host; published on
  `127.0.0.1:5445` instead, configurable via `PGEU_DBPORT` (0 = don't publish).
- `.devcontainer/` + `install.sh` removed (git rm) same day; SETUP.md
  documents only the podman flow.

