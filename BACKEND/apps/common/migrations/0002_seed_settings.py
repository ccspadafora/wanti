from django.db import migrations


SETTINGS = [
    ('WANTI_PRICE_COP', '5000', 'INT', 'Precio en COP de 1 Wanti'),
    ('NEED_DURATION_DAYS', '30', 'INT', 'Días de vigencia de una necesidad'),
    ('LEAD_EXPIRY_DAYS', '30', 'INT', 'Días para caducidad automática de un lead sin actividad'),
    ('MATCH_HIGH_THRESHOLD', '85', 'INT', '% mínimo para match "alto" (color teal)'),
    ('MATCH_MIN_SCORE', '50', 'INT', '% mínimo para generar un match visible'),
    ('MATCH_RADIUS_KM', '50', 'INT', 'Radio geográfico de búsqueda en km'),
    ('MIN_BUDGET_RATIO', '0.40', 'DECIMAL', 'Ratio mínimo presupuesto/valor comercial (filtro anti-abuso)'),
    ('DISPUTE_AUTO_TIMEOUT_HOURS', '72', 'INT', 'Horas para que el comprador responda antes de escalar'),
    ('DISPUTE_APPEAL_DAYS', '7', 'INT', 'Días para apelar una disputa resuelta'),
    ('OTP_TTL_SECONDS', '300', 'INT', 'Vigencia del OTP (5 min)'),
    ('OTP_MAX_ATTEMPTS', '5', 'INT', 'Máximo de intentos de OTP antes de invalidar'),
    ('REVIEW_REWARD_THRESHOLD', '5', 'INT', 'Cantidad de reseñas para recompensa en Wantis'),
]


def seed_settings(apps, schema_editor):
    SystemSetting = apps.get_model('common', 'SystemSetting')
    for key, value, value_type, description in SETTINGS:
        SystemSetting.objects.update_or_create(
            key=key,
            defaults={
                'value': value,
                'value_type': value_type,
                'description': description,
            },
        )


def unseed_settings(apps, schema_editor):
    SystemSetting = apps.get_model('common', 'SystemSetting')
    SystemSetting.objects.filter(key__in=[row[0] for row in SETTINGS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('common', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(seed_settings, unseed_settings),
    ]
