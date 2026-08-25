from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status

from apps.catalog.models import VehicleBrand, VehicleModel, VehicleModelYear, VehicleVersion
from apps.catalog.serializers import (
    VehicleBrandSerializer,
    VehicleBrandWriteSerializer,
    VehicleModelSerializer,
    VehicleModelWriteSerializer,
    VehicleVersionSerializer,
    VehicleVersionWriteSerializer,
    VehicleYearSerializer,
    VehicleYearWriteSerializer,
)
from apps.catalog.services.csv_import import import_vehicle_catalog_csv
from apps.catalog.services.version_specs import specs_payload
from apps.common.constants import VehicleCategory
from apps.common.permissions import IsAdminOrModerator
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser

# Categoría de publicación → categorías de marca en catálogo (fallback a CAR).
_BRAND_CATEGORY_ALIASES = {
    VehicleCategory.CAR: [VehicleCategory.CAR],
    VehicleCategory.SUV: [VehicleCategory.SUV, VehicleCategory.CAR],
    VehicleCategory.MOTO: [VehicleCategory.MOTO],
    VehicleCategory.COLLECTION: [VehicleCategory.COLLECTION, VehicleCategory.CAR],
    VehicleCategory.TRUCK: [VehicleCategory.TRUCK, VehicleCategory.CAR],
    VehicleCategory.NAUTICAL: [VehicleCategory.NAUTICAL, VehicleCategory.OTHER],
    VehicleCategory.HEAVY_MACHINERY: [
        VehicleCategory.HEAVY_MACHINERY,
        VehicleCategory.OTHER,
    ],
    VehicleCategory.OTHER: [VehicleCategory.OTHER, VehicleCategory.CAR],
}


class BrandListView(APIView):
    """GET público; POST solo admin."""

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsAdminOrModerator()]
        return []

    def get(self, request):
        qs = VehicleBrand.objects.filter(is_active=True)
        category = (request.query_params.get('category') or '').strip().upper()
        aliases = _BRAND_CATEGORY_ALIASES.get(category)
        if aliases:
            qs = qs.filter(category__in=aliases)
        elif category:
            qs = qs.filter(category=category)
        search = (request.query_params.get('search') or '').strip()
        if search:
            qs = qs.filter(name__icontains=search)
        return Response({'results': VehicleBrandSerializer(qs, many=True).data})

    def post(self, request):
        ser = VehicleBrandWriteSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        brand = ser.save()
        return Response(VehicleBrandSerializer(brand).data, status=status.HTTP_201_CREATED)


