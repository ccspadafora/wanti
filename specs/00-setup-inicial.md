# Backend Django (DRF) — Wanti Reverse Marketplace

## Guía de Implementación Paso a Paso

**Modelo de negocio:** Reverse marketplace. El comprador publica su necesidad, el motor de match sugiere vendedores compatibles, y **el comprador paga con Wantis para desbloquear el contacto del vendedor**.

**Cliente:** Valfora Holdings S.A.S. / Sense Digital S.A.S.
**Versión del documento:** 1.0
**Fecha:** Julio 2026
**Confidencialidad:** Alta / Restringido

---

## 📋 Objetivo

Construir un backend base funcional y seguro que incluya:

- Django 5.x + Django REST Framework
- PostgreSQL **+ PostGIS** (consultas geoespaciales para el motor de match)
- Autenticación estándar (email + password + JWT)
- Verificación de email + OTP telefónico (WhatsApp/SMS vía Twilio)
- Gestión completa de usuarios con rol dual (comprador y vendedor simultáneos)
- Módulo de necesidades (vehículos e inmuebles) con criterios obligatorios y preferencias
- Motor de match con scoring geoespacial
- Wallet interno con moneda "Wantis"
- Módulo de disputas con flujo de revisión automática y humana
- Sistema de calificaciones y reseñas bidireccional
- CRM interno de leads para vendedores
- Auditoría de acciones sensibles
- Endpoint `/api/v1/health` con validación de DB
- Celery + Redis para tareas asíncronas (matching, notificaciones, caducidades)
- Dockerización (API + DB + Redis + Celery worker + Celery beat)

### ⚠️ Alcance explícito de esta fase

**SÍ se implementa:**
- Autenticación completa (registro, login, recuperación de contraseña, verificación email, OTP)
- CRUD de necesidades de compra
- Perfil de inventario del vendedor
- Motor de match con scoring
- Wallet y transacciones de Wantis
- Desbloqueo de contactos
- Disputas y reembolsos
- Calificaciones y reseñas
- CRM de leads
- Panel administrativo (endpoints)

**NO se implementa en esta fase:**
- Integración real con pasarela de pagos (se deja el contrato de API preparado y un modo sandbox)
- Generación real de imágenes por IA (se deja el servicio abstracto con implementación mock)
- Notificaciones push reales (se deja el servicio abstracto y se registran en DB)
- Frontend / app móvil

---

## 🔧 Paso 0: Pre-requisitos

```bash
# Verificar Python 3.12+
python --version

# Docker y Docker Compose
docker --version
docker-compose --version
```

**Requisitos:**
- ✅ Python 3.12+
- ✅ Docker + Docker Compose
- ✅ PostgreSQL 15+ con extensión PostGIS 3.4+
- ✅ Redis 7+
- ✅ GDAL / GEOS / PROJ (librerías de sistema para GeoDjango)

---

## 📁 Paso 1: Crear Estructura del Proyecto (Domain-First)

### 1.1 Crear directorio base

```bash
mkdir -p backend
cd backend
```

### 1.2 Crear estructura de directorios

```bash
# Configuración
mkdir -p app/settings

# Apps de dominio
mkdir -p apps/{common,audit,users,authn,health}
mkdir -p apps/{needs,inventory,matching,wallet,contacts,disputes,reviews,leads,notifications,admin_panel}

# Subdirectorios de servicios y selectors
for app in users needs inventory matching wallet contacts disputes reviews leads notifications admin_panel; do
  mkdir -p apps/$app/services
  mkdir -p apps/$app/selectors
done

mkdir -p apps/audit/services
mkdir -p apps/authn/services
mkdir -p apps/common/{services,integrations}

# Integraciones externas
mkdir -p apps/common/integrations/{twilio,payments,ai_images,push}

# Crear __init__.py en todos lados
find app apps -type d -exec touch {}/__init__.py \;
```

### 1.3 Estructura final esperada

