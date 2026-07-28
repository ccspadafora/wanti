# Wanti — Marketplace Inverso de Vehículos e Inmuebles


## Descripción del Proyecto

Wanti es una aplicación móvil de **marketplace inverso** para vehículos e inmuebles. A diferencia de un clasificado tradicional, aquí **el comprador publica su necesidad** (presupuesto, características obligatorias y preferencias, ubicación) y los **vendedores** encuentran esas necesidades, envían ofertas y **pagan con la moneda interna "Wantis" para desbloquear el contacto del comprador interesado**.

El sistema incorpora un motor de coincidencias con scoring geoespacial, una billetera interna con paquetes de recarga, un módulo de disputas y reembolsos, calificaciones bidireccionales, un CRM de leads para el vendedor y un panel administrativo con métricas y moderación.

**Moneda interna:** 1 Wanti = $5.000 COP (parametrizable desde el panel admin).

> ⚠️ **Nota de alineación pendiente.** Las historias de usuario (HUS18–HUS21) definen que **el vendedor paga** para desbloquear el contacto del comprador. Los documentos previos de backend (`01-modelos.md`, `02-servicios.md`) modelaban el flujo inverso (comprador paga por el contacto del vendedor). Este documento adopta la versión de las historias de usuario: **paga el vendedor**. Cualquier código ya escrito bajo el supuesto anterior debe ajustarse en `contacts` y `wallet`.

---

## Arquitectura General

Arquitectura cliente-servidor desacoplada y escalable:

- **Frontend Mobile:** Flutter (iOS / Android)
- **Backend API:** Python (Django 5.x + Django REST Framework)
- **Base de Datos:** PostgreSQL 15+ con PostGIS 3.4+ (consultas geoespaciales)
- **Autenticación:** JWT + verificación de correo + OTP por WhatsApp/SMS (Twilio)
- **Pagos:** Pasarela local (Wompi / PSE) — contrato de API con modo sandbox
- **Notificaciones:** Firebase Cloud Messaging / OneSignal + Email + WhatsApp
- **Tareas asíncronas:** Celery + Redis
- **IA:** API externa de generación/optimización de imágenes (HUS22–HUS23)

```
      Mobile Apps (Flutter — iOS / Android)
                      │
                      ▼
        Backend API (Django + DRF)
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
   PostgreSQL     Celery +      Integraciones
   + PostGIS       Redis     (Twilio, Pagos, IA, Push)
```

---

## Stack Tecnológico

### Backend
- **Python 3.12+**
- **Django 5.2+** — Framework web principal
- **Django REST Framework 3.15+** — APIs REST
- **djangorestframework-gis** — Serialización geoespacial
- **djangorestframework-simplejwt** — Autenticación JWT
- **PostgreSQL 15+ / PostGIS 3.4+** — Base de datos y geodatos
- **Celery 5.3+ + Redis 7+** — Tareas asíncronas y programadas
- **django-celery-beat** — Tareas periódicas
- **drf-spectacular** — Documentación OpenAPI
- **Twilio** — OTP por WhatsApp / SMS
- **django-storages + boto3** — Almacenamiento de archivos (S3)
- **Docker / Docker Compose** — API + DB + Redis + worker + beat

### Frontend Mobile
- **Flutter** — Base de código única para iOS y Android
- **Dart** — Lenguaje con tipado estático
- **Firebase Cloud Messaging** — Notificaciones push
- **Deep linking** — Navegación desde notificaciones a matches, leads y disputas

### Sistema de diseño (app móvil)
- **Paleta:** navy `#0A1F44`, teal `#00B2A9`, ámbar `#EF9F27`
- **Tipografía:** Nunito (interfaz) / JetBrains Mono (datos numéricos: Wantis, precios, porcentajes de match)
- **Tono de copy:** voseo colombiano ("Podés publicar", "Ingresá el código")

---

## Estructura del Proyecto

```
├── BACKEND/
│   ├── app/                     # Configuración principal (settings, celery, urls)
│   ├── apps/
│   │   ├── common/              # BaseModel, constantes, excepciones, integraciones
│   │   ├── users/               # Usuarios, roles y permisos
│   │   ├── authn/               # JWT, OTP, verificación de email, reset de contraseña
│   │   ├── needs/               # Necesidades publicadas por compradores
│   │   ├── inventory/           # Inventario del vendedor
│   │   ├── offers/              # Ofertas del vendedor a una necesidad
│   │   ├── matching/            # Motor de coincidencias y scoring
│   │   ├── wallet/              # Wantis, recargas y transacciones
│   │   ├── contacts/            # Desbloqueo de contactos
│   │   ├── disputes/            # Disputas y reembolsos
│   │   ├── reviews/             # Calificaciones y reseñas
│   │   ├── leads/               # CRM interno del vendedor
│   │   ├── notifications/       # Push, email, WhatsApp
│   │   ├── ai_images/           # Generación y optimización de imágenes
│   │   ├── admin_panel/         # Métricas, moderación y reportes
│   │   ├── analytics/           # Eventos de interacción y métricas agregadas
│   │   ├── audit/               # Auditoría de acciones sensibles
│   │   └── health/              # Healthcheck con validación de DB
│   ├── manage.py
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── docker-compose.prod.yml
```

### Docker (desarrollo)

