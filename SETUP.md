# Development setup (podman)

Requirements: rootless podman ≥ 4 and the `pgusweb` skin checked out as a
sibling of this repo (or point `PGUSWEB_DIR` elsewhere).

```
tools/podman-dev/up.sh
```

That builds the app image, creates the `pgeu-dev` pod (postgres 17 + uwsgi),
runs migrations, seeds a superuser, and serves:

- http://localhost:8012/ — the site, with the PgUS skin active (templates,
  URLs, *and* static assets — served via uwsgi `static-map`)
- admin login: `testuser` / `testpass` (community auth is disabled in dev via
  `tools/podman-dev/config/pgeu_system_override_settings.py`)
- postgres on `127.0.0.1:5445` for host tools (`PGEU_DBPORT=0` to disable,
  password `postgresqleu`)

Edits to Python code reload automatically (`py-autoreload`); template and
static changes are picked up immediately. Configuration lives in
`tools/podman-dev/config/` as `pgeu_system_global_settings` /
`pgeu_system_override_settings` modules on `PYTHONPATH` — do **not** create
`postgresqleu/local_settings.py`; it loads mid-chain and fights the skin.

Other commands, all in `tools/podman-dev/`:

| command | effect |
|---|---|
| `down.sh` | stop and remove the pod (keeps DB data) |
| `reset.sh` | remove pod **and** the `pgeu-pgdata` volume (fresh DB) |
| `logs.sh [app\|db]` | follow logs |
| `shell.sh [app\|db\|django\|psql]` | interactive shells |
| `checks/run-checks.sh` | verify the whole environment end to end |
