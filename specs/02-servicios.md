# Wanti Backend — 02 · Servicios y Lógica de Negocio

**Prerequisito:** haber completado `00-setup-inicial.md` y `01-modelos.md`
**Objetivo:** implementar la capa de servicios (business logic), selectors (consultas), motor de match, tasks de Celery y reglas transaccionales.

---

## Arquitectura de la capa de servicios

**Regla arquitectónica fundamental:**

Las **views** son *thin* — solo validan input y llaman al servicio.
Los **serializers** validan estructura.
Los **services** contienen **toda la lógica de negocio**.
Los **selectors** contienen **toda la lógica de consultas** (queries complejas, filtros, agregaciones).
Los **models** solo tienen validaciones de integridad y propiedades derivadas simples.

```
Request → View → Serializer (valida) → Service (aplica lógica) → Model (persiste)
                              ↓
                         Selector (consulta)
```

**Nunca:**
- Lógica de negocio dentro de una view o de un serializer
- Queries directas al ORM fuera de un selector
- Modificaciones directas de campos sensibles (`wallet.balance_wantis`, `user.status`, etc.) sin pasar por su servicio

---

## Convenciones de servicios

1. Cada función de servicio recibe **objetos ya cargados** (no IDs sueltos, salvo en el punto de entrada).
2. Cada función devuelve el objeto modificado.
3. Cada acción sensible genera un `AuditLog` **dentro** de la misma transacción atómica.
4. Los servicios usan `@transaction.atomic` cuando modifican múltiples tablas.
5. Los servicios levantan excepciones de dominio (`apps/common/exceptions.py`) que las views traducen a HTTP.
6. Las tasks de Celery son *finas* — llaman a servicios, no contienen lógica.

### Excepciones base

Crear `apps/common/exceptions.py`:

```python
class DomainError(Exception):
    """Excepción base de errores de dominio."""
    default_message = 'Error de dominio'
    def __init__(self, message=None):
        super().__init__(message or self.default_message)

class ValidationError(DomainError):    default_message = 'Datos inválidos'
class NotFoundError(DomainError):      default_message = 'Recurso no encontrado'
class PermissionError(DomainError):    default_message = 'Sin permisos'
class ConflictError(DomainError):      default_message = 'Conflicto de estado'
class InsufficientFundsError(DomainError): default_message = 'Saldo insuficiente'
class UserNotVerifiedError(DomainError):   default_message = 'Verificación pendiente'
class UserSuspendedError(DomainError):     default_message = 'Cuenta suspendida'
class OtpInvalidError(DomainError):        default_message = 'OTP inválido o expirado'
class DisputeStateError(DomainError):      default_message = 'Estado de disputa inválido para esta acción'
```

---

## 1 · Servicio de auditoría

### 1.1 `apps/audit/services/audit_log.py`

```python
from apps.audit.models import AuditLog

def log_audit_event(*, actor_user=None, action, entity, entity_id=None,
                    metadata=None, ip_address=None, user_agent=''):
    """
    Registra un evento inmutable de auditoría.

    Args:
        actor_user: User que ejecuta la acción (None si es el sistema).
        action: Código de acción (mayúsculas, ej. "USER_REGISTERED").
        entity: Nombre del modelo afectado (ej. "User", "Need").
        entity_id: UUID del objeto afectado.
        metadata: Dict con datos adicionales. NUNCA passwords/tokens/OTPs.
        ip_address: IP del request.
        user_agent: User-Agent del request.
    """
    return AuditLog.objects.create(
        actor_user=actor_user,
        action=action,
        entity=entity,
        entity_id=entity_id,
        metadata=metadata or {},
        ip_address=ip_address,
        user_agent=user_agent[:500],
    )
```

**Regla:** cada servicio de dominio importa esta función y la llama al final de la operación exitosa, **dentro de la misma transacción atómica**.

---

## 2 · Servicios de `users`

### 2.1 `apps/users/services/users.py`

**Funciones a implementar:**

#### `register_user(data: dict, ip_address=None) -> User`

Registro público. Crea usuario en estado `PENDING`.

Pasos:
1. Validar que `email` no existe.
2. Validar que `(id_type, id_number)` no existe.
3. Crear `User(status=PENDING, role=USER)`.
4. `user.set_password(data['password'])`.
5. Crear `Wallet(user=user, balance_wantis=0)` — signal `post_save` alternativo.
6. Emitir token de verificación de email (llamar a `authn.services.email_verification.send_verification_email`).
7. `log_audit_event(actor_user=None, action='USER_REGISTERED', entity='User', entity_id=user.id, ip_address=ip_address)`.
8. Retornar `user`.

**Todo bajo `@transaction.atomic`.**

#### `activate_user_after_verification(user: User) -> User`

Se llama cuando **ambos** canales (email + celular) están verificados.

Pasos:
1. Si `user.email_verified_at` y `user.phone_verified_at` no nulos → `user.status = ACTIVE`.
2. Guardar.
3. `log_audit_event(actor_user=user, action='USER_ACTIVATED', entity='User', entity_id=user.id)`.

#### `update_self_profile(user: User, data: dict) -> User`

Actualización de perfil propio. **Campos permitidos** (whitelist explícita):
`full_name`, `city`, `location`, `profile_photo_url`.

Campos **prohibidos**: `email`, `phone`, `role`, `status`, `id_type`, `id_number`, `password`. Si aparecen → `ValidationError`.

Pasos:
1. Validar whitelist.
2. Actualizar campos permitidos.
3. Log `USER_UPDATED_SELF`.

#### `update_email_request(user: User, new_email: str) -> None`

Cambio de email → dispara nueva verificación. **No cambia `user.email` hasta verificar.**

Pasos:
1. Validar que `new_email` no está en uso.
2. Crear `EmailVerificationToken` con metadata `{"new_email": new_email}`.
3. Enviar correo al `new_email`.
4. Log `USER_EMAIL_CHANGE_REQUESTED`.

#### `update_phone_request(user: User, new_phone: str, channel='WHATSAPP') -> None`

Cambio de celular → dispara nuevo OTP. **No cambia `user.phone` hasta verificar.**

#### `suspend_user(target_user_id, actor_user: User, reason: str) -> User`

Solo `role=ADMIN`.

Pasos:
1. Validar `actor_user.role == ADMIN` (sino `PermissionError`).
2. `target = get_user_by_id(target_user_id)`.
3. `target.status = SUSPENDED`.
4. Log `USER_SUSPENDED` con metadata `{"reason": reason, "actor_id": actor_user.id}`.

#### `activate_user_by_admin(target_user_id, actor_user: User) -> User`

Reactiva un usuario suspendido. Solo ADMIN. Log `USER_REACTIVATED`.

---

### 2.2 `apps/users/selectors/users.py`