```
backend/
├── app/
│   ├── __init__.py
│   ├── celery.py
│   ├── settings/
│   │   ├── __init__.py
│   │   ├── base.py
│   │   ├── local.py
│   │   ├── production.py
│   │   └── logging.py
│   ├── urls.py
│   ├── asgi.py
│   └── wsgi.py
├── apps/
│   ├── common/
│   │   ├── constants.py
│   │   ├── exceptions.py
│   │   ├── pagination.py
│   │   ├── permissions.py
│   │   ├── utils.py
│   │   ├── models.py           # BaseModel abstracto (uuid, timestamps)
│   │   ├── services/
│   │   │   └── settings_service.py    # lee parámetros del sistema desde DB
│   │   └── integrations/
│   │       ├── twilio/
│   │       │   ├── client.py
│   │       │   └── otp.py
│   │       ├── payments/
│   │       │   ├── base.py            # interfaz abstracta
│   │       │   └── sandbox.py         # implementación de pruebas
│   │       ├── ai_images/
│   │       │   ├── base.py
│   │       │   └── mock.py
│   │       └── push/
│   │           ├── base.py
│   │           └── db_logger.py       # registra push en DB (fase 1)
│   ├── audit/
│   │   ├── models.py
│   │   ├── admin.py
│   │   └── services/audit_log.py
│   ├── users/
│   │   ├── models.py
│   │   ├── admin.py
│   │   ├── permissions.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── selectors/users.py
│   │   └── services/users.py
│   ├── authn/
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   └── services/
│   │       ├── jwt.py
│   │       ├── email_verification.py
│   │       ├── otp.py
│   │       └── password_reset.py
│   ├── needs/                  # Necesidades publicadas por compradores
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── selectors/needs.py
│   │   └── services/needs.py
│   ├── inventory/              # Perfil de inventario del vendedor
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── selectors/inventory.py
│   │   └── services/inventory.py
│   ├── matching/               # Motor de match
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── tasks.py            # Celery tasks
│   │   ├── selectors/matches.py
│   │   └── services/
│   │       ├── scoring.py      # algoritmo de afinidad
│   │       └── engine.py       # orquestador del match
│   ├── wallet/                 # Wantis, recargas, transacciones
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── selectors/wallet.py
│   │   └── services/
│   │       ├── wallet.py
│   │       └── packages.py     # paquetes de recarga con bonificación
│   ├── contacts/               # Desbloqueo de contactos
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── selectors/contacts.py
│   │   └── services/contacts.py
│   ├── disputes/               # Disputas y reembolsos
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── tasks.py
│   │   ├── selectors/disputes.py
│   │   └── services/disputes.py
│   ├── reviews/                # Calificaciones y reseñas
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── selectors/reviews.py
│   │   └── services/reviews.py
│   ├── leads/                  # CRM interno del vendedor
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── tasks.py
│   │   ├── selectors/leads.py
│   │   └── services/leads.py
│   ├── notifications/          # Push, email, WhatsApp
│   │   ├── models.py
│   │   ├── tasks.py
│   │   └── services/dispatcher.py
│   ├── admin_panel/            # Endpoints administrativos
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   └── selectors/metrics.py
│   └── health/
│       ├── views.py
│       └── urls.py
├── manage.py
├── requirements.txt
├── .env.example
├── Dockerfile
└── docker-compose.yml
```

---

## 📦 Paso 2: Configurar Dependencias

### 2.1 Crear `requirements.txt`

```bash
cat > requirements.txt << 'EOF'
Django>=5.2
djangorestframework>=3.15
djangorestframework-simplejwt>=5.3
djangorestframework-gis>=1.1
psycopg[binary]>=3.2
python-dotenv>=1.0
celery>=5.3
django-celery-beat>=2.6
redis>=5.0
django-cors-headers>=4.4
django-filter>=24.3
gunicorn>=22.0
drf-spectacular>=0.27
twilio>=9.0
Pillow>=10.4
django-storages>=1.14
boto3>=1.35
EOF
```

### 2.2 Instalar dependencias

```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

**Nota GeoDjango:** en macOS instalar librerías nativas antes:
```bash
brew install gdal geos proj
```
En Linux (Debian/Ubuntu):
```bash
sudo apt-get install binutils libproj-dev gdal-bin libgdal-dev
```

---

## ⚙️ Paso 3: Variables de Entorno

### 3.1 Crear `.env.example`

```bash
cat > .env.example << 'EOF'
# Django
DJANGO_SECRET_KEY=change_me
DJANGO_DEBUG=true
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
DJANGO_SETTINGS_MODULE=app.settings.local

# Base de datos (PostGIS)
DATABASE_URL=postgis://postgres:postgres@localhost:5432/wanti_db

# Redis / Celery
REDIS_URL=redis://localhost:6379/0

# JWT
JWT_ACCESS_MINUTES=15
JWT_REFRESH_DAYS=7

# Twilio (OTP WhatsApp/SMS)
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_WHATSAPP_FROM=whatsapp:+14155238886
TWILIO_SMS_FROM=+15005550006
TWILIO_ENABLED=false

