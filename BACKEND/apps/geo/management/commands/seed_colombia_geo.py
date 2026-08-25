from django.core.management.base import BaseCommand

from apps.geo.models import GeoCity, GeoDepartment

# Capitales + municipios frecuentes para Wanti (Colombia).
COLOMBIA_GEO = {
    'Amazonas': [('Leticia', -4.215278, -69.940556, True)],
    'Antioquia': [
        ('Medellín', 6.244203, -75.581212, True),
        ('Envigado', 6.169833, -75.586861, False),
        ('Bello', 6.337322, -75.557953, False),
        ('Rionegro', 6.155147, -75.373711, False),
        ('Itagüí', 6.184611, -75.599389, False),
    ],
    'Arauca': [('Arauca', 7.090278, -70.761667, True)],
    'Atlántico': [
        ('Barranquilla', 10.96854, -74.781322, True),
        ('Soledad', 10.918433, -74.769742, False),
        ('Malambo', 10.859533, -74.773861, False),
    ],
    'Bolívar': [
        ('Cartagena', 10.391049, -75.479426, True),
        ('Magangué', 9.242019, -74.754667, False),
    ],
    'Boyacá': [
        ('Tunja', 5.535278, -73.367778, True),
        ('Duitama', 5.824481, -73.034108, False),
        ('Sogamoso', 5.71434, -72.933937, False),
    ],
    'Caldas': [
        ('Manizales', 5.070275, -75.513817, True),
        ('La Dorada', 5.447778, -74.663056, False),
        ('Chinchiná', 4.9825, -75.606111, False),
    ],
    'Caquetá': [('Florencia', 1.614381, -75.606231, True)],
    'Casanare': [('Yopal', 5.337753, -72.395859, True)],
    'Cauca': [
        ('Popayán', 2.444814, -76.614739, True),
        ('Santander de Quilichao', 3.009444, -76.484722, False),
    ],
    'Cesar': [
        ('Valledupar', 10.46314, -73.253222, True),
        ('Aguachica', 8.308472, -73.616639, False),
    ],
    'Chocó': [('Quibdó', 5.691881, -76.658353, True)],
    'Córdoba': [
        ('Montería', 8.750003, -75.878534, True),
        ('Lorica', 9.236528, -75.813611, False),
    ],
    'Cundinamarca': [
        ('Soacha', 4.579344, -74.222167, False),
        ('Chía', 4.861389, -74.032778, False),
        ('Zipaquirá', 5.022083, -74.004722, False),
        ('Facatativá', 4.813672, -74.354528, False),
        ('Girardot', 4.304722, -74.803056, False),
    ],
    'Bogotá D.C.': [
        ('Bogotá', 4.711, -74.0721, True),
    ],
    'Guainía': [('Inírida', 3.865278, -67.923889, True)],
    'Guaviare': [('San José del Guaviare', 2.572306, -72.645889, True)],
    'Huila': [
        ('Neiva', 2.9273, -75.28189, True),
        ('Pitalito', 1.853719, -76.050713, False),
        ('Garzón', 2.196111, -75.627778, False),
    ],
    'La Guajira': [
        ('Riohacha', 11.544444, -72.907222, True),
        ('Maicao', 11.383206, -72.243206, False),
    ],
    'Magdalena': [
        ('Santa Marta', 11.240355, -74.211023, True),
        ('Ciénaga', 11.006944, -74.2475, False),
    ],
    'Meta': [
        ('Villavicencio', 4.142, -73.6266, True),
        ('Acacías', 3.986944, -73.757778, False),
    ],
    'Nariño': [
        ('Pasto', 1.213611, -77.281111, True),
        ('Ipiales', 0.830278, -77.649444, False),
        ('Tumaco', 1.798611, -78.815556, False),
    ],
    'Norte de Santander': [
        ('Cúcuta', 7.889097, -72.49669, True),
        ('Ocaña', 8.237778, -73.356111, False),
        ('Pamplona', 7.375651, -72.647949, False),
    ],
    'Putumayo': [('Mocoa', 1.149444, -76.646944, True)],
    'Quindío': [
        ('Armenia', 4.53389, -75.68111, True),
        ('Calarcá', 4.529722, -75.640556, False),
        ('Circasia', 4.618056, -75.635833, False),
    ],
    'Risaralda': [
        ('Pereira', 4.813333, -75.696111, True),
        ('Dosquebradas', 4.839167, -75.6725, False),
        ('Santa Rosa de Cabal', 4.868056, -75.621389, False),
    ],
    'San Andrés y Providencia': [('San Andrés', 12.584722, -81.700556, True)],
    'Santander': [
        ('Bucaramanga', 7.119349, -73.122742, True),
        ('Floridablanca', 7.062222, -73.086389, False),
        ('Girón', 7.073056, -73.169167, False),
        ('Piedecuesta', 6.988889, -73.050278, False),
        ('Barrancabermeja', 7.065278, -73.854722, False),
    ],
    'Sucre': [
        ('Sincelejo', 9.304722, -75.397778, True),
        ('Corozal', 9.318056, -75.293611, False),
    ],
    'Tolima': [
        ('Ibagué', 4.444676, -75.242438, True),
        ('Espinal', 4.149444, -74.884444, False),
        ('Melgar', 4.203889, -74.640556, False),
    ],
    'Valle del Cauca': [
        ('Cali', 3.4516, -76.532, True),
        ('Palmira', 3.539444, -76.303611, False),
        ('Buenaventura', 3.8801, -77.0312, False),
        ('Tuluá', 4.084656, -76.195365, False),
        ('Buga', 3.900833, -76.300556, False),
        ('Cartago', 4.746389, -75.911667, False),
    ],
    'Vaupés': [('Mitú', 1.198333, -70.173333, True)],
    'Vichada': [('Puerto Carreño', 6.189031, -67.485878, True)],
}


class Command(BaseCommand):
    help = 'Carga departamentos y ciudades/municipios de Colombia'

    def handle(self, *args, **options):
        created_deps = 0
        created_cities = 0
        for dep_name, cities in COLOMBIA_GEO.items():
            dep, was_created = GeoDepartment.objects.get_or_create(
                name=dep_name,
                defaults={'is_active': True},
            )
            if was_created:
                created_deps += 1
            for city_name, lat, lng, is_capital in cities:
                _, city_created = GeoCity.objects.update_or_create(
                    department=dep,
                    name=city_name,
                    defaults={
                        'latitude': lat,
                        'longitude': lng,
                        'is_capital': is_capital,
                        'is_active': True,
                    },
                )
                if city_created:
                    created_cities += 1
        self.stdout.write(
            self.style.SUCCESS(
                f'Departamentos nuevos={created_deps} ciudades nuevas={created_cities} '
                f'total deps={GeoDepartment.objects.count()} cities={GeoCity.objects.count()}'
            )
        )
