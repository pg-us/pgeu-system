#!/bin/bash

# This is meant to be run from the root of the dev container.

createuser -h 127.0.01 -U postgres -s postgresqleu
createdb -h 127.0.01 -U postgresqleu postgresqleu

psql -h 127.0.01 -U postgresqleu <<EOF
 CREATE SCHEMA pgcrypto;
 CREATE EXTENSION pgcrypto SCHEMA pgcrypto;
 GRANT USAGE ON SCHEMA pgcrypto TO PUBLIC;
EOF

pip3 install -r ./tools/devsetup/dev_requirements.txt
pip3 install -r ./tools/devsetup/dev_requirements_full.txt

cat > ./postgresqleu/local_settings.py <<EOF
DEBUG = True
DISABLE_HTTPS_REDIRECTS = True
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'postgresqleu',
        'HOST': '127.0.0.1',
        'PORT': '5432',
        'USER': 'postgresqleu',
    }
}
SECRET_KEY = 'reallysecretbutwhocares'
SERVER_EMAIL = 'root@localhost'
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
SITEBASE = "http://localhost:8012/"
EOF

python3 manage.py migrate
cat tools/devsetup/devserver-uwsgi.ini.tmpl | sed -e "s#%DJANGO%#$(pwd)/tools/devsetup/venv_dev#g" > devserver-uwsgi.ini
DJANGO_SUPERUSER_USERNAME=testuser \
  DJANGO_SUPERUSER_PASSWORD=testpass \
  DJANGO_SUPERUSER_EMAIL="admin@admin.com" \
  python3 manage.py createsuperuser --noinput