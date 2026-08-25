from django.urls import path

from apps.geo.views import CityListView, DepartmentListView

urlpatterns = [
    path('departments/', DepartmentListView.as_view(), name='geo-departments'),
    path('cities/', CityListView.as_view(), name='geo-cities'),
]
