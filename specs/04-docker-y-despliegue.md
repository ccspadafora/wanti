# Wanti Backend — 04 · Docker, Despliegue y Producción

**Prerequisito:** haber completado `00-setup-inicial.md`, `01-modelos.md`, `02-servicios.md` y `03-endpoints.md`
**Objetivo:** dockerizar la aplicación completa, hardening de seguridad para producción, monitoreo, despliegue y operaciones.

---

## Índice

1. Arquitectura de servicios en producción
2. Dockerfile
3. docker-compose (dev y prod)
4. Variables de entorno de producción
5. Settings de producción y hardening
6. Nginx como reverse proxy
7. Celery worker y beat
8. Backups y disaster recovery
9. Logging, monitoreo y métricas
10. Deployment estrategias
11. Comandos operativos
12. Checklist de release
13. Checklist maestro del proyecto

---

## 1 · Arquitectura de servicios en producción

```
                        ┌───────────────┐
                        │   Cloudflare  │ (WAF, TLS termination opcional)
                        └───────┬───────┘
                                │
                        ┌───────▼───────┐
                        │     Nginx     │ (reverse proxy, TLS, static/media)
                        └───────┬───────┘
                                │
             ┌──────────────────┼──────────────────┐
             │                  │                  │
      ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐
      │  Gunicorn   │    │  Gunicorn   │    │  Gunicorn   │
      │  (Django)   │    │  (Django)   │    │  (Django)   │
      └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
             │                  │                  │
             └──────────────────┼──────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
  ┌─────▼──────┐         ┌──────▼──────┐        ┌───────▼──────┐
  │ PostgreSQL │         │    Redis    │        │  S3 storage  │
  │ + PostGIS  │         │             │        │  (media)     │
  └────────────┘         └──────┬──────┘        └──────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
             ┌──────▼──────┐         ┌──────▼──────┐
             │ Celery      │         │ Celery      │
             │ Worker      │         │ Beat        │
             └─────────────┘         └─────────────┘
```

**Servicios en total:**

| Servicio | Función | Réplicas dev | Réplicas prod |
|---|---|---|---|
| `api` | Django + Gunicorn | 1 | 2–4 |
| `postgres` | PostgreSQL 16 + PostGIS 3.4 | 1 | Externa gestionada (RDS/Cloud SQL) |
| `redis` | Broker Celery + cache | 1 | Externa gestionada |
| `celery-worker` | Ejecución de tasks | 1 | 2 |
| `celery-beat` | Scheduler de tareas periódicas | 1 | 1 (nunca más de 1) |
| `nginx` | Reverse proxy y TLS | opcional | 1+ |

**Regla crítica:** solo puede haber **una** instancia de `celery-beat` corriendo. Múltiples beats generan tasks duplicadas.

---

## 2 · Dockerfile

Crear `backend/Dockerfile` con multi-stage build:

```dockerfile
# =============================================
# STAGE 1: builder
# =============================================
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# Dependencias del sistema para compilar psycopg y GeoDjango
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libgdal-dev \
    gdal-bin \
    libgeos-dev \
    libproj-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --user --no-warn-script-location -r requirements.txt

# =============================================
# STAGE 2: runtime
# =============================================
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/home/app/.local/bin:$PATH \
    DJANGO_SETTINGS_MODULE=app.settings.production

# Runtime deps: solo librerías compartidas de GDAL/GEOS/PROJ y postgres client
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libgdal32 \
    libgeos-c1v5 \
    libproj25 \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Usuario no-root (best practice)
RUN groupadd --system app && useradd --system --gid app --shell /bin/bash --home /home/app app
RUN mkdir -p /home/app/code && chown -R app:app /home/app

USER app
WORKDIR /home/app/code

# Copiar dependencias del builder
COPY --from=builder --chown=app:app /root/.local /home/app/.local

# Copiar código
COPY --chown=app:app . .

# Directorios de staticfiles y media
RUN mkdir -p /home/app/code/staticfiles /home/app/code/media

EXPOSE 8000

# Healthcheck a nivel de contenedor
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/api/v1/health/ || exit 1

# Entrypoint gestiona migraciones y arranque
COPY --chown=app:app docker/entrypoint.sh /home/app/entrypoint.sh
RUN chmod +x /home/app/entrypoint.sh

ENTRYPOINT ["/home/app/entrypoint.sh"]
CMD ["gunicorn", "app.wsgi:application", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "4", \
     "--worker-class", "gthread", \
     "--threads", "2", \
     "--timeout", "60", \
     "--access-logfile", "-", \
     "--error-logfile", "-"]
```

### 2.1 `docker/entrypoint.sh`

```bash
#!/bin/bash
set -e

echo "▶ Waiting for PostgreSQL..."
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; do
  sleep 1
done
echo "✓ PostgreSQL ready"

# Solo el contenedor 'api' (no worker/beat) corre migraciones y collectstatic
if [ "$RUN_MIGRATIONS" = "true" ]; then
  echo "▶ Running migrations..."
  python manage.py migrate --noinput
  echo "▶ Collecting static files..."
  python manage.py collectstatic --noinput --clear
fi

exec "$@"
```

### 2.2 `.dockerignore`

