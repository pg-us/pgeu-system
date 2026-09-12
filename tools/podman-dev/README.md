# podman-dev

Rootless-podman dev environment for pgeu-system with the PgUS skin
(`pgusweb`). Usage lives in the top-level `SETUP.md`; this file documents the
design and the non-obvious environment facts.

## Layout

One pod (`pgeu-dev`) so the app reaches postgres on `127.0.0.1`:

- `pgeu-db` — `postgres:17-bookworm`, data in the `pgeu-pgdata` volume,
  `initdb/10-pgcrypto.sql` creates the pgcrypto schema+extension on first boot.
- `pgeu-app` — built from `Containerfile`; bind-mounts pgeu-system at `/app`
  and pgusweb at `/skin` (`:z` — SELinux host). `entrypoint.sh` waits for the
  DB, migrates, seeds a superuser, then runs uwsgi.

uwsgi serves the app *and* all static trees (`uwsgi.ini`):
`/media` → `/app/media`, `/media/pgus` → `/skin/media/pgus` (the skin's
assets — Django never serves these), `/media/admin` → a symlink to Django's
admin static, created at image build.

Settings use upstream's out-of-tree module scheme via `PYTHONPATH=config/`:

- `pgeu_system_global_settings.py` — DB credentials, SECRET_KEY, and
  `SYSTEM_SKIN_DIRECTORY=/skin` (the single variable that wires the skin in).
- `pgeu_system_override_settings.py` — loads **after** `skin_settings.py`,
  which is the only way to beat the skin's `SITEBASE=https://postgresql.us`
  and `ENABLE_PG_COMMUNITY_AUTH=True` (community auth can't work locally, so
  dev uses plain Django auth).

Never create `postgresqleu/local_settings.py` in this flow — it loads
mid-chain, silently swallows its own ImportErrors, and fights the modules
above. `checks/00-prereqs.sh` fails if one exists.

## Non-obvious environment facts

- **IPv6**: on the host, `localhost` resolves to `::1` and pasta forwards it —
  against a `0.0.0.0`-only bind the connection hangs with no v4 fallback.
  uwsgi binds `[::]:8012` (dual-stack; binding both separately EADDRINUSEs).
- **MIME**: slim Debian images lack `/etc/mime.types`; without the
  `media-types` package uwsgi serves CSS as octet-stream and browsers ignore
  it. `checks/60-static.sh` asserts `text/css`.
- **userns**: per-container `--userns=keep-id` is rejected when joining a pod;
  not needed — default rootless mapping makes container root the host user,
  so bind-mount writes have correct ownership.
- **CWD**: settings.py/docsviews use relative paths; uwsgi `chdir=/app` is
  load-bearing.
- **Fonts**: `FONTROOT` expects `.../ttf-dejavu`; bookworm ships
  `.../dejavu`, symlinked in the image.
- **Ports**: DB published on `127.0.0.1:5432` (the postgres default);
  `PGEU_DBPORT` overrides, `0` disables. If 5432 is taken on your machine,
  set the override in `local.env` (untracked, sourced by `up.sh`).
- **Pins**: `Pillow==9.5.0` and `pycryptodomex==3.7.0` in
  `tools/devsetup/dev_requirements.txt` replace pins that no longer install
  on Python 3.11. Submitted upstream.

## Verification

`checks/run-checks.sh` is the post-`up.sh` smoke suite: prereqs/config
landmines (00), image runtime deps (10), DB + migrations applied (30), HTTP
(40), skin templates/URLs/pages (50), all three static-maps + MIME (60), auth
and the settings-override chain (70). Each script exits 0/1 and can run
standalone; `STOP_ON_FAIL=1` aborts at the first failure.
