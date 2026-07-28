# Wanti Backend — Modelos de Dominio

**Archivo 2 de 5** · Continúa de `00-setup-inicial.md`

Este documento define **todos los modelos de datos** de la aplicación: campos, tipos, relaciones, constraints, índices y reglas de integridad.

**Convenciones aplicadas a todos los modelos:**
- Todos heredan de `apps.common.models.BaseModel` (aporta `id` UUID, `created_at`, `updated_at`)
- Nombres de tabla explícitos vía `db_table` en snake_case plural
- Toda FK a `User` usa `settings.AUTH_USER_MODEL`
- Los borrados son lógicos (cambio de estado), nunca `DELETE` físico en entidades de negocio
- Los montos en COP se guardan como `DecimalField(max_digits=14, decimal_places=2)`
- Los saldos de Wantis se guardan como `IntegerField` (unidades enteras, nunca fracciones)

---

## Índice de modelos

| Módulo | Modelos |
|---|---|
| `common` | `SystemSetting` |
| `users` | `User` |
| `authn` | `EmailVerificationToken`, `PhoneOtp`, `PasswordResetToken` |
| `needs` | `Need`, `NeedCriterion`, `NeedImage` |
| `inventory` | `InventoryItem`, `InventoryImage` |
| `matching` | `Match`, `MatchCriterionResult` |
| `wallet` | `Wallet`, `WalletTransaction`, `TopupPackage`, `TopupOrder` |
| `contacts` | `ContactUnlock` |
| `disputes` | `Dispute`, `DisputeAttachment`, `DisputeEvent` |
| `reviews` | `Review`, `ReviewTag`, `ReviewDispute` |
| `leads` | `Lead`, `LeadNote` |
| `notifications` | `Notification`, `DeviceToken` |
| `audit` | `AuditLog` |

---

## 👤 Paso 7: Modelo de Usuario

### 7.1 Crear `apps/users/models.py`

**Implementar `User` heredando de `AbstractBaseUser` + `PermissionsMixin`:**

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUIDField | PK, default uuid4 |
| `full_name` | CharField(150) | Obligatorio |
| `id_type` | CharField(20) | choices=IdType |
| `id_number` | CharField(30) | |
| `email` | EmailField | **unique, USERNAME_FIELD** |
| `phone` | CharField(20) | Formato E.164, ej. +573005551234 |
| `city` | CharField(100) | Ciudad de residencia |
| `location` | PointField | Nullable, SRID 4326 — georreferenciación |
| `profile_photo_url` | URLField | Nullable |
| `role` | CharField(20) | choices=UserRole, default USER |
| `status` | CharField(20) | choices=UserStatus, default PENDING |
| `email_verified_at` | DateTimeField | Nullable |
| `phone_verified_at` | DateTimeField | Nullable |
| `is_staff` | BooleanField | default False |
| `created_at` / `updated_at` | DateTimeField | auto |
| `last_login_at` | DateTimeField | Nullable |

**Propiedades calculadas:**

```python
@property
def is_active(self):
    return self.status == UserStatus.ACTIVE

@property
def is_fully_verified(self):
    return self.email_verified_at is not None and self.phone_verified_at is not None

@property
def can_publish(self):
    """Regla crítica: no puede publicar necesidades ni inventario sin verificación dual."""
    return self.is_active and self.is_fully_verified

@property
def rating_average(self):
    """Promedio de calificaciones recibidas. None si no tiene."""
    from apps.reviews.selectors.reviews import get_user_rating
    return get_user_rating(self)

@property
def is_new_user(self):
    """True si no tiene calificaciones — se muestra badge 'Usuario nuevo'."""
    return self.rating_average is None
```

**Manager:**

```python
class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('El email es obligatorio')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('role', UserRole.ADMIN)
        extra_fields.setdefault('status', UserStatus.ACTIVE)
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('email_verified_at', timezone.now())
        extra_fields.setdefault('phone_verified_at', timezone.now())
        return self.create_user(email, password, **extra_fields)
```

**Meta:**

```python
class Meta:
    db_table = 'users'
    constraints = [
        models.UniqueConstraint(fields=['id_type', 'id_number'], name='unique_identity_document'),
    ]
    indexes = [
        models.Index(fields=['email']),
        models.Index(fields=['status']),
        models.Index(fields=['role']),
        models.Index(fields=['city']),
    ]
```

**Nota crítica sobre roles:**
No hay campo "es comprador" o "es vendedor". **Un mismo usuario puede publicar necesidades (rol comprador) y mantener inventario (rol vendedor) simultáneamente.** El rol se infiere del contexto de uso, no del modelo.

### 7.2 Modelos auxiliares de autenticación

**`EmailVerificationToken`** (en `apps/authn/models.py`):
- `user` (FK a User)
- `token` (CharField(64), unique, indexado)
- `expires_at` (DateTimeField)
- `used_at` (DateTimeField, nullable)

**`PhoneOtp`**:
- `user` (FK a User)
- `code_hash` (CharField(128)) — **nunca guardar el código en claro**
- `channel` (CharField, choices=OtpChannel)
- `expires_at` (DateTimeField)
- `attempts` (IntegerField, default 0)
- `verified_at` (DateTimeField, nullable)

**`PasswordResetToken`**:
- `user` (FK a User)
- `token` (CharField(64), unique, indexado)
- `expires_at` (DateTimeField)
- `used_at` (DateTimeField, nullable)

**`SystemSetting`** (en `apps/common/models.py`):
- `key` (CharField(64), unique) — usa `SettingKey`
- `value` (CharField(255))
- `value_type` (CharField: INT, DECIMAL, BOOL, STRING)
- `description` (TextField)

> Todos los parámetros de negocio (precio del Wanti, duración de necesidades, umbrales de match, radio geográfico) se leen de esta tabla vía `apps/common/services/settings_service.py`, **nunca hardcodeados**.