```
# Python
__pycache__/
*.pyc
*.pyo
*.pyd
venv/
env/
.venv/
*.egg-info/

# Django
*.sqlite3
media/
staticfiles/

# Env & secrets
.env
.env.*
!.env.example

# Git
.git/
.gitignore

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store

# Docker
docker-compose*.yml
Dockerfile*

# Tests / coverage
.coverage
htmlcov/
.pytest_cache/
```

---

## 3 · docker-compose

### 3.1 `docker-compose.yml` (desarrollo)

```yaml
version: '3.9'

services:
  postgres:
    image: postgis/postgis:16-3.4
    container_name: wanti-postgres
    environment:
      POSTGRES_DB: wanti_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: wanti-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  api:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: wanti-api
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - .:/home/app/code
      - static_volume:/home/app/code/staticfiles
      - media_volume:/home/app/code/media
    ports:
      - "8000:8000"
    environment:
      DJANGO_SETTINGS_MODULE: app.settings.local
      RUN_MIGRATIONS: "true"
    env_file:
      - .env
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  celery-worker:
    build: .
    container_name: wanti-celery-worker
    command: celery -A app worker --loglevel=info --concurrency=4
    volumes:
      - .:/home/app/code
    environment:
      DJANGO_SETTINGS_MODULE: app.settings.local
      RUN_MIGRATIONS: "false"
    env_file:
      - .env
    depends_on:
      - postgres
      - redis

  celery-beat:
    build: .
    container_name: wanti-celery-beat
    command: celery -A app beat --loglevel=info --scheduler django_celery_beat.schedulers:DatabaseScheduler
    volumes:
      - .:/home/app/code
    environment:
      DJANGO_SETTINGS_MODULE: app.settings.local
      RUN_MIGRATIONS: "false"
    env_file:
      - .env
    depends_on:
      - postgres
      - redis

volumes:
  postgres_data:
  redis_data:
  static_volume:
  media_volume:
```

### 3.2 `docker-compose.prod.yml` (producción)

```yaml
version: '3.9'

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    image: wanti/backend:${IMAGE_TAG:-latest}
    restart: always
    environment:
      DJANGO_SETTINGS_MODULE: app.settings.production
      RUN_MIGRATIONS: "true"
    env_file:
      - .env.production
    volumes:
      - static_volume:/home/app/code/staticfiles
      - media_volume:/home/app/code/media
    depends_on:
      - redis
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1'
          memory: 1G

  celery-worker:
    image: wanti/backend:${IMAGE_TAG:-latest}
    restart: always
    command: celery -A app worker --loglevel=info --concurrency=4
    environment:
      DJANGO_SETTINGS_MODULE: app.settings.production
      RUN_MIGRATIONS: "false"
    env_file:
      - .env.production
    depends_on:
      - redis
    deploy:
      replicas: 2

  celery-beat:
    image: wanti/backend:${IMAGE_TAG:-latest}
    restart: always
    command: celery -A app beat --loglevel=info --scheduler django_celery_beat.schedulers:DatabaseScheduler
    environment:
      DJANGO_SETTINGS_MODULE: app.settings.production
      RUN_MIGRATIONS: "false"
    env_file:
      - .env.production
    depends_on:
      - redis
    deploy:
      replicas: 1   # NUNCA más de 1

  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 512mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data

  nginx:
    image: nginx:1.27-alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./docker/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./docker/certs:/etc/nginx/certs:ro
      - static_volume:/var/www/staticfiles:ro
      - media_volume:/var/www/media:ro
    depends_on:
      - api

volumes:
  redis_data:
  static_volume:
  media_volume:
```

**Nota:** PostgreSQL en producción **no va como contenedor**. Usar servicio gestionado (RDS con extensión PostGIS, Cloud SQL, DigitalOcean Managed DB, Neon). Backups automáticos, replicación y patching quedan a cargo del proveedor.

---

## 4 · Variables de entorno de producción

Crear `.env.production` (nunca commiteado — usar secrets manager):

