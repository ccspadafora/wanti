from django.utils.text import slugify
from rest_framework import serializers

from apps.catalog.models import VehicleBrand, VehicleModel, VehicleModelYear, VehicleVersion
from apps.common.constants import VehicleCategory


class VehicleBrandSerializer(serializers.ModelSerializer):
    class Meta:
        model = VehicleBrand
        fields = (
            'id',
            'name',
            'slug',
            'category',
            'is_popular',
            'is_active',
            'sort_order',
        )


class VehicleBrandWriteSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=80)
    category = serializers.ChoiceField(
        choices=[c.value for c in VehicleCategory],
        default=VehicleCategory.CAR,
    )
    is_popular = serializers.BooleanField(required=False, default=False)
    is_active = serializers.BooleanField(required=False, default=True)
    sort_order = serializers.IntegerField(required=False, default=0)

    def create(self, validated_data):
        name = validated_data['name'].strip()
        slug = slugify(name) or 'marca'
        base = slug
        i = 1
        while VehicleBrand.objects.filter(slug=slug).exists():
            slug = f'{base}-{i}'
            i += 1
        return VehicleBrand.objects.create(name=name, slug=slug, **{
            k: validated_data[k]
            for k in ('category', 'is_popular', 'is_active', 'sort_order')
            if k in validated_data
        })


class VehicleModelSerializer(serializers.ModelSerializer):
    brand_id = serializers.UUIDField(source='brand.id', read_only=True)
    brand_name = serializers.CharField(source='brand.name', read_only=True)

    class Meta:
        model = VehicleModel
        fields = (
            'id',
            'brand_id',
            'brand_name',
            'name',
            'slug',
            'is_popular',
            'is_active',
            'sort_order',
        )


class VehicleModelWriteSerializer(serializers.Serializer):
    brand_id = serializers.UUIDField()
    name = serializers.CharField(max_length=120)
    is_popular = serializers.BooleanField(required=False, default=False)
    is_active = serializers.BooleanField(required=False, default=True)
    sort_order = serializers.IntegerField(required=False, default=0)

    def create(self, validated_data):
        brand = VehicleBrand.objects.get(id=validated_data['brand_id'])
        name = validated_data['name'].strip()
        slug = slugify(name) or 'modelo'
        base = slug
        i = 1
        while VehicleModel.objects.filter(brand=brand, slug=slug).exists():
            slug = f'{base}-{i}'
            i += 1
        return VehicleModel.objects.create(
            brand=brand,
            name=name,
            slug=slug,
            is_popular=validated_data.get('is_popular', False),
            is_active=validated_data.get('is_active', True),
            sort_order=validated_data.get('sort_order', 0),
        )


class VehicleYearSerializer(serializers.ModelSerializer):
    model_id = serializers.UUIDField(source='model.id', read_only=True)
    year = serializers.IntegerField()

    class Meta:
        model = VehicleModelYear
        fields = ('id', 'model_id', 'year', 'is_popular', 'is_active')


class VehicleYearWriteSerializer(serializers.Serializer):
    model_id = serializers.UUIDField()
    year = serializers.IntegerField(min_value=1950, max_value=2100)
    is_popular = serializers.BooleanField(required=False, default=False)
    is_active = serializers.BooleanField(required=False, default=True)

    def create(self, validated_data):
        model = VehicleModel.objects.get(id=validated_data['model_id'])
        obj, _ = VehicleModelYear.objects.get_or_create(
            model=model,
            year=validated_data['year'],
            defaults={
                'is_popular': validated_data.get('is_popular', False),
                'is_active': validated_data.get('is_active', True),
            },
        )
        return obj


class VehicleVersionSerializer(serializers.ModelSerializer):
    model_year_id = serializers.UUIDField(source='model_year.id', read_only=True)
    year = serializers.IntegerField(source='model_year.year', read_only=True)
    model_id = serializers.UUIDField(source='model_year.model.id', read_only=True)
    brand_name = serializers.CharField(source='model_year.model.brand.name', read_only=True)
    model_name = serializers.CharField(source='model_year.model.name', read_only=True)

    class Meta:
        model = VehicleVersion
        fields = (
            'id',
            'model_year_id',
            'model_id',
            'brand_name',
            'model_name',
            'year',
            'name',
            'catalog_key',
            'quality',
            'is_active',
            'sort_order',
        )


class VehicleVersionWriteSerializer(serializers.Serializer):
    model_year_id = serializers.UUIDField(required=False)
    model_id = serializers.UUIDField(required=False)
    year = serializers.IntegerField(required=False, min_value=1950, max_value=2100)
    name = serializers.CharField(max_length=120)
    is_active = serializers.BooleanField(required=False, default=True)
    sort_order = serializers.IntegerField(required=False, default=0)

    def validate(self, attrs):
        if not attrs.get('model_year_id') and not (attrs.get('model_id') and attrs.get('year')):
            raise serializers.ValidationError(
                'Indicá model_year_id o (model_id + year)'
            )
        return attrs

    def create(self, validated_data):
        if validated_data.get('model_year_id'):
            model_year = VehicleModelYear.objects.select_related('model__brand').get(
                id=validated_data['model_year_id']
            )
        else:
            model = VehicleModel.objects.select_related('brand').get(
                id=validated_data['model_id']
            )
            model_year, _ = VehicleModelYear.objects.get_or_create(
                model=model,
                year=validated_data['year'],
                defaults={'is_active': True},
            )
        name = validated_data['name'].strip()
        key = f'{model_year.model.brand.name}|{model_year.model.name}|{model_year.year}|{name}'
        return VehicleVersion.objects.create(
            model_year=model_year,
            name=name,
            catalog_key=key,
            quality='manual',
            is_active=validated_data.get('is_active', True),
            sort_order=validated_data.get('sort_order', 0),
        )