**Detalle de los tres modelos de `authn/models.py`:**

### 2.1 `EmailVerificationToken`

| Campo | Tipo | Notas |
|---|---|---|
| `user` | FK a `User`, `on_delete=CASCADE` | Un usuario puede tener varios (histórico) |
| `token` | CharField(64), unique, db_index | Generado con `secrets.token_urlsafe(48)` |
| `expires_at` | DateTimeField | Default: `now() + 24h` |
| `used_at` | DateTimeField, nullable | Marca cuándo se consumió el token |
| `created_at` | DateTimeField, auto_now_add | |

**Meta:**
- `db_table = 'email_verification_tokens'`
- `indexes = [Index(fields=['token']), Index(fields=['user', 'used_at'])]`

**Regla:** al usar un token válido, se marca `used_at` y **no se elimina la fila** (histórico auditable).

---

### 2.2 `PhoneOtp`

| Campo | Tipo | Notas |
|---|---|---|
| `user` | FK a `User`, `on_delete=CASCADE` | |
| `code_hash` | CharField(128) | **Hash SHA-256 del código**, nunca el código en claro |
| `channel` | CharField(20), choices=OtpChannel | WHATSAPP / SMS |
| `expires_at` | DateTimeField | Default: `now() + OTP_TTL_SECONDS` (de `SystemSetting`) |
| `attempts` | IntegerField, default 0 | Se incrementa en cada intento fallido |
| `verified_at` | DateTimeField, nullable | |
| `created_at` | DateTimeField, auto_now_add | |

**Meta:**
- `db_table = 'phone_otps'`
- `indexes = [Index(fields=['user', 'verified_at']), Index(fields=['created_at'])]`

**Reglas críticas:**
- **Nunca se guarda el código en claro.** El servicio recibe el código, lo hashea con `hashlib.sha256(code + settings.SECRET_KEY)`, y compara hashes.
- Si `attempts >= OTP_MAX_ATTEMPTS` (de `SystemSetting`), el OTP queda invalidado.
- Al pedir un OTP nuevo, cualquier OTP previo no verificado del usuario se invalida (`expires_at = now()`).

---

### 2.3 `PasswordResetToken`

| Campo | Tipo | Notas |
|---|---|---|
| `user` | FK a `User`, `on_delete=CASCADE` | |
| `token` | CharField(64), unique, db_index | `secrets.token_urlsafe(48)` |
| `expires_at` | DateTimeField | Default: `now() + 2h` |
| `used_at` | DateTimeField, nullable | |
| `requested_ip` | GenericIPAddressField, nullable | Para auditoría de intentos |
| `created_at` | DateTimeField, auto_now_add | |

**Meta:**
- `db_table = 'password_reset_tokens'`
- `indexes = [Index(fields=['token']), Index(fields=['user', 'used_at'])]`

**Regla:** al ejecutar un reset exitoso, se marca `used_at` **y** se invalidan todos los otros tokens pendientes del mismo usuario.

---

## 3 · App `common` — `SystemSetting`

### 3.1 `apps/common/models.py`

Además del `BaseModel` abstracto ya definido, este archivo contiene el modelo de configuración global:

```python
class SystemSetting(models.Model):
    """
    Parámetros de negocio ajustables desde el panel admin.
    Se leen vía apps.common.services.settings_service.
    Nunca se hardcodean valores de negocio en el código.
    """
    key = models.CharField(max_length=64, unique=True, db_index=True)
    value = models.CharField(max_length=255)
    value_type = models.CharField(
        max_length=10,
        choices=[('INT', 'Entero'), ('DECIMAL', 'Decimal'),
                 ('BOOL', 'Booleano'), ('STRING', 'Texto')]
    )
    description = models.TextField(blank=True)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True, blank=True,
        related_name='+'
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'system_settings'
```

**Fixture inicial** (crear vía `data migration` en `apps/common/migrations/0002_seed_settings.py`):

| Key | Value | Type | Descripción |
|---|---|---|---|
| `WANTI_PRICE_COP` | `5000` | INT | Precio en COP de 1 Wanti |
| `NEED_DURATION_DAYS` | `30` | INT | Días de vigencia de una necesidad |
| `LEAD_EXPIRY_DAYS` | `30` | INT | Días para caducidad automática de un lead sin actividad |
| `MATCH_HIGH_THRESHOLD` | `85` | INT | % mínimo para match "alto" (color teal) |
| `MATCH_MIN_SCORE` | `50` | INT | % mínimo para generar un match visible |
| `MATCH_RADIUS_KM` | `50` | INT | Radio geográfico de búsqueda en km |
| `MIN_BUDGET_RATIO` | `0.40` | DECIMAL | Ratio mínimo presupuesto/valor comercial (filtro anti-abuso) |
| `DISPUTE_AUTO_TIMEOUT_HOURS` | `72` | INT | Horas para que el comprador responda antes de escalar |
| `DISPUTE_APPEAL_DAYS` | `7` | INT | Días para apelar una disputa resuelta |
| `OTP_TTL_SECONDS` | `300` | INT | Vigencia del OTP (5 min) |
| `OTP_MAX_ATTEMPTS` | `5` | INT | Máximo de intentos de OTP antes de invalidar |
| `REVIEW_REWARD_THRESHOLD` | `5` | INT | Cantidad de reseñas para recompensa en Wantis |

**Servicio de lectura:**

```python
# apps/common/services/settings_service.py
from django.core.cache import cache
from apps.common.models import SystemSetting
from decimal import Decimal

def get_setting(key: str, default=None):
    """Lee un parámetro del sistema con caché de 60 segundos."""
    cache_key = f'sys:{key}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        s = SystemSetting.objects.get(key=key)
        val = _cast(s.value, s.value_type)
        cache.set(cache_key, val, 60)
        return val
    except SystemSetting.DoesNotExist:
        return default

def _cast(value, value_type):
    if value_type == 'INT':     return int(value)
    if value_type == 'DECIMAL': return Decimal(value)
    if value_type == 'BOOL':    return value.lower() in ('true', '1', 'yes')
    return value
```

