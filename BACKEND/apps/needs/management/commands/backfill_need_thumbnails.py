from django.core.management.base import BaseCommand

from apps.needs.models import Need
from apps.needs.services.thumbnails import ensure_need_thumbnail


class Command(BaseCommand):
    help = 'Asocia miniaturas IA de catálogo a sueños sin imágenes'

    def handle(self, *args, **options):
        qs = Need.objects.prefetch_related('images').select_related('vehicle', 'property')
        created = 0
        for need in qs:
            before = need.images.count()
            ensure_need_thumbnail(need)
            if need.images.count() > before:
                created += 1
        self.stdout.write(self.style.SUCCESS(f'Miniaturas creadas: {created}'))