```bash
# Django
DJANGO_SECRET_KEY=<64+ chars, generado con secrets.token_urlsafe(64)>
DJANGO_DEBUG=false
DJANGO_ALLOWED_HOSTS=api.wanti.co,wanti.co
DJANGO_SETTINGS_MODULE=app.settings.production
CSRF_TRUSTED_ORIGINS=https://api.wanti.co,https://wanti.co
CORS_ALLOWED_ORIGINS=https://app.wanti.co,https://wanti.co

# Base de datos gestionada (RDS/Cloud SQL/Neon)
DB_ENGINE=django.contrib.gis.db.backends.postgis
DB_NAME=wanti_prod
DB_USER=wanti_app
DB_PASSWORD=<strong>
DB_HOST=wanti-prod.rds.amazonaws.com
DB_PORT=5432
DB_SSLMODE=require
DB_CONN_MAX_AGE=60

# Redis gestionado con TLS
REDIS_URL=rediss://:<password>@wanti-redis.example.com:6379/0
REDIS_PASSWORD=<strong>

# JWT
JWT_ACCESS_MINUTES=15
JWT_REFRESH_DAYS=7
JWT_SIGNING_KEY=<distinto del SECRET_KEY, generado con secrets.token_urlsafe(64)>

# Twilio
TWILIO_ACCOUNT_SID=<real>
TWILIO_AUTH_TOKEN=<real>
TWILIO_WHATSAPP_FROM=whatsapp:+573001234567
TWILIO_SMS_FROM=+573001234567
TWILIO_ENABLED=true

# Email transaccional (SendGrid / SES / Postmark)
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.sendgrid.net
EMAIL_PORT=587
EMAIL_HOST_USER=apikey
EMAIL_HOST_PASSWORD=<sendgrid-key>
EMAIL_USE_TLS=true
DEFAULT_FROM_EMAIL=no-reply@wanti.co
FRONTEND_BASE_URL=https://app.wanti.co

# Pasarela de pagos (producción)
PAYMENT_PROVIDER=<wompi|mercadopago|epayco|stripe>
PAYMENT_API_KEY=<real>
PAYMENT_WEBHOOK_SECRET=<hmac-secret>

# IA de imágenes
AI_IMAGE_PROVIDER=<openai|replicate|stability>
AI_IMAGE_API_KEY=<real>

# Storage de archivos (S3)
STORAGE_BACKEND=s3
AWS_ACCESS_KEY_ID=<iam-user>
AWS_SECRET_ACCESS_KEY=<iam-secret>
AWS_STORAGE_BUCKET_NAME=wanti-media-prod
AWS_S3_REGION_NAME=us-east-1
AWS_S3_CUSTOM_DOMAIN=cdn.wanti.co
AWS_QUERYSTRING_AUTH=false

# Sentry / observabilidad
SENTRY_DSN=<real>
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.1

# Logging
LOG_LEVEL=INFO
LOG_JSON=true
```

**Gestión de secretos en producción:**
- Nunca commitear `.env.production`.
- Usar **AWS Secrets Manager**, **Doppler**, **HashiCorp Vault** o el secrets store del orquestador (Kubernetes Secrets, Docker Swarm secrets).
- Rotar `DJANGO_SECRET_KEY`, `JWT_SIGNING_KEY` y credenciales de DB al menos una vez al año.

---

## 5 · Settings de producción y hardening

### 5.1 `app/settings/production.py`

```python
from .base import *
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration
from sentry_sdk.integrations.celery import CeleryIntegration

# ── Debug siempre false ─────────────────────────────────────
DEBUG = False
ALLOWED_HOSTS = os.environ['DJANGO_ALLOWED_HOSTS'].split(',')

# ── HTTPS obligatorio ───────────────────────────────────────
SECURE_SSL_REDIRECT = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
CSRF_TRUSTED_ORIGINS = os.environ['CSRF_TRUSTED_ORIGINS'].split(',')

# ── HSTS (1 año, incluir subdominios) ───────────────────────
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

# ── Anti-clickjacking, MIME-sniffing ────────────────────────
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
SECURE_REFERRER_POLICY = 'strict-origin-when-cross-origin'

# ── CORS estricto ───────────────────────────────────────────
CORS_ALLOWED_ORIGINS = os.environ['CORS_ALLOWED_ORIGINS'].split(',')
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOWED_METHODS = ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS']

# ── Password hashing con Argon2 ─────────────────────────────
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.Argon2PasswordHasher',
    'django.contrib.auth.hashers.PBKDF2PasswordHasher',
    'django.contrib.auth.hashers.BCryptSHA256PasswordHasher',
]

# ── Validadores de contraseña ───────────────────────────────
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
     'OPTIONS': {'min_length': 10}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
]

# ── DB con SSL obligatorio y pool ───────────────────────────
DATABASES['default'].update({
    'OPTIONS': {'sslmode': os.environ.get('DB_SSLMODE', 'require')},
    'CONN_MAX_AGE': int(os.environ.get('DB_CONN_MAX_AGE', 60)),
    'CONN_HEALTH_CHECKS': True,
})

# ── JWT con clave dedicada ──────────────────────────────────
SIMPLE_JWT['SIGNING_KEY'] = os.environ['JWT_SIGNING_KEY']

# ── Rate limiting endurecido ────────────────────────────────
REST_FRAMEWORK['DEFAULT_THROTTLE_RATES'].update({
    'login': '5/min',
    'otp_send': '3/hour',
    'otp_verify': '5/hour',
    'password_reset': '3/hour',
    'unlock_contact': '30/hour',
    'need_create': '10/day',
})

# ── Storage S3 ──────────────────────────────────────────────
if os.environ.get('STORAGE_BACKEND') == 's3':
    DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
    AWS_ACCESS_KEY_ID = os.environ['AWS_ACCESS_KEY_ID']
    AWS_SECRET_ACCESS_KEY = os.environ['AWS_SECRET_ACCESS_KEY']
    AWS_STORAGE_BUCKET_NAME = os.environ['AWS_STORAGE_BUCKET_NAME']
    AWS_S3_REGION_NAME = os.environ.get('AWS_S3_REGION_NAME', 'us-east-1')
    AWS_S3_CUSTOM_DOMAIN = os.environ.get('AWS_S3_CUSTOM_DOMAIN')
    AWS_DEFAULT_ACL = 'public-read'
    AWS_QUERYSTRING_AUTH = False

# ── Static files vía WhiteNoise si no hay CDN separado ──────
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
MIDDLEWARE.insert(1, 'whitenoise.middleware.WhiteNoiseMiddleware')

# ── Correlation ID middleware (trazabilidad) ────────────────
MIDDLEWARE.insert(0, 'apps.common.middleware.CorrelationIdMiddleware')

# ── Sentry ──────────────────────────────────────────────────
if os.environ.get('SENTRY_DSN'):
    sentry_sdk.init(
        dsn=os.environ['SENTRY_DSN'],
        environment=os.environ.get('SENTRY_ENVIRONMENT', 'production'),
        integrations=[DjangoIntegration(), CeleryIntegration()],
        traces_sample_rate=float(os.environ.get('SENTRY_TRACES_SAMPLE_RATE', 0.1)),
        send_default_pii=False,   # importante: no enviar PII al APM
    )

# ── Logging estructurado JSON ───────────────────────────────
LOGGING['formatters']['json'] = {
    '()': 'pythonjsonlogger.jsonlogger.JsonFormatter',
    'format': '%(asctime)s %(name)s %(levelname)s %(message)s',
}
for handler in LOGGING['handlers'].values():
    handler['formatter'] = 'json'
```