```python
def get_user_by_id(user_id: UUID) -> User
def get_user_by_email(email: str) -> User
def list_users(*, actor_user: User, filters: dict) -> QuerySet
```

**`list_users`:**
- Solo `role in [ADMIN, MODERATOR]` puede listar.
- Filtros: `role`, `status`, `city`, `search` (busca en `full_name`, `email`, `id_number`).
- Orden: `-created_at`.

---

## 3 · Servicios de `authn`

### 3.1 `apps/authn/services/email_verification.py`

```python
import secrets
from datetime import timedelta
from django.utils import timezone
from django.core.mail import send_mail
from django.conf import settings
from apps.authn.models import EmailVerificationToken
from apps.audit.services.audit_log import log_audit_event

def send_verification_email(user, new_email=None) -> EmailVerificationToken:
    """Genera y envía token de verificación."""
    # Invalidar tokens previos no usados
    EmailVerificationToken.objects.filter(
        user=user, used_at__isnull=True
    ).update(expires_at=timezone.now())

    token = EmailVerificationToken.objects.create(
        user=user,
        token=secrets.token_urlsafe(48),
        expires_at=timezone.now() + timedelta(hours=24),
    )
    target_email = new_email or user.email
    verify_url = f"{settings.FRONTEND_BASE_URL}/auth/verify-email?token={token.token}"
    send_mail(
        subject='Verifica tu correo en Wanti',
        message=f'Confirma tu correo: {verify_url}',
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[target_email],
    )
    log_audit_event(actor_user=user, action='EMAIL_VERIFICATION_SENT',
                    entity='User', entity_id=user.id)
    return token

def verify_email_token(token_str: str) -> User:
    """Consume el token y marca email_verified_at."""
    try:
        token = EmailVerificationToken.objects.select_related('user').get(token=token_str)
    except EmailVerificationToken.DoesNotExist:
        raise ValidationError('Token inválido')
    if token.used_at is not None:
        raise ValidationError('Token ya usado')
    if token.expires_at < timezone.now():
        raise ValidationError('Token expirado')

    user = token.user
    user.email_verified_at = timezone.now()
    user.save(update_fields=['email_verified_at', 'updated_at'])
    token.used_at = timezone.now()
    token.save(update_fields=['used_at'])

    # Si ambos canales verificados → activar
    if user.phone_verified_at is not None and user.status == UserStatus.PENDING:
        from apps.users.services.users import activate_user_after_verification
        activate_user_after_verification(user)

    log_audit_event(actor_user=user, action='EMAIL_VERIFIED',
                    entity='User', entity_id=user.id)
    return user
```

---

### 3.2 `apps/authn/services/otp.py`

```python
import hashlib
import secrets
from datetime import timedelta
from django.utils import timezone
from django.conf import settings
from apps.authn.models import PhoneOtp
from apps.common.constants import OtpChannel, UserStatus
from apps.common.services.settings_service import get_setting
from apps.audit.services.audit_log import log_audit_event
from apps.common.exceptions import OtpInvalidError, ValidationError
from apps.common.integrations.twilio.otp import send_otp_via_twilio


def _hash_code(code: str) -> str:
    salted = f"{code}{settings.SECRET_KEY}"
    return hashlib.sha256(salted.encode()).hexdigest()


def request_otp(user, channel=OtpChannel.WHATSAPP, new_phone=None) -> PhoneOtp:
    """
    Genera un OTP de 6 dígitos y lo envía por WhatsApp o SMS.
    Nunca guarda el código en claro.
    """
    # Invalidar OTPs previos no verificados
    PhoneOtp.objects.filter(
        user=user, verified_at__isnull=True
    ).update(expires_at=timezone.now())

    code = f"{secrets.randbelow(1_000_000):06d}"
    ttl = get_setting('OTP_TTL_SECONDS', 300)

    otp = PhoneOtp.objects.create(
        user=user,
        code_hash=_hash_code(code),
        channel=channel,
        expires_at=timezone.now() + timedelta(seconds=ttl),
    )

    target_phone = new_phone or user.phone
    send_otp_via_twilio(target_phone, code, channel)

    log_audit_event(actor_user=user, action='OTP_SENT',
                    entity='User', entity_id=user.id,
                    metadata={'channel': channel})
    # OJO: no incluir el código en metadata jamás.
    return otp


def verify_otp(user, code: str) -> None:
    """Valida el OTP más reciente del usuario. Actualiza phone_verified_at."""
    otp = PhoneOtp.objects.filter(
        user=user, verified_at__isnull=True
    ).order_by('-created_at').first()

    if otp is None:
        raise OtpInvalidError('No hay un OTP activo')
    if otp.expires_at < timezone.now():
        raise OtpInvalidError('OTP expirado')

    max_attempts = get_setting('OTP_MAX_ATTEMPTS', 5)
    if otp.attempts >= max_attempts:
        raise OtpInvalidError('Demasiados intentos fallidos')

    if _hash_code(code) != otp.code_hash:
        otp.attempts += 1
        otp.save(update_fields=['attempts'])
        raise OtpInvalidError('Código incorrecto')

    otp.verified_at = timezone.now()
    otp.save(update_fields=['verified_at'])

    user.phone_verified_at = timezone.now()
    user.save(update_fields=['phone_verified_at', 'updated_at'])

    if user.email_verified_at is not None and user.status == UserStatus.PENDING:
        from apps.users.services.users import activate_user_after_verification
        activate_user_after_verification(user)

    log_audit_event(actor_user=user, action='OTP_VERIFIED',
                    entity='User', entity_id=user.id)
```

---

### 3.3 `apps/authn/services/password_reset.py`

Funciones:
- `request_password_reset(email, ip_address)` — genera token, envía correo. **Nunca revela si el email existe** (response idempotente).
- `confirm_password_reset(token, new_password)` — valida token, resetea password, invalida sesiones (`user.last_login_at = None`, blacklist de refresh tokens).

Logs: `PASSWORD_RESET_REQUESTED`, `PASSWORD_RESET_COMPLETED`.

---

### 3.4 `apps/authn/services/jwt.py`

Utilidades sobre SimpleJWT:

```python
def issue_tokens_for_user(user) -> dict:
    """Retorna {'access': str, 'refresh': str}"""
    from rest_framework_simplejwt.tokens import RefreshToken
    refresh = RefreshToken.for_user(user)
    refresh['role'] = user.role
    refresh['fully_verified'] = user.is_fully_verified
    return {'access': str(refresh.access_token), 'refresh': str(refresh)}
```

**Login flow (llamado desde la view):**

1. `user = get_user_by_email(email)` → si no existe: 401 genérico.
2. `user.check_password(password)` → si falla: log `LOGIN_FAILED` + 401.
3. Si `user.status == SUSPENDED`: log `LOGIN_BLOCKED_SUSPENDED` + 403.
4. Si `user.status == PENDING`: emitir tokens **pero** el cliente sabe (por claim) que debe completar verificación.
5. Actualizar `user.last_login_at = now()`.
6. Log `LOGIN_SUCCESS`.
7. Retornar tokens.