**Regla:** cualquier cambio en el admin panel debe invalidar el caché (`cache.delete(f'sys:{key}')`).

---

## 4 · App `needs` — Necesidades del comprador

### 4.1 `apps/needs/models.py`

Un `Need` es la publicación central del comprador. Tiene una relación 1:1 con un modelo específico según el tipo de activo (`VehicleNeed` o `PropertyNeed`), N criterios y N imágenes.

### 4.1.1 `Need`

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUIDField (heredado de BaseModel) | |
| `buyer` | FK a `User`, `on_delete=PROTECT`, related_name='needs' | El comprador |
| `asset_type` | CharField(20), choices=AssetType | VEHICLE / PROPERTY |
| `title` | CharField(150) | Autogenerado o editable |
| `description` | TextField, blank | Notas del comprador |
| `budget_max_cop` | DecimalField(15,2) | Presupuesto máximo, **infranqueable** |
| `payment_type` | CharField(20), choices=PaymentType | CASH / CREDIT / TRADE_IN |
| `city` | CharField(100) | Ciudad textual |
| `location` | PointField(srid=4326, geography=True) | Coordenadas para PostGIS |
| `status` | CharField(20), choices=NeedStatus, default DRAFT | |
| `expires_at` | DateTimeField | Se setea al pasar a ACTIVE: `now() + NEED_DURATION_DAYS` |
| `matches_count` | IntegerField, default 0 | Denormalizado, actualizado por señal |
| `views_count` | IntegerField, default 0 | Denormalizado |
| `legal_disclaimer_accepted_at` | DateTimeField | Cláusula de responsabilidad |
| `created_at` / `updated_at` | (heredados) | |

**Meta:**
- `db_table = 'needs'`
- `indexes = [Index(fields=['buyer', 'status']), Index(fields=['asset_type', 'status']), Index(fields=['expires_at']), Index(fields=['city'])]`
- Índice GIST sobre `location` se crea automáticamente por GeoDjango.

**Regla:** al pasar de `DRAFT` a `ACTIVE`, el motor de match se dispara (Celery task).

---

### 4.1.2 `VehicleNeed` (OneToOne con `Need`)

| Campo | Tipo | Notas |
|---|---|---|
| `need` | OneToOneField a `Need`, primary_key=True, related_name='vehicle' | |
| `brand` | CharField(80) | Ej. Toyota |
| `model` | CharField(80) | Ej. Hilux |
| `line` | CharField(120), blank | Ej. SRV 4×4 |
| `year_min` | IntegerField, nullable | |
| `year_max` | IntegerField, nullable | |
| `fuel_type` | CharField(30), blank | Diésel, Gasolina, Eléctrico, Híbrido |
| `body_type` | CharField(30), blank | Sedán, Pickup, SUV, Hatchback |
| `mileage_max_km` | IntegerField, nullable | |
| `traction` | CharField(10), blank | 4x4 / 4x2 / AWD |
| `transmission` | CharField(20), blank | Mecánica / Automática |
| `doors` | IntegerField, nullable | |
| `single_owner` | BooleanField, nullable | |
| `plate_last_digit` | CharField(20), blank | Puede ser "par", "impar", "sin restricción" o un dígito |
| `accessories` | JSONField, default=list | Lista de accesorios deseados |

**Meta:** `db_table = 'need_vehicles'`

---

### 4.1.3 `PropertyNeed` (OneToOne con `Need`)

| Campo | Tipo | Notas |
|---|---|---|
| `need` | OneToOneField a `Need`, primary_key=True, related_name='property' | |
| `property_type` | CharField(20) | Casa / Apartamento |
| `neighborhood` | CharField(120), blank | |
| `area_min_sqm` | IntegerField, nullable | Metros cuadrados mínimos |
| `bedrooms_min` | IntegerField, nullable | |
| `bathrooms_min` | IntegerField, nullable | |
| `parking_spots_min` | IntegerField, nullable | |
| `has_elevator` | BooleanField, nullable | Con validación auto si `floor` es alto |
| `urbanization_type` | CharField(30), blank | Conjunto cerrado / Condominio / Barrio abierto |
| `has_pool` | BooleanField, nullable | |
| `has_sports_courts` | BooleanField, nullable | |
| `has_social_area` | BooleanField, nullable | |
| `has_terrace` | BooleanField, nullable | |
| `max_construction_age_years` | IntegerField, nullable | |
| `socioeconomic_stratum` | IntegerField, nullable | 1–6 (Colombia) |
| `admin_fee_max_cop` | DecimalField(15,2), nullable | Cuota máxima de administración |
| `utilities_max_cop` | DecimalField(15,2), nullable | Cuota máxima de servicios |
| `required_utilities` | JSONField, default=list | ["Agua", "Gas", "Luz", "Internet"] |

**Meta:** `db_table = 'need_properties'`

---

### 4.1.4 `NeedCriterion`

Este modelo materializa la marca "obligatorio vs preferencia" sobre cada atributo del vehículo/inmueble. **No todos los atributos están en la tabla específica** — este modelo permite que el comprador marque como obligatorio o preferencia cualquier atributo del formulario.

| Campo | Tipo | Notas |
|---|---|---|
| `need` | FK a `Need`, `on_delete=CASCADE`, related_name='criteria' | |
| `attribute` | CharField(80) | Nombre del atributo: `fuel_type`, `traction`, `has_elevator`, etc. |
| `mode` | CharField(20), choices=CriterionMode | REQUIRED / PREFERRED |
| `weight` | IntegerField, default 10 | Peso para el scoring (0–100). Un criterio REQUIRED excluye si no cumple; un PREFERRED reduce el score. |