### 5.2 Middleware Correlation ID

Crear `apps/common/middleware.py`:

```python
import uuid
import logging

logger = logging.getLogger(__name__)


class CorrelationIdMiddleware:
    """
    Adjunta un correlation-id a cada request para trazabilidad end-to-end.
    Se propaga en logs y en headers de response.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        cid = request.headers.get('X-Correlation-Id') or str(uuid.uuid4())
        request.correlation_id = cid
        response = self.get_response(request)
        response['X-Correlation-Id'] = cid
        return response
```

---

## 6 · Nginx como reverse proxy

Crear `docker/nginx.conf`:

```nginx
upstream django_backend {
    server api:8000;
    keepalive 32;
}

# HTTP → HTTPS
server {
    listen 80;
    server_name api.wanti.co;
    return 301 https://$host$request_uri;
}

# HTTPS
server {
    listen 443 ssl http2;
    server_name api.wanti.co;

    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;

    client_max_body_size 10M;      # Uploads de evidencia hasta 10MB

    # Timeouts
    proxy_connect_timeout 10s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Compression
    gzip on;
    gzip_types application/json text/plain text/css application/javascript;
    gzip_min_length 1024;

    # Static files servidos directamente por nginx
    location /static/ {
        alias /var/www/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /var/www/media/;
        expires 7d;
    }

    # API
    location /api/ {
        proxy_pass http://django_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
    }

    # Rate limiting adicional a nivel nginx (defensa en profundidad)
    limit_req_zone $binary_remote_addr zone=login_zone:10m rate=10r/m;
    location /api/v1/auth/login/ {
        limit_req zone=login_zone burst=5 nodelay;
        proxy_pass http://django_backend;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health endpoint sin logs (evita ruido)
    location = /api/v1/health/ {
        access_log off;
        proxy_pass http://django_backend;
    }
}
```

**Certificados TLS:**
- Usar Let's Encrypt vía certbot con renovación automática.
- Alternativa: TLS termination en el load balancer (AWS ALB, DigitalOcean LB) — en ese caso, nginx puede escuchar solo en HTTP interno.

---

## 7 · Celery worker y beat

### 7.1 Configuración de colas por prioridad

En `app/celery.py`:

```python
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'app.settings.production')

app = Celery('wanti')
app.config_from_object('django.conf:settings', namespace='CELERY')

app.conf.task_routes = {
    # Alta prioridad: acciones que el usuario está esperando
    'apps.notifications.tasks.notify_contact_unlocked': {'queue': 'high'},
    'apps.notifications.tasks.notify_dispute_auto_ping': {'queue': 'high'},
    'apps.matching.tasks.run_match_for_need_task': {'queue': 'high'},

    # Media prioridad: procesos de fondo del sistema
    'apps.matching.tasks.run_match_for_item_task': {'queue': 'default'},
    'apps.notifications.tasks.notify_matches': {'queue': 'default'},

    # Baja prioridad: jobs periódicos
    'apps.leads.tasks.expire_stale_leads': {'queue': 'low'},
    'apps.needs.tasks.expire_stale_needs': {'queue': 'low'},
    'apps.wallet.tasks.reconcile_balances': {'queue': 'low'},
    'apps.disputes.tasks.check_auto_review_timeouts': {'queue': 'low'},
}

app.autodiscover_tasks()
```

### 7.2 Comandos de arranque

```bash
# Worker que consume 3 colas (alta, media, baja)
celery -A app worker \
    --loglevel=info \
    --queues=high,default,low \
    --concurrency=4 \
    --max-tasks-per-child=1000 \
    --time-limit=300 \
    --soft-time-limit=240

# Beat (nunca más de 1 instancia)
celery -A app beat \
    --loglevel=info \
    --scheduler django_celery_beat.schedulers:DatabaseScheduler
```

**Reglas operativas:**
- `--max-tasks-per-child=1000` evita memory leaks.
- `--time-limit=300` mata tasks colgadas después de 5 min.
- Cada worker debe montar el mismo código y `.env` que la API.

### 7.3 Retries y dead-letter

Las tasks críticas (webhooks de pago, notificaciones a Twilio) deben tener retry con backoff:

```python
@shared_task(bind=True, max_retries=5, default_retry_delay=60)
def complete_topup_from_webhook(self, order_id, payload):
    try:
        # lógica
    except Exception as exc:
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))
```

Tasks que agoten retries deben ir a una **dead-letter queue** para revisión manual.

---

## 8 · Backups y disaster recovery

### 8.1 Backups de base de datos

**Frecuencia:**
- Snapshot automático diario (retención 30 días).
- WAL archiving continuo (RPO ≤ 5 min).
- Snapshot semanal a bucket S3 en otra región (retención 6 meses).

**En un servicio gestionado (RDS/Cloud SQL):**
- Habilitar `automated backups` con retention window 30d.
- Point-in-time recovery activado.

**Backup manual (si se maneja PostgreSQL propio):**
```bash
docker exec wanti-postgres pg_dump -U postgres -Fc wanti_prod \
  > backups/wanti_prod_$(date +%Y%m%d_%H%M%S).dump

# Restauración
docker exec -i wanti-postgres pg_restore -U postgres -d wanti_prod \
  --clean --if-exists < backups/wanti_prod_20260720_020000.dump
```

### 8.2 Backups de media (S3)

- Versionado activado en el bucket.
- Replicación cross-region a un bucket secundario.
- Lifecycle policy: mover a Glacier objetos > 6 meses no accedidos.

### 8.3 Disaster recovery — RTO/RPO objetivos

| Métrica | Objetivo |
|---|---|
| RPO (Recovery Point Objective) | 5 minutos (WAL) |
| RTO (Recovery Time Objective) | 2 horas |

**Runbook de recuperación:**
1. Provisionar nueva DB desde último snapshot + WAL replay.
2. Levantar stack docker-compose con `.env.production`.
3. Verificar `/health` → todos los servicios OK.
4. DNS switch de `api.wanti.co` al nuevo IP.
5. Validar login, publicación de necesidad, unlock de contacto.

Practicar el runbook al menos **1 vez por trimestre**.

---

## 9 · Logging, monitoreo y métricas

### 9.1 Logs estructurados

Todos los logs en formato **JSON** con estos campos mínimos:

```json
{
  "timestamp": "2026-07-20T15:50:00.123Z",
  "level": "INFO",
  "logger": "apps.contacts.services.contacts",
  "message": "Contact unlocked",
  "correlation_id": "abc-123",
  "user_id": "0b6e1f0f-...",
  "action": "CONTACT_UNLOCKED",
  "entity_id": "unlock-uuid"
}
```

**Nunca loggear:**
- Contraseñas, códigos OTP en claro, tokens JWT completos.
- Datos personales completos (usar `user_id` en vez de email/teléfono).

### 9.2 Destinos de logs

- **Desarrollo:** stdout (visible con `docker logs`).
- **Producción:** stdout capturado por el orquestador y enviado a **CloudWatch / Loki / Datadog / Elasticsearch**.

### 9.3 Métricas clave (SLIs)

Exponer via Prometheus (`django-prometheus`):

| Métrica | Alerta |
|---|---|
| Latencia p95 de `/api/v1/matches/{id}/unlock/` | > 500 ms |
| Tasa de errores 5xx | > 1% en 5 min |
| Cola de Celery (`high`) | > 100 tasks pendientes |
| Tasa de disputas abiertas / unlocks | > 5% en 24h |
| Uso de CPU / memoria en workers | > 80% sostenido |
| Latencia de replicación DB | > 30 s |

### 9.4 APM y trazas

**Sentry** (ya configurado en `production.py`) captura:
- Excepciones no manejadas
- Trazas de performance (10% sample rate)
- Contexto de usuario (id, correlation_id)
- Breadcrumbs (últimas queries, HTTP calls)

### 9.5 Alertas críticas

Configurar en el sistema de alertas (PagerDuty/Opsgenie):

- `/health` devuelve 5xx durante > 2 min → **P1**
- Diferencia en reconciliación de wallets detectada → **P1**
- Certificado TLS a menos de 15 días de expirar → **P2**
- Task de Celery beat no ejecutada en > 24h → **P2**
- Disputa abierta > 96h sin resolver → **P3**

---

## 10 · Deployment estrategias

### 10.1 Flujo git → deploy

```
feature/*  →  develop  →  main  →  tag v1.x.y  →  build image  →  deploy prod
                 │
                 └──────→  deploy staging (automático)
```

### 10.2 Pipeline CI/CD (GitHub Actions)

`.github/workflows/deploy.yml`:

```yaml
name: Build and Deploy

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgis/postgis:16-3.4
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: wanti_test
        ports: [5432:5432]
        options: --health-cmd pg_isready
      redis:
        image: redis:7-alpine
        ports: [6379:6379]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: '3.12'}
      - run: |
          pip install -r requirements.txt
          pip install -r requirements-dev.txt
          python manage.py migrate --noinput
          python manage.py test
          ruff check .
          bandit -r apps/ -ll

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ghcr.io/valfora/wanti-backend:${{ github.ref_name }}
            ghcr.io/valfora/wanti-backend:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to prod
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.PROD_HOST }}
          username: deploy
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/wanti
            export IMAGE_TAG=${{ github.ref_name }}
            docker compose -f docker-compose.prod.yml pull
            docker compose -f docker-compose.prod.yml up -d --no-build --remove-orphans
            docker system prune -f
```

