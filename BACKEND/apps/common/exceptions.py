class DomainError(Exception):
    default_message = "Error de dominio"

    def __init__(self, message=None):
        super().__init__(message or self.default_message)


class ValidationError(DomainError):
    default_message = "Datos inválidos"


class NotFoundError(DomainError):
    default_message = "Recurso no encontrado"


class PermissionError(DomainError):
    default_message = "Sin permisos"


class ConflictError(DomainError):
    default_message = "Conflicto de estado"


class InsufficientFundsError(DomainError):
    default_message = "Saldo insuficiente"


class UserNotVerifiedError(DomainError):
    default_message = "Verificación pendiente"


class UserSuspendedError(DomainError):
    default_message = "Cuenta suspendida"


class OtpInvalidError(DomainError):
    default_message = "OTP inválido o expirado"


class DisputeStateError(DomainError):
    default_message = "Estado de disputa inválido para esta acción"
