import os

from django.db import connection
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView


class HealthView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        checks = {
            'database': self._check_database(),
            'redis': self._check_redis(),
            'postgis': self._check_postgis(),
        }
        ok = all(v == 'ok' for v in checks.values())
        payload = {
            'status': 'ok' if ok else 'error',
            'service': 'wanti-backend',
            'version': 'v1',
            **checks,
        }
        return Response(payload, status=200 if ok else 503)

    @staticmethod
    def _check_database():
        try:
            connection.ensure_connection()
            return 'ok'
        except Exception:
            return 'error'

    @staticmethod
    def _check_redis():
        try:
            import redis

            client = redis.from_url(os.getenv('REDIS_URL', 'redis://localhost:6379/0'))
            client.ping()
            return 'ok'
        except Exception:
            return 'error'

    @staticmethod
    def _check_postgis():
        try:
            with connection.cursor() as cursor:
                cursor.execute('SELECT PostGIS_Version()')
                cursor.fetchone()
            return 'ok'
        except Exception:
            return 'error'