### 10.3 Rolling deploy (zero-downtime)

Con 2+ réplicas de `api`:

1. `docker compose pull` la nueva imagen.
2. Reiniciar réplicas una por una (`docker compose up -d --scale api=3` temporalmente, luego bajar la vieja).
3. Nginx sigue enrutando a la instancia viva mientras la otra se recicla.
4. Migraciones idempotentes garantizan que **corran en el arranque de la primera instancia solamente** (flag `RUN_MIGRATIONS=true` en solo 1 replica).

### 10.4 Rollback

```bash
# Retag a la versión anterior
export IMAGE_TAG=v1.4.2   # versión previa estable
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

**Regla:** las migraciones que rompen compatibilidad hacia atrás deben desplegarse en **dos releases separados**:
- Release N: agregar campo nuevo, código lee ambos.
- Release N+1: eliminar campo viejo.

Esto permite rollback sin restaurar backup.

---

## 11 · Comandos operativos frecuentes

### 11.1 Levantar todo el stack (dev)

```bash
docker compose up -d
docker compose logs -f api
docker compose exec api python manage.py createsuperuser
```

### 11.2 Migraciones

```bash
docker compose exec api python manage.py makemigrations
docker compose exec api python manage.py migrate
docker compose exec api python manage.py showmigrations
```

### 11.3 Shell de Django

```bash
docker compose exec api python manage.py shell
# o con IPython
docker compose exec api python manage.py shell -i ipython
```

### 11.4 Ejecutar tests

```bash
docker compose exec api python manage.py test
docker compose exec api pytest apps/wallet -v
docker compose exec api coverage run -m pytest && coverage report
```

### 11.5 Regenerar OpenAPI schema

```bash
docker compose exec api python manage.py spectacular --file schema.yml
```

### 11.6 Ejecutar una task manualmente

```bash
docker compose exec api python manage.py shell -c "
from apps.matching.tasks import run_match_for_need_task
run_match_for_need_task.delay('<need-uuid>')
"
```

### 11.7 Ver colas y workers de Celery

```bash
docker compose exec celery-worker celery -A app inspect active
docker compose exec celery-worker celery -A app inspect scheduled
docker compose exec celery-worker celery -A app inspect stats
```

### 11.8 Reconciliación manual de wallets

```bash
docker compose exec api python manage.py shell -c "
from apps.wallet.tasks import reconcile_balances
reconcile_balances()
"
```

### 11.9 Backup manual pre-deploy

```bash
docker exec wanti-postgres pg_dump -U postgres -Fc wanti_prod \
  | gzip > backup_pre_deploy_$(date +%Y%m%d_%H%M).dump.gz
