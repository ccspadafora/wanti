# Wanti Backend — 03 · Endpoints API REST

**Prerequisito:** haber completado `00-setup-inicial.md`, `01-modelos.md` y `02-servicios.md`
**Objetivo:** definir todos los endpoints REST de la API, sus contratos, permisos, códigos de error y ejemplos.

---

## Convenciones generales

### Base URL

`https://api.wanti.co/api/v1/`

### Autenticación

- Todos los endpoints **requieren JWT** salvo los explícitamente marcados como públicos.
- Header: `Authorization: Bearer <access_token>`
- El access token vence en 15 min; el refresh dura 7 días.

### Formato

- **Todos los request y response son JSON** (`Content-Type: application/json`).
- **Fechas**: ISO 8601 con timezone (`2026-07-20T15:30:00-05:00`).
- **UUIDs** como strings.
- **Montos monetarios**: strings decimales en COP (`"120000000.00"`).
- **Wantis**: enteros.
- **Coordenadas geográficas**: objeto `{"latitude": 4.6097, "longitude": -74.0817}` en el input; en el output, GeoJSON Point.

### Códigos HTTP

| Código | Uso |
|---|---|
| `200 OK` | Consulta exitosa o mutación con response body |
| `201 Created` | Creación exitosa |
| `204 No Content` | Mutación sin body |
| `400 Bad Request` | Payload inválido, datos malformados |
| `401 Unauthorized` | Token ausente, inválido o expirado |
| `403 Forbidden` | Autenticado pero sin permiso para el recurso |
| `404 Not Found` | Recurso no existe (o no visible para el usuario) |
| `409 Conflict` | Estado incompatible (ej. disputa ya activa) |
| `422 Unprocessable Entity` | Validación de negocio falla (ej. saldo insuficiente) |
| `429 Too Many Requests` | Throttling activo |
| `500 Internal Server Error` | Error inesperado |
| `503 Service Unavailable` | DB o servicios críticos caídos (usado por `/health`) |

### Formato de errores

```json
{
  "error": {
    "code": "INSUFFICIENT_FUNDS",
    "message": "Saldo insuficiente: 0 Wantis disponibles",
    "details": {}
  }
}
```

**Códigos de error de dominio:**

- `VALIDATION_ERROR` (400)
- `NOT_FOUND` (404)
- `PERMISSION_DENIED` (403)
- `CONFLICT` (409)
- `INSUFFICIENT_FUNDS` (422)
- `USER_NOT_VERIFIED` (422)
- `USER_SUSPENDED` (403)
- `OTP_INVALID` (422)
- `DISPUTE_STATE_ERROR` (409)
- `THROTTLED` (429)

### Paginación

Todos los endpoints de listado usan paginación cursor-agnóstica:

**Request:** `?page=1&page_size=20`
**Response:**
```json
{
  "count": 120,
  "next": "https://api.wanti.co/api/v1/needs/?page=2",
  "previous": null,
  "results": [ ... ]
}
```

`page_size` máx: 100. Default: 20.

### Filtros y ordenación

Todos los listados soportan:
- **Filtros**: query params específicos por endpoint (documentados abajo)
- **Búsqueda**: `?search=<término>` cuando aplica
- **Ordenación**: `?ordering=-created_at,score`

### Throttling

Rates configurados en `DEFAULT_THROTTLE_RATES`:

| Scope | Rate |
|---|---|
| `login` | 10/min |
| `otp_send` | 5/hour |
| `otp_verify` | 10/hour |
| `password_reset` | 5/hour |
| `need_create` | 20/day |

---

## Índice de endpoints

| Grupo | Prefix |
|---|---|
| Health | `/health/` |
| Autenticación | `/auth/` |
| Usuarios | `/users/` |
| Necesidades | `/needs/` |
| Inventario | `/inventory/` |
| Matches | `/matches/` |
| Wallet | `/wallet/` |
| Contactos | `/contacts/` |
| Disputas | `/disputes/` |
| Reseñas | `/reviews/` |
| Leads (CRM vendedor) | `/leads/` |
| Notificaciones | `/notifications/` |
| Admin | `/admin/` |

---

## 1 · Health

### `GET /api/v1/health/` — público

**Response 200:**
```json
{
  "status": "ok",
  "service": "wanti-backend",
  "version": "v1",
  "database": "ok",
  "redis": "ok",
  "postgis": "ok"
}
```

**Response 503** si falla alguno:
```json
{
  "status": "error",
  "database": "error",
  "redis": "ok",
  "postgis": "ok"
}
```

---

## 2 · Autenticación (`/api/v1/auth/`)

### 2.1 `POST /auth/register/` — público — HUS01, HUS02

**No hay selector comprador/vendedor.** Un usuario puede ser ambos simultáneamente.

**Request:**
```json
{
  "full_name": "María García",
  "id_type": "CC",
  "id_number": "1234567890",
  "email": "maria@example.com",
  "phone": "+573001234567",
  "city": "Bogotá",
  "password": "Str0ngPassword!2025"
}
```

**Response 201:**
```json
{
  "id": "0b6e1f0f-8e51-4a19-9c2e-1d7ff2b4ef54",
  "email": "maria@example.com",
  "full_name": "María García",
  "status": "PENDING",
  "email_verified_at": null,
  "phone_verified_at": null,
  "next_step": "verify_email"
}
```

**Errores:**
- `400 VALIDATION_ERROR` — email/id ya en uso, formato inválido
- Throttle scope: registration (5/hour por IP)

**Efectos:**
- Se envía email con token de verificación
- Se crea `Wallet(balance_wantis=0)`
- Se registra `AuditLog(action='USER_REGISTERED')`

---

### 2.2 `POST /auth/login/` — público — HUS03

**Request:**
```json
{
  "email": "maria@example.com",
  "password": "Str0ngPassword!2025"
}
```

**Response 200:**
```json
{
  "access": "eyJhbGciOi...",
  "refresh": "eyJhbGciOi...",
  "user": {
    "id": "0b6e1f0f-...",
    "email": "maria@example.com",
    "full_name": "María García",
    "role": "USER",
    "status": "PENDING",
    "email_verified_at": null,
    "phone_verified_at": null,
    "is_fully_verified": false,
    "wallet_balance_wantis": 0
  }
}
```

**Errores:**
- `401 VALIDATION_ERROR` — credenciales inválidas (genérico, sin revelar si el email existe)
- `403 USER_SUSPENDED` — cuenta suspendida
- Throttle scope: `login` (10/min por IP + email)

