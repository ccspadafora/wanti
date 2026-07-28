from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.exceptions import NotFoundError
from apps.common.pagination import StandardPagination
from apps.notifications.models import DeviceToken, Notification
from apps.notifications.serializers import (
    DeviceTokenCreateSerializer,
    DeviceTokenSerializer,
    NotificationSerializer,
)


class NotificationListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Notification.objects.filter(recipient=request.user).order_by('-created_at')
        channel = request.query_params.get('channel')
        if channel:
            qs = qs.filter(channel=channel)
        read = request.query_params.get('read')
        if read is not None:
            if read.lower() in ('true', '1'):
                qs = qs.filter(read_at__isnull=False)
            elif read.lower() in ('false', '0'):
                qs = qs.filter(read_at__isnull=True)

        unread_count = Notification.objects.filter(
            recipient=request.user,
            read_at__isnull=True,
        ).count()

        paginator = StandardPagination()
        page = paginator.paginate_queryset(qs, request, view=self)
        response = paginator.get_paginated_response(
            NotificationSerializer(page, many=True).data
        )
        response.data['unread_count'] = unread_count
        return response


class NotificationMarkReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        try:
            notification = Notification.objects.get(pk=id, recipient=request.user)
        except Notification.DoesNotExist as exc:
            raise NotFoundError('Notificación no encontrada') from exc
        if notification.read_at is None:
            notification.read_at = timezone.now()
            notification.save(update_fields=['read_at', 'updated_at'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class NotificationMarkAllReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        Notification.objects.filter(
            recipient=request.user,
            read_at__isnull=True,
        ).update(read_at=timezone.now())
        return Response(status=status.HTTP_204_NO_CONTENT)


class DeviceTokenCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DeviceTokenCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        token, _ = DeviceToken.objects.update_or_create(
            token=data['token'],
            defaults={
                'user': request.user,
                'platform': data['platform'],
                'device_id': data.get('device_id', ''),
                'is_active': True,
            },
        )
        return Response(
            DeviceTokenSerializer(token).data,
            status=status.HTTP_201_CREATED,
        )


class DeviceTokenDeleteView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, id):
        try:
            token = DeviceToken.objects.get(pk=id, user=request.user)
        except DeviceToken.DoesNotExist as exc:
            raise NotFoundError('Device token no encontrado') from exc
        token.is_active = False
        token.save(update_fields=['is_active', 'updated_at'])
        return Response(status=status.HTTP_204_NO_CONTENT)