---

## 4 · Servicios de `wallet` — Ledger transaccional

Este es el módulo más crítico. **Todo movimiento de Wantis pasa por acá.**

### 4.1 `apps/wallet/services/wallet.py`

```python
from django.db import transaction
from django.db.models import F
from apps.wallet.models import Wallet, WalletTransaction
from apps.common.constants import TransactionType
from apps.common.exceptions import InsufficientFundsError, ValidationError
from apps.audit.services.audit_log import log_audit_event


@transaction.atomic
def apply_transaction(*, wallet: Wallet, transaction_type: str,
                      amount_wantis: int, related_object=None,
                      note: str = '', created_by=None) -> WalletTransaction:
    """
    Único punto de mutación del saldo del wallet.

    Args:
        wallet: instancia (será re-cargada con SELECT FOR UPDATE).
        transaction_type: TransactionType.
        amount_wantis: positivo (crédito) o negativo (débito).
        related_object: instancia del objeto que originó el movimiento
                        (ContactUnlock, Dispute, TopupOrder, etc.).
        note: descripción legible.
        created_by: User que originó (None = system).

    Raises:
        InsufficientFundsError si el débito deja saldo negativo.
    """
    if amount_wantis == 0:
        raise ValidationError('El monto no puede ser cero')

    # Lock optimista con SELECT FOR UPDATE
    wallet = Wallet.objects.select_for_update().get(pk=wallet.pk)

    new_balance = wallet.balance_wantis + amount_wantis
    if new_balance < 0:
        raise InsufficientFundsError(
            f'Saldo insuficiente: {wallet.balance_wantis} Wantis disponibles'
        )

    related_type = related_object.__class__.__name__ if related_object else ''
    related_id = related_object.pk if related_object else None

    txn = WalletTransaction.objects.create(
        wallet=wallet,
        transaction_type=transaction_type,
        amount_wantis=amount_wantis,
        balance_after=new_balance,
        related_object_type=related_type,
        related_object_id=related_id,
        note=note,
        created_by=created_by,
    )

    Wallet.objects.filter(pk=wallet.pk).update(
        balance_wantis=F('balance_wantis') + amount_wantis
    )

    log_audit_event(
        actor_user=created_by,
        action='WALLET_TRANSACTION',
        entity='Wallet',
        entity_id=wallet.id,
        metadata={
            'transaction_type': transaction_type,
            'amount': amount_wantis,
            'balance_after': new_balance,
            'related_type': related_type,
            'related_id': str(related_id) if related_id else None,
        }
    )
    return txn


def get_or_create_wallet(user) -> Wallet:
    wallet, _ = Wallet.objects.get_or_create(user=user)
    return wallet
```

**Reglas de invocación:**

| Origen | `transaction_type` | Signo | Ejemplo de `note` |
|---|---|---|---|
| Webhook pasarela (base) | `TOPUP` | + | "Recarga paquete Popular" |
| Webhook pasarela (bonus) | `BONUS` | + | "Bonificación +1 gratis" |
| Desbloqueo de contacto | `UNLOCK` | − | "Desbloqueo Toyota Hilux 2022" |
| Disputa aprobada | `REFUND` | + | "Reembolso disputa WD-2847" |
| Ajuste admin manual | `ADJUSTMENT` | ± | "Ajuste admin: ver ticket #123" |
| Recompensa por reseña | `REWARD` | + | "Recompensa 5 reseñas" |

---

### 4.2 `apps/wallet/services/packages.py`

```python
@transaction.atomic
def create_topup_order(user, package_id) -> TopupOrder:
    """Crea la orden con snapshot de precio y wantis. Devuelve la URL de checkout."""
    package = TopupPackage.objects.get(id=package_id, is_active=True)
    order = TopupOrder.objects.create(
        user=user,
        package=package,
        wantis_total=package.wantis_base + package.wantis_bonus,
        price_cop=package.price_cop,
        status=TopupStatus.PENDING,
    )
    log_audit_event(actor_user=user, action='TOPUP_ORDER_CREATED',
                    entity='TopupOrder', entity_id=order.id,
                    metadata={'package': package.name, 'price': str(package.price_cop)})
    return order


@transaction.atomic
def complete_topup_order(order: TopupOrder, provider_reference: str,
                        provider_payload: dict) -> TopupOrder:
    """
    Llamado desde el webhook de la pasarela.
    Aplica dos transacciones separadas: TOPUP (base) y BONUS (extra).
    Idempotente por provider_reference.
    """
    if order.status == TopupStatus.COMPLETED:
        return order  # idempotencia

    order.provider_reference = provider_reference
    order.provider_payload = provider_payload

    wallet = get_or_create_wallet(order.user)

    # 1) Movimiento base
    apply_transaction(
        wallet=wallet,
        transaction_type=TransactionType.TOPUP,
        amount_wantis=order.package.wantis_base,
        related_object=order,
        note=f'Recarga paquete "{order.package.name}"',
    )
    # 2) Bonificación (si aplica)
    if order.package.wantis_bonus > 0:
        apply_transaction(
            wallet=wallet,
            transaction_type=TransactionType.BONUS,
            amount_wantis=order.package.wantis_bonus,
            related_object=order,
            note=f'Bonificación +{order.package.wantis_bonus} gratis',
        )

    order.status = TopupStatus.COMPLETED
    order.completed_at = timezone.now()
    order.save()

    log_audit_event(actor_user=order.user, action='TOPUP_COMPLETED',
                    entity='TopupOrder', entity_id=order.id,
                    metadata={'wantis_total': order.wantis_total})
    return order


def fail_topup_order(order, error: str):
    order.status = TopupStatus.FAILED
    order.provider_payload = {'error': error}
    order.save()
    log_audit_event(actor_user=order.user, action='TOPUP_FAILED',
                    entity='TopupOrder', entity_id=order.id)
```

**Regla de idempotencia:** el webhook puede llegar varias veces. Si `order.status == COMPLETED`, retornar sin hacer nada.

---

### 4.3 `apps/wallet/selectors/wallet.py`

```python
def get_wallet(user) -> Wallet
def list_transactions(user, filters={}) -> QuerySet
def get_active_packages() -> QuerySet[TopupPackage]
```

---

## 5 · Servicios de `needs`

### 5.1 `apps/needs/services/needs.py`

#### `create_need(buyer, data) -> Need`

Pasos bajo `@transaction.atomic`:

1. **Validar** que `buyer.can_publish` es `True`. Sino → `UserNotVerifiedError`.
2. **Validar** que `data['budget_max_cop']` es positivo.
3. Crear `Need(status=DRAFT, expires_at=None)` — el motor no corre en DRAFT.
4. Según `asset_type`:
   - VEHICLE → crear `VehicleNeed(need=need, **vehicle_data)`.
   - PROPERTY → crear `PropertyNeed(need=need, **property_data)`.