**Nota:** un usuario `PENDING` **puede loguearse** pero el cliente lee `is_fully_verified` para forzar el flujo de verificación antes de permitir publicar.

---

### 2.3 `POST /auth/token/refresh/` — público

**Request:**
```json
{ "refresh": "eyJhbGciOi..." }
```

**Response 200:**
```json
{ "access": "eyJhbGciOi...", "refresh": "eyJhbGciOi..." }
```

`ROTATE_REFRESH_TOKENS=True` — el refresh anterior queda blacklisted.

---

### 2.4 `POST /auth/verify-email/` — público

**Request:**
```json
{ "token": "abc123..." }
```

**Response 200:**
```json
{
  "email_verified_at": "2026-07-20T15:30:00-05:00",
  "next_step": "verify_phone"
}
```

**Errores:**
- `400 VALIDATION_ERROR` — token inválido, expirado o usado

---

### 2.5 `POST /auth/resend-email-verification/` — JWT requerido

Solo si `email_verified_at is null`.

**Response 204** — Throttle scope: `otp_send` (5/hour)

---

### 2.6 `POST /auth/otp/request/` — JWT requerido

**Request:**
```json
{ "channel": "WHATSAPP" }
```

`channel` puede ser `WHATSAPP` o `SMS`.

**Response 204** — Throttle scope: `otp_send` (5/hour)

**Errores:**
- `409 CONFLICT` — teléfono ya verificado
- `429 THROTTLED`

---

### 2.7 `POST /auth/otp/verify/` — JWT requerido

**Request:**
```json
{ "code": "472891" }
```

**Response 200:**
```json
{
  "phone_verified_at": "2026-07-20T15:32:00-05:00",
  "is_fully_verified": true,
  "status": "ACTIVE"
}
```

**Errores:**
- `422 OTP_INVALID` — código incorrecto, expirado o sin OTP activo
- Throttle scope: `otp_verify` (10/hour)

---

### 2.8 `POST /auth/password/reset-request/` — público — HUS04

**Request:**
```json
{ "email": "maria@example.com" }
```

**Response 204** — **siempre 204**, no revela si el email existe.

Throttle scope: `password_reset` (5/hour por IP)

---

### 2.9 `POST /auth/password/reset-confirm/` — público

**Request:**
```json
{
  "token": "abc123...",
  "new_password": "NewStr0ngP@ss!"
}
```

**Response 204**

**Errores:**
- `400 VALIDATION_ERROR` — token inválido, expirado o password débil

**Efecto:** invalida todos los refresh tokens activos del usuario.

---

### 2.10 `POST /auth/logout/` — JWT requerido

**Request:**
```json
{ "refresh": "eyJhbGciOi..." }
```

**Response 204**

Añade el refresh token al blacklist.

---

## 3 · Usuarios (`/api/v1/users/`)

### 3.1 `GET /users/me/` — JWT requerido

**Response 200:**
```json
{
  "id": "0b6e1f0f-...",
  "full_name": "María García",
  "email": "maria@example.com",
  "phone": "+573001234567",
  "city": "Bogotá",
  "location": {"type": "Point", "coordinates": [-74.0817, 4.6097]},
  "profile_photo_url": "https://...",
  "role": "USER",
  "status": "ACTIVE",
  "email_verified_at": "2026-07-20T15:30:00-05:00",
  "phone_verified_at": "2026-07-20T15:32:00-05:00",
  "is_fully_verified": true,
  "created_at": "2026-07-20T15:00:00-05:00",
  "last_login_at": "2026-07-20T16:00:00-05:00",
  "rating_average": 4.8,
  "reviews_received_count": 12,
  "wallet_balance_wantis": 48
}
```

---

### 3.2 `PATCH /users/me/`

**Whitelist estricta.** Solo estos campos son editables:

```json
{
  "full_name": "María García López",
  "city": "Medellín",
  "location": {"latitude": 6.2442, "longitude": -75.5812},
  "profile_photo_url": "https://..."
}
```

**Response 200** con el user actualizado.

**Errores:**
- `400 VALIDATION_ERROR` — si el request incluye `email`, `phone`, `role`, `status`, `id_type`, `id_number`, `password` → mensaje: "Campo no editable: X"

---

### 3.3 `POST /users/me/change-email/`

**Request:**
```json
{ "new_email": "nuevo@example.com", "password": "Str0ngPassword!2025" }
```

**Response 202:**
```json
{ "detail": "Enviamos un correo de confirmación a nuevo@example.com" }
```

El cambio se materializa solo tras hacer clic en el enlace del nuevo correo.

---

### 3.4 `POST /users/me/change-phone/`

**Request:**
```json
{ "new_phone": "+573009999999", "password": "Str0ngPassword!2025", "channel": "WHATSAPP" }
```

**Response 202** — se envía OTP al nuevo número.

---

### 3.5 `POST /users/me/change-password/`

**Request:**
```json
{ "current_password": "Old...", "new_password": "NewStr0ngP@ss!" }
```

**Response 204** — invalida sesiones previas.

---

### 3.6 `GET /users/{id}/` — JWT

- Cualquiera puede ver el perfil **público** de un usuario (nombre, ciudad, foto, rating, reseñas).
- Solo el propio user o admin ve datos privados (email, teléfono, id_number, wallet).

**Response 200 (perfil público):**
```json
{
  "id": "...",
  "full_name": "Carlos Ramírez",
  "city": "Bogotá",
  "profile_photo_url": "https://...",
  "rating_average": 4.8,
  "reviews_received_count": 12,
  "is_new_user": false,
  "member_since": "2026-05-10"
}
```

---

## 4 · Necesidades (`/api/v1/needs/`)

### 4.1 `POST /needs/` — JWT — HUS05, HUS06, HUS07

Crear una nueva necesidad. Usuario debe estar `fully_verified` (`can_publish=True`).