Desde `BACKEND/`:

```bash
cp .env.example .env          # ajustar si hace falta
make up                       # postgres + redis + api + worker + beat
make logs                     # logs de la API
make migrate                  # migraciones (también corren al arrancar api)
```

Producción: copiar `.env.production.example` → `.env.production`, colocar certs en `docker/certs/`, y usar `docker compose -f docker-compose.prod.yml up -d`. El pipeline en `.github/workflows/deploy.yml` construye la imagen en tags `v*.*.*`.

---

## Convenciones de Modelado

- Todas las entidades heredan de `BaseModel` → `id` (UUID), `created_at`, `updated_at`
- Nombres de tabla explícitos vía `db_table`, en snake_case plural
- Toda FK a usuario usa `settings.AUTH_USER_MODEL`
- **Borrados lógicos** (cambio de estado), nunca `DELETE` físico en entidades de negocio
- Montos en COP: `DecimalField(max_digits=15, decimal_places=2)`
- Saldos de Wantis: `IntegerField` — unidades enteras, nunca fracciones
- Coordenadas: `PointField(srid=4326, geography=True)`
- Ningún parámetro de negocio se hardcodea: todo se lee desde `SystemSetting`

---

# Entidades del Sistema

## 1 · Usuarios, Roles y Permisos

### User (Usuario)

Un mismo usuario puede actuar como **comprador y vendedor simultáneamente**. No existe un campo "es comprador" o "es vendedor": el rol funcional se infiere del contexto de uso (publicar necesidades vs. mantener inventario y ofertar).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | PK |
| `full_name` | string(150) | Nombres y apellidos (obligatorio) |
| `id_type` | enum | CC \| CE \| PASSPORT \| NIT |
| `id_number` | string(30) | Número de identificación |
| `email` | string, unique | **USERNAME_FIELD** (obligatorio) |
| `password_hash` | string | Nunca en claro |
| `phone` | string(20) | Formato E.164, ej. +573005551234 |
| `city` | string(100) | Ciudad de residencia |
| `location` | PointField | SRID 4326, nullable — georreferenciación |
| `address` | string, nullable | Dirección de residencia (opcional) |
| `birth_date` | date, nullable | |
| `profile_photo_url` | string, nullable | |
| `role` | enum | ADMIN \| MODERATOR \| USER |
| `status` | enum | PENDING \| ACTIVE \| SUSPENDED |
| `email_verified_at` | datetime, nullable | |
| `phone_verified_at` | datetime, nullable | |
| `is_staff` | boolean | default False |
| `last_login_at` | datetime, nullable | |
| `created_at` / `updated_at` | datetime | |

**Constraints:** `UNIQUE(id_type, id_number)`
**Índices:** `email`, `status`, `role`, `city`

**Propiedades derivadas:**
- `is_active` → `status == ACTIVE`
- `is_fully_verified` → email y teléfono verificados
- `can_publish` → activo **y** verificado en ambos canales (regla crítica: sin verificación dual no se publica necesidad, inventario ni oferta)
- `rating_average` → promedio de reseñas recibidas publicadas; `None` si no tiene
- `is_new_user` → `rating_average is None` (badge "Usuario nuevo")

---

### Role

Catálogo de roles del sistema. Permite escalar más allá del enum `User.role` cuando se requiera multirol o roles personalizados.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `name` | string(50), unique | ADMIN, MODERATOR, USER, SUPPORT |
| `description` | string(200) | |
| `is_system` | boolean | Roles base no eliminables |

---

### Permission

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `code` | string(80), unique | Ej. `USER_SUSPEND`, `DISPUTE_RESOLVE`, `NEED_MODERATE`, `METRICS_VIEW`, `SETTING_EDIT` |
| `module` | string(40) | users, needs, offers, wallet, disputes, reviews, admin |
| `description` | string(200) | |

---

### RolePermission

Tabla puente de la relación N↔N entre roles y permisos.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `role_id` | FK → Role | |
| `permission_id` | FK → Permission | |

**Constraints:** `UNIQUE(role_id, permission_id)`

---

### UserRole *(opcional — habilitar si se adopta multirol)*

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `user_id` | FK → User | |
| `role_id` | FK → Role | |
| `assigned_by` | FK → User, nullable | |
| `assigned_at` | datetime | |

> Si se mantiene `User.role` como enum simple, esta tabla no es necesaria.

---

## 2 · Autenticación y Verificación

### EmailVerificationToken

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `user_id` | FK → User, CASCADE | |
| `token` | string(64), unique, indexado | `secrets.token_urlsafe(48)` |
| `expires_at` | datetime | Default `now() + 24h` |
| `used_at` | datetime, nullable | No se elimina la fila (histórico auditable) |

---

### PhoneOtp

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `user_id` | FK → User, CASCADE | |
| `code_hash` | string(128) | **SHA-256 del código, nunca en claro** |
| `channel` | enum | WHATSAPP \| SMS |
| `expires_at` | datetime | `now() + OTP_TTL_SECONDS` |
| `attempts` | int | Se incrementa en cada intento fallido |
| `verified_at` | datetime, nullable | |

**Reglas:** si `attempts >= OTP_MAX_ATTEMPTS` el OTP queda invalidado; al solicitar uno nuevo se invalidan los previos no verificados.