5. Crear todos los `NeedCriterion` que vengan en `data['criteria']`.
6. Si `data['images']` → crear `NeedImage` por cada uno.
7. `log_audit_event(action='NEED_CREATED', entity='Need', entity_id=need.id, actor_user=buyer)`.
8. Retornar `need`.

#### `publish_need(need: Need, buyer: User) -> Need`

Transición `DRAFT → ACTIVE`:

1. Validar `need.buyer == buyer`.
2. Validar `need.status == DRAFT`.
3. Validar `need.legal_disclaimer_accepted_at is not None`.
4. **Filtro anti-abuso**: llamar a `_validate_budget_ratio(need)` — si el presupuesto es < 40% del valor comercial estimado, rechazar (o marcar para revisión, según parametrización).
5. `need.status = ACTIVE`.
6. `need.expires_at = now() + timedelta(days=get_setting('NEED_DURATION_DAYS'))`.
7. Guardar.
8. **Disparar Celery task** `apps.matching.tasks.run_match_for_need.delay(need.id)`.
9. Log `NEED_PUBLISHED`.

#### `update_need(need, buyer, data) -> Need`

Solo mientras `status in [DRAFT, ACTIVE]` y `buyer == need.buyer`.

Si `status == ACTIVE` y se modifican criterios/valores → **recalcular matches** (dispara task de rematching).

Log `NEED_UPDATED`.

#### `pause_need(need, buyer)` / `resume_need(need, buyer)` / `delete_need(need, buyer)`

- `pause`: `status = PAUSED`. Los matches existentes permanecen visibles pero no se generan nuevos.
- `resume`: si estaba `PAUSED`, vuelve a `ACTIVE` y recalcula expiración.
- `delete`: `status = DELETED` (soft delete). Los matches y contactos históricos se preservan.

Logs correspondientes.

#### `expire_stale_needs()` (task de Celery beat)

Diario. Marca como `EXPIRED` todas las needs con `expires_at < now()` y `status = ACTIVE`.

---

### 5.2 `apps/needs/selectors/needs.py`

```python
def get_need_by_id(need_id, actor_user) -> Need
    # 404 si no existe. Si actor_user no es el buyer ni admin → 404 (no exponer)

def list_own_needs(buyer, filters) -> QuerySet
    # Filtra por buyer=buyer, ordena por -created_at

def list_needs_for_seller_search(seller, filters) -> QuerySet
    # HUS11-14: navegación pública de necesidades activas
    # Solo status=ACTIVE, excluye needs propias del seller
    # Filtros: asset_type, city, budget_min/max, brand, property_type, etc.
    # Ordena por -created_at o -matches_count
```

---

## 6 · Servicios de `inventory`

### 6.1 `apps/inventory/services/inventory.py`

#### `create_inventory_item(seller, data) -> InventoryItem`

Similar a `create_need` pero para el vendedor:

1. Validar `seller.can_publish`.
2. Crear `InventoryItem(status=AVAILABLE)` + `VehicleItem`/`PropertyItem`.
3. Si `data['images']` incluye referencias → crear `InventoryImage`.
4. Si se solicita generación IA → disparar Celery task `generate_ai_images_for_item`.
5. **Disparar** `apps.matching.tasks.run_match_for_item.delay(item.id)` — busca coincidencias con needs existentes.
6. Log `INVENTORY_CREATED`.

#### `update_inventory_item(item, seller, data)`

Rechazar si `seller != item.seller`. Si cambia atributos clave → rematching.

#### `mark_as_sold(item, seller)` / `mark_as_reserved` / `deactivate`

#### `generate_ai_images_for_item(item)` (Celery task)

Llama a `apps.common.integrations.ai_images.base.generate_images(prompt)`. En fase 1 usa el mock que retorna URLs de placeholder.

---

## 7 · Motor de match — `matching`

**El corazón del sistema.** Implementa HUS24.

### 7.1 `apps/matching/services/scoring.py`

Algoritmo puro (sin I/O). Función testeable en aislamiento.

```python
from decimal import Decimal
from apps.common.services.settings_service import get_setting


def score_pair(need, need_vehicle_or_property, need_criteria,
               item, item_vehicle_or_property, distance_km) -> dict:
    """
    Retorna:
    {
        'score': int (0-100),
        'required_met': bool,
        'unmet_preferences': list[str],
        'criteria_results': list[dict]  # detalle por criterio
    }

    Regla:
    1. Filtro duro: si algún REQUIRED no se cumple → score=0, required_met=False.
    2. Filtro duro: si item.price > need.budget_max_cop → score=0.
    3. Filtro duro: distancia > MATCH_RADIUS_KM → score=0.
    4. Filtro anti-abuso: item.price < 40% del valor comercial → score=0.
    5. Cálculo: base = 100.
       - Cada PREFERRED no cumplido descuenta según su weight.
       - Cercanía geográfica bonifica: (radius - distance) / radius * 5 puntos.
    6. score = max(0, min(100, base))
    """
    criteria_results = []
    unmet_preferences = []

    # Reglas duras
    if item.price_cop > need.budget_max_cop:
        return {'score': 0, 'required_met': False, 'unmet_preferences': [],
                'criteria_results': []}

    max_radius = get_setting('MATCH_RADIUS_KM', 50)
    if distance_km > max_radius:
        return {'score': 0, 'required_met': False, 'unmet_preferences': [],
                'criteria_results': []}

    # Evaluar criterios
    base = 100
    required_met = True

    for criterion in need_criteria:
        expected = getattr(need_vehicle_or_property, criterion.attribute, None)
        actual = getattr(item_vehicle_or_property, criterion.attribute, None)
        met = _evaluate_criterion(criterion.attribute, expected, actual)

        contribution = criterion.weight if met else 0
        criteria_results.append({
            'attribute': criterion.attribute,
            'mode': criterion.mode,
            'expected_value': str(expected),
            'actual_value': str(actual),
            'met': met,
            'contribution': contribution,
        })

        if not met:
            if criterion.mode == 'REQUIRED':
                required_met = False
                base = 0
                break
            else:
                base -= criterion.weight
                unmet_preferences.append(criterion.attribute)

    if not required_met:
        return {'score': 0, 'required_met': False, 'unmet_preferences': [],
                'criteria_results': criteria_results}

    # Bonus por cercanía
    proximity_bonus = int((max_radius - distance_km) / max_radius * 5)
    base = min(100, base + proximity_bonus)
    base = max(0, base)

    return {
        'score': base,
        'required_met': True,
        'unmet_preferences': unmet_preferences,
        'criteria_results': criteria_results,
    }


def _evaluate_criterion(attribute, expected, actual):
    """Compara valores según el tipo de atributo."""
    if expected is None or actual is None:
        return True  # sin restricción explícita
    if attribute.endswith('_max_km') or attribute.endswith('_max_cop'):
        return actual <= expected
    if attribute.endswith('_min_sqm') or attribute.endswith('_min') or attribute == 'bedrooms_min':
        return actual >= expected
    if attribute == 'year_min':   return actual >= expected
    if attribute == 'year_max':   return actual <= expected
    # Booleanos y strings: igualdad
    return expected == actual
```

