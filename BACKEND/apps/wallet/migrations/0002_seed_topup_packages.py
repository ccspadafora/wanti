from decimal import Decimal

from django.db import migrations


PACKAGES = [
    {
        'name': 'Básico',
        'wantis_base': 5,
        'wantis_bonus': 0,
        'price_cop': Decimal('25000'),
        'is_popular': False,
        'order': 1,
    },
    {
        'name': 'Popular',
        'wantis_base': 10,
        'wantis_bonus': 1,
        'price_cop': Decimal('50000'),
        'is_popular': True,
        'order': 2,
    },
    {
        'name': 'Premium',
        'wantis_base': 20,
        'wantis_bonus': 5,
        'price_cop': Decimal('100000'),
        'is_popular': False,
        'order': 3,
    },
]


def seed_packages(apps, schema_editor):
    TopupPackage = apps.get_model('wallet', 'TopupPackage')
    for package in PACKAGES:
        TopupPackage.objects.update_or_create(
            name=package['name'],
            defaults={
                'wantis_base': package['wantis_base'],
                'wantis_bonus': package['wantis_bonus'],
                'price_cop': package['price_cop'],
                'is_popular': package['is_popular'],
                'is_active': True,
                'order': package['order'],
            },
        )


def unseed_packages(apps, schema_editor):
    TopupPackage = apps.get_model('wallet', 'TopupPackage')
    TopupPackage.objects.filter(name__in=[p['name'] for p in PACKAGES]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('wallet', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(seed_packages, unseed_packages),
    ]
