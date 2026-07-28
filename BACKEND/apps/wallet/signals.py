from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver
from apps.common.constants import UserStatus
from apps.wallet.models import Wallet


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def ensure_wallet_for_active_user(sender, instance, **kwargs):
    if instance.status != UserStatus.ACTIVE:
        return
    Wallet.objects.get_or_create(user=instance)
