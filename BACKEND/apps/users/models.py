import uuid
from django.contrib.auth.models import (
    AbstractBaseUser,
    BaseUserManager,
    PermissionsMixin,
)
from django.contrib.gis.db import models
from django.utils import timezone
from apps.common.constants import IdType, UserRole, UserStatus


class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("El email es obligatorio")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("role", UserRole.ADMIN)
        extra_fields.setdefault("status", UserStatus.ACTIVE)
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("email_verified_at", timezone.now())
        extra_fields.setdefault("phone_verified_at", timezone.now())
        return self.create_user(email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    id = models.UUIDField(
        primary_key=True, default=uuid.uuid4, editable=False, verbose_name="ID"
    )
    full_name = models.CharField(max_length=150, verbose_name="Nombre completo")
    id_type = models.CharField(
        max_length=20, choices=IdType.choices, verbose_name="Tipo de documento"
    )
    id_number = models.CharField(max_length=30, verbose_name="Número de documento")
    email = models.EmailField(unique=True, verbose_name="Correo electrónico")
    phone = models.CharField(max_length=20, verbose_name="Teléfono")
    city = models.CharField(max_length=100, verbose_name="Ciudad")
    location = models.PointField(
        srid=4326, geography=True, null=True, blank=True, verbose_name="Ubicación"
    )
    profile_photo_url = models.URLField(
        max_length=500, null=True, blank=True, verbose_name="URL de foto de perfil"
    )
    role = models.CharField(
        max_length=20,
        choices=UserRole.choices,
        default=UserRole.USER,
        verbose_name="Rol",
    )
    status = models.CharField(
        max_length=20,
        choices=UserStatus.choices,
        default=UserStatus.PENDING,
        verbose_name="Estado",
    )
    email_verified_at = models.DateTimeField(
        null=True, blank=True, verbose_name="Correo verificado el"
    )
    phone_verified_at = models.DateTimeField(
        null=True, blank=True, verbose_name="Teléfono verificado el"
    )
    is_staff = models.BooleanField(default=False, verbose_name="Acceso al panel admin")
    last_login_at = models.DateTimeField(
        null=True, blank=True, verbose_name="Último acceso el"
    )
    created_at = models.DateTimeField(
        auto_now_add=True, db_index=True, verbose_name="Creado el"
    )
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Actualizado el")
    objects = UserManager()
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["full_name", "id_type", "id_number", "phone", "city"]

    class Meta:
        db_table = "users"
        verbose_name = "Usuario"
        verbose_name_plural = "Usuarios"
        constraints = [
            models.UniqueConstraint(
                fields=["id_type", "id_number"], name="unique_identity_document"
            )
        ]
        indexes = [
            models.Index(fields=["email"]),
            models.Index(fields=["status"]),
            models.Index(fields=["role"]),
            models.Index(fields=["city"]),
        ]

    def __str__(self):
        return f"{self.full_name} <{self.email}>"

    @property
    def is_active(self):
        return self.status != UserStatus.SUSPENDED

    @property
    def is_fully_verified(self):
        return self.email_verified_at is not None and self.phone_verified_at is not None

    @property
    def can_publish(self):
        return self.status == UserStatus.ACTIVE and self.is_fully_verified

    @property
    def rating_average(self):
        from apps.reviews.selectors.reviews import get_user_rating

        return get_user_rating(self)

    @property
    def is_new_user(self):
        return self.rating_average is None