class BrandDetailView(APIView):
    permission_classes = [IsAdminOrModerator]

    def patch(self, request, id):
        brand = VehicleBrand.objects.get(id=id)
        for field in ('name', 'category', 'is_popular', 'is_active', 'sort_order'):
            if field in request.data:
                setattr(brand, field, request.data[field])
        brand.save()
        return Response(VehicleBrandSerializer(brand).data)

    def delete(self, request, id):
        brand = VehicleBrand.objects.get(id=id)
        brand.is_active = False
        brand.save(update_fields=['is_active', 'updated_at'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class ModelListView(APIView):
    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsAdminOrModerator()]
        return []

    def get(self, request):
        brand_id = request.query_params.get('brand_id')
        if not brand_id:
            return Response({'detail': 'brand_id es requerido'}, status=400)
        qs = VehicleModel.objects.filter(brand_id=brand_id, is_active=True).select_related(
            'brand'
        )
        search = (request.query_params.get('search') or '').strip()
        if search:
            qs = qs.filter(name__icontains=search)
        return Response({'results': VehicleModelSerializer(qs, many=True).data})

    def post(self, request):
        ser = VehicleModelWriteSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        model = ser.save()
        return Response(VehicleModelSerializer(model).data, status=status.HTTP_201_CREATED)


class ModelDetailView(APIView):
    permission_classes = [IsAdminOrModerator]

    def patch(self, request, id):
        model = VehicleModel.objects.select_related('brand').get(id=id)
        for field in ('name', 'is_popular', 'is_active', 'sort_order'):
            if field in request.data:
                setattr(model, field, request.data[field])
        model.save()
        return Response(VehicleModelSerializer(model).data)

    def delete(self, request, id):
        model = VehicleModel.objects.get(id=id)
        model.is_active = False
        model.save(update_fields=['is_active', 'updated_at'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class YearListView(APIView):
    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsAdminOrModerator()]
        return []

    def get(self, request):
        model_id = request.query_params.get('model_id')
        if not model_id:
            return Response({'detail': 'model_id es requerido'}, status=400)
        qs = VehicleModelYear.objects.filter(model_id=model_id, is_active=True)
        return Response({'results': VehicleYearSerializer(qs, many=True).data})

    def post(self, request):
        ser = VehicleYearWriteSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        year = ser.save()
        return Response(VehicleYearSerializer(year).data, status=status.HTTP_201_CREATED)


class YearDetailView(APIView):
    permission_classes = [IsAdminOrModerator]

    def patch(self, request, id):
        year = VehicleModelYear.objects.get(id=id)
        for field in ('is_popular', 'is_active'):
            if field in request.data:
                setattr(year, field, request.data[field])
        year.save()
        return Response(VehicleYearSerializer(year).data)

    def delete(self, request, id):
        year = VehicleModelYear.objects.get(id=id)
        year.is_active = False
        year.save(update_fields=['is_active', 'updated_at'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class VersionListView(APIView):
    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsAdminOrModerator()]
        return []

    def get(self, request):
        model_id = request.query_params.get('model_id')
        year = request.query_params.get('year')
        model_year_id = request.query_params.get('model_year_id')
        qs = VehicleVersion.objects.filter(is_active=True).select_related(
            'model_year__model__brand'
        )
        if model_year_id:
            qs = qs.filter(model_year_id=model_year_id)
        elif model_id and year:
            qs = qs.filter(model_year__model_id=model_id, model_year__year=int(year))
        else:
            return Response(
                {'detail': 'model_year_id o (model_id + year) requeridos'},
                status=400,
            )
        search = (request.query_params.get('search') or '').strip()
        if search:
            qs = qs.filter(name__icontains=search)
        return Response({'results': VehicleVersionSerializer(qs, many=True).data})

    def post(self, request):
        ser = VehicleVersionWriteSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        version = ser.save()
        return Response(
            VehicleVersionSerializer(version).data, status=status.HTTP_201_CREATED
        )


class VersionDetailView(APIView):
    permission_classes = [IsAdminOrModerator]

    def patch(self, request, id):
        version = VehicleVersion.objects.select_related('model_year__model__brand').get(
            id=id
        )
        for field in ('name', 'is_active', 'sort_order', 'quality'):
            if field in request.data:
                setattr(version, field, request.data[field])
        version.save()
        return Response(VehicleVersionSerializer(version).data)

    def delete(self, request, id):
        version = VehicleVersion.objects.get(id=id)
        version.is_active = False
        version.save(update_fields=['is_active', 'updated_at'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class VersionSpecsView(APIView):
    """GET specs técnicas permitidas / precargadas para una versión."""

    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        try:
            version = VehicleVersion.objects.select_related('specs', 'model_year__model__brand').get(
                id=id,
                is_active=True,
            )
        except VehicleVersion.DoesNotExist:
            return Response({'detail': 'Versión no encontrada'}, status=404)
        return Response(specs_payload(version))


class CatalogImportView(APIView):
    """
    POST multipart: file=<csv>
    Query/body:
      dry_run=true|false (default true para preview)
      update_existing=true|false (default true)
      default_category=CAR
    """

    permission_classes = [IsAdminOrModerator]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        upload = request.FILES.get('file')
        if upload is None:
            return Response(
                {'detail': 'Adjunta un archivo CSV en el campo "file"'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if upload.size and upload.size > 25 * 1024 * 1024:
            return Response(
                {'detail': 'El archivo supera el límite de 25 MB'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        dry_run_raw = (
            request.data.get('dry_run')
            if 'dry_run' in request.data
            else request.query_params.get('dry_run', 'true')
        )
        dry_run = str(dry_run_raw).strip().lower() in {'1', 'true', 'yes', 'si', 'sí'}

        update_raw = (
            request.data.get('update_existing')
            if 'update_existing' in request.data
            else request.query_params.get('update_existing', 'true')
        )
        update_existing = str(update_raw).strip().lower() in {
            '1',
            'true',
            'yes',
            'si',
            'sí',
        }

        default_category = (
            request.data.get('default_category')
            or request.query_params.get('default_category')
            or VehicleCategory.CAR
        )

        result = import_vehicle_catalog_csv(
            upload,
            dry_run=dry_run,
            update_existing=update_existing,
            default_category=str(default_category).upper(),
        )
        code = status.HTTP_200_OK if dry_run else status.HTTP_201_CREATED
        if result.errors and result.created_versions == 0 and result.updated_versions == 0:
            # Todo falló
            code = status.HTTP_400_BAD_REQUEST if not dry_run else status.HTTP_200_OK
        return Response(result.to_dict(), status=code)


class CatalogImportTemplateView(APIView):
    """GET descarga un CSV de ejemplo con encabezados esperados."""

    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        from django.http import HttpResponse

        content = (
            'categoria,marca,modelo,anio,version,combustible,transmision,traccion,activo\n'
            'CAR,Chevrolet,Spark,2020,GT,Gasolina,Mecánica,4x2,true\n'
            'MOTO,Yamaha,FZ,2022,2.0,Gasolina,Mecánica,,true\n'
            'SUV,Toyota,Fortuner,2021,SRV,Diésel,Automática,4x4,true\n'
        )
        response = HttpResponse(content, content_type='text/csv; charset=utf-8')
        response['Content-Disposition'] = 'attachment; filename="wanti_catalog_template.csv"'
        return response
