from django.db import migrations


TAGS = [
    # Comprador → Vendedor
    ('FAST_RESPONSE', 'Rápido en responder', 'BUYER_REVIEWING_SELLER', 1),
    ('ACCURATE_INFO', 'Información precisa', 'BUYER_REVIEWING_SELLER', 2),
    ('GOOD_TREATMENT', 'Buen trato', 'BUYER_REVIEWING_SELLER', 3),
    ('FAIR_PRICE', 'Precio justo', 'BUYER_REVIEWING_SELLER', 4),
    # Vendedor → Comprador
    ('SERIOUS_COMMITTED', 'Serio y comprometido', 'SELLER_REVIEWING_BUYER', 1),
    ('CLEAR_COMMUNICATION', 'Comunicación clara', 'SELLER_REVIEWING_BUYER', 2),
    ('RESPECTFUL', 'Trato respetuoso', 'SELLER_REVIEWING_BUYER', 3),
    ('FAST_PAYMENT', 'Pagó rápido', 'SELLER_REVIEWING_BUYER', 4),
]


def seed_tags(apps, schema_editor):
    ReviewTag = apps.get_model('reviews', 'ReviewTag')
    for code, label, for_role, order in TAGS:
        ReviewTag.objects.update_or_create(
            code=code,
            defaults={
                'label': label,
                'for_role': for_role,
                'is_active': True,
                'order': order,
            },
        )


def unseed_tags(apps, schema_editor):
    ReviewTag = apps.get_model('reviews', 'ReviewTag')
    ReviewTag.objects.filter(code__in=[row[0] for row in TAGS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('reviews', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(seed_tags, unseed_tags),
    ]