---

### 7.2 `apps/matching/services/engine.py`

```python
from django.db import transaction
from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.measure import D
from apps.needs.models import Need
from apps.inventory.models import InventoryItem
from apps.matching.models import Match, MatchCriterionResult
from apps.common.constants import NeedStatus, InventoryStatus, MatchStatus, AssetType
from apps.common.services.settings_service import get_setting
from apps.matching.services.scoring import score_pair
from apps.audit.services.audit_log import log_audit_event


def run_match_for_need(need_id):
    """Genera matches para una Need recién publicada o editada."""
    need = Need.objects.select_related('buyer').get(id=need_id)
    if need.status != NeedStatus.ACTIVE:
        return

    # Cargar el detalle específico
    detail = need.vehicle if need.asset_type == AssetType.VEHICLE else need.property
    criteria = list(need.criteria.all())

    # Candidatos: mismo asset_type, AVAILABLE, dentro del radio
    radius_km = get_setting('MATCH_RADIUS_KM', 50)
    candidates = InventoryItem.objects.filter(
        asset_type=need.asset_type,
        status=InventoryStatus.AVAILABLE,
    ).exclude(
        seller=need.buyer  # no matchear consigo mismo
    ).annotate(
        distance=Distance('location', need.location)
    ).filter(
        location__dwithin=(need.location, D(km=radius_km))
    ).select_related(
        'vehicle', 'property'
    )

    min_score = get_setting('MATCH_MIN_SCORE', 50)
    matches_created = 0

    for item in candidates:
        item_detail = item.vehicle if item.asset_type == AssetType.VEHICLE else item.property
        distance_km = item.distance.km if item.distance else 0

        result = score_pair(need, detail, criteria, item, item_detail, distance_km)

        if result['score'] < min_score:
            continue

        with transaction.atomic():
            match, created = Match.objects.update_or_create(
                need=need, inventory_item=item,
                defaults={
                    'buyer': need.buyer,
                    'seller': item.seller,
                    'score': result['score'],
                    'distance_km': round(distance_km, 2),
                    'required_criteria_met': result['required_met'],
                    'unmet_preferences': result['unmet_preferences'],
                    'status': MatchStatus.GENERATED,
                }
            )
            # Detalle por criterio
            if created:
                MatchCriterionResult.objects.bulk_create([
                    MatchCriterionResult(match=match, **cr)
                    for cr in result['criteria_results']
                ])
            matches_created += 1

    # Actualizar contador denormalizado
    Need.objects.filter(id=need.id).update(matches_count=matches_created)

    log_audit_event(
        actor_user=None,
        action='MATCH_ENGINE_RUN',
        entity='Need',
        entity_id=need.id,
        metadata={'matches_created': matches_created}
    )

    # Notificar bidireccionalmente (push primero)
    from apps.notifications.tasks import notify_matches
    notify_matches.delay(need.id)


def run_match_for_item(item_id):
    """Cuando se crea/edita un inventario, buscar needs activas que le hagan match."""
    item = InventoryItem.objects.select_related('seller').get(id=item_id)
    if item.status != InventoryStatus.AVAILABLE:
        return

    detail = item.vehicle if item.asset_type == AssetType.VEHICLE else item.property
    radius_km = get_setting('MATCH_RADIUS_KM', 50)

    candidate_needs = Need.objects.filter(
        asset_type=item.asset_type,
        status=NeedStatus.ACTIVE,
    ).exclude(
        buyer=item.seller
    ).annotate(
        distance=Distance('location', item.location)
    ).filter(
        location__dwithin=(item.location, D(km=radius_km))
    ).select_related('vehicle', 'property').prefetch_related('criteria')

    min_score = get_setting('MATCH_MIN_SCORE', 50)

    for need in candidate_needs:
        need_detail = need.vehicle if need.asset_type == AssetType.VEHICLE else need.property
        distance_km = need.distance.km if need.distance else 0
        criteria = list(need.criteria.all())
        result = score_pair(need, need_detail, criteria, item, detail, distance_km)
        if result['score'] < min_score:
            continue
        # (misma lógica de creación/update de Match)
        # ...
```

### 7.3 `apps/matching/tasks.py`

```python
from celery import shared_task
from apps.matching.services.engine import run_match_for_need, run_match_for_item

@shared_task
def run_match_for_need_task(need_id):
    run_match_for_need(need_id)

@shared_task
def run_match_for_item_task(item_id):
    run_match_for_item(item_id)
```

---

### 7.4 `apps/matching/selectors/matches.py`

```python
def list_matches_for_need(need, actor_user) -> QuerySet[Match]:
    # Solo need.buyer puede verlos. Excluye descartados.
    # Ordena por -score.
    # prefetch_related('inventory_item__vehicle', 'inventory_item__property',
    #                  'inventory_item__seller', 'criteria_results')

def list_alerts_for_seller(seller, filters={}) -> QuerySet[Match]:
    # Matches donde seller=seller, excluye descartados por el vendedor
    # Ordena por -created_at, -score

def get_match_detail(match_id, actor_user) -> Match
```

---

## 8 · Servicios de `contacts` — Desbloqueo

### 8.1 `apps/contacts/services/contacts.py`

