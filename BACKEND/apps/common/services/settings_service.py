from decimal import Decimal
from django.core.cache import cache
from apps.common.models import SystemSetting


def get_setting(key: str, default=None):
    cache_key = f"sys:{key}"
    cached = cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        setting = SystemSetting.objects.get(key=key)
        val = _cast(setting.value, setting.value_type)
        cache.set(cache_key, val, 60)
        return val
    except SystemSetting.DoesNotExist:
        return default


def invalidate_setting_cache(key: str) -> None:
    cache.delete(f"sys:{key}")


def _cast(value, value_type):
    if value_type == "INT":
        return int(value)
    if value_type == "DECIMAL":
        return Decimal(value)
    if value_type == "BOOL":
        return value.lower() in ("true", "1", "yes")
    return value