**Request (vehículo):**
```json
{
  "asset_type": "VEHICLE",
  "title": "Toyota Hilux 4x4 2021",
  "description": "Uso familiar principalmente carretera",
  "budget_max_cop": "120000000.00",
  "payment_type": "CASH",
  "city": "Bogotá",
  "location": {"latitude": 4.6097, "longitude": -74.0817},
  "vehicle": {
    "brand": "Toyota",
    "model": "Hilux",
    "line": "SRV 4x4",
    "year_min": 2019,
    "year_max": 2022,
    "fuel_type": "Diésel",
    "body_type": "Pickup",
    "mileage_max_km": 80000,
    "traction": "4x4",
    "transmission": "Mecánica",
    "doors": 4,
    "single_owner": true,
    "accessories": ["Aire acondicionado", "Bluetooth"]
  },
  "criteria": [
    {"attribute": "fuel_type", "mode": "REQUIRED", "weight": 20},
    {"attribute": "traction", "mode": "REQUIRED", "weight": 20},
    {"attribute": "mileage_max_km", "mode": "PREFERRED", "weight": 10},
    {"attribute": "transmission", "mode": "PREFERRED", "weight": 8},
    {"attribute": "single_owner", "mode": "PREFERRED", "weight": 5}
  ],
  "images": [
    {"image_url": "https://...", "caption": "Referencia visual"}
  ],
  "legal_disclaimer_accepted": true
}
```

**Request (inmueble):**
```json
{
  "asset_type": "PROPERTY",
  "title": "Apartamento en Chapinero",
  "budget_max_cop": "450000000.00",
  "payment_type": "CREDIT",
  "city": "Bogotá",
  "location": {"latitude": 4.6483, "longitude": -74.0623},
  "property": {
    "property_type": "Apartamento",
    "neighborhood": "Chapinero Alto",
    "area_min_sqm": 80,
    "bedrooms_min": 3,
    "bathrooms_min": 2,
    "parking_spots_min": 1,
    "has_elevator": true,
    "urbanization_type": "Conjunto cerrado",
    "socioeconomic_stratum": 4,
    "admin_fee_max_cop": "500000.00"
  },
  "criteria": [
    {"attribute": "has_elevator", "mode": "REQUIRED", "weight": 15},
    {"attribute": "urbanization_type", "mode": "REQUIRED", "weight": 10},
    {"attribute": "has_pool", "mode": "PREFERRED", "weight": 5}
  ],
  "legal_disclaimer_accepted": true
}
```

**Response 201:** la necesidad completa creada en `status=DRAFT`.

**Errores:**
- `422 USER_NOT_VERIFIED` — si `is_fully_verified=false`
- `422 VALIDATION_ERROR` — presupuesto negativo, criteria con atributo inexistente
- Throttle: `need_create` (20/day)

---

### 4.2 `POST /needs/{id}/publish/`

Transición `DRAFT → ACTIVE`. Dispara el motor de match.

**Response 200:**
```json
{
  "id": "...",
  "status": "ACTIVE",
  "expires_at": "2026-08-19T15:30:00-05:00"
}
```

**Errores:**
- `409 CONFLICT` — ya está ACTIVE
- `422 VALIDATION_ERROR` — presupuesto < 40% valor comercial estimado
- `422 VALIDATION_ERROR` — legal_disclaimer_accepted es false

---

### 4.3 `GET /needs/` — HUS10, HUS11

**Vista dual según query:**

- **Sin `?scope=browse`** → lista las necesidades **propias del usuario** (`buyer=me`).
- **Con `?scope=browse`** → HUS11-14, lista todas las necesidades **públicas activas** (excluye las propias) para que el vendedor navegue oportunidades.

**Filtros para `?scope=browse`:**
- `asset_type=VEHICLE|PROPERTY`
- `city=Bogotá`
- `budget_min=50000000` / `budget_max=200000000`
- `brand=Toyota` / `property_type=Apartamento`
- `location=lat,lng&radius_km=50` — filtro geoespacial vía PostGIS
- `search=<texto>` — busca en título y descripción
- `ordering=-created_at|-matches_count`

**Response 200 (paginado):**
```json
{
  "count": 25,
  "next": "...",
  "previous": null,
  "results": [
    {
      "id": "...",
      "asset_type": "VEHICLE",
      "title": "Toyota Hilux 4x4 2021",
      "budget_max_cop": "120000000.00",
      "payment_type": "CASH",
      "city": "Bogotá",
      "status": "ACTIVE",
      "matches_count": 3,
      "views_count": 47,
      "expires_at": "2026-08-19T15:30:00-05:00",
      "created_at": "2026-07-20T15:30:00-05:00",
      "buyer": {
        "id": "...",
        "full_name": "María G.",
        "rating_average": 4.5,
        "is_new_user": false
      }
    }
  ]
}
```

---

### 4.4 `GET /needs/{id}/` — HUS13

Detalle completo, incluyendo `vehicle` o `property`, `criteria` e `images`.

**Autorización:** el buyer siempre ve su propia. Otros usuarios solo ven `ACTIVE`.

**Efecto:** si el que consulta no es el buyer, incrementa `views_count`.

---

### 4.5 `PATCH /needs/{id}/` — HUS08

Solo `need.buyer`. Solo mientras `status in [DRAFT, ACTIVE, PAUSED]`.

**Request:** campos parciales del payload de create.

**Response 200** con la necesidad actualizada.

Si cambia criterios o valores clave → recalcula matches (nueva Celery task).

---

### 4.6 `POST /needs/{id}/pause/` / `POST /needs/{id}/resume/`

Pausa o reanuda una necesidad. **Response 200** con `status` actualizado.

---

### 4.7 `DELETE /needs/{id}/` — HUS09

Soft delete: `status=DELETED`. Los matches y contactos históricos se preservan.

**Response 204**

---

### 4.8 `GET /needs/{id}/matches/` — HUS10, ver matches de una necesidad

Ver detalle en la sección 6.

---

## 5 · Inventario (`/api/v1/inventory/`)

### 5.1 `POST /inventory/` — HUS22 opcionalmente dispara IA

Crear item de inventario. Usuario debe estar `fully_verified`.

**Request (vehículo):**
```json
{
  "asset_type": "VEHICLE",
  "title": "Toyota Hilux 2022 4x4",
  "description": "Vendedor autorizado",
  "price_cop": "118000000.00",
  "city": "Bogotá",
  "location": {"latitude": 4.6097, "longitude": -74.0817},
  "vehicle": {
    "brand": "Toyota",
    "model": "Hilux",
    "line": "SRV",
    "year": 2022,
    "fuel_type": "Diésel",
    "body_type": "Pickup",
    "traction": "4x4",
    "transmission": "Mecánica",
    "mileage_km": 43000,
    "doors": 4,
    "single_owner": true,
    "accessories": ["Aire", "Bluetooth", "Kit off-road"]
  },
  "generate_ai_images": true
}
```

**Response 201:** el item creado en `status=AVAILABLE`, con `unlock_count=0`.

Si `generate_ai_images=true` → dispara Celery task; las imágenes aparecerán como `is_ai_generated=true` cuando estén listas.