```python
from django.db import transaction
from apps.contacts.models import ContactUnlock
from apps.matching.models import Match
from apps.wallet.services.wallet import apply_transaction, get_or_create_wallet
from apps.common.constants import TransactionType, MatchStatus, ContactOutcome
from apps.common.exceptions import ConflictError, PermissionError, UserSuspendedError
from apps.audit.services.audit_log import log_audit_event


@transaction.atomic
def unlock_contact(match: Match, buyer) -> ContactUnlock:
    """
    Descuenta 1 Wanti al comprador, crea el ContactUnlock, crea Lead y notifica.
    Idempotente si el contacto ya fue desbloqueado (retorna el existente).
    """
    if match.buyer_id != buyer.id:
        raise PermissionError('Este match no es tuyo')
    if match.status == MatchStatus.UNLOCKED:
        # Idempotencia — ya desbloqueado
        return match.unlock
    if buyer.status != 'ACTIVE':
        raise UserSuspendedError()

    wallet = get_or_create_wallet(buyer)
    cost = 1  # Wantis por desbloqueo (parametrizable a futuro)

    # 1) Debitar del wallet (levanta InsufficientFundsError si no alcanza)
    txn = apply_transaction(
        wallet=wallet,
        transaction_type=TransactionType.UNLOCK,
        amount_wantis=-cost,
        related_object=match,
        note=f'Desbloqueo contacto — {match.inventory_item.title}',
        created_by=buyer,
    )

    # 2) Crear el registro de desbloqueo
    unlock = ContactUnlock.objects.create(
        match=match,
        buyer=buyer,
        seller=match.seller,
        wantis_charged=cost,
        wallet_transaction=txn,
    )

    # 3) Actualizar el match
    match.status = MatchStatus.UNLOCKED
    match.unlocked_at = unlock.created_at
    match.save(update_fields=['status', 'unlocked_at'])

    # 4) Actualizar contador denormalizado del item
    from django.db.models import F
    from apps.inventory.models import InventoryItem
    InventoryItem.objects.filter(id=match.inventory_item_id).update(
        unlock_count=F('unlock_count') + 1
    )

    # 5) Crear Lead automáticamente para el vendedor
    from apps.leads.services.leads import create_lead_from_unlock
    create_lead_from_unlock(unlock)

    # 6) Auditoría + notificaciones
    log_audit_event(
        actor_user=buyer,
        action='CONTACT_UNLOCKED',
        entity='ContactUnlock',
        entity_id=unlock.id,
        metadata={'match_id': str(match.id), 'seller_id': str(match.seller_id)}
    )
    from apps.notifications.tasks import notify_contact_unlocked
    notify_contact_unlocked.delay(unlock.id)

    return unlock


def mark_whatsapp_opened(unlock: ContactUnlock, buyer):
    if unlock.buyer_id != buyer.id:
        raise PermissionError()
    if unlock.whatsapp_opened_at is None:
        unlock.whatsapp_opened_at = timezone.now()
        unlock.save(update_fields=['whatsapp_opened_at'])


def report_outcome(unlock: ContactUnlock, buyer, outcome: str):
    """
    Comprador reporta: Compré / En proceso / No compré.
    Al reportar PURCHASED o NOT_PURCHASED, se habilita el flujo de review.
    """
    if unlock.buyer_id != buyer.id:
        raise PermissionError()
    unlock.outcome = outcome
    unlock.outcome_reported_at = timezone.now()
    unlock.save()

    log_audit_event(actor_user=buyer, action='CONTACT_OUTCOME_REPORTED',
                    entity='ContactUnlock', entity_id=unlock.id,
                    metadata={'outcome': outcome})

    # Notificar al vendedor para que también pueda calificar
    if outcome in ('PURCHASED', 'NOT_PURCHASED'):
        from apps.notifications.tasks import notify_review_pending
        notify_review_pending.delay(unlock.id)
```

---

## 9 · Servicios de `disputes`

### 9.1 `apps/disputes/services/disputes.py`

```python
@transaction.atomic
def open_dispute(unlock: ContactUnlock, opened_by, reason: str,
                 description: str = '', attachments: list = None) -> Dispute:
    if opened_by.id not in (unlock.buyer_id, unlock.seller_id):
        raise PermissionError('Solo el comprador o vendedor pueden abrir disputa')

    if Dispute.objects.filter(
        contact_unlock=unlock,
        status__in=['OPEN', 'AUTO_REVIEW', 'HUMAN_REVIEW']
    ).exists():
        raise ConflictError('Ya existe una disputa activa para este contacto')

    dispute = Dispute.objects.create(
        contact_unlock=unlock,
        opened_by=opened_by,
        reason=reason,
        description=description,
        status='OPEN',
    )
    # Adjuntos
    for att in (attachments or []):
        DisputeAttachment.objects.create(
            dispute=dispute,
            file_url=att['url'],
            file_name=att['name'],
            mime_type=att['mime'],
            uploaded_by=opened_by,
        )
    _add_event(dispute, 'OPENED', actor=opened_by)

    # Disparar verificación automática
    from apps.disputes.tasks import start_auto_review
    start_auto_review.delay(dispute.id)

    log_audit_event(actor_user=opened_by, action='DISPUTE_OPENED',
                    entity='Dispute', entity_id=dispute.id,
                    metadata={'reason': reason})
    return dispute


@transaction.atomic
def start_auto_review(dispute: Dispute):
    """Envía ping al comprador y agenda deadline."""
    timeout_hours = get_setting('DISPUTE_AUTO_TIMEOUT_HOURS', 72)
    dispute.status = 'AUTO_REVIEW'
    dispute.auto_review_started_at = timezone.now()
    dispute.auto_review_deadline = timezone.now() + timedelta(hours=timeout_hours)
    dispute.save()

    _add_event(dispute, 'AUTO_PING_SENT')
    from apps.notifications.tasks import notify_dispute_auto_ping
    notify_dispute_auto_ping.delay(dispute.id)


@transaction.atomic
def buyer_responds_auto_review(dispute: Dispute, buyer, confirmed_purchase: bool):
    if buyer.id != dispute.contact_unlock.buyer_id:
        raise PermissionError()
    if dispute.status != 'AUTO_REVIEW':
        raise DisputeStateError()

    dispute.buyer_confirmed_purchase = confirmed_purchase
    _add_event(dispute, 'BUYER_RESPONDED', actor=buyer,
               payload={'confirmed': confirmed_purchase})

    if confirmed_purchase:
        # Comprador dice que sí compró → disputa rechazada automáticamente
        _reject_dispute(dispute, resolved_by=None,
                        note='Comprador confirmó compra en verificación automática')
    else:
        _escalate_to_human(dispute)


def _escalate_to_human(dispute):
    dispute.status = 'HUMAN_REVIEW'
    dispute.escalated_at = timezone.now()
    dispute.save()
    _add_event(dispute, 'ESCALATED')


@transaction.atomic
def approve_dispute(dispute: Dispute, admin, note: str = ''):
    """Solo admin. Emite reembolso al comprador."""
    if admin.role not in ('ADMIN', 'MODERATOR'):
        raise PermissionError()
    if dispute.status not in ('HUMAN_REVIEW', 'AUTO_REVIEW'):
        raise DisputeStateError()

    wallet = get_or_create_wallet(dispute.contact_unlock.buyer)
    refund_txn = apply_transaction(
        wallet=wallet,
        transaction_type=TransactionType.REFUND,
        amount_wantis=dispute.contact_unlock.wantis_charged,
        related_object=dispute,
        note=f'Reembolso disputa #{dispute.id}',
        created_by=admin,
    )
    dispute.status = 'APPROVED'
    dispute.resolved_at = timezone.now()
    dispute.resolved_by = admin
    dispute.resolution_note = note
    dispute.refund_transaction = refund_txn
    dispute.appeal_deadline = timezone.now() + timedelta(
        days=get_setting('DISPUTE_APPEAL_DAYS', 7)
    )
    dispute.save()
    _add_event(dispute, 'RESOLVED', actor=admin, payload={'outcome': 'APPROVED'})
    log_audit_event(actor_user=admin, action='DISPUTE_APPROVED',
                    entity='Dispute', entity_id=dispute.id)


def _reject_dispute(dispute, resolved_by, note):
    dispute.status = 'REJECTED'
    dispute.resolved_at = timezone.now()
    dispute.resolved_by = resolved_by
    dispute.resolution_note = note
    dispute.appeal_deadline = timezone.now() + timedelta(
        days=get_setting('DISPUTE_APPEAL_DAYS', 7)
    )
    dispute.save()
    _add_event(dispute, 'RESOLVED', actor=resolved_by, payload={'outcome': 'REJECTED'})


def cancel_dispute(dispute, user):
    if user.id != dispute.opened_by_id:
        raise PermissionError()
    if dispute.status in ('APPROVED', 'REJECTED', 'CANCELLED'):
        raise DisputeStateError()
    dispute.status = 'CANCELLED'
    dispute.resolved_at = timezone.now()
    dispute.save()
    _add_event(dispute, 'CANCELLED', actor=user)


def _add_event(dispute, event_type, actor=None, payload=None):
    from apps.disputes.models import DisputeEvent
    DisputeEvent.objects.create(
        dispute=dispute, event_type=event_type,
        actor=actor, payload=payload or {}
    )
```