---

### PasswordResetToken

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `user_id` | FK → User, CASCADE | |
| `token` | string(64), unique, indexado | |
| `expires_at` | datetime | Default `now() + 2h` |
| `used_at` | datetime, nullable | |
| `requested_ip` | inet, nullable | Auditoría de intentos |

---

## 3 · Parametrización

### SystemSetting

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `key` | string(64), unique | |
| `value` | string(255) | |
| `value_type` | enum | INT \| DECIMAL \| BOOL \| STRING |
| `description` | text | |
| `updated_by` | FK → User, nullable | |
| `updated_at` | datetime | |

**Parámetros iniciales:**

| Key | Valor | Tipo | Descripción |
|---|---|---|---|
| `WANTI_PRICE_COP` | 5000 | INT | Precio en COP de 1 Wanti |
| `UNLOCK_COST_WANTIS` | 1 | INT | Costo de desbloquear un contacto |
| `NEED_DURATION_DAYS` | 30 | INT | Vigencia de una necesidad |
| `OFFER_DURATION_DAYS` | 15 | INT | Vigencia de una oferta sin respuesta |
| `LEAD_EXPIRY_DAYS` | 30 | INT | Caducidad de un lead sin actividad |
| `MATCH_HIGH_THRESHOLD` | 85 | INT | % mínimo para match "alto" (teal) |
| `MATCH_MIN_SCORE` | 50 | INT | % mínimo para generar un match visible |
| `MATCH_RADIUS_KM` | 50 | INT | Radio geográfico de búsqueda |
| `MIN_BUDGET_RATIO` | 0.40 | DECIMAL | Ratio mínimo presupuesto/valor comercial (anti-abuso) |
| `DISPUTE_AUTO_TIMEOUT_HOURS` | 72 | INT | Horas para responder antes de escalar |
| `DISPUTE_APPEAL_DAYS` | 7 | INT | Días para apelar una disputa resuelta |
| `OTP_TTL_SECONDS` | 300 | INT | Vigencia del OTP |
| `OTP_MAX_ATTEMPTS` | 5 | INT | Intentos máximos de OTP |
| `REVIEW_REWARD_THRESHOLD` | 5 | INT | Reseñas necesarias para recompensa |
| `AI_IMAGES_PER_OFFER` | 4 | INT | Máximo de imágenes IA por oferta |

---

## 4 · Necesidades del Comprador

### Need (Necesidad)

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `buyer_id` | FK → User, PROTECT | El comprador |
| `asset_type` | enum | VEHICLE \| PROPERTY |
| `title` | string(150) | Autogenerado o editable |
| `description` | text | |
| `budget_max_cop` | decimal(15,2) | Presupuesto máximo — **infranqueable** |
| `payment_type` | enum | CASH \| CREDIT \| TRADE_IN |
| `city` | string(100) | |
| `location` | PointField | SRID 4326 |
| `status` | enum | DRAFT \| ACTIVE \| PAUSED \| EXPIRED \| FULFILLED \| DELETED |
| `expires_at` | datetime | Se setea al pasar a ACTIVE |
| `matches_count` | int | Denormalizado |
| `offers_count` | int | Denormalizado (HUS10) |
| `views_count` | int | Denormalizado |
| `legal_disclaimer_accepted_at` | datetime | Cláusula de responsabilidad |

**Índices:** `(buyer, status)`, `(asset_type, status)`, `expires_at`, `city`, GIST sobre `location`

---

### VehicleNeed *(1:1 con Need)*

| Campo | Tipo | Notas |
|---|---|---|
| `need_id` | OneToOne → Need, PK | |
| `brand`, `model`, `line` | string | Ej. Toyota / Hilux / SRV 4×4 |
| `year_min`, `year_max` | int, nullable | |
| `fuel_type` | string(30) | Diésel, Gasolina, Eléctrico, Híbrido |
| `body_type` | string(30) | Sedán, Pickup, SUV, Hatchback |
| `mileage_max_km` | int, nullable | |
| `traction` | string(10) | 4x4 / 4x2 / AWD |
| `transmission` | string(20) | Mecánica / Automática |
| `doors` | int, nullable | |
| `single_owner` | boolean, nullable | |
| `plate_last_digit` | string(20) | Par / impar / sin restricción / dígito |
| `accessories` | json | Lista de accesorios deseados |

---

### PropertyNeed *(1:1 con Need)*

| Campo | Tipo | Notas |
|---|---|---|
| `need_id` | OneToOne → Need, PK | |
| `property_type` | string(20) | Casa / Apartamento |
| `neighborhood` | string(120) | |
| `area_min_sqm` | int, nullable | |
| `bedrooms_min`, `bathrooms_min`, `parking_spots_min` | int, nullable | |
| `has_elevator` | boolean, nullable | |
| `urbanization_type` | string(30) | Conjunto cerrado / Condominio / Barrio abierto |
| `has_pool`, `has_sports_courts`, `has_social_area`, `has_terrace` | boolean, nullable | |
| `max_construction_age_years` | int, nullable | |
| `socioeconomic_stratum` | int, nullable | 1–6 (Colombia) |
| `admin_fee_max_cop`, `utilities_max_cop` | decimal(15,2), nullable | |
| `required_utilities` | json | ["Agua", "Gas", "Luz", "Internet"] |