**Meta:**
- `db_table = 'need_criteria'`
- `constraints = [UniqueConstraint(fields=['need', 'attribute'], name='unique_criterion_per_need')]`
- `indexes = [Index(fields=['need', 'mode'])]`

**Regla:** si un criterio no está registrado explícitamente para una `Need`, se asume `PREFERRED` con peso bajo.

---

### 4.1.5 `NeedImage`

Imágenes de referencia adjuntas por el comprador (HUS07).

| Campo | Tipo | Notas |
|---|---|---|
| `need` | FK a `Need`, `on_delete=CASCADE`, related_name='images' | |
| `image_url` | URLField(500) | URL en storage (S3/local) |
| `caption` | CharField(200), blank | |
| `order` | IntegerField, default 0 | |

**Meta:** `db_table = 'need_images'`, `ordering = ['order']`

---

## 5 · App `inventory` — Perfil de inventario del vendedor

**Nota conceptual (decisión de la reunión):** el vendedor **no publica avisos públicos individuales**. Mantiene un catálogo interno de items disponibles con precios aproximados; las fotos reales se comparten directamente por WhatsApp tras el desbloqueo. Las imágenes en el sistema son generadas por IA o cacheadas.

### 5.1 `InventoryItem`

| Campo | Tipo | Notas |
|---|---|---|
| `seller` | FK a `User`, `on_delete=PROTECT`, related_name='inventory' | El vendedor |
| `asset_type` | CharField(20), choices=AssetType | |
| `title` | CharField(150) | |
| `description` | TextField, blank | |
| `price_cop` | DecimalField(15,2) | Precio aproximado publicado |
| `city` | CharField(100) | |
| `location` | PointField(srid=4326, geography=True) | |
| `status` | CharField(20), choices=InventoryStatus, default AVAILABLE | |
| `views_count` | IntegerField, default 0 | |
| `unlock_count` | IntegerField, default 0 | Veces que se pagó por desbloquear su contacto para este item |

**Meta:**
- `db_table = 'inventory_items'`
- `indexes = [Index(fields=['seller', 'status']), Index(fields=['asset_type', 'status']), Index(fields=['city'])]`

---

### 5.2 `VehicleItem` (OneToOne con `InventoryItem`)

Espeja los campos de `VehicleNeed` pero con **valores concretos** (no rangos):

| Campo | Tipo |
|---|---|
| `item` | OneToOneField, pk, related_name='vehicle' |
| `brand`, `model`, `line` | CharField |
| `year` | IntegerField |
| `fuel_type`, `body_type`, `traction`, `transmission` | CharField |
| `mileage_km` | IntegerField |
| `doors` | IntegerField |
| `single_owner` | BooleanField |
| `plate_last_digit` | CharField(2) |
| `accessories` | JSONField, default=list |

**Meta:** `db_table = 'inventory_vehicles'`

---

### 5.3 `PropertyItem` (OneToOne con `InventoryItem`)

Espeja `PropertyNeed` con valores concretos:

| Campo | Tipo |
|---|---|
| `item` | OneToOneField, pk, related_name='property' |
| `property_type` | CharField |
| `neighborhood` | CharField |
| `area_sqm` | IntegerField |
| `bedrooms`, `bathrooms`, `parking_spots` | IntegerField |
| `floor` | IntegerField |
| `has_elevator`, `has_pool`, `has_sports_courts`, `has_social_area`, `has_terrace` | BooleanField |
| `urbanization_type` | CharField |
| `construction_year` | IntegerField |
| `socioeconomic_stratum` | IntegerField |
| `admin_fee_cop` | DecimalField(15,2) |
| `utilities_avg_cop` | DecimalField(15,2) |
| `available_utilities` | JSONField, default=list |

**Meta:** `db_table = 'inventory_properties'`

---

### 5.4 `InventoryImage`

| Campo | Tipo | Notas |
|---|---|---|
| `item` | FK a `InventoryItem`, `on_delete=CASCADE`, related_name='images' | |
| `image_url` | URLField(500) | |
| `is_ai_generated` | BooleanField, default False | HUS22 |
| `source_prompt` | TextField, blank | Prompt usado si es IA |
| `order` | IntegerField, default 0 | |

**Meta:** `db_table = 'inventory_images'`, `ordering = ['order']`

---

## 6 · App `matching` — Motor de match

### 6.1 `Match`

Representa una coincidencia entre una `Need` (comprador) y un `InventoryItem` (vendedor), con su porcentaje de afinidad calculado.

| Campo | Tipo | Notas |
|---|---|---|
| `need` | FK a `Need`, `on_delete=CASCADE`, related_name='matches' | |
| `inventory_item` | FK a `InventoryItem`, `on_delete=CASCADE`, related_name='matches' | |
| `buyer` | FK a `User`, related_name='matches_as_buyer` | Denormalizado desde `need.buyer` |
| `seller` | FK a `User`, related_name='matches_as_seller` | Denormalizado desde `inventory_item.seller` |
| `score` | IntegerField | 0–100 |
| `distance_km` | DecimalField(6,2) | Distancia geográfica calculada |
| `required_criteria_met` | BooleanField, default True | Si algún REQUIRED falla, el match no se genera (redundante pero útil para debug) |
| `unmet_preferences` | JSONField, default=list | Lista de criterios PREFERRED no cumplidos, para mostrar "Deseable, pero no excluyente" |
| `status` | CharField(20), choices=MatchStatus, default GENERATED | |
| `viewed_at` | DateTimeField, nullable | |
| `unlocked_at` | DateTimeField, nullable | Cuando el comprador pagó por el contacto |
| `discarded_at` | DateTimeField, nullable | Si el comprador lo descarta |