---

### 5.2 `GET /inventory/` — inventario propio

Solo lista items del usuario autenticado. Filtros: `asset_type`, `status`.

---

### 5.3 `GET /inventory/{id}/`

Detalle. Solo el `seller` puede ver items en cualquier status. Un tercero solo ve `AVAILABLE` en contextos de match.

---

### 5.4 `PATCH /inventory/{id}/`

Solo el seller. Si cambia atributos que afectan matches → dispara rematching.

---

### 5.5 `POST /inventory/{id}/mark-sold/`

Cambia `status=SOLD`. Los matches activos hacia este item se marcan como `DISCARDED`.

**Response 200**

---

### 5.6 `POST /inventory/{id}/reserve/` / `POST /inventory/{id}/reactivate/`

---

### 5.7 `DELETE /inventory/{id}/`

Soft delete → `status=INACTIVE`.

---

### 5.8 `POST /inventory/{id}/generate-ai-image/` — HUS22

Dispara generación IA con prompt automático basado en atributos del item.

**Request opcional:**
```json
{ "prompt_override": "vista frontal, luz natural" }
```

**Response 202:**
```json
{ "task_id": "...", "estimated_ready_at": "2026-07-20T15:35:00-05:00" }
```

---

### 5.9 `POST /inventory/{id}/images/select-ai/` — HUS23

Selecciona cuáles imágenes IA generadas se muestran en el item.

**Request:**
```json
{ "image_ids": ["...", "..."] }
```

---

## 6 · Matches (`/api/v1/matches/`)

### 6.1 `GET /matches/` — HUS10, HUS17

**Vista dual según `?role=`:**

- **`?role=buyer`** (default) — matches donde `buyer=me`: los vendedores encontrados para mis necesidades.
- **`?role=seller`** — matches donde `seller=me`: los compradores que buscan algo compatible con mi inventario (HUS17).

**Filtros:**
- `need_id=<uuid>` — matches de una necesidad específica
- `inventory_item_id=<uuid>` — matches de un item específico (seller view)
- `status=GENERATED|VIEWED|UNLOCKED|DISCARDED`
- `min_score=80`
- `ordering=-score|-created_at`

**Response 200 (buyer):**
```json
{
  "count": 3,
  "results": [
    {
      "id": "match-uuid",
      "need_id": "...",
      "inventory_item": {
        "id": "...",
        "title": "Toyota Hilux 2022 4x4",
        "price_cop": "118000000.00",
        "city": "Bogotá",
        "distance_km": "3.5",
        "images": [{"image_url": "...", "is_ai_generated": true}],
        "vehicle": { "brand": "Toyota", "model": "Hilux", "year": 2022, ... }
      },
      "seller": {
        "id": "...",
        "full_name": "Carlos Ramírez",
        "rating_average": 4.8,
        "reviews_received_count": 12,
        "is_new_user": false
      },
      "score": 98,
      "distance_km": "3.5",
      "unmet_preferences": [],
      "status": "GENERATED",
      "already_unlocked": false,
      "unlock_cost_wantis": 1
    },
    {
      "id": "...",
      "score": 82,
      "unmet_preferences": ["traction"],
      "unmet_preferences_labels": ["Deseable, pero no excluyente: Tracción 4x2"],
      "seller": { "is_new_user": true, "rating_average": null, ... },
      ...
    }
  ]
}
```

**Response 200 (seller):**
```json
{
  "count": 7,
  "results": [
    {
      "id": "...",
      "need": {
        "id": "...",
        "title": "Toyota Hilux 4x4",
        "budget_max_cop": "120000000.00",
        "payment_type": "CASH",
        "city": "Bogotá",
        "criteria_summary": {
          "required": ["Diésel", "4x4"],
          "preferred": ["< 80.000 km", "Mecánica"]
        }
      },
      "buyer": {
        "id": "...",
        "full_name": "María G.",
        "rating_average": 4.5,
        "is_new_user": false
      },
      "score": 94,
      "inventory_item_id": "...",
      "status": "GENERATED",
      "created_at": "..."
    }
  ]
}
```

---

### 6.2 `GET /matches/{id}/`

Detalle completo del match, incluyendo `criteria_results` con el breakdown por criterio (útil para explicar el score).

**Response 200:**
```json
{
  "id": "...",
  "need": { ... },
  "inventory_item": { ... },
  "buyer": { ... },
  "seller": { ... },
  "score": 82,
  "distance_km": "3.5",
  "criteria_results": [
    {"attribute": "fuel_type", "mode": "REQUIRED", "expected": "Diésel", "actual": "Diésel", "met": true, "contribution": 20},
    {"attribute": "traction", "mode": "PREFERRED", "expected": "4x4", "actual": "4x2", "met": false, "contribution": 0},
    {"attribute": "mileage_max_km", "mode": "PREFERRED", "expected": "80000", "actual": "71000", "met": true, "contribution": 10}
  ],
  "unmet_preferences": ["traction"],
  "already_unlocked": false
}
```

**Efecto:** si el que consulta es el buyer y `status=GENERATED`, transiciona a `VIEWED`.

---

### 6.3 `POST /matches/{id}/discard/`

El buyer descarta un match. `status=DISCARDED`.

---

## 7 · Wallet (`/api/v1/wallet/`)

### 7.1 `GET /wallet/`

**Response 200:**
```json
{
  "balance_wantis": 48,
  "wanti_price_cop": 5000,
  "balance_equivalent_cop": "240000.00"
}
```

---

### 7.2 `GET /wallet/packages/` — HUS18 previo

Lista los paquetes activos de recarga.

**Response 200:**
```json
[
  {
    "id": "...",
    "name": "Básico",
    "wantis_base": 5,
    "wantis_bonus": 0,
    "wantis_total": 5,
    "price_cop": "25000.00",
    "is_popular": false
  },
  {
    "id": "...",
    "name": "Popular",
    "wantis_base": 10,
    "wantis_bonus": 1,
    "wantis_total": 11,
    "price_cop": "50000.00",
    "is_popular": true
  }
]
```

---

### 7.3 `POST /wallet/topups/` — HUS18

Inicia una orden de recarga. Retorna la URL de checkout de la pasarela.

**Request:**
```json
{ "package_id": "..." }
```

**Response 201:**
```json
{
  "order_id": "...",
  "status": "PENDING",
  "checkout_url": "https://checkout.sandbox-provider.com/...",
  "expires_at": "2026-07-20T16:00:00-05:00"
}
```

---

