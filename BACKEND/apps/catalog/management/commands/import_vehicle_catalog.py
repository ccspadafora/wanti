from pathlib import Path

from django.core.management.base import BaseCommand

from apps.catalog.models import VehicleBrand, VehicleModel, VehicleModelYear, VehicleVersion
from apps.catalog.services.csv_import import import_vehicle_catalog_csv


class Command(BaseCommand):
    help = 'Importa el catálogo masivo de vehículos Colombia (CSV)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--path',
            default=str(
                Path(__file__).resolve().parents[2] / 'data' / 'vehicle_catalog.csv'
            ),
        )
        parser.add_argument('--clear', action='store_true', help='Borra catálogo antes')
        parser.add_argument('--dry-run', action='store_true', help='Solo valida, no escribe')
        parser.add_argument(
            '--no-update',
            action='store_true',
            help='No actualiza versiones existentes (solo crea nuevas)',
        )
        parser.add_argument(
            '--default-category',
            default='CAR',
            help='Categoría por defecto si el CSV no trae columna categoria',
        )

    def handle(self, *args, **options):
        path = Path(options['path'])
        if not path.exists():
            self.stderr.write(f'No existe {path}')
            return

        if options['clear'] and not options['dry_run']:
            VehicleVersion.objects.all().delete()
            VehicleModelYear.objects.all().delete()
            VehicleModel.objects.all().delete()
            VehicleBrand.objects.all().delete()
            self.stdout.write('Catálogo limpiado')

        with path.open('rb') as f:
            result = import_vehicle_catalog_csv(
                f,
                dry_run=options['dry_run'],
                update_existing=not options['no_update'],
                default_category=options['default_category'],
            )

        self.stdout.write(
            self.style.SUCCESS(
                f"{'DRY-RUN ' if result.dry_run else ''}"
                f'rows={result.total_rows} brands+{result.created_brands} '
                f'models+{result.created_models} years+{result.created_years} '
                f'versions+{result.created_versions} updated={result.updated_versions} '
                f'skipped_dup={result.skipped_duplicates} specs={result.specs_upserted} '
                f'errors={len(result.errors)}'
            )
        )
        for err in result.errors[:30]:
            self.stderr.write(f'  fila {err.row} [{err.field}]: {err.message}')
        if len(result.errors) > 30:
            self.stderr.write(f'  … y {len(result.errors) - 30} errores más')