### 9.2 `apps/disputes/tasks.py`

```python
@shared_task
def start_auto_review(dispute_id):
    dispute = Dispute.objects.get(id=dispute_id)
    from apps.disputes.services.disputes import start_auto_review as _service
    _service(dispute)


@shared_task
def check_auto_review_timeouts():
    """
    Celery beat cada hora.
    Escala a HUMAN_REVIEW cualquier disputa con deadline vencido sin respuesta.
    """
    from apps.disputes.services.disputes import _escalate_to_human
    now = timezone.now()
    for d in Dispute.objects.filter(
        status='AUTO_REVIEW',
        auto_review_deadline__lt=now,
        buyer_confirmed_purchase__isnull=True,
    ):
        _escalate_to_human(d)
```

---

## 10 · Servicios de `reviews`

### 10.1 `apps/reviews/services/reviews.py`

```python
@transaction.atomic
def create_review(unlock: ContactUnlock, reviewer, rating: int,
                  comment: str = '', tags: list = None) -> Review:
    # Solo comprador o vendedor del unlock
    if reviewer.id not in (unlock.buyer_id, unlock.seller_id):
        raise PermissionError()
    # No calificar dos veces
    if Review.objects.filter(contact_unlock=unlock, reviewer=reviewer).exists():
        raise ConflictError('Ya calificaste este contacto')
    # Solo si el outcome fue reportado
    if unlock.outcome == 'PENDING':
        raise ValidationError('El comprador debe reportar el resultado primero')

    reviewee_id = unlock.seller_id if reviewer.id == unlock.buyer_id else unlock.buyer_id

    review = Review.objects.create(
        contact_unlock=unlock,
        reviewer=reviewer,
        reviewee_id=reviewee_id,
        rating=max(1, min(5, rating)),
        comment=comment,
        tags=tags or [],
    )
    log_audit_event(actor_user=reviewer, action='REVIEW_CREATED',
                    entity='Review', entity_id=review.id,
                    metadata={'rating': rating, 'reviewee_id': str(reviewee_id)})

    # Recompensa por volumen de reseñas
    _check_review_reward(reviewer)
    return review


def _check_review_reward(user):
    """Si el usuario alcanza N reseñas dadas → recompensa 1 Wanti."""
    threshold = get_setting('REVIEW_REWARD_THRESHOLD', 5)
    total_reviews = Review.objects.filter(reviewer=user).count()
    if total_reviews > 0 and total_reviews % threshold == 0:
        wallet = get_or_create_wallet(user)
        apply_transaction(
            wallet=wallet,
            transaction_type='REWARD',
            amount_wantis=1,
            note=f'Recompensa por {total_reviews} reseñas',
        )


def dispute_review(review: Review, disputed_by, reason: str):
    if disputed_by.id != review.reviewee_id:
        raise PermissionError('Solo el receptor de la reseña puede impugnarla')
    if hasattr(review, 'dispute'):
        raise ConflictError('Reseña ya impugnada')

    review.status = 'UNDER_REVIEW'
    review.save(update_fields=['status'])

    from apps.reviews.models import ReviewDispute
    d = ReviewDispute.objects.create(
        review=review, disputed_by=disputed_by, reason=reason, status='OPEN'
    )
    log_audit_event(actor_user=disputed_by, action='REVIEW_DISPUTED',
                    entity='Review', entity_id=review.id)
    return d


def resolve_review_dispute(review_dispute, admin, keep: bool, note: str = ''):
    review = review_dispute.review
    review_dispute.status = 'RESOLVED_KEPT' if keep else 'RESOLVED_REMOVED'
    review_dispute.resolved_by = admin
    review_dispute.resolved_at = timezone.now()
    review_dispute.admin_note = note
    review_dispute.save()

    review.status = 'PUBLISHED' if keep else 'REMOVED'
    review.save(update_fields=['status'])

    log_audit_event(actor_user=admin, action='REVIEW_DISPUTE_RESOLVED',
                    entity='Review', entity_id=review.id,
                    metadata={'keep': keep})
```

### 10.2 `apps/reviews/selectors/reviews.py`

```python
def get_user_rating(user) -> float | None:
    """Promedio de reviews PUBLISHED donde reviewee=user. None si no tiene."""
    from django.db.models import Avg
    agg = Review.objects.filter(reviewee=user, status='PUBLISHED').aggregate(avg=Avg('rating'))
    return round(agg['avg'], 2) if agg['avg'] is not None else None

def list_reviews_of_user(user) -> QuerySet[Review]
def list_reviews_by_user(user) -> QuerySet[Review]
def list_review_disputes_pending() -> QuerySet[ReviewDispute]
```

---

## 11 · Servicios de `leads`

### 11.1 `apps/leads/services/leads.py`