---

### NeedCriterion

Materializa la marca **obligatorio vs. preferencia** sobre cada atributo (HUS06).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `need_id` | FK → Need, CASCADE | |
| `attribute` | string(80) | `fuel_type`, `traction`, `has_elevator`, etc. |
| `mode` | enum | REQUIRED \| PREFERRED |
| `weight` | int | 0–100. REQUIRED excluye si no cumple; PREFERRED reduce el score |

**Constraints:** `UNIQUE(need_id, attribute)`
**Regla:** si un atributo no tiene criterio explícito, se asume PREFERRED con peso bajo.

---

### NeedImage

Imágenes o referencias adjuntas por el comprador (HUS07).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `need_id` | FK → Need, CASCADE | |
| `image_url` | string(500) | |
| `caption` | string(200) | |
| `order` | int | |

---

## 5 · Inventario del Vendedor

### InventoryItem

Catálogo interno del vendedor. No es un aviso público individual: alimenta el motor de match y las ofertas.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `seller_id` | FK → User, PROTECT | |
| `asset_type` | enum | VEHICLE \| PROPERTY |
| `title` | string(150) | |
| `description` | text | |
| `price_cop` | decimal(15,2) | Precio aproximado |
| `city` | string(100) | |
| `location` | PointField | |
| `status` | enum | AVAILABLE \| RESERVED \| SOLD \| INACTIVE |
| `views_count` | int | |
| `unlock_count` | int | Veces que se pagó por desbloquear contacto asociado a este item |

---

### VehicleItem *(1:1 con InventoryItem)*

Espeja `VehicleNeed` con **valores concretos**: `brand`, `model`, `line`, `year`, `fuel_type`, `body_type`, `traction`, `transmission`, `mileage_km`, `doors`, `single_owner`, `plate_last_digit`, `accessories` (json).

### PropertyItem *(1:1 con InventoryItem)*

Espeja `PropertyNeed` con valores concretos: `property_type`, `neighborhood`, `area_sqm`, `bedrooms`, `bathrooms`, `parking_spots`, `floor`, `has_elevator`, `has_pool`, `has_sports_courts`, `has_social_area`, `has_terrace`, `urbanization_type`, `construction_year`, `socioeconomic_stratum`, `admin_fee_cop`, `utilities_avg_cop`, `available_utilities` (json).

### InventoryImage

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `item_id` | FK → InventoryItem, CASCADE | |
| `image_url` | string(500) | |
| `is_ai_generated` | boolean | HUS22 |
| `source_prompt` | text | Prompt usado si es IA |
| `order` | int | |

---

## 6 · Ofertas del Vendedor

### Offer (Oferta) — HUS15–HUS17

Propuesta que un vendedor envía a una necesidad publicada. Es la entidad que conecta al vendedor con el comprador **antes** del desbloqueo de contacto.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `offer_number` | string(20), unique | Consecutivo legible (ej. WO-004821) |
| `need_id` | FK → Need, PROTECT | Necesidad a la que responde |
| `seller_id` | FK → User, PROTECT | |
| `buyer_id` | FK → User, PROTECT | Denormalizado desde `need.buyer` |
| `inventory_item_id` | FK → InventoryItem, nullable, PROTECT | Item ofertado (opcional) |
| `price_cop` | decimal(15,2) | Precio propuesto |
| `message` | text | Mensaje del vendedor al comprador |
| `attributes_snapshot` | json | Características del bien al momento de ofertar (HUS16) |
| `status` | enum | DRAFT \| SENT \| VIEWED \| SHORTLISTED \| ACCEPTED \| REJECTED \| WITHDRAWN \| EXPIRED |
| `match_id` | FK → Match, nullable | Si nace de una sugerencia del motor |
| `contact_unlocked` | boolean | True cuando el vendedor pagó el desbloqueo |
| `sent_at`, `viewed_at`, `responded_at`, `expires_at` | datetime, nullable | |

**Constraints:** `UNIQUE(need_id, seller_id, inventory_item_id)` — una oferta activa por item y necesidad
**Índices:** `(need_id, status)`, `(seller_id, status)`, `(buyer_id, status)`, `expires_at`

---

### OfferImage

Imágenes adjuntas a la oferta, propias o generadas por IA (HUS16, HUS23).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `offer_id` | FK → Offer, CASCADE | |
| `image_url` | string(500) | |
| `source` | enum | UPLOADED \| AI_GENERATED \| INVENTORY |
| `ai_image_id` | FK → AIImageJob, nullable | Trazabilidad de la generación |
| `caption` | string(200) | |
| `order` | int | |

---

### OfferEvent

Trazabilidad del ciclo de vida de la oferta (HUS17).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `offer_id` | FK → Offer, CASCADE | |
| `event_type` | string(50) | CREATED, SENT, VIEWED, SHORTLISTED, ACCEPTED, REJECTED, WITHDRAWN, EXPIRED |
| `actor_id` | FK → User, nullable | Puede ser el sistema |
| `payload` | json | |

---

## 7 · Motor de Coincidencias

### Match

