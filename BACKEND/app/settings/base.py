from datetime import timedelta
from pathlib import Path
from urllib.parse import urlparse
import os
from dotenv import load_dotenv

load_dotenv()
BASE_DIR = Path(__file__).resolve().parent.parent.parent
SECRET_KEY = os.getenv("DJANGO_SECRET_KEY", "change_me")
DEBUG = os.getenv("DJANGO_DEBUG", "false").lower() in ("1", "true", "yes")
ALLOWED_HOSTS = [
    host.strip()
    for host in os.getenv("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1").split(",")
    if host.strip()
]
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.gis",
    "rest_framework",
    "rest_framework_gis",
    "corsheaders",
    "drf_spectacular",
    "django_filters",
    "django_celery_beat",
    "apps.common",
    "apps.audit",
    "apps.users",
    "apps.authn",
    "apps.health",
    "apps.needs",
    "apps.inventory",
    "apps.catalog",
    "apps.geo",
    "apps.matching",
    "apps.wallet",
    "apps.contacts",
    "apps.disputes",
    "apps.reviews",
    "apps.leads",
    "apps.notifications",
    "apps.admin_panel",
]
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]
ROOT_URLCONF = "app.urls"
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ]
        },
    }
]
WSGI_APPLICATION = "app.wsgi.application"
ASGI_APPLICATION = "app.asgi.application"
AUTH_USER_MODEL = "users.User"
_database_url = os.getenv("DATABASE_URL", "")
if _database_url:
    _parsed = urlparse(_database_url)
    DATABASES = {
        "default": {
            "ENGINE": "django.contrib.gis.db.backends.postgis",
            "NAME": _parsed.path.lstrip("/") or "wanti_db",
            "USER": _parsed.username or "postgres",
            "PASSWORD": _parsed.password or "postgres",
            "HOST": _parsed.hostname or "localhost",
            "PORT": str(_parsed.port or 5432),
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.contrib.gis.db.backends.postgis",
            "NAME": os.getenv("DB_NAME", "wanti_db"),
            "USER": os.getenv("DB_USER", "postgres"),
            "PASSWORD": os.getenv("DB_PASSWORD", "postgres"),
            "HOST": os.getenv("DB_HOST", "localhost"),
            "PORT": os.getenv("DB_PORT", "5432"),
        }
    }
AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"
    },
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]
LANGUAGE_CODE = "es-co"
TIME_ZONE = "America/Bogota"
USE_I18N = True
USE_TZ = True
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_PAGINATION_CLASS": "apps.common.pagination.StandardPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": (
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_THROTTLE_CLASSES": ("rest_framework.throttling.ScopedRateThrottle",),
    "DEFAULT_THROTTLE_RATES": {
        "login": "10/min",
        "otp_send": "5/hour",
        "otp_verify": "10/hour",
        "password_reset": "5/hour",
        "unlock_contact": "60/hour",
        "need_create": "20/day",
        "register": "5/hour",
    },
    "EXCEPTION_HANDLER": "apps.common.exceptions_handler.custom_exception_handler",
}
SPECTACULAR_SETTINGS = {
    "TITLE": "API Wanti",
    "DESCRIPTION": "API del marketplace inverso de vehículos e inmuebles",
    "VERSION": "1.0.0",
}
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(
        minutes=int(os.getenv("JWT_ACCESS_MINUTES", 15))
    ),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=int(os.getenv("JWT_REFRESH_DAYS", 7))),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "user_id",
}
CELERY_BROKER_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
CELERY_RESULT_BACKEND = os.getenv("REDIS_URL", "redis://localhost:6379/0")
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TIMEZONE = "America/Bogota"
CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler"
from celery.schedules import crontab

CELERY_BEAT_SCHEDULE = {
    "expire-stale-needs": {
        "task": "apps.needs.tasks.expire_stale_needs",
        "schedule": crontab(hour=2, minute=0),
    },
    "notify-needs-expiring-soon": {
        "task": "apps.needs.tasks.notify_needs_expiring_soon",
        "schedule": crontab(hour=9, minute=0),
    },
    "expire-stale-leads": {
        "task": "apps.leads.tasks.expire_stale_leads",
        "schedule": crontab(hour=3, minute=0),
    },
    "check-dispute-timeouts": {
        "task": "apps.disputes.tasks.check_auto_review_timeouts",
        "schedule": crontab(minute="*/60"),
    },
    "reconcile-wallet-balances": {
        "task": "apps.wallet.tasks.reconcile_balances",
        "schedule": crontab(hour=4, minute=0),
    },
}
TWILIO_ENABLED = os.getenv("TWILIO_ENABLED", "false").lower() in ("1", "true", "yes")
ONESIGNAL_ENABLED = os.getenv("ONESIGNAL_ENABLED", "false").lower() in ("1", "true", "yes")
ONESIGNAL_APP_ID = os.getenv("ONESIGNAL_APP_ID", "")
ONESIGNAL_REST_API_KEY = os.getenv("ONESIGNAL_REST_API_KEY", "")

# Pagos / recargas
PAYMENT_PROVIDER = os.getenv("PAYMENT_PROVIDER", "sandbox").strip().lower()
PAYMENT_WEBHOOK_SECRET = os.getenv("PAYMENT_WEBHOOK_SECRET", "")
PAYMENT_WEBHOOK_URL = os.getenv("PAYMENT_WEBHOOK_URL", "")
PAYMENT_AUTO_COMPLETE = os.getenv("PAYMENT_AUTO_COMPLETE", "false").lower() in (
    "1",
    "true",
    "yes",
)
BOLT_API_URL = os.getenv("BOLT_API_URL", "")
BOLT_API_KEY = os.getenv("BOLT_API_KEY", "")

EMAIL_BACKEND = os.getenv(
    "EMAIL_BACKEND", "django.core.mail.backends.console.EmailBackend"
)
EMAIL_HOST = os.getenv("EMAIL_HOST", "")
EMAIL_PORT = int(os.getenv("EMAIL_PORT", "587"))
EMAIL_HOST_USER = os.getenv("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.getenv("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_TLS = os.getenv("EMAIL_USE_TLS", "true").lower() in ("1", "true", "yes")
DEFAULT_FROM_EMAIL = os.getenv("DEFAULT_FROM_EMAIL", "no-reply@wanti.co")
FRONTEND_BASE_URL = os.getenv("FRONTEND_BASE_URL", "http://localhost:3000")

# Demo/staging: si no hay SMTP real, el registro marca el email como verificado
# para no bloquear el onboarding. Forzar con AUTO_VERIFY_EMAIL=true|false.
_auto_verify_email = os.getenv("AUTO_VERIFY_EMAIL", "").strip().lower()
if _auto_verify_email in ("1", "true", "yes"):
    AUTO_VERIFY_EMAIL = True
elif _auto_verify_email in ("0", "false", "no"):
    AUTO_VERIFY_EMAIL = False
else:
    AUTO_VERIFY_EMAIL = EMAIL_BACKEND.endswith("console.EmailBackend")
CORS_ALLOW_ALL_ORIGINS = DEBUG
GDAL_LIBRARY_PATH = os.getenv("GDAL_LIBRARY_PATH")
GEOS_LIBRARY_PATH = os.getenv("GEOS_LIBRARY_PATH")
