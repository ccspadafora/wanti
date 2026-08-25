from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.geo.models import GeoCity, GeoDepartment
from apps.geo.serializers import GeoCitySerializer, GeoDepartmentSerializer


class DepartmentListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = GeoDepartment.objects.filter(is_active=True).order_by('name')
        search = request.query_params.get('search')
        if search:
            qs = qs.filter(name__icontains=search.strip())
        return Response({'results': GeoDepartmentSerializer(qs, many=True).data})


class CityListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = GeoCity.objects.filter(is_active=True).select_related('department')
        department_id = request.query_params.get('department_id')
        department_name = request.query_params.get('department')
        search = request.query_params.get('search')
        if department_id:
            qs = qs.filter(department_id=department_id)
        if department_name:
            qs = qs.filter(department__name__iexact=department_name.strip())
        if search:
            qs = qs.filter(name__icontains=search.strip())
        qs = qs.order_by('-is_capital', 'name')
        return Response({'results': GeoCitySerializer(qs, many=True).data})