**Meta:**
- `db_table = 'matches'`
- `constraints = [UniqueConstraint(fields=['need', 'inventory_item'], name='unique_match_per_pair')]`
- `indexes = [Index(fields=['buyer', 'status']), Index(fields=['seller', 'status']), Index(fields=['need', '-score']), Index(fields=['score'])]`

**Regla crítica:** solo se generan `Match` con `score >= MATCH_MIN_SCORE` (de `SystemSetting`).

---

### 6.2 `MatchCriterionResult`

Detalle por criterio del scoring — permite explicar al comprador y al vendedor **por qué** un match tiene un puntaje dado.

| Campo | Tipo | Notas |
|---|---|---|
| `match` | FK a `Match`, `on_delete=CASCADE`, related_name='criteria_results` | |
| `attribute` | CharField(80) | El mismo `attribute` de `NeedCriterion` |
| `mode` | CharField(20) | REQUIRED / PREFERRED |
| `expected_value` | CharField(150) | Valor solicitado por el comprador |
| `actual_value` | CharField(150) | Valor del inventario |
| `met` | BooleanField | ¿Cumple? |
| `contribution` | IntegerField | Puntos que aportó al score (positivo o cero) |

**Meta:**
- `db_table = 'match_criterion_results'`
- `indexes = [Index(fields=['match', 'met'])]`

---

## 7 · App `wallet` — Wantis, transacciones y recargas

### 7.1 `Wallet`

Uno por usuario, creado automáticamente al activar la cuenta (signal `post_save` sobre `User`).

| Campo | Tipo | Notas |
|---|---|---|
| `user` | OneToOneField a `User`, `on_delete=PROTECT`, related_name='wallet` | |
| `balance_wantis` | IntegerField, default 0 | **Saldo en Wantis (unidades enteras)** |

**Meta:** `db_table = 'wallets'`

**Regla:** el saldo nunca se modifica directamente. Todas las mutaciones pasan por `apps.wallet.services.wallet.apply_transaction()` dentro de una transacción atómica que crea una fila en `WalletTransaction` **y** ajusta el balance en la misma operación.

---

### 7.2 `WalletTransaction`

**Ledger inmutable** — cada movimiento de Wantis se registra como una fila. Nunca se edita ni elimina.

| Campo | Tipo | Notas |
|---|---|---|
| `wallet` | FK a `Wallet`, `on_delete=PROTECT`, related_name='transactions' | |
| `transaction_type` | CharField(20), choices=TransactionType | |
| `amount_wantis` | IntegerField | Positivo (crédito) o negativo (débito) |
| `balance_after` | IntegerField | Saldo resultante — permite validar integridad |
| `related_object_type` | CharField(50), blank | Ej. "ContactUnlock", "Dispute", "TopupOrder" |
| `related_object_id` | UUIDField, nullable | ID de la entidad relacionada |
| `note` | TextField, blank | Descripción legible |
| `created_by` | FK a `User`, nullable, `on_delete=PROTECT` | Quién originó (puede ser system) |

**Meta:**
- `db_table = 'wallet_transactions'`
- `indexes = [Index(fields=['wallet', '-created_at']), Index(fields=['transaction_type'])]`

**Regla:** `balance_after` se calcula dentro de la transacción atómica y sirve como checksum. Un job diario puede validar que la suma acumulada coincide con `wallet.balance_wantis`.

---

### 7.3 `TopupPackage`

Paquetes de recarga configurables desde el admin panel.

| Campo | Tipo | Notas |
|---|---|---|
| `name` | CharField(80) | Ej. "Paquete Popular" |
| `wantis_base` | IntegerField | Wantis por el precio base |
| `wantis_bonus` | IntegerField, default 0 | Wantis adicionales (bonificación por volumen) |
| `price_cop` | DecimalField(15,2) | |
| `is_popular` | BooleanField, default False | Badge "Popular" en UI |
| `is_active` | BooleanField, default True | |
| `order` | IntegerField, default 0 | Orden de despliegue |

**Meta:** `db_table = 'topup_packages'`, `ordering = ['order']`

**Ejemplo de fixture inicial:**
| name | wantis_base | wantis_bonus | price_cop | is_popular |
|---|---|---|---|---|
| Básico | 5 | 0 | 25000 | false |
| Popular | 10 | 1 | 50000 | true |
| Premium | 20 | 5 | 100000 | false |

---

### 7.4 `TopupOrder`

Orden de recarga generada al iniciar el flujo con la pasarela de pagos.

| Campo | Tipo | Notas |
|---|---|---|
| `user` | FK a `User`, `on_delete=PROTECT` | |
| `package` | FK a `TopupPackage`, `on_delete=PROTECT` | Snapshot |
| `wantis_total` | IntegerField | `wantis_base + wantis_bonus` en el momento de la orden |
| `price_cop` | DecimalField(15,2) | Snapshot del precio |
| `status` | CharField(20), choices=TopupStatus, default PENDING | |
| `provider_reference` | CharField(120), blank, db_index | ID externo de la pasarela |
| `provider_payload` | JSONField, default=dict | Respuesta completa del webhook |
| `completed_at` | DateTimeField, nullable | |

**Meta:**
- `db_table = 'topup_orders'`
- `indexes = [Index(fields=['user', 'status']), Index(fields=['status', 'created_at']), Index(fields=['provider_reference'])]`

**Regla:** al recibir el webhook `COMPLETED`, se crea una `WalletTransaction` de tipo `TOPUP` con `wantis_base` y, si aplica, una segunda de tipo `BONUS` con `wantis_bonus`. Esto permite reportes claros sobre cuántos Wantis vinieron por compra directa vs. bonificación.

---

## 8 · App `contacts` — Desbloqueo de contactos

### 8.1 `ContactUnlock`

Registro del pago de un Wanti por parte del comprador para acceder al contacto del vendedor de un `Match`.