```

---

## 12 · Checklist de release

Antes de cada deploy a producción:

### Pre-deploy
- [ ] Todos los tests pasan en CI (`unit` + `integration`)
- [ ] `ruff check` sin warnings
- [ ] `bandit -r apps/` sin issues de severidad alta
- [ ] Migraciones revisadas manualmente — sin operaciones destructivas sin plan
- [ ] Cambios de `SystemSetting` documentados en el PR
- [ ] Changelog actualizado
- [ ] Backup manual de DB tomado
- [ ] Nuevas variables de entorno agregadas al secret store
- [ ] Load test corrido si hay cambios en el motor de match o wallet

### Deploy
- [ ] Tag creado: `git tag v1.x.y && git push --tags`
- [ ] Pipeline CI/CD termina exitoso
- [ ] Imagen publicada en el registry
- [ ] `docker compose pull && up -d` ejecutado en prod
- [ ] Migraciones aplicadas sin errores
- [ ] `/api/v1/health/` responde 200

### Post-deploy (validación manual)
- [ ] Login funciona
- [ ] Publicar una necesidad de prueba y verificar match generado
- [ ] Recarga sandbox → confirmar wallet actualizado
- [ ] Unlock de un match de prueba → confirmar deep link WhatsApp
- [ ] Alertas de Sentry sin picos anómalos en 10 min
- [ ] Latencia p95 estable en Grafana/Datadog

### Rollback (si falla algo crítico)
- [ ] Retag a versión previa
- [ ] `docker compose pull && up -d`
- [ ] Verificar `/health`
- [ ] Post-mortem programado

---

## 13 · Checklist maestro del proyecto

Alcance completo del backend (todos los `.md` combinados):

### Setup y estructura (`00-setup-inicial.md`)
- [ ] Python 3.12+, GDAL/GEOS/PROJ instalados
- [ ] PostgreSQL 16 + PostGIS 3.4 corriendo
- [ ] Redis 7 corriendo
- [ ] Estructura de 15 apps de dominio creada
- [ ] `settings/` dividido en `base/local/production/logging`
- [ ] `.env` configurado

### Modelos (`01-modelos.md`)
- [ ] 13 apps con sus ~35 modelos definidos
- [ ] Constantes centralizadas en `apps/common/constants.py`
- [ ] `SystemSetting` con fixture inicial de 12 keys
- [ ] Data migrations para `TopupPackage` y `ReviewTag`
- [ ] Todos los `db_table`, `indexes` y `constraints` declarados
- [ ] Migraciones aplicadas limpias en DB nueva

### Servicios (`02-servicios.md`)
- [ ] `apps/common/exceptions.py` con jerarquía de errores
- [ ] `audit.services.audit_log` funciona
- [ ] `users.services`: registro, verificación, suspensión, update perfil con whitelist
- [ ] `authn.services`: email verify, OTP con hash, password reset, JWT
- [ ] `wallet.services.apply_transaction` con `select_for_update`
- [ ] `wallet.services.complete_topup_order` idempotente
- [ ] `needs.services`: create, publish, pause, resume, delete
- [ ] `inventory.services`: create, mark_as_sold, generate_ai_images
- [ ] `matching.services.scoring.score_pair` cubierto por tests
- [ ] `matching.services.engine.run_match_for_need` usando PostGIS
- [ ] `contacts.services.unlock_contact` idempotente + crea Lead
- [ ] `disputes.services`: open, auto_review, escalate, approve, reject, cancel, appeal
- [ ] `reviews.services`: create, dispute, resolve_dispute, recompensa por volumen
- [ ] `leads.services`: create_from_unlock, change_stage, add_note
- [ ] `notifications.services.dispatcher.dispatch`
- [ ] Todas las mutaciones sensibles emiten `AuditLog`
- [ ] Ningún parámetro de negocio hardcodeado (leído de `SystemSetting`)

### Endpoints (`03-endpoints.md`)
- [ ] ~90 endpoints implementados en sus URLs
- [ ] Views thin — delegan a servicios
- [ ] Serializers con `Meta.fields` explícito
- [ ] Filtros con `django_filter`
- [ ] Paginación en todos los listados
- [ ] Códigos HTTP y formato de errores consistentes
- [ ] Webhook de pagos valida HMAC
- [ ] Throttling configurado por scope
- [ ] `/api/docs/` (OpenAPI Swagger) accesible
- [ ] Matriz de permisos validada endpoint por endpoint

### Docker y producción (`04-docker-y-despliegue.md`)
- [ ] `Dockerfile` multi-stage con usuario no-root
- [ ] `docker-compose.yml` (dev) y `docker-compose.prod.yml` funcionan
- [ ] Solo 1 replica de `celery-beat`
- [ ] Colas Celery por prioridad (high/default/low)
- [ ] Nginx reverse proxy con TLS y rate limiting
- [ ] `.env.production` en secrets manager
- [ ] `settings/production.py` con HSTS, CORS estricto, Argon2, SSL DB
- [ ] Sentry configurado con `send_default_pii=False`
- [ ] Correlation ID middleware activo
- [ ] Logs en JSON estructurado
- [ ] Backup DB diario + WAL archiving
- [ ] Storage S3 con versionado
- [ ] CI/CD pipeline funcionando
- [ ] Runbook de disaster recovery documentado
- [ ] Alertas P1/P2/P3 configuradas

---

## 14 · Historias de usuario del contrato — matriz de cumplimiento

Trazabilidad HUS → módulos implementados:

| HUS | Descripción | App | Endpoint(s) |
|---|---|---|---|
| HUS01 | Comprador se registra con email + password | `authn` | `POST /auth/register/` |
| HUS02 | Vendedor se registra con email + password | `authn` | `POST /auth/register/` (mismo — rol único) |
| HUS03 | Login con credenciales | `authn` | `POST /auth/login/` |
| HUS04 | Recuperación de contraseña | `authn` | `POST /auth/password/reset-request/`, `POST /auth/password/reset-confirm/` |
| HUS05 | Comprador crea solicitud vehículo/inmueble | `needs` | `POST /needs/` |
| HUS06 | Registra presupuesto, criterios, ubicación | `needs` | `POST /needs/` payload completo |
| HUS07 | Carga imágenes de referencia | `needs` | `NeedImage` en el payload |
| HUS08 | Edita solicitudes activas | `needs` | `PATCH /needs/{id}/` |
| HUS09 | Elimina solicitudes | `needs` | `DELETE /needs/{id}/` (soft delete) |
| HUS10 | Visualiza estado y ofertas recibidas | `needs`, `matching` | `GET /needs/{id}/`, `GET /matches/?need_id=` |
| HUS11 | Vendedor navega solicitudes | `needs` | `GET /needs/?scope=browse` |
| HUS12 | Filtra por presupuesto, ubicación, tipo | `needs` | Query params en `/needs/?scope=browse` |
| HUS13 | Visualiza detalle de una solicitud | `needs` | `GET /needs/{id}/` |
| HUS14 | Identifica solicitudes compatibles | `matching` | Motor de match automático + `GET /matches/?role=seller` |
| HUS15 | Vendedor "envía una oferta" | **Adaptado**: motor de match reemplaza el envío manual — el sistema genera el vínculo automáticamente. El vendedor solo espera notificación de match. |
| HUS16 | Vendedor adjunta info/imágenes del bien | `inventory` | `POST /inventory/`, `InventoryImage` |
| HUS17 | Visualiza estado de matches enviados | `matching` | `GET /matches/?role=seller` |
| HUS18 | **Comprador paga para desbloquear contacto** (adaptado del contrato: en el modelo B, quien paga es el comprador) | `contacts`, `wallet` | `POST /wallet/topups/`, `POST /matches/{id}/unlock/` |
| HUS19 | Sistema valida el pago | `wallet` | `POST /wallet/topups/webhook/` con HMAC |
| HUS20 | Acceso al contacto tras pago | `contacts` | Response de `POST /matches/{id}/unlock/` |
| HUS21 | Historial de pagos | `wallet` | `GET /wallet/transactions/` |
| HUS22 | IA genera imágenes optimizadas | `inventory` | `POST /inventory/{id}/generate-ai-image/` |
| HUS23 | Vendedor selecciona imágenes IA | `inventory` | `POST /inventory/{id}/images/select-ai/` |
| HUS24 | IA sugiere coincidencias | `matching` | Motor de scoring con PostGIS |
| HUS25 | Admin visualiza métricas | `admin_panel` | `GET /admin/metrics/` |
| HUS26 | Admin gestiona usuarios | `admin_panel` | `GET /admin/users/`, suspend/activate |
| HUS27 | Admin gestiona solicitudes | `admin_panel` | `GET /admin/needs/`, flag/unpublish |
| HUS28 | Admin gestiona inventario del vendedor | `admin_panel` | `GET /admin/inventory/` |
| HUS29 | Admin valida pagos | `admin_panel` | `GET /admin/topups/` |
| HUS30 | Admin modera contenido | `admin_panel` | Flag needs, resolve review disputes |
| HUS31 | Sistema registra eventos | `audit` | `AuditLog` en cada acción sensible |
| HUS32 | Admin visualiza reportes de conversión | `admin_panel` | `GET /admin/reports/interactions/` |
| HUS33 | Admin visualiza métricas de match | `admin_panel` | `GET /admin/reports/matching/` |

**Notas de adaptación:**
- **HUS15**: el contrato original habla de "enviar oferta" — el modelo B implementado no tiene envío manual sino generación automática por scoring. El vendedor recibe la notificación de match como el equivalente semántico.
- **HUS18**: el contrato dice "vendedor paga" — la decisión estratégica del cliente (opción B) invirtió esto: el comprador paga con Wantis. Esta adaptación fue confirmada explícitamente y está reflejada en todo el diseño.

---

## 15 · Roadmap sugerido de implementación

Orden recomendado de sprints:

**Sprint 1** — Fundamentos
- Setup completo (`00`)
- Modelos base: User, Wallet, SystemSetting, AuditLog
- Autenticación completa (registro, login, verificación email + OTP, reset password)
- Endpoint `/health`

**Sprint 2** — Necesidades e inventario
- Modelos: Need, VehicleNeed, PropertyNeed, NeedCriterion, NeedImage
- Modelos: InventoryItem, VehicleItem, PropertyItem, InventoryImage
- Servicios y endpoints CRUD de `/needs` y `/inventory`
- Vista `?scope=browse` para HUS11-14

**Sprint 3** — Motor de match y notificaciones
- Modelos: Match, MatchCriterionResult
- Servicio `scoring.py` (algoritmo puro) + tests exhaustivos
- Servicio `engine.py` con PostGIS
- Celery tasks de matching
- Dispatcher de notificaciones + registro en DB (canal PUSH mock)

**Sprint 4** — Wallet y desbloqueo
- Modelos: WalletTransaction, TopupPackage, TopupOrder, ContactUnlock, Lead
- Ledger transaccional con `apply_transaction`
- Endpoint `/wallet/topups/` + webhook mock
- Endpoint `/matches/{id}/unlock/`
- CRM básico de leads

**Sprint 5** — Disputas y reseñas
- Modelos: Dispute, DisputeAttachment, DisputeEvent, Review, ReviewTag, ReviewDispute
- Flujo completo de disputas con auto-review y escalada
- Sistema de calificaciones bidireccional

**Sprint 6** — Panel admin y observabilidad
- Endpoints de admin (métricas, gestión, moderación, reportes)
- Logging JSON estructurado
- Sentry integrado
- Middleware de correlation-id
- Dockerización completa

**Sprint 7** — Hardening y producción
- Settings de producción con hardening completo
- Nginx + TLS
- CI/CD
- Backups automáticos
- Runbook de disaster recovery
- Load testing y ajustes de índices

**Sprint 8** — Integraciones reales (fase 2)
- Pasarela de pagos real (Wompi/MercadoPago/etc.)
- Twilio real para OTP en producción
- Provider real de generación de imágenes IA (OpenAI DALL-E / Stability / Replicate)
- Push notifications reales (FCM + APNs)

---

## ➡️ Cierre

Este es el archivo final del setup. Con los 4 `.md` combinados el equipo de desarrollo tiene:

1. **`00-setup-inicial.md`** — configuración del entorno, dependencias, constantes y modelo base
2. **`01-modelos.md`** — 35+ modelos de dominio con todas sus relaciones
3. **`02-servicios.md`** — lógica de negocio, motor de match, wallet transaccional, flujos automáticos
4. **`03-endpoints.md`** — contratos completos de API REST
5. **`04-docker-y-despliegue.md`** — dockerización, hardening producción, monitoreo, CI/CD

**Alineación con requerimientos contractuales:** 33 de 33 historias de usuario cubiertas, con dos adaptaciones documentadas (HUS15 y HUS18) confirmadas por el cliente.

---
