# Stage-1 settings (pgeu_system_global_settings): loaded before the skin.
# Dev-only values for the podman-dev environment. See tools/podman-dev/PLAN.md.
# Anything the skin must NOT override belongs in pgeu_system_override_settings.

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'postgresqleu',
        'HOST': '127.0.0.1',
        'PORT': '5432',
        'USER': 'postgresqleu',
        'PASSWORD': 'postgresqleu',
    }
}

SECRET_KEY = 'dev-only-secret-key-do-not-use-outside-podman-dev'
SERVER_EMAIL = 'root@localhost'

# The single glue variable: enables pgusweb templates, code and URLs.
SYSTEM_SKIN_DIRECTORY = '/skin'