Coincidencia calculada entre una `Need` y un `InventoryItem` (HUS14, HUS24).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `need_id` | FK → Need, CASCADE | |
| `inventory_item_id` | FK → InventoryItem, CASCADE | |
| `buyer_id` | FK → User | Denormalizado |
| `seller_id` | FK → User | Denormalizado |
| `score` | int | 0–100 (% de afinidad) |
| `distance_km` | decimal(6,2) | Distancia geográfica calculada |
| `required_criteria_met` | boolean | |
| `unmet_preferences` | json | Criterios PREFERRED no cumplidos ("Deseable, pero no excluyente") |
| `status` | enum | GENERATED \| VIEWED \| OFFERED \| UNLOCKED \| DISCARDED |
| `viewed_at`, `offered_at`, `unlocked_at`, `discarded_at` | datetime, nullable | |

**Constraints:** `UNIQUE(need_id, inventory_item_id)`
**Regla:** solo se persisten matches con `score >= MATCH_MIN_SCORE`.

---

### MatchCriterionResult

Detalle por criterio del scoring — explica **por qué** un match tiene su puntaje.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `match_id` | FK → Match, CASCADE | |
| `attribute` | string(80) | |
| `mode` | enum | REQUIRED \| PREFERRED |
| `expected_value` | string(150) | Valor solicitado por el comprador |
| `actual_value` | string(150) | Valor del inventario |
| `met` | boolean | |
| `contribution` | int | Puntos aportados al score |

---

## 8 · Billetera y Monetización

### Wallet

Una por usuario, creada al activar la cuenta.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `user_id` | OneToOne → User, PROTECT | |
| `balance_wantis` | int | Saldo en unidades enteras |

**Regla:** el saldo nunca se modifica directamente. Toda mutación pasa por `apply_transaction()` dentro de una transacción atómica con `SELECT FOR UPDATE`.

---

### WalletTransaction

**Ledger inmutable.** Nunca se edita ni elimina.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `wallet_id` | FK → Wallet, PROTECT | |
| `transaction_type` | enum | TOPUP \| BONUS \| UNLOCK \| REFUND \| ADJUSTMENT \| REWARD |
| `amount_wantis` | int | Positivo (crédito) / negativo (débito) |
| `balance_after` | int | Checksum de integridad |
| `related_object_type` | string(50) | "ContactUnlock", "Dispute", "TopupOrder" |
| `related_object_id` | UUID, nullable | |
| `note` | text | Descripción legible |
| `created_by` | FK → User, nullable | Null = sistema |

---

### TopupPackage

Paquetes de recarga configurables desde el panel admin.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `name` | string(80) | |
| `wantis_base` | int | |
| `wantis_bonus` | int | Bonificación por volumen |
| `price_cop` | decimal(15,2) | |
| `is_popular` | boolean | Badge "Popular" |
| `is_active` | boolean | |
| `order` | int | |

**Fixture inicial:** Básico (5 + 0 → $25.000) · Popular (10 + 1 → $50.000, destacado) · Premium (20 + 5 → $100.000)

---

### TopupOrder

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `user_id` | FK → User, PROTECT | |
| `package_id` | FK → TopupPackage, PROTECT | |
| `wantis_total` | int | Snapshot `base + bonus` |
| `price_cop` | decimal(15,2) | Snapshot del precio |
| `status` | enum | PENDING \| COMPLETED \| FAILED \| REFUNDED |
| `provider` | enum | WOMPI \| PSE \| SANDBOX |
| `provider_reference` | string(120), indexado | ID externo de la pasarela |
| `provider_payload` | json | Respuesta completa del webhook |
| `completed_at` | datetime, nullable | |

**Regla (HUS19):** al recibir el webhook `COMPLETED` se generan dos asientos — `TOPUP` (base) y `BONUS` (extra). Idempotente por `provider_reference`.

---

### PaymentProviderConfig

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `provider` | enum | WOMPI \| PSE \| SANDBOX |
| `public_key` | string | |
| `private_key` | string | Cifrada en reposo |
| `webhook_secret` | string | |
| `active` | boolean | |

---

### Receipt (Comprobante) — HUS21

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `topup_order_id` | FK → TopupOrder, PROTECT | |
| `receipt_number` | string(30), unique | |
| `pdf_url` | string(500) | |
| `sent_to_email_at` | datetime, nullable | |
| `delivery_status` | enum | PENDING \| SENT \| FAILED |

---

## 9 · Desbloqueo de Contactos

### ContactUnlock — HUS18, HUS20

Registro del pago en Wantis que hace **el vendedor** para acceder a los datos de contacto del comprador.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `offer_id` | OneToOne → Offer, PROTECT | Un desbloqueo por oferta |
| `match_id` | FK → Match, nullable, PROTECT | Si nace de una sugerencia del motor |
| `seller_id` | FK → User | Quien paga |
| `buyer_id` | FK → User | Cuyo contacto se libera |
| `wantis_charged` | int | Default `UNLOCK_COST_WANTIS` |
| `wallet_transaction_id` | OneToOne → WalletTransaction, PROTECT | Asiento de débito |
| `outcome` | enum | PENDING \| PURCHASED \| IN_PROGRESS \| NOT_PURCHASED \| INVALID_LEAD |
| `outcome_reported_at` | datetime, nullable | |
| `whatsapp_opened_at` | datetime, nullable | Auditoría del click en "Abrir WhatsApp" |

