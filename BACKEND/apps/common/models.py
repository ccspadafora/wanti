import uuid
from django.conf import settings
from django.db import models


class BaseModel(models.Model):
    id = models.UUIDField(
        primary_key=True, default=uuid.uuid4, editable=False, verbose_name="ID"
    )
    created_at = models.DateTimeField(
        auto_now_add=True, db_index=True, verbose_name="Creado el"
    )
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Actualizado el")

    class Meta:
        abstract = True
        ordering = ["-created_at"]


class SystemSetting(models.Model):
    key = models.CharField(
        max_length=64, unique=True, db_index=True, verbose_name="Clave"
    )
    value = models.CharField(max_length=255, verbose_name="Valor")
    value_type = models.CharField(
        max_length=10,
        choices=[
            ("INT", "Entero"),
            ("DECIMAL", "Decimal"),
            ("BOOL", "Booleano"),
            ("STRING", "Texto"),
        ],
        verbose_name="Tipo de valor",
    )
    description = models.TextField(blank=True, verbose_name="Descripción")
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="+",
        verbose_name="Actualizado por",
    )
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Actualizado el")

    class Meta:
        db_table = "system_settings"
        verbose_name = "Parámetro del sistema"
        verbose_name_plural = "Parámetros del sistema"

    def __str__(self):
        return f"{self.key}={self.value}"