| Campo | Tipo | Notas |
|---|---|---|
| `match` | OneToOneField a `Match`, `on_delete=PROTECT`, related_name='unlock' | Un match solo puede desbloquearse una vez |
| `buyer` | FK a `User`, related_name='unlocks_as_buyer' | Denormalizado |
| `seller` | FK a `User`, related_name='unlocks_as_seller' | Denormalizado |
| `wantis_charged` | IntegerField, default 1 | Costo del desbloqueo (parametrizable a futuro) |
| `wallet_transaction` | OneToOneField a `WalletTransaction`, `on_delete=PROTECT` | El asiento de débito |
| `outcome` | CharField(20), choices=ContactOutcome, default PENDING | Resultado reportado por el comprador |
| `outcome_reported_at` | DateTimeField, nullable | |
| `whatsapp_opened_at` | DateTimeField, nullable | Auditoría del click en "Abrir WhatsApp" |

**Meta:**
- `db_table = 'contact_unlocks'`
- `indexes = [Index(fields=['buyer', '-created_at']), Index(fields=['seller', '-created_at']), Index(fields=['outcome'])]`

**Regla:** al crear un `ContactUnlock`, automáticamente se crea un `Lead` para el vendedor (ver app `leads`).

---

## 9 · App `disputes` — Disputas y reembolsos

### 9.1 `Dispute`

| Campo | Tipo | Notas |
|---|---|---|
| `contact_unlock` | FK a `ContactUnlock`, `on_delete=PROTECT`, related_name='disputes' | |
| `opened_by` | FK a `User`, `on_delete=PROTECT` | Quien abrió la disputa (normalmente el comprador) |
| `reason` | CharField(30), choices=DisputeReason | |
| `description` | TextField, blank | Texto libre del usuario |
| `status` | CharField(20), choices=DisputeStatus, default OPEN | |
| `auto_review_started_at` | DateTimeField, nullable | |
| `auto_review_deadline` | DateTimeField, nullable | `now() + DISPUTE_AUTO_TIMEOUT_HOURS` |
| `buyer_confirmed_purchase` | BooleanField, nullable | Respuesta del comprador al ping automático |
| `escalated_at` | DateTimeField, nullable | Cuando pasa a HUMAN_REVIEW |
| `resolved_at` | DateTimeField, nullable | |
| `resolved_by` | FK a `User`, nullable, `on_delete=PROTECT` | Admin que resolvió |
| `resolution_note` | TextField, blank | |
| `refund_transaction` | OneToOneField a `WalletTransaction`, nullable, `on_delete=PROTECT`, related_name='dispute_refund' | Asiento de reembolso |
| `appeal_deadline` | DateTimeField, nullable | `resolved_at + DISPUTE_APPEAL_DAYS` |

**Meta:**
- `db_table = 'disputes'`
- `indexes = [Index(fields=['status', '-created_at']), Index(fields=['opened_by', '-created_at']), Index(fields=['auto_review_deadline'])]`

**Reglas de flujo:**
1. Al abrir la disputa → `status=OPEN`, se dispara Celery task que envía notificación al comprador y setea `auto_review_deadline`.
2. Si el comprador responde "Sí, compré" → `status=REJECTED` automáticamente, sin reembolso.
3. Si responde "No compré" o no responde antes del deadline → `status=HUMAN_REVIEW`.
4. Admin resuelve → `status=APPROVED` (con reembolso) o `REJECTED`.
5. Solo mientras `now() < appeal_deadline` el usuario puede apelar.

---

### 9.2 `DisputeAttachment`

| Campo | Tipo | Notas |
|---|---|---|
| `dispute` | FK a `Dispute`, `on_delete=CASCADE`, related_name='attachments' | |
| `file_url` | URLField(500) | |
| `file_name` | CharField(200) | |
| `mime_type` | CharField(80) | Solo image/png, image/jpeg permitidos (5MB máx) |
| `uploaded_by` | FK a `User`, `on_delete=PROTECT` | |

**Meta:** `db_table = 'dispute_attachments'`

---

### 9.3 `DisputeEvent`

Historial de eventos de una disputa — trazabilidad completa para auditoría.

| Campo | Tipo | Notas |
|---|---|---|
| `dispute` | FK a `Dispute`, `on_delete=CASCADE`, related_name='events' | |
| `event_type` | CharField(50) | OPENED, AUTO_PING_SENT, BUYER_RESPONDED, ESCALATED, RESOLVED, APPEALED |
| `actor` | FK a `User`, nullable, `on_delete=PROTECT` | Puede ser system |
| `payload` | JSONField, default=dict | Datos del evento |

**Meta:** `db_table = 'dispute_events'`, `ordering = ['created_at']`

---

## 10 · App `reviews` — Calificaciones y reseñas

### 10.1 `Review`

Reseña entre comprador y vendedor. Se activa después de un `ContactUnlock` con `outcome` reportado.

| Campo | Tipo | Notas |
|---|---|---|
| `contact_unlock` | FK a `ContactUnlock`, `on_delete=PROTECT`, related_name='reviews' | |
| `reviewer` | FK a `User`, `on_delete=PROTECT`, related_name='reviews_given' | |
| `reviewee` | FK a `User`, `on_delete=PROTECT`, related_name='reviews_received' | |
| `rating` | IntegerField | 1–5 estrellas |
| `comment` | TextField, blank | |
| `tags` | JSONField, default=list | Chips seleccionadas ("Rápido en responder", etc.) |
| `status` | CharField(20), choices=ReviewStatus, default PUBLISHED | |

**Meta:**
- `db_table = 'reviews'`
- `constraints = [UniqueConstraint(fields=['contact_unlock', 'reviewer'], name='unique_review_per_reviewer')]`
- `indexes = [Index(fields=['reviewee', 'status']), Index(fields=['rating'])]`

**Regla:** un mismo `reviewer` solo puede calificar una vez por `ContactUnlock`, pero ambos lados pueden calificar (comprador→vendedor y vendedor→comprador).