### 7.4 `POST /wallet/topups/webhook/` — público (con firma HMAC)

**Endpoint que consume la pasarela de pagos.** Idempotente.

**Headers:**
```
X-Wanti-Signature: sha256=<hmac>
```

**Request (ejemplo genérico):**
```json
{
  "event": "payment.completed",
  "provider_reference": "TXN-abc-123",
  "order_id": "...",
  "amount_cop": "50000.00",
  "status": "COMPLETED",
  "paid_at": "2026-07-20T15:45:00-05:00"
}
```

**Response 200:** `{"received": true}`

**Efecto:** al recibir `COMPLETED`, se aplican dos `WalletTransaction`: `TOPUP` (base) y `BONUS` (extra). Se envía push al usuario. **Sin autenticación JWT** pero con validación HMAC obligatoria.

---

### 7.5 `GET /wallet/transactions/` — HUS21

Historial completo de transacciones del wallet.

**Filtros:**
- `transaction_type=UNLOCK|TOPUP|REFUND|...`
- `date_from=2026-07-01&date_to=2026-07-31`

**Response 200 (paginado):**
```json
{
  "count": 12,
  "results": [
    {
      "id": "...",
      "transaction_type": "UNLOCK",
      "amount_wantis": -1,
      "balance_after": 47,
      "note": "Desbloqueo contacto — Toyota Hilux 2022",
      "related_object_type": "ContactUnlock",
      "related_object_id": "...",
      "created_at": "2026-07-20T15:50:00-05:00"
    },
    {
      "transaction_type": "TOPUP",
      "amount_wantis": 10,
      "balance_after": 48,
      "note": "Recarga paquete Popular",
      "created_at": "2026-07-19T20:15:00-05:00"
    },
    {
      "transaction_type": "BONUS",
      "amount_wantis": 1,
      "balance_after": 49,
      "note": "Bonificación +1 gratis",
      "created_at": "2026-07-19T20:15:00-05:00"
    }
  ]
}
```

---

## 8 · Contactos — Desbloqueo (`/api/v1/contacts/`)

### 8.1 `POST /matches/{match_id}/unlock/` — HUS20

**Endpoint estelar del reverse marketplace.** El comprador paga 1 Wanti para acceder al contacto del vendedor.

**Response 201:**
```json
{
  "unlock_id": "...",
  "seller": {
    "id": "...",
    "full_name": "Carlos Ramírez",
    "phone": "+573105550192",
    "email": "carlos@example.com",
    "profile_photo_url": "https://...",
    "rating_average": 4.8,
    "is_new_user": false
  },
  "inventory_item": {
    "id": "...",
    "title": "Toyota Hilux 2022 4x4",
    "price_cop": "118000000.00",
    "detailed_images": ["https://..."]
  },
  "whatsapp_deep_link": "https://wa.me/573105550192?text=Hola%20Carlos%2C%20vi%20tu%20Toyota%20Hilux%20en%20Wanti...",
  "wantis_charged": 1,
  "wallet_balance_after": 47,
  "unlocked_at": "2026-07-20T15:50:00-05:00"
}
```

**Errores:**
- `403 PERMISSION_DENIED` — el match no es del usuario
- `409 CONFLICT` — match ya desbloqueado (retorna el existente en modo idempotente si se pasa header `Idempotency-Key`)
- `422 INSUFFICIENT_FUNDS` — `{"error": {"code":"INSUFFICIENT_FUNDS","message":"...","details":{"needed":1,"available":0,"topup_url":"/wallet/packages/"}}}`

**Efectos:**
- Débito de 1 Wanti (`WalletTransaction.UNLOCK`)
- `Match.status = UNLOCKED`
- `ContactUnlock` creado
- `Lead(stage=NEW)` creado para el vendedor
- Push al vendedor: "Un comprador desbloqueó tu contacto"
- `AuditLog(CONTACT_UNLOCKED)`

---

### 8.2 `GET /contacts/unlocks/`

Lista de contactos desbloqueados por el usuario (vista del comprador).

**Filtros:** `outcome`, `date_from`, `date_to`.

**Response 200 (paginado):**
```json
{
  "count": 5,
  "results": [
    {
      "id": "...",
      "seller": { ... },
      "inventory_item": { ... },
      "wantis_charged": 1,
      "outcome": "IN_PROGRESS",
      "outcome_reported_at": "2026-07-20T16:00:00-05:00",
      "whatsapp_opened_at": "2026-07-20T15:52:00-05:00",
      "created_at": "2026-07-20T15:50:00-05:00",
      "can_open_dispute": true,
      "review_pending": false
    }
  ]
}
```

---

### 8.3 `POST /contacts/unlocks/{id}/whatsapp-opened/`

Marca timestamp de apertura de WhatsApp (auditoría).

**Response 204**

---

### 8.4 `POST /contacts/unlocks/{id}/report-outcome/`

**Request:**
```json
{ "outcome": "PURCHASED" }
```

Valores: `PURCHASED`, `IN_PROGRESS`, `NOT_PURCHASED`, `INVALID_LEAD`.

**Response 200** con el unlock actualizado.

**Efecto:** si `outcome in [PURCHASED, NOT_PURCHASED]` → habilita flujo de review para ambas partes.

Si `outcome=INVALID_LEAD` → guía al usuario al flujo de disputa (pero no la crea automáticamente).

---

## 9 · Disputas (`/api/v1/disputes/`)

### 9.1 `POST /contacts/unlocks/{id}/disputes/`

Abre una nueva disputa. Solo el comprador o el vendedor del unlock pueden.

**Request:**
```json
{
  "reason": "CONTACT_INVALID",
  "description": "El número no existe, mensaje rebota",
  "attachments": [
    {"url": "https://storage/evidence1.png", "name": "captura.png", "mime": "image/png"}
  ]
}
```

**Response 201:**
```json
{
  "id": "...",
  "status": "OPEN",
  "reason": "CONTACT_INVALID",
  "auto_review_deadline": "2026-07-23T15:50:00-05:00",
  "created_at": "2026-07-20T15:55:00-05:00"
}
```

**Errores:**
- `409 CONFLICT` — ya existe una disputa activa para este unlock

---

### 9.2 `GET /disputes/`

Lista de disputas del usuario autenticado (como opener o como contraparte).

**Response 200 (paginado):**
```json
{
  "results": [
    {
      "id": "...",
      "status": "AUTO_REVIEW",
      "reason": "CONTACT_INVALID",
      "opened_by": {"id": "...", "full_name": "María G."},
      "contact_unlock_id": "...",
      "auto_review_deadline": "2026-07-23T15:50:00-05:00",
      "created_at": "..."
    }
  ]
}
```

