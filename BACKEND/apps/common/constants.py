from django.db import models


class IdType(models.TextChoices):
    CC = 'CC', 'Cédula de Ciudadanía'
    CE = 'CE', 'Cédula de Extranjería'
    PASSPORT = 'PASSPORT', 'Pasaporte'
    NIT = 'NIT', 'NIT'


class UserRole(models.TextChoices):
    USER = 'USER', 'Usuario'  # comprador y/o vendedor
    ADMIN = 'ADMIN', 'Administrador'
    MODERATOR = 'MODERATOR', 'Moderador'


class UserStatus(models.TextChoices):
    PENDING = 'PENDING', 'Pendiente de verificación'
    ACTIVE = 'ACTIVE', 'Activo'
    SUSPENDED = 'SUSPENDED', 'Suspendido'


class AssetType(models.TextChoices):
    VEHICLE = 'VEHICLE', 'Vehículo'
    PROPERTY = 'PROPERTY', 'Inmueble'


class VehicleCategory(models.TextChoices):
    CAR = 'CAR', 'Carros'
    SUV = 'SUV', 'Camionetas'
    MOTO = 'MOTO', 'Motos'
    COLLECTION = 'COLLECTION', 'Carros de colección'
    TRUCK = 'TRUCK', 'Camiones'
    NAUTICAL = 'NAUTICAL', 'Náutica'
    HEAVY_MACHINERY = 'HEAVY_MACHINERY', 'Maquinaria pesada'
    OTHER = 'OTHER', 'Otros vehículos'


class PropertyType(models.TextChoices):
    APTO = 'APTO', 'Apartamento'
    CASA = 'CASA', 'Casa'
    LOTE_FINCA = 'LOTE_FINCA', 'Lote / Finca'
    LOCAL = 'LOCAL', 'Local'
    BODEGA = 'BODEGA', 'Bodega'
    CONSULTORIO = 'CONSULTORIO', 'Consultorio'


class ListingIntent(models.TextChoices):
    SALE = 'SALE', 'Venta'
    RENT = 'RENT', 'Arriendo'


class PaymentType(models.TextChoices):
    CASH = 'CASH', 'Efectivo'
    TRANSFER = 'TRANSFER', 'Transferencia'
    CREDIT = 'CREDIT', 'Crédito'
    MORTGAGE = 'MORTGAGE', 'Crédito hipotecario'
    TRADE_IN = 'TRADE_IN', 'Permuta'


class InsuranceReportAcceptance(models.TextChoices):
    NONE = 'NONE', 'No acepta'
    MINOR = 'MINOR', 'Menor cuantía'
    MAJOR = 'MAJOR', 'Mayor cuantía'


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
    CANCELLED = 'CANCELLED', 'Cancelada'
    REFUNDED = 'REFUNDED', 'Reembolsada'


class ContactOutcome(models.TextChoices):
    PENDING = 'PENDING', 'Sin confirmar'
    PURCHASED = 'PURCHASED', 'Compré'
    IN_PROGRESS = 'IN_PROGRESS', 'En proceso'
    NOT_PURCHASED = 'NOT_PURCHASED', 'No compré'
    INVALID_LEAD = 'INVALID_LEAD', 'Lead inválido'


class DisputeReason(models.TextChoices):
    # Vendedor (quien gasta Wanti) → disputa de contacto / reembolso
    BUYER_CONTACT_INVALID = 'BUYER_CONTACT_INVALID', 'El contacto del comprador es inválido'
    BUYER_NO_RESPONSE = 'BUYER_NO_RESPONSE', 'El comprador no responde'
    SPAM_OR_ABUSE = 'SPAM_OR_ABUSE', 'Lead spam, abuso o mala fe'
    FALSE_NEED = 'FALSE_NEED', 'La búsqueda no es real o tiene datos falsos'
    # Legacy buyer-contact reasons (ya no se usan para abrir, se mantienen por historial)
    CONTACT_INVALID = 'CONTACT_INVALID', 'El contacto no existe o es inválido'
    NO_RESPONSE = 'NO_RESPONSE', 'El vendedor no responde'
    ASSET_UNAVAILABLE = 'ASSET_UNAVAILABLE', 'El bien ya no está disponible'
    FALSE_INFO = 'FALSE_INFO', 'Información falsa o engañosa'
    OTHER = 'OTHER', 'Otro motivo'


# Solo el vendedor (pagador de Wanti) abre disputas de contacto/reembolso.
SELLER_DISPUTE_REASONS = {
    DisputeReason.BUYER_CONTACT_INVALID,
    DisputeReason.BUYER_NO_RESPONSE,
    DisputeReason.SPAM_OR_ABUSE,
    DisputeReason.FALSE_NEED,
    DisputeReason.OTHER,
}

# Comprador no abre disputas de Wanti; solo reseñas (otro módulo).
BUYER_DISPUTE_REASONS = set()



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


class SettingKey:
    WANTI_PRICE_COP = 'WANTI_PRICE_COP'  # default 5000
    NEED_DURATION_DAYS = 'NEED_DURATION_DAYS'  # default 30
    LEAD_EXPIRY_DAYS = 'LEAD_EXPIRY_DAYS'  # default 30
    MATCH_HIGH_THRESHOLD = 'MATCH_HIGH_THRESHOLD'  # default 85
    MATCH_MIN_SCORE = 'MATCH_MIN_SCORE'  # default 50
    MATCH_RADIUS_KM = 'MATCH_RADIUS_KM'  # default 50
    MIN_BUDGET_RATIO = 'MIN_BUDGET_RATIO'  # default 0.40
    DISPUTE_AUTO_TIMEOUT_HOURS = 'DISPUTE_AUTO_TIMEOUT_HOURS'  # default 72
    DISPUTE_APPEAL_DAYS = 'DISPUTE_APPEAL_DAYS'  # default 7
    OTP_TTL_SECONDS = 'OTP_TTL_SECONDS'  # default 300
    OTP_MAX_ATTEMPTS = 'OTP_MAX_ATTEMPTS'  # default 5
    REVIEW_REWARD_THRESHOLD = 'REVIEW_REWARD_THRESHOLD'  # default 5