**Cálculo del rating del usuario:** promedio de `rating` de todas las `Review` donde `reviewee = user` y `status = PUBLISHED`.

---

### 10.2 `ReviewTag`

Catálogo de tags disponibles para las reseñas — administrable.

| Campo | Tipo | Notas |
|---|---|---|
| `code` | CharField(50), unique | Ej. "FAST_RESPONSE" |
| `label` | CharField(80) | "Rápido en responder" |
| `for_role` | CharField(20) | BUYER_REVIEWING_SELLER / SELLER_REVIEWING_BUYER |
| `is_active` | BooleanField, default True | |
| `order` | IntegerField, default 0 | |

**Meta:** `db_table = 'review_tags'`, `ordering = ['for_role', 'order']`

**Fixture inicial:**
- Comprador → Vendedor: "Rápido en responder", "Información precisa", "Buen trato", "Precio justo"
- Vendedor → Comprador: "Serio y comprometido", "Comunicación clara", "Trato respetuoso", "Pagó rápido"

---

### 10.3 `ReviewDispute`

Impugnación de una reseña — el receptor de una mala reseña puede pedir revisión admin.

| Campo | Tipo | Notas |
|---|---|---|
| `review` | OneToOneField a `Review`, `on_delete=PROTECT`, related_name='dispute' | |
| `disputed_by` | FK a `User`, `on_delete=PROTECT` | Debe ser `review.reviewee` |
| `reason` | TextField | |
| `status` | CharField(20) | OPEN / RESOLVED_KEPT / RESOLVED_REMOVED |
| `resolved_by` | FK a `User`, nullable, `on_delete=PROTECT` | |
| `resolved_at` | DateTimeField, nullable | |
| `admin_note` | TextField, blank | |

**Meta:** `db_table = 'review_disputes'`

**Regla:** al abrir un `ReviewDispute`, la `Review` asociada pasa a `status=UNDER_REVIEW` (oculta en el perfil) hasta que el admin decida.

---

## 11 · App `leads` — CRM interno del vendedor

### 11.1 `Lead`

Se crea automáticamente al desbloquear un contacto. Es la vista del vendedor sobre los compradores que pagaron por su contacto.

| Campo | Tipo | Notas |
|---|---|---|
| `contact_unlock` | OneToOneField a `ContactUnlock`, `on_delete=PROTECT`, related_name='lead' | |
| `seller` | FK a `User`, `on_delete=PROTECT`, related_name='leads' | |
| `buyer` | FK a `User`, `on_delete=PROTECT`, related_name='leads_as_buyer' | Denormalizado |
| `stage` | CharField(20), choices=LeadStage, default NEW | |
| `last_activity_at` | DateTimeField, auto_now_add | Se actualiza con cada nota o cambio de stage |
| `expires_at` | DateTimeField | `last_activity_at + LEAD_EXPIRY_DAYS` |
| `sold_price_cop` | DecimalField(15,2), nullable | Al marcar como PURCHASED |

**Meta:**
- `db_table = 'leads'`
- `indexes = [Index(fields=['seller', 'stage']), Index(fields=['expires_at']), Index(fields=['seller', '-last_activity_at'])]`

**Regla:** Celery beat corre diariamente `tasks.expire_stale_leads`, que marca `stage=EXPIRED` para leads con `expires_at < now()` y `stage in [NEW, IN_NEGOTIATION, TO_VISIT]`.

---

### 11.2 `LeadNote`

| Campo | Tipo | Notas |
|---|---|---|
| `lead` | FK a `Lead`, `on_delete=CASCADE`, related_name='notes' | |
| `author` | FK a `User`, `on_delete=PROTECT` | Siempre el vendedor |
| `text` | TextField | |
| `stage_at_time` | CharField(20), choices=LeadStage | Snapshot del stage al momento de la nota |

**Meta:** `db_table = 'lead_notes'`, `ordering = ['-created_at']`

**Regla:** cada `LeadNote` creado actualiza `lead.last_activity_at` y recalcula `expires_at`.

---

## 12 · App `notifications`

### 12.1 `Notification`

| Campo | Tipo | Notas |
|---|---|---|
| `recipient` | FK a `User`, `on_delete=CASCADE`, related_name='notifications' | |
| `channel` | CharField(20), choices=NotificationChannel | PUSH / EMAIL / WHATSAPP / SMS |
| `template_code` | CharField(80) | Ej. "MATCH_NEW", "CONTACT_UNLOCKED", "DISPUTE_RESOLVED" |
| `title` | CharField(150), blank | |
| `body` | TextField | |
| `payload` | JSONField, default=dict | Datos para deep-linking |
| `sent_at` | DateTimeField, nullable | |
| `read_at` | DateTimeField, nullable | |
| `delivery_status` | CharField(20), default 'PENDING' | PENDING / SENT / DELIVERED / FAILED |
| `provider_reference` | CharField(120), blank | ID del proveedor externo |
| `error_message` | TextField, blank | |

**Meta:**
- `db_table = 'notifications'`
- `indexes = [Index(fields=['recipient', '-created_at']), Index(fields=['channel', 'delivery_status']), Index(fields=['template_code'])]`

---

### 12.2 `DeviceToken`

Registro de tokens de push (FCM/APNs) por dispositivo.

| Campo | Tipo | Notas |
|---|---|---|
| `user` | FK a `User`, `on_delete=CASCADE`, related_name='device_tokens' | |
| `token` | CharField(500), unique | |
| `platform` | CharField(10) | IOS / ANDROID / WEB |
| `device_id` | CharField(120), blank | |
| `is_active` | BooleanField, default True | Se desactiva si el proveedor devuelve `Unregistered` |
| `last_used_at` | DateTimeField, auto_now | |