**Reglas:** operación idempotente (no cobra dos veces); al crearse genera automáticamente un `Lead` para el vendedor y notifica al comprador.

---

## 10 · Disputas y Reembolsos

### Dispute

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `dispute_number` | string(20), unique | Ej. WD-2847 |
| `contact_unlock_id` | FK → ContactUnlock, PROTECT | |
| `opened_by` | FK → User, PROTECT | |
| `reason` | enum | CONTACT_INVALID \| NO_RESPONSE \| ASSET_UNAVAILABLE \| FALSE_INFO \| OTHER |
| `description` | text | |
| `status` | enum | OPEN \| AUTO_REVIEW \| HUMAN_REVIEW \| APPROVED \| REJECTED \| APPEALED \| CANCELLED |
| `auto_review_started_at` | datetime, nullable | |
| `auto_review_deadline` | datetime, nullable | `now() + DISPUTE_AUTO_TIMEOUT_HOURS` |
| `counterparty_confirmed` | boolean, nullable | Respuesta al ping automático |
| `escalated_at`, `resolved_at` | datetime, nullable | |
| `resolved_by` | FK → User, nullable | Admin que resolvió |
| `resolution_note` | text | |
| `refund_transaction_id` | OneToOne → WalletTransaction, nullable | Asiento de reembolso |
| `appeal_deadline` | datetime, nullable | `resolved_at + DISPUTE_APPEAL_DAYS` |

**Flujo:** OPEN → AUTO_REVIEW (ping a la contraparte) → si confirma, REJECTED automático; si niega o no responde antes del deadline, HUMAN_REVIEW → admin resuelve APPROVED (con reembolso) o REJECTED → ventana de apelación.

---

### DisputeAttachment

`id`, `dispute_id` (FK, CASCADE), `file_url`, `file_name`, `mime_type` (solo image/png, image/jpeg — 5 MB máx), `uploaded_by` (FK → User).

### DisputeEvent

`id`, `dispute_id` (FK, CASCADE), `event_type` (OPENED, AUTO_PING_SENT, RESPONDED, ESCALATED, RESOLVED, APPEALED, CANCELLED), `actor_id` (FK → User, nullable), `payload` (json).

---

## 11 · Calificaciones y Reseñas

### Review

Reseña bidireccional habilitada tras reportar el resultado del contacto.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `contact_unlock_id` | FK → ContactUnlock, PROTECT | |
| `reviewer_id` | FK → User, PROTECT | |
| `reviewee_id` | FK → User, PROTECT | |
| `rating` | int | 1–5 estrellas |
| `comment` | text | |
| `tags` | json | Chips seleccionadas |
| `status` | enum | PUBLISHED \| UNDER_REVIEW \| REMOVED |

**Constraints:** `UNIQUE(contact_unlock_id, reviewer_id)` — cada parte califica una sola vez.

---

### ReviewTag

`id`, `code` (unique), `label`, `for_role` (BUYER_REVIEWING_SELLER \| SELLER_REVIEWING_BUYER), `is_active`, `order`.

**Fixture:** Comprador→Vendedor: "Rápido en responder", "Información precisa", "Buen trato", "Precio justo". Vendedor→Comprador: "Serio y comprometido", "Comunicación clara", "Trato respetuoso", "Cerró rápido".

### ReviewDispute

`id`, `review_id` (OneToOne, PROTECT), `disputed_by` (FK → User, debe ser `review.reviewee`), `reason` (text), `status` (OPEN \| RESOLVED_KEPT \| RESOLVED_REMOVED), `resolved_by`, `resolved_at`, `admin_note`.

**Regla:** al abrirse, la reseña pasa a `UNDER_REVIEW` y se oculta del perfil hasta la decisión del admin.

---

## 12 · CRM del Vendedor

### Lead

Se crea automáticamente al desbloquear un contacto.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `contact_unlock_id` | OneToOne → ContactUnlock, PROTECT | |
| `seller_id` | FK → User, PROTECT | |
| `buyer_id` | FK → User, PROTECT | Denormalizado |
| `need_id` | FK → Need, PROTECT | Necesidad de origen |
| `stage` | enum | NEW \| IN_NEGOTIATION \| TO_VISIT \| PURCHASED \| DISCARDED \| EXPIRED |
| `last_activity_at` | datetime | Se actualiza con cada nota o cambio de etapa |
| `expires_at` | datetime | `last_activity_at + LEAD_EXPIRY_DAYS` |
| `sold_price_cop` | decimal(15,2), nullable | Al marcar PURCHASED |

### LeadNote

`id`, `lead_id` (FK, CASCADE), `author_id` (FK → User, siempre el vendedor), `text`, `stage_at_time`.

**Regla:** cada nota actualiza `last_activity_at` y recalcula `expires_at`.

---

## 13 · Inteligencia Artificial de Imágenes

### AIImageJob — HUS22

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `requested_by` | FK → User, PROTECT | Vendedor |
| `inventory_item_id` | FK → InventoryItem, nullable | |
| `source_image_url` | string(500), nullable | Foto original cargada |
| `prompt` | text | Prompt enviado al proveedor |
| `provider` | enum | MOCK \| EXTERNAL_API |
| `status` | enum | QUEUED \| PROCESSING \| READY \| FAILED |
| `result_urls` | json | Lista de URLs generadas |
| `error_message` | text | |
| `cost_credits` | int | Consumo interno, para control de costos |
| `completed_at` | datetime, nullable | |

