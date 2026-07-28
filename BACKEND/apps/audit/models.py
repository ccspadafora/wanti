from django.conf import settings
from django.db import models
from apps.common.models import BaseModel


class AuditLog(BaseModel):
    actor_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="audit_logs",
        verbose_name="Usuario que realizó la acción",
    )
    action = models.CharField(max_length=80, verbose_name="Acción")
    entity = models.CharField(max_length=50, verbose_name="Entidad")
    entity_id = models.UUIDField(null=True, blank=True, verbose_name="ID de la entidad")
    metadata = models.JSONField(default=dict, blank=True, verbose_name="Detalle")
    ip_address = models.GenericIPAddressField(
        null=True, blank=True, verbose_name="Dirección IP"
    )
    user_agent = models.CharField(
        max_length=500, blank=True, verbose_name="Navegador / dispositivo"
    )

    class Meta:
        db_table = "audit_logs"
        verbose_name = "Registro de auditoría"
        verbose_name_plural = "Registros de auditoría"
        indexes = [
            models.Index(fields=["actor_user", "-created_at"]),
            models.Index(fields=["entity", "entity_id"]),
            models.Index(fields=["action", "-created_at"]),
        ]

    def __str__(self):
        return f"{self.action} on {self.entity}({self.entity_id})"