```python
def create_lead_from_unlock(unlock: ContactUnlock) -> Lead:
    """Llamado automáticamente cuando el comprador desbloquea el contacto."""
    lead, _ = Lead.objects.get_or_create(
        contact_unlock=unlock,
        defaults={
            'seller': unlock.seller,
            'buyer': unlock.buyer,
            'stage': 'NEW',
            'expires_at': timezone.now() + timedelta(
                days=get_setting('LEAD_EXPIRY_DAYS', 30)
            ),
        }
    )
    log_audit_event(actor_user=None, action='LEAD_CREATED',
                    entity='Lead', entity_id=lead.id)
    return lead


@transaction.atomic
def change_stage(lead, seller, new_stage: str, sold_price_cop=None):
    if lead.seller_id != seller.id:
        raise PermissionError()
    lead.stage = new_stage
    lead.last_activity_at = timezone.now()
    lead.expires_at = timezone.now() + timedelta(days=get_setting('LEAD_EXPIRY_DAYS', 30))
    if new_stage == 'PURCHASED' and sold_price_cop:
        lead.sold_price_cop = sold_price_cop
    lead.save()
    log_audit_event(actor_user=seller, action='LEAD_STAGE_CHANGED',
                    entity='Lead', entity_id=lead.id,
                    metadata={'new_stage': new_stage})


def add_note(lead, seller, text: str):
    if lead.seller_id != seller.id:
        raise PermissionError()
    from apps.leads.models import LeadNote
    note = LeadNote.objects.create(
        lead=lead, author=seller, text=text, stage_at_time=lead.stage
    )
    lead.last_activity_at = timezone.now()
    lead.expires_at = timezone.now() + timedelta(days=get_setting('LEAD_EXPIRY_DAYS', 30))
    lead.save(update_fields=['last_activity_at', 'expires_at'])
    return note
```

### 11.2 `apps/leads/tasks.py`

```python
@shared_task
def expire_stale_leads():
    """Celery beat diario. Marca leads expirados."""
    from apps.leads.models import Lead
    Lead.objects.filter(
        expires_at__lt=timezone.now(),
        stage__in=['NEW', 'IN_NEGOTIATION', 'TO_VISIT']
    ).update(stage='EXPIRED')
```

---

## 12 · Servicios de `notifications`

### 12.1 `apps/notifications/services/dispatcher.py`

**Interfaz única de envío** — abstrae el canal.

```python
from apps.notifications.models import Notification
from apps.common.constants import NotificationChannel


def dispatch(recipient, template_code: str, channel=NotificationChannel.PUSH,
             title='', body='', payload=None):
    """
    Crea el registro y despacha por el canal.
    Fase 1: solo registra en DB (canal PUSH usa el logger mock).
    """
    n = Notification.objects.create(
        recipient=recipient,
        channel=channel,
        template_code=template_code,
        title=title,
        body=body,
        payload=payload or {},
    )
    if channel == NotificationChannel.PUSH:
        from apps.common.integrations.push.db_logger import send_push
        send_push(n)
    elif channel == NotificationChannel.EMAIL:
        _send_email(n)
    # WHATSAPP, SMS → futuras integraciones
    return n
```

### 12.2 `apps/notifications/tasks.py`

Cada evento clave tiene su task. **Regla: push primero, email solo para hitos, WhatsApp solo para compra de contacto y disputas críticas.**

```python
@shared_task
def notify_matches(need_id):
    """Notifica a comprador y vendedor de nuevos matches (push bidireccional)."""
    need = Need.objects.get(id=need_id)
    matches = need.matches.filter(status='GENERATED')
    if matches.exists():
        dispatch(need.buyer, 'MATCH_NEW_FOR_BUYER',
                 body=f'Tenés {matches.count()} nuevos matches para {need.title}')
        for match in matches:
            dispatch(match.seller, 'MATCH_NEW_FOR_SELLER',
                     body=f'Un comprador busca algo como tu {match.inventory_item.title}',
                     payload={'match_id': str(match.id)})


@shared_task
def notify_contact_unlocked(unlock_id):
    unlock = ContactUnlock.objects.get(id=unlock_id)
    dispatch(unlock.seller, 'CONTACT_UNLOCKED_TO_SELLER',
             channel=NotificationChannel.PUSH,
             body=f'Un comprador desbloqueó tu contacto',
             payload={'unlock_id': str(unlock.id)})


@shared_task
def notify_dispute_auto_ping(dispute_id):
    d = Dispute.objects.get(id=dispute_id)
    buyer = d.contact_unlock.buyer
    dispatch(buyer, 'DISPUTE_AUTO_PING',
             body='¿Completaste la compra con este vendedor?')


@shared_task
def notify_review_pending(unlock_id): ...
@shared_task
def notify_dispute_resolved(dispute_id): ...
```

---

## 13 · Celery beat — Tareas periódicas

En `app/settings/base.py`:

```python
from celery.schedules import crontab

CELERY_BEAT_SCHEDULE = {
    'expire-stale-needs': {
        'task': 'apps.needs.tasks.expire_stale_needs',
        'schedule': crontab(hour=2, minute=0),  # diario 2 AM
    },
    'expire-stale-leads': {
        'task': 'apps.leads.tasks.expire_stale_leads',
        'schedule': crontab(hour=3, minute=0),
    },
    'check-dispute-timeouts': {
        'task': 'apps.disputes.tasks.check_auto_review_timeouts',
        'schedule': crontab(minute='*/60'),  # cada hora
    },
    'reconcile-wallet-balances': {
        'task': 'apps.wallet.tasks.reconcile_balances',
        'schedule': crontab(hour=4, minute=0),
    },
}
```

**`reconcile_balances`** (job de auditoría diaria):
Para cada `Wallet`, sumar todas las `WalletTransaction.amount_wantis` y validar que coincide con `wallet.balance_wantis`. Si no coincide → crear `AuditLog` con `action='WALLET_INTEGRITY_BREACH'` y notificar al equipo por email.

---

## ✅ Checklist de cierre

Antes de pasar a `03-endpoints.md`, verificar:

- [ ] Todos los servicios documentados están implementados en su archivo correspondiente
- [ ] `apps/common/exceptions.py` contiene todas las excepciones de dominio
- [ ] `apps/audit/services/audit_log.py` funciona y no filtra datos sensibles
- [ ] Motor de match implementa filtros duros (presupuesto, radio, criterios obligatorios)
- [ ] Motor de match calcula score con criterios de preferencia ponderados
- [ ] Motor de match guarda `MatchCriterionResult` con el detalle de cada evaluación
- [ ] `wallet.apply_transaction` usa `select_for_update` y `@transaction.atomic`
- [ ] `wallet.apply_transaction` guarda `balance_after` para checksums
- [ ] `contacts.unlock_contact` es idempotente (no cobra dos veces)
- [ ] `disputes.open_dispute` no permite dos disputas activas sobre el mismo unlock
- [ ] `disputes.start_auto_review` agenda el timeout correctamente
- [ ] `disputes.check_auto_review_timeouts` escala automáticamente
- [ ] `reviews.create_review` no permite calificar dos veces
- [ ] `reviews.create_review` incentiva con recompensa cada N reseñas
- [ ] `leads` se crean automáticamente al desbloquear contacto
- [ ] `leads.expire_stale_leads` corre diariamente por Celery beat
- [ ] Todas las mutaciones sensibles emiten un `AuditLog`
- [ ] Ninguna función de servicio recibe `password`, `otp_code` o `token` en `metadata`
- [ ] `SystemSetting` se lee vía `get_setting()` — cero valores hardcodeados

---