---

### 9.3 `GET /disputes/{id}/`

Detalle completo con `attachments`, `events` (timeline).

**Response 200:**
```json
{
  "id": "...",
  "status": "HUMAN_REVIEW",
  "reason": "CONTACT_INVALID",
  "description": "...",
  "opened_by": { ... },
  "contact_unlock": { ... },
  "attachments": [{"file_url":"...","file_name":"captura.png"}],
  "events": [
    {"event_type": "OPENED", "created_at": "..."},
    {"event_type": "AUTO_PING_SENT", "created_at": "..."},
    {"event_type": "BUYER_RESPONDED", "payload": {"confirmed": false}, "created_at": "..."},
    {"event_type": "ESCALATED", "created_at": "..."}
  ],
  "auto_review_deadline": "...",
  "escalated_at": "...",
  "resolved_at": null,
  "refund_transaction": null,
  "appeal_deadline": null,
  "user_actions_available": ["cancel"]
}
```

---

### 9.4 `POST /disputes/{id}/respond-auto/`

Respuesta del comprador al ping automático.

**Request:**
```json
{ "confirmed_purchase": false }
```

**Response 200:**
```json
{ "status": "HUMAN_REVIEW", "escalated_at": "..." }
```

Si `confirmed_purchase=true` → status pasa a `REJECTED` (sin reembolso).

---

### 9.5 `POST /disputes/{id}/cancel/`

Solo `opened_by` mientras la disputa no esté resuelta.

**Response 200** con `status=CANCELLED`.

---

### 9.6 `POST /disputes/{id}/appeal/`

Reabre una disputa resuelta si estamos dentro del `appeal_deadline`.

**Request:**
```json
{ "reason": "Nueva evidencia adjunta" }
```

**Response 200** con `status=APPEALED` (queda en cola de revisión humana).

---

## 10 · Reseñas (`/api/v1/reviews/`)

### 10.1 `GET /reviews/tags/` — público

Catálogo de tags disponibles. Filtro `?for_role=BUYER_REVIEWING_SELLER`.

**Response 200:**
```json
[
  {"code": "FAST_RESPONSE", "label": "Rápido en responder", "for_role": "BUYER_REVIEWING_SELLER"},
  ...
]
```

---

### 10.2 `POST /contacts/unlocks/{id}/reviews/`

Crea una reseña. Solo comprador o vendedor del unlock. Solo si `outcome != PENDING`.

**Request:**
```json
{
  "rating": 5,
  "comment": "Muy amable, el vehículo estaba tal como lo describió.",
  "tags": ["FAST_RESPONSE", "ACCURATE_INFO"]
}
```

**Response 201** con la review creada.

**Errores:**
- `409 CONFLICT` — el usuario ya calificó este unlock
- `422 VALIDATION_ERROR` — outcome=PENDING

---

### 10.3 `GET /users/{id}/reviews/`

Reseñas recibidas por un usuario (público, solo `status=PUBLISHED`).

**Response 200 (paginado):**
```json
{
  "count": 12,
  "average_rating": 4.8,
  "results": [
    {
      "id": "...",
      "reviewer": {"id": "...", "full_name": "María G."},
      "rating": 5,
      "comment": "...",
      "tags": ["FAST_RESPONSE"],
      "created_at": "..."
    }
  ]
}
```

---

### 10.4 `GET /reviews/mine/`

Reseñas dadas por mí + reseñas recibidas por mí (con filtro `?type=given|received`).

---

### 10.5 `POST /reviews/{id}/dispute/`

Impugnar una reseña recibida.

**Request:**
```json
{ "reason": "Cliente nunca visitó el vehículo; comentario falso" }
```

**Response 201** — la review pasa a `UNDER_REVIEW` (queda oculta).

---

## 11 · Leads (CRM vendedor) — (`/api/v1/leads/`)

### 11.1 `GET /leads/`

Lista de leads del vendedor autenticado.

**Filtros:** `stage`, `search` (nombre del comprador), `ordering=-last_activity_at`.

**Response 200 (paginado):**
```json
{
  "count": 8,
  "results": [
    {
      "id": "...",
      "buyer": {
        "id": "...",
        "full_name": "Carlos Ramírez",
        "phone": "+573105550192",
        "rating_average": 4.5
      },
      "contact_unlock": {
        "id": "...",
        "inventory_item_title": "Toyota Hilux 2022 4x4",
        "price_cop": "118000000.00"
      },
      "stage": "IN_NEGOTIATION",
      "last_activity_at": "2026-07-20T10:34:00-05:00",
      "expires_at": "2026-08-19T10:34:00-05:00",
      "days_until_expiry": 30,
      "notes_count": 2,
      "sold_price_cop": null
    }
  ]
}
```

---

### 11.2 `GET /leads/{id}/`

Detalle + timeline de notas.

---

### 11.3 `POST /leads/{id}/change-stage/`

**Request:**
```json
{ "stage": "PURCHASED", "sold_price_cop": "115000000.00" }
```

`sold_price_cop` solo requerido si `stage=PURCHASED`.

**Response 200** con el lead actualizado. `last_activity_at` y `expires_at` se recalculan.

---

### 11.4 `POST /leads/{id}/notes/`

**Request:**
```json
{ "text": "Visita agendada para el sábado 24 a las 3 pm" }
```

**Response 201** con la nota creada.

---

### 11.5 `GET /leads/{id}/notes/`

Lista de notas del lead, ordenadas por `-created_at`.

---

## 12 · Notificaciones (`/api/v1/notifications/`)

### 12.1 `GET /notifications/`

Lista de notificaciones del usuario. Filtros: `channel`, `read=true|false`.

**Response 200 (paginado):**
```json
{
  "count": 15,
  "unread_count": 3,
  "results": [
    {
      "id": "...",
      "channel": "PUSH",
      "template_code": "MATCH_NEW_FOR_BUYER",
      "title": "Nuevo match para tu Hilux",
      "body": "Tenés 3 nuevos matches",
      "payload": {"need_id": "..."},
      "read_at": null,
      "created_at": "2026-07-20T15:30:00-05:00"
    }
  ]
}
```

---

### 12.2 `POST /notifications/{id}/mark-read/`

**Response 204**

---

### 12.3 `POST /notifications/mark-all-read/`

**Response 204**

---

### 12.4 `POST /notifications/device-tokens/`