# Email
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
DEFAULT_FROM_EMAIL=no-reply@wanti.co
FRONTEND_BASE_URL=http://localhost:3000

# Pasarela de pagos
PAYMENT_PROVIDER=sandbox
PAYMENT_API_KEY=
PAYMENT_WEBHOOK_SECRET=

# IA de imágenes
AI_IMAGE_PROVIDER=mock
AI_IMAGE_API_KEY=

# Almacenamiento de archivos
STORAGE_BACKEND=local
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_STORAGE_BUCKET_NAME=

# Logging
LOG_LEVEL=INFO
EOF

cp .env.example .env
```

---

## 🚀 Paso 4: Inicializar Proyecto Django

```bash
django-admin startproject app .
mv app/settings.py app/settings/base.py
touch app/settings/{local.py,production.py,logging.py}
```

---

## ⚙️ Paso 5: Configurar Settings

### 5.1 `app/settings/base.py`

**Tareas a realizar:**

1. **Cargar variables de entorno:**
```python
from dotenv import load_dotenv
import os
from pathlib import Path
load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent.parent
```

2. **INSTALLED_APPS:**
```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.gis',              # GeoDjango — OBLIGATORIO

    # Third party
    'rest_framework',
    'rest_framework_gis',
    'corsheaders',
    'drf_spectacular',
    'django_filters',
    'django_celery_beat',

    # Local apps
    'apps.common',
    'apps.audit',
    'apps.users',
    'apps.authn',
    'apps.health',
    'apps.needs',
    'apps.inventory',
    'apps.matching',
    'apps.wallet',
    'apps.contacts',
    'apps.disputes',
    'apps.reviews',
    'apps.leads',
    'apps.notifications',
    'apps.admin_panel',
]
```

3. **AUTH_USER_MODEL:**
```python
AUTH_USER_MODEL = 'users.User'
```

4. **Base de datos con PostGIS:**
```python
import dj_database_url  # o parseo manual de DATABASE_URL

DATABASES = {
    'default': {
        'ENGINE': 'django.contrib.gis.db.backends.postgis',
        'NAME': os.getenv('DB_NAME', 'wanti_db'),
        'USER': os.getenv('DB_USER', 'postgres'),
        'PASSWORD': os.getenv('DB_PASSWORD', 'postgres'),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
    }
}
```

5. **DRF:**
```python
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_PAGINATION_CLASS': 'apps.common.pagination.StandardPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ),
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    'DEFAULT_THROTTLE_CLASSES': (
        'rest_framework.throttling.ScopedRateThrottle',
    ),
    'DEFAULT_THROTTLE_RATES': {
        'login': '10/min',
        'otp_send': '5/hour',
        'otp_verify': '10/hour',
        'password_reset': '5/hour',
        'need_create': '20/day',
    },
}

from datetime import timedelta
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=int(os.getenv('JWT_ACCESS_MINUTES', 15))),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=int(os.getenv('JWT_REFRESH_DAYS', 7))),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
}
```

6. **Celery:**
```python
CELERY_BROKER_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
CELERY_RESULT_BACKEND = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TIMEZONE = 'America/Bogota'
CELERY_BEAT_SCHEDULER = 'django_celery_beat.schedulers:DatabaseScheduler'
```

7. **Localización:**
```python
LANGUAGE_CODE = 'es-co'
TIME_ZONE = 'America/Bogota'
USE_I18N = True
USE_TZ = True
```

8. **Logging centralizado sin secretos** (en `app/settings/logging.py`)

### 5.2 `app/settings/__init__.py`

```python
from .base import *
from .logging import *
```

---

## 🗄️ Paso 6: Modelo Base Común

### 6.1 Crear `apps/common/models.py`

```python
import uuid
from django.db import models


