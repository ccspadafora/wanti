from rest_framework import serializers

from apps.geo.models import GeoCity, GeoDepartment


class GeoDepartmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = GeoDepartment
        fields = ('id', 'name', 'code')


class GeoCitySerializer(serializers.ModelSerializer):
    department_id = serializers.UUIDField(source='department.id', read_only=True)
    department_name = serializers.CharField(source='department.name', read_only=True)

    class Meta:
        model = GeoCity
        fields = (
            'id',
            'name',
            'department_id',
            'department_name',
            'latitude',
            'longitude',
            'is_capital',
        )