**Meta:** `db_table = 'device_tokens'`, `indexes = [Index(fields=['user', 'is_active'])]`

---

## 13 · App `audit`

### 13.1 `AuditLog`

Registro inmutable de todas las acciones sensibles del sistema.

| Campo | Tipo | Notas |
|---|---|---|
| `actor_user` | FK a `User`, nullable, `on_delete=PROTECT` | Nullable para eventos del sistema |
| `action` | CharField(80) | Ej. "USER_REGISTERED", "OTP_VERIFIED", "NEED_PUBLISHED", "MATCH_GENERATED", "CONTACT_UNLOCKED", "WALLET_TOPUP", "DISPUTE_OPENED", "DISPUTE_RESOLVED", "REVIEW_CREATED", "SETTING_CHANGED", "USER_SUSPENDED" |
| `entity` | CharField(50) | "User", "Need", "Match", "Wallet", "Dispute", etc. |
| `entity_id` | UUIDField, nullable | |
| `metadata` | JSONField, default=dict | Datos adicionales (nunca contraseñas ni tokens) |
| `ip_address` | GenericIPAddressField, nullable | |
| `user_agent` | CharField(500), blank | |
| `created_at` | DateTimeField, auto_now_add, db_index | |

**Meta:**
- `db_table = 'audit_logs'`
- `indexes = [Index(fields=['actor_user', '-created_at']), Index(fields=['entity', 'entity_id']), Index(fields=['action', '-created_at'])]`

**Regla crítica:** cada servicio de dominio debe emitir al menos un `AuditLog` por acción sensible. Nunca se registran datos sensibles (contraseñas, códigos OTP en claro, tokens JWT completos).

---

## 14 · Migraciones y orden de creación

Ejecutar en este orden para evitar dependencias circulares:

```bash
python manage.py makemigrations common
python manage.py makemigrations users
python manage.py makemigrations authn audit
python manage.py makemigrations wallet
python manage.py makemigrations needs inventory
python manage.py makemigrations matching
python manage.py makemigrations contacts leads
python manage.py makemigrations reviews disputes
python manage.py makemigrations notifications
python manage.py migrate
```

Después crear las **data migrations** para cargar fixtures:

```bash
python manage.py makemigrations common --empty --name seed_settings
python manage.py makemigrations wallet --empty --name seed_topup_packages
python manage.py makemigrations reviews --empty --name seed_review_tags
```

Editar cada archivo para poblar la data inicial descrita en las tablas de este documento.

---

## 15 · Diagrama de relaciones (resumen)

```
User ──1:1──> Wallet ──1:N──> WalletTransaction
  │
  ├──1:N──> Need (buyer) ──1:1──> VehicleNeed | PropertyNeed
  │              │──1:N──> NeedCriterion
  │              │──1:N──> NeedImage
  │              └──1:N──> Match
  │
  ├──1:N──> InventoryItem (seller) ──1:1──> VehicleItem | PropertyItem
  │              │──1:N──> InventoryImage
  │              └──1:N──> Match
  │
  ├──1:N──> Match ──1:1──> ContactUnlock ──1:1──> Lead ──1:N──> LeadNote
  │                              │
  │                              ├──1:N──> Dispute ──1:N──> DisputeAttachment
  │                              │                 └──1:N──> DisputeEvent
  │                              │
  │                              └──1:N──> Review ──1:1──> ReviewDispute
  │
  ├──1:N──> Notification
  ├──1:N──> DeviceToken
  └──1:N──> AuditLog (actor)

SystemSetting  (parametrización global — sin FK)
TopupPackage ──1:N──> TopupOrder ──> Wallet (por webhook)
ReviewTag     (catálogo de chips)
```

---

## ✅ Checklist de cierre del archivo de modelos

Antes de pasar a `02-servicios.md`, verificar:

- [ ] `apps/common/models.py` contiene `BaseModel` y `SystemSetting`
- [ ] `apps/users/models.py` contiene `User` con Manager custom
- [ ] `apps/authn/models.py` contiene `EmailVerificationToken`, `PhoneOtp`, `PasswordResetToken`
- [ ] `apps/needs/models.py` contiene `Need`, `VehicleNeed`, `PropertyNeed`, `NeedCriterion`, `NeedImage`
- [ ] `apps/inventory/models.py` contiene `InventoryItem`, `VehicleItem`, `PropertyItem`, `InventoryImage`
- [ ] `apps/matching/models.py` contiene `Match`, `MatchCriterionResult`
- [ ] `apps/wallet/models.py` contiene `Wallet`, `WalletTransaction`, `TopupPackage`, `TopupOrder`
- [ ] `apps/contacts/models.py` contiene `ContactUnlock`
- [ ] `apps/disputes/models.py` contiene `Dispute`, `DisputeAttachment`, `DisputeEvent`
- [ ] `apps/reviews/models.py` contiene `Review`, `ReviewTag`, `ReviewDispute`
- [ ] `apps/leads/models.py` contiene `Lead`, `LeadNote`
- [ ] `apps/notifications/models.py` contiene `Notification`, `DeviceToken`
- [ ] `apps/audit/models.py` contiene `AuditLog`
- [ ] Todos los modelos declaran `db_table` explícito
- [ ] Todos los índices y constraints están declarados en `Meta`
- [ ] Las migraciones se generan sin errores (`makemigrations --dry-run`)
- [ ] Las migraciones se aplican limpiamente en una DB nueva
- [ ] Data migrations pobladas para `SystemSetting`, `TopupPackage` y `ReviewTag`

---

## ➡️ Siguiente paso

Continuar con **`02-servicios.md`**: implementación de la lógica de negocio para cada dominio — servicios, selectors, motor de match, cálculo de scoring, gestión de wallet transaccional, flujo automático de disputas, y tasks de Celery.

---

*Sense Digital S.A.S. — Wanti Backend · Modelos v1.0 — Julio 2026*