Registra un token FCM/APNs para push.

**Request:**
```json
{
  "token": "fcm-token-abc123",
  "platform": "IOS",
  "device_id": "unique-device-uuid"
}
```

**Response 201**

---

### 12.5 `DELETE /notifications/device-tokens/{id}/`

Desregistra un dispositivo.

---

## 13 · Admin (`/api/v1/admin/`)

Todos requieren `role in [ADMIN, MODERATOR]`.

### 13.1 `GET /admin/metrics/` — HUS25

Dashboard de métricas generales.

**Response 200:**
```json
{
  "users": {
    "total": 1243,
    "active": 1189,
    "suspended": 54,
    "pending_verification": 78,
    "new_last_7_days": 45
  },
  "needs": {
    "total": 892,
    "active": 348,
    "expired": 421,
    "fulfilled": 78
  },
  "inventory": {
    "total_items": 1567,
    "available": 1204
  },
  "matches": {
    "generated_last_7_days": 3421,
    "unlocked_last_7_days": 187,
    "unlock_conversion_rate": 0.055
  },
  "wallet": {
    "total_wantis_in_circulation": 12480,
    "total_topup_cop_last_30_days": "42000000.00"
  },
  "disputes": {
    "open": 12,
    "in_human_review": 4,
    "resolved_last_30_days": 87,
    "approval_rate": 0.34
  }
}
```

---

### 13.2 `GET /admin/users/` — HUS26

Lista completa de usuarios con filtros de admin.

**Filtros:** `status`, `role`, `city`, `search`, `has_disputes=true`.

---

### 13.3 `GET /admin/users/{id}/` — HUS26

Vista extendida con toda la info del usuario, wallet, disputas, calificaciones.

---

### 13.4 `POST /admin/users/{id}/suspend/`

**Request:**
```json
{ "reason": "Múltiples reportes de fraude" }
```

---

### 13.5 `POST /admin/users/{id}/activate/`

---

### 13.6 `GET /admin/needs/` — HUS27

Todas las necesidades con filtros: `status`, `buyer_id`, `flagged=true`.

---

### 13.7 `POST /admin/needs/{id}/flag/` / `POST /admin/needs/{id}/unpublish/`

Moderación de contenido — HUS30.

---

### 13.8 `GET /admin/inventory/` — HUS28

---

### 13.9 `GET /admin/disputes/`

**Filtros:** `status`, `assigned_to`.

---

### 13.10 `POST /admin/disputes/{id}/approve/`

**Request:**
```json
{ "note": "Evidencia clara de contacto inválido. Reembolso emitido." }
```

**Response 200** — dispara reembolso al wallet del comprador.

---

### 13.11 `POST /admin/disputes/{id}/reject/`

**Request:**
```json
{ "note": "Evidencia insuficiente." }
```

---

### 13.12 `GET /admin/topups/` — HUS29

Historial completo de recargas para validación.

---

### 13.13 `POST /admin/wallets/{user_id}/adjust/`

Ajuste manual de wallet (uso extraordinario).

**Request:**
```json
{ "amount_wantis": 5, "note": "Compensación por incidencia técnica ticket #123" }
```

Crea `WalletTransaction(type=ADJUSTMENT)` con auditoría.

---

### 13.14 `GET /admin/review-disputes/` / `POST /admin/review-disputes/{id}/resolve/`

**Request:**
```json
{ "keep": false, "note": "Reseña confirmada como falsa. Eliminada." }
```

---

### 13.15 `GET /admin/reports/interactions/` — HUS31, HUS32

Reporte de eventos entre compradores y vendedores.

**Filtros:** `date_from`, `date_to`, `event_type`.

**Response 200:**
```json
{
  "period": "2026-07-01 to 2026-07-31",
  "totals": {
    "needs_created": 234,
    "matches_generated": 4231,
    "contacts_unlocked": 187,
    "wantis_spent_on_unlocks": 187,
    "reviews_created": 148,
    "disputes_opened": 23,
    "disputes_approved": 8
  },
  "conversion_funnel": {
    "need_to_match_rate": "18.1",
    "match_to_unlock_rate": "4.4",
    "unlock_to_purchase_rate": "38.5"
  }
}
```

---

### 13.16 `GET /admin/reports/matching/` — HUS33

**Response 200:**
```json
{
  "match_distribution": {
    "high_match_count": 340,
    "mid_match_count": 3891,
    "avg_score": 71.3,
    "avg_matches_per_need": 12.1
  },
  "top_matched_criteria": [
    {"attribute": "fuel_type", "match_rate": 0.87},
    {"attribute": "traction", "match_rate": 0.62}
  ]
}
```

---

### 13.17 `GET /admin/settings/` / `PATCH /admin/settings/{key}/`

Consulta y modificación de parámetros del sistema (`SystemSetting`).

**PATCH request:**
```json
{ "value": "6000" }
```

**Response 200:**
```json
{ "key": "WANTI_PRICE_COP", "value": "6000", "value_type": "INT", "updated_at": "..." }
```

Cambio se refleja en runtime (invalidando caché).

---

## 14 · Estructura de URLs raíz

`app/urls.py`:

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('django-admin/', admin.site.urls),
    path('api/v1/health/', include('apps.health.urls')),
    path('api/v1/auth/', include('apps.authn.urls')),
    path('api/v1/users/', include('apps.users.urls')),
    path('api/v1/needs/', include('apps.needs.urls')),
    path('api/v1/inventory/', include('apps.inventory.urls')),
    path('api/v1/matches/', include('apps.matching.urls')),
    path('api/v1/wallet/', include('apps.wallet.urls')),
    path('api/v1/contacts/', include('apps.contacts.urls')),
    path('api/v1/disputes/', include('apps.disputes.urls')),
    path('api/v1/reviews/', include('apps.reviews.urls')),
    path('api/v1/leads/', include('apps.leads.urls')),
    path('api/v1/notifications/', include('apps.notifications.urls')),
    path('api/v1/admin/', include('apps.admin_panel.urls')),
    # OpenAPI docs
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
]
```

---

## 15 · Matriz de permisos por endpoint

| Endpoint | Público | USER | USER (owner) | MODERATOR | ADMIN |
|---|:---:|:---:|:---:|:---:|:---:|
| `POST /auth/register/` | ✅ | | | | |
| `POST /auth/login/` | ✅ | | | | |
| `POST /needs/` | | ✅ verificado | | | |
| `GET /needs/?scope=browse` | | ✅ | | ✅ | ✅ |
| `PATCH /needs/{id}/` | | | ✅ | | ✅ (moderación) |
| `POST /inventory/` | | ✅ verificado | | | |
| `POST /matches/{id}/unlock/` | | | ✅ (buyer del match) | | |
| `POST /wallet/topups/webhook/` | ✅ (HMAC) | | | | |
| `GET /wallet/transactions/` | | | ✅ | | ✅ (ajenos) |
| `POST /disputes/` | | | ✅ (buyer o seller) | | |
| `POST /admin/disputes/{id}/approve/` | | | | ✅ | ✅ |
| `PATCH /admin/settings/{key}/` | | | | | ✅ |

**Regla general:**
- `USER` puede leer/mutar **solo lo propio**.
- `MODERATOR` puede moderar contenido (needs, reviews) pero no toca wallets ni settings.
- `ADMIN` tiene acceso total incluyendo settings y wallets.

---

## 16 · Ejemplos completos de flujo

### 16.1 Flujo comprador — registrarse hasta desbloquear contacto

```bash
# 1. Registro
curl -X POST https://api.wanti.co/api/v1/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"full_name":"María García","id_type":"CC","id_number":"123","email":"maria@x.co","phone":"+573001234567","city":"Bogotá","password":"S3cure!Pass"}'

