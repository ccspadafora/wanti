from django.core.management.base import BaseCommand

from apps.catalog.models import VehicleVersion
from apps.catalog.services.version_specs import upsert_inferred_spec


class Command(BaseCommand):
    help = 'Infiere y guarda specs técnicas a partir del nombre de cada versión de catálogo'

    def add_arguments(self, parser):
        parser.add_argument(
            '--limit',
            type=int,
            default=0,
            help='Procesar solo N versiones (0 = todas)',
        )

    def handle(self, *args, **options):
        qs = VehicleVersion.objects.filter(is_active=True).order_by('catalog_key')
        limit = options['limit']
        if limit:
            qs = qs[:limit]
        total = 0
        for version in qs.iterator(chunk_size=500):
            upsert_inferred_spec(version)
            total += 1
            if total % 2000 == 0:
                self.stdout.write(f'… {total} versiones')
        self.stdout.write(self.style.SUCCESS(f'Specs actualizados: {total} versiones'))