### AIImageSelection — HUS23

`id`, `ai_image_job_id` (FK), `offer_id` (FK → Offer), `selected_url`, `selected_by` (FK → User), `selected_at`.

---

## 14 · Notificaciones

### NotificationTemplate

`id`, `code` (unique, ej. `MATCH_NEW`, `OFFER_RECEIVED`, `CONTACT_UNLOCKED`, `DISPUTE_RESOLVED`), `channel` (PUSH \| EMAIL \| WHATSAPP \| SMS), `title`, `body`, `variables_schema` (json), `is_active`.

### Notification

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `recipient_id` | FK → User, CASCADE | |
| `channel` | enum | PUSH \| EMAIL \| WHATSAPP \| SMS |
| `template_code` | string(80) | |
| `title` / `body` | string / text | |
| `payload` | json | Datos para deep-linking |
| `delivery_status` | enum | PENDING \| SENT \| DELIVERED \| FAILED |
| `sent_at`, `read_at` | datetime, nullable | |
| `provider_reference` | string(120) | |
| `error_message` | text | |

### DeviceToken

`id`, `user_id` (FK, CASCADE), `token` (string(500), unique), `platform` (IOS \| ANDROID \| WEB), `device_id`, `is_active`, `last_used_at`.

**Regla de canales:** push primero; email solo para hitos (registro, recarga, resolución de disputa); WhatsApp solo para desbloqueo de contacto y disputas críticas.

---

## 15 · Analítica y Administración

### InteractionEvent — HUS31

Registro granular de interacciones para análisis de embudo.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `user_id` | FK → User, nullable | |
| `event_type` | string(60) | NEED_VIEWED, OFFER_SENT, MATCH_VIEWED, CONTACT_UNLOCKED, WHATSAPP_OPENED, etc. |
| `entity` | string(50) | Modelo relacionado |
| `entity_id` | UUID, nullable | |
| `session_id` | string(64) | |
| `platform` | enum | IOS \| ANDROID \| WEB |
| `metadata` | json | |
| `occurred_at` | datetime, indexado | |

### AdminMetricDaily — HUS25, HUS32

`id`, `date` (unique), `new_users`, `active_users`, `needs_created`, `needs_active`, `offers_sent`, `offers_accepted`, `matches_generated`, `contacts_unlocked`, `wantis_sold`, `revenue_cop`, `disputes_opened`, `disputes_approved`.

### MatchMetricDaily — HUS33

`id`, `date`, `asset_type`, `matches_generated`, `avg_score`, `high_matches` (≥ `MATCH_HIGH_THRESHOLD`), `matches_converted_to_offer`, `matches_converted_to_unlock`, `conversion_rate`.

### ReportExport — HUS32

`id`, `requested_by` (FK → User), `type` (USERS \| NEEDS \| OFFERS \| PAYMENTS \| MATCHES \| DISPUTES), `filters` (json), `status` (GENERATING \| READY \| FAILED), `file_url`, `expires_at`.

### ModerationCase — HUS30

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `entity` | string(50) | Need, Offer, Review, User, InventoryItem |
| `entity_id` | UUID | |
| `reported_by` | FK → User, nullable | Null si es detección automática |
| `reason` | enum | SPAM \| FRAUD \| OFFENSIVE \| DUPLICATE \| MISLEADING \| OTHER |
| `description` | text | |
| `status` | enum | PENDING \| IN_REVIEW \| ACTIONED \| DISMISSED |
| `action_taken` | enum, nullable | CONTENT_REMOVED \| USER_SUSPENDED \| WARNING \| NONE |
| `reviewed_by` | FK → User, nullable | |
| `reviewed_at` | datetime, nullable | |
| `admin_note` | text | |

---

## 16 · Auditoría

### AuditLog

Registro inmutable de acciones sensibles.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `actor_user_id` | FK → User, nullable, PROTECT | Null en eventos del sistema |
| `action` | string(80) | USER_REGISTERED, OTP_VERIFIED, NEED_PUBLISHED, OFFER_SENT, MATCH_GENERATED, CONTACT_UNLOCKED, WALLET_TOPUP, DISPUTE_RESOLVED, SETTING_CHANGED, USER_SUSPENDED… |
| `entity` | string(50) | |
| `entity_id` | UUID, nullable | |
| `metadata` | json | **Nunca** contraseñas, OTP en claro ni tokens |
| `ip_address` | inet, nullable | |
| `user_agent` | string(500) | |
| `created_at` | datetime, indexado | |

---

# Relaciones entre Entidades

### 1) Usuarios, roles y seguridad
- **Role (N) ↔ (N) Permission** vía `RolePermission`
- **User (1) → (N) EmailVerificationToken / PhoneOtp / PasswordResetToken**
- *(Opcional)* **User (N) ↔ (N) Role** vía `UserRole` si se adopta multirol

### 2) Necesidades
- **User (1) → (N) Need** (como comprador)
- **Need (1) → (0..1) VehicleNeed | PropertyNeed** (excluyentes según `asset_type`)
- **Need (1) → (N) NeedCriterion** — `UNIQUE(need, attribute)`
- **Need (1) → (N) NeedImage**