class BaseModel(models.Model):
    """Modelo base con UUID y timestamps para toda la aplicación."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
        ordering = ['-created_at']
```

### 6.2 Crear `apps/common/constants.py`

**Definir todas las TextChoices del sistema:**

```python
from django.db import models


class IdType(models.TextChoices):
    CC = 'CC', 'Cédula de Ciudadanía'
    CE = 'CE', 'Cédula de Extranjería'
    PASSPORT = 'PASSPORT', 'Pasaporte'
    NIT = 'NIT', 'NIT'


class UserRole(models.TextChoices):
    USER = 'USER', 'Usuario'          # comprador y/o vendedor
    ADMIN = 'ADMIN', 'Administrador'
    MODERATOR = 'MODERATOR', 'Moderador'


class UserStatus(models.TextChoices):
    PENDING = 'PENDING', 'Pendiente de verificación'
    ACTIVE = 'ACTIVE', 'Activo'
    SUSPENDED = 'SUSPENDED', 'Suspendido'


class AssetType(models.TextChoices):
    VEHICLE = 'VEHICLE', 'Vehículo'
    PROPERTY = 'PROPERTY', 'Inmueble'


class PaymentType(models.TextChoices):
    CASH = 'CASH', 'Contado'
    CREDIT = 'CREDIT', 'Crédito'
    TRADE_IN = 'TRADE_IN', 'Permuta'


class CriterionMode(models.TextChoices):
    REQUIRED = 'REQUIRED', 'Obligatorio'
    PREFERRED = 'PREFERRED', 'Preferencia'


class NeedStatus(models.TextChoices):
    DRAFT = 'DRAFT', 'Borrador'
    ACTIVE = 'ACTIVE', 'Activa'
    PAUSED = 'PAUSED', 'Pausada'
    EXPIRED = 'EXPIRED', 'Expirada'
    FULFILLED = 'FULFILLED', 'Cumplida'
    DELETED = 'DELETED', 'Eliminada'


class InventoryStatus(models.TextChoices):
    AVAILABLE = 'AVAILABLE', 'Disponible'
    RESERVED = 'RESERVED', 'Reservado'
    SOLD = 'SOLD', 'Vendido'
    INACTIVE = 'INACTIVE', 'Inactivo'


class MatchStatus(models.TextChoices):
    GENERATED = 'GENERATED', 'Generado'
    VIEWED = 'VIEWED', 'Visto por el comprador'
    UNLOCKED = 'UNLOCKED', 'Contacto desbloqueado'
    DISCARDED = 'DISCARDED', 'Descartado'


class TransactionType(models.TextChoices):
    TOPUP = 'TOPUP', 'Recarga'
    BONUS = 'BONUS', 'Bonificación por volumen'
    UNLOCK = 'UNLOCK', 'Desbloqueo de contacto'
    REFUND = 'REFUND', 'Reembolso por disputa'
    ADJUSTMENT = 'ADJUSTMENT', 'Ajuste administrativo'
    REWARD = 'REWARD', 'Recompensa por calificar'


class TopupStatus(models.TextChoices):
    PENDING = 'PENDING', 'Pendiente'
    COMPLETED = 'COMPLETED', 'Completada'
    FAILED = 'FAILED', 'Fallida'
    REFUNDED = 'REFUNDED', 'Reembolsada'


class ContactOutcome(models.TextChoices):
    PENDING = 'PENDING', 'Sin confirmar'
    PURCHASED = 'PURCHASED', 'Compré'
    IN_PROGRESS = 'IN_PROGRESS', 'En proceso'
    NOT_PURCHASED = 'NOT_PURCHASED', 'No compré'
    INVALID_LEAD = 'INVALID_LEAD', 'Lead inválido'


class DisputeReason(models.TextChoices):
    CONTACT_INVALID = 'CONTACT_INVALID', 'El contacto no existe o es inválido'
    NO_RESPONSE = 'NO_RESPONSE', 'El vendedor no responde'
    ASSET_UNAVAILABLE = 'ASSET_UNAVAILABLE', 'El bien ya no está disponible'
    FALSE_INFO = 'FALSE_INFO', 'Información falsa o engaños'
    OTHER = 'OTHER', 'Otro motivo'


class DisputeStatus(models.TextChoices):
    OPEN = 'OPEN', 'Disputa abierta'
    AUTO_REVIEW = 'AUTO_REVIEW', 'Verificación automática'
    HUMAN_REVIEW = 'HUMAN_REVIEW', 'Revisión humana'
    APPROVED = 'APPROVED', 'Aprobada — reembolso emitido'
    REJECTED = 'REJECTED', 'Rechazada'
    APPEALED = 'APPEALED', 'Apelada'
    CANCELLED = 'CANCELLED', 'Cancelada por el usuario'


class ReviewStatus(models.TextChoices):
    PUBLISHED = 'PUBLISHED', 'Publicada'
    UNDER_REVIEW = 'UNDER_REVIEW', 'En revisión'
    REMOVED = 'REMOVED', 'Eliminada'


class LeadStage(models.TextChoices):
    NEW = 'NEW', 'Nuevo'
    IN_NEGOTIATION = 'IN_NEGOTIATION', 'En negociación'
    TO_VISIT = 'TO_VISIT', 'Por visitar'
    PURCHASED = 'PURCHASED', 'Comprado'
    DISCARDED = 'DISCARDED', 'Descartado'
    EXPIRED = 'EXPIRED', 'Caducado'


class NotificationChannel(models.TextChoices):
    PUSH = 'PUSH', 'Push'
    EMAIL = 'EMAIL', 'Email'
    WHATSAPP = 'WHATSAPP', 'WhatsApp'
    SMS = 'SMS', 'SMS'


class OtpChannel(models.TextChoices):
    WHATSAPP = 'WHATSAPP', 'WhatsApp'
    SMS = 'SMS', 'SMS'


# ── Parámetros del sistema (claves para SystemSetting) ──
class SettingKey:
    WANTI_PRICE_COP = 'WANTI_PRICE_COP'                   # default 5000
    NEED_DURATION_DAYS = 'NEED_DURATION_DAYS'             # default 30
    LEAD_EXPIRY_DAYS = 'LEAD_EXPIRY_DAYS'                 # default 30
    MATCH_HIGH_THRESHOLD = 'MATCH_HIGH_THRESHOLD'         # default 85
    MATCH_MIN_SCORE = 'MATCH_MIN_SCORE'                   # default 50
    MATCH_RADIUS_KM = 'MATCH_RADIUS_KM'                   # default 50
    MIN_BUDGET_RATIO = 'MIN_BUDGET_RATIO'                 # default 0.40
    DISPUTE_AUTO_TIMEOUT_HOURS = 'DISPUTE_AUTO_TIMEOUT_HOURS'  # default 72
    DISPUTE_APPEAL_DAYS = 'DISPUTE_APPEAL_DAYS'           # default 7
    OTP_TTL_SECONDS = 'OTP_TTL_SECONDS'                   # default 300
    OTP_MAX_ATTEMPTS = 'OTP_MAX_ATTEMPTS'                 # default 5
    REVIEW_REWARD_THRESHOLD = 'REVIEW_REWARD_THRESHOLD'   # default 5
```

---


---

## ✅ Paso 8: Verificación del Setup

### 8.1 Levantar PostgreSQL con PostGIS

```bash
docker run -d \
  --name wanti-postgres \
  -e POSTGRES_DB=wanti_db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  postgis/postgis:16-3.4
```

### 8.2 Habilitar la extensión PostGIS

```bash
docker exec -it wanti-postgres psql -U postgres -d wanti_db \
  -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# Verificar
docker exec -it wanti-postgres psql -U postgres -d wanti_db \
  -c "SELECT PostGIS_Version();"
```

Salida esperada: algo como `3.4 USE_GEOS=1 USE_PROJ=1 USE_STATS=1`

### 8.3 Levantar Redis

```bash
docker run -d --name wanti-redis -p 6379:6379 redis:7-alpine
docker exec -it wanti-redis redis-cli ping   # → PONG
```

### 8.4 Verificar que Django arranca

```bash
python manage.py check
```

No debe arrojar errores. Si falla por GDAL, revisar el Paso 2.2.

### 8.5 Verificar conexión a la base de datos

```bash
python manage.py dbshell -c "SELECT 1;"
```

---

## 📋 Checklist de cierre del setup

Antes de pasar al archivo `01-modelos.md`, verificar:

- [ ] Python 3.12+ instalado y virtualenv activo
- [ ] Todas las dependencias de `requirements.txt` instaladas sin errores
- [ ] Librerías nativas GDAL / GEOS / PROJ instaladas
- [ ] Contenedor PostgreSQL con PostGIS corriendo
- [ ] Extensión `postgis` habilitada y verificada con `PostGIS_Version()`
- [ ] Contenedor Redis corriendo y respondiendo a `PING`
- [ ] Archivo `.env` creado a partir de `.env.example` con `DJANGO_SECRET_KEY` cambiada
- [ ] Estructura completa de carpetas `apps/` creada con sus `__init__.py`
- [ ] `app/settings/` dividido en `base.py`, `local.py`, `production.py`, `logging.py`
- [ ] `django.contrib.gis` presente en `INSTALLED_APPS`
- [ ] `AUTH_USER_MODEL = 'users.User'` configurado
- [ ] Engine de base de datos apuntando a `django.contrib.gis.db.backends.postgis`
- [ ] `apps/common/models.py` con `BaseModel` abstracto creado
- [ ] `apps/common/constants.py` con todas las `TextChoices` definidas
- [ ] `python manage.py check` pasa sin errores

---

