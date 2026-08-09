# Stage-5 settings (pgeu_system_override_settings): loaded AFTER the skin.
# pgusweb/code/skin_settings.py forces SITEBASE=https://postgresql.us and
# ENABLE_PG_COMMUNITY_AUTH=True — these dev values must win over that,
# which only this module can do.

DEBUG = True
SITEBASE = 'http://localhost:8012/'
ALLOWED_HOSTS = ['*']

SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False

# Community auth needs PGAUTH_KEY/PGAUTH_REDIRECT against postgresql.org;
# in dev use plain Django auth so the seeded superuser can log in.
ENABLE_PG_COMMUNITY_AUTH = False