### 3) Inventario
- **User (1) → (N) InventoryItem** (como vendedor)
- **InventoryItem (1) → (0..1) VehicleItem | PropertyItem**
- **InventoryItem (1) → (N) InventoryImage**

### 4) Coincidencias
- **Need (1) → (N) Match** · **InventoryItem (1) → (N) Match** — `UNIQUE(need, inventory_item)`
- **Match (1) → (N) MatchCriterionResult**

### 5) Ofertas
- **Need (1) → (N) Offer** · **User (1) → (N) Offer** (como vendedor)
- **Match (0..1) → (0..1) Offer** — una sugerencia puede convertirse en oferta
- **Offer (1) → (N) OfferImage** · **Offer (1) → (N) OfferEvent**

### 6) Billetera y pagos
- **User (1) → (1) Wallet** → **(N) WalletTransaction**
- **TopupPackage (1) → (N) TopupOrder** → dispara `WalletTransaction` vía webhook
- **TopupOrder (1) → (0..1) Receipt**
- **PaymentProviderConfig** — configuración activa, sin FK directa

### 7) Desbloqueo y CRM
- **Offer (1) → (0..1) ContactUnlock** → **(1) Lead** → **(N) LeadNote**
- **ContactUnlock (1) → (1) WalletTransaction** (asiento de débito)

### 8) Disputas y reseñas
- **ContactUnlock (1) → (N) Dispute** → **(N) DisputeAttachment**, **(N) DisputeEvent**
- **Dispute (0..1) → (0..1) WalletTransaction** (reembolso)
- **ContactUnlock (1) → (N) Review** (máx. 2: una por parte) → **(0..1) ReviewDispute**
- **ReviewTag** — catálogo sin FK

### 9) IA
- **User (1) → (N) AIImageJob** → **(N) AIImageSelection** → **(1) Offer**

### 10) Notificaciones
- **User (1) → (N) Notification** · **User (1) → (N) DeviceToken**
- **NotificationTemplate (1) → (N) Notification** (por `template_code`)

### 11) Analítica, administración y auditoría
- **User (1) → (N) InteractionEvent / ReportExport / AuditLog**
- **AdminMetricDaily / MatchMetricDaily** — agregados diarios sin FK
- **ModerationCase** — referencia flexible por `entity` + `entity_id`

---

## Diagrama de relaciones (resumen)

```
User ──1:1──> Wallet ──1:N──> WalletTransaction
  │
  ├──1:N──> Need (comprador) ──1:1──> VehicleNeed | PropertyNeed
  │              ├──1:N──> NeedCriterion
  │              ├──1:N──> NeedImage
  │              ├──1:N──> Match
  │              └──1:N──> Offer
  │
  ├──1:N──> InventoryItem (vendedor) ──1:1──> VehicleItem | PropertyItem
  │              ├──1:N──> InventoryImage
  │              └──1:N──> Match ──1:N──> MatchCriterionResult
  │
  ├──1:N──> Offer (vendedor) ──1:N──> OfferImage | OfferEvent
  │              └──1:1──> ContactUnlock ──1:1──> Lead ──1:N──> LeadNote
  │                              ├──1:N──> Dispute ──1:N──> DisputeAttachment
  │                              │                └──1:N──> DisputeEvent
  │                              └──1:N──> Review ──1:1──> ReviewDispute
  │
  ├──1:N──> AIImageJob ──1:N──> AIImageSelection ──> Offer
  ├──1:N──> Notification · DeviceToken
  ├──1:N──> InteractionEvent · ReportExport
  └──1:N──> AuditLog (actor)

Role ──N:N──> Permission (vía RolePermission)
TopupPackage ──1:N──> TopupOrder ──1:1──> Receipt
SystemSetting · ReviewTag · NotificationTemplate · PaymentProviderConfig  (catálogos)
AdminMetricDaily · MatchMetricDaily · ModerationCase
```

---

## Trazabilidad Historias de Usuario ↔ Entidades

| Épica | HUS | Entidades involucradas |
|---|---|---|
| 1 · Autenticación | HUS01–04 | `User`, `Role`, `Permission`, `RolePermission`, `EmailVerificationToken`, `PhoneOtp`, `PasswordResetToken` |
| 2 · Necesidad | HUS05–10 | `Need`, `VehicleNeed`, `PropertyNeed`, `NeedCriterion`, `NeedImage`, `Offer` (conteo) |
| 3 · Oportunidades | HUS11–17 | `Need` (búsqueda), `Match`, `InventoryItem`, `Offer`, `OfferImage`, `OfferEvent` |
| 4 · Monetización | HUS18–21 | `Wallet`, `WalletTransaction`, `TopupPackage`, `TopupOrder`, `Receipt`, `ContactUnlock`, `PaymentProviderConfig` |
| 5 · IA | HUS22–24 | `AIImageJob`, `AIImageSelection`, `Match`, `MatchCriterionResult` |
| 6 · Administrador | HUS25–30 | `AdminMetricDaily`, `User`, `Need`, `Offer`, `TopupOrder`, `ModerationCase` |
| 7 · Analítica | HUS31–33 | `InteractionEvent`, `AdminMetricDaily`, `MatchMetricDaily`, `ReportExport` |

---
