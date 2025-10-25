1. Open directory in VSCode, use the provided dev container. This configures a good version of python and sets up postgres with the right credentials.
2. Read through, and _then_ run `./install.sh`
3. Run `python3 manage.py runserver`

If using a skin:
1. Add something like the following to `local_settings.py`: `SYSTEM_SKIN_DIRECTORY = "/workspaces/pgusweb"`
2. Note that the path is absolute and relative to the dev container, not the local filesystem.
3. This will connect templates, but static assets will need to be symlinked and adding to `.gitignore` (or `.git/info/exclude`)

The _correct_ way to handle the skins is to correctly configure the uwsgi server, but this is simpler and works for now.