# 2. Verificar email (link recibido por correo)
curl -X POST https://api.wanti.co/api/v1/auth/verify-email/ \
  -H "Content-Type: application/json" \
  -d '{"token":"..."}'

# 3. Login
curl -X POST https://api.wanti.co/api/v1/auth/login/ \
  -d '{"email":"maria@x.co","password":"S3cure!Pass"}'
# → {access, refresh, user}

# 4. Solicitar OTP
curl -X POST https://api.wanti.co/api/v1/auth/otp/request/ \
  -H "Authorization: Bearer $ACCESS" \
  -d '{"channel":"WHATSAPP"}'

# 5. Verificar OTP
curl -X POST https://api.wanti.co/api/v1/auth/otp/verify/ \
  -H "Authorization: Bearer $ACCESS" \
  -d '{"code":"472891"}'
# → status: ACTIVE

# 6. Crear necesidad (DRAFT)
curl -X POST https://api.wanti.co/api/v1/needs/ \
  -H "Authorization: Bearer $ACCESS" \
  -d @need-payload.json
# → 201 con id="need-uuid"

# 7. Publicar necesidad
curl -X POST https://api.wanti.co/api/v1/needs/need-uuid/publish/ \
  -H "Authorization: Bearer $ACCESS"
# → status: ACTIVE. Motor de match corre en background.

# 8. Listar matches
curl https://api.wanti.co/api/v1/matches/?need_id=need-uuid \
  -H "Authorization: Bearer $ACCESS"

# 9. Ver detalle de un match
curl https://api.wanti.co/api/v1/matches/match-uuid/ \
  -H "Authorization: Bearer $ACCESS"

# 10. Recargar wantis (requiere completar checkout)
curl -X POST https://api.wanti.co/api/v1/wallet/topups/ \
  -H "Authorization: Bearer $ACCESS" \
  -d '{"package_id":"..."}'
# → checkout_url. Usuario paga en la pasarela; webhook actualiza wallet.

# 11. Desbloquear contacto
curl -X POST https://api.wanti.co/api/v1/matches/match-uuid/unlock/ \
  -H "Authorization: Bearer $ACCESS"
# → 201 con datos del vendedor + whatsapp_deep_link

# 12. Reportar resultado
curl -X POST https://api.wanti.co/api/v1/contacts/unlocks/unlock-uuid/report-outcome/ \
  -H "Authorization: Bearer $ACCESS" \
  -d '{"outcome":"PURCHASED"}'

# 13. Calificar al vendedor
curl -X POST https://api.wanti.co/api/v1/contacts/unlocks/unlock-uuid/reviews/ \
  -H "Authorization: Bearer $ACCESS" \
  -d '{"rating":5,"comment":"Excelente vendedor","tags":["FAST_RESPONSE"]}'
```

---

### 16.2 Flujo disputa (comprador reporta lead inválido)

```bash
# 1. Abrir disputa
curl -X POST https://api.wanti.co/api/v1/contacts/unlocks/unlock-uuid/disputes/ \
  -H "Authorization: Bearer $ACCESS" \
  -d '{"reason":"CONTACT_INVALID","description":"El número no existe","attachments":[]}'
# → 201, status=OPEN, sistema envía push al comprador con "¿Compraste?"

# 2. (72h después, sin respuesta) → Celery escala automáticamente a HUMAN_REVIEW
# O el comprador responde:
curl -X POST https://api.wanti.co/api/v1/disputes/dispute-uuid/respond-auto/ \
  -H "Authorization: Bearer $ACCESS" \
  -d '{"confirmed_purchase":false}'

# 3. Admin resuelve (aprueba)
curl -X POST https://api.wanti.co/api/v1/admin/disputes/dispute-uuid/approve/ \
  -H "Authorization: Bearer $ADMIN_ACCESS" \
  -d '{"note":"Contacto verificado como inválido"}'
# → Reembolso +1 Wanti al wallet del comprador

# 4. Comprador puede apelar dentro de 7 días si no está de acuerdo
```

---

## ✅ Checklist de cierre

- [ ] Todos los endpoints listados están implementados con sus verbos correctos
- [ ] Todas las views delegan a servicios (thin views)
- [ ] Serializers usan Meta.fields explícitos (no `__all__`)
- [ ] Permisos `IsAuthenticated` por defecto; overrides en `permission_classes` por vista
- [ ] Filtros implementados con `django_filter.rest_framework.DjangoFilterBackend`
- [ ] Paginación aplicada a todos los listados
- [ ] Códigos HTTP conforme a la tabla
- [ ] Formato de errores consistente (`error.code`, `error.message`, `error.details`)
- [ ] Webhook de pagos valida HMAC antes de procesar
- [ ] OpenAPI/Swagger disponible en `/api/docs/`
- [ ] Endpoints con throttling correctamente decorados con `throttle_scope`
- [ ] Endpoint `/unlock/` es idempotente ante header `Idempotency-Key`
- [ ] Endpoints admin restringidos a `role in [ADMIN, MODERATOR]`

---

## ➡️ Siguiente paso

Continuar con **`04-docker-y-despliegue.md`**: dockerización completa (API, DB, Redis, Celery worker, Celery beat), variables de entorno de producción, hardening de seguridad, monitoreo y despliegue.

---
