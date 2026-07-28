from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler

from apps.common import exceptions as domain


ERROR_MAP = {
    domain.ValidationError: ('VALIDATION_ERROR', status.HTTP_400_BAD_REQUEST),
    domain.NotFoundError: ('NOT_FOUND', status.HTTP_404_NOT_FOUND),
    domain.PermissionError: ('PERMISSION_DENIED', status.HTTP_403_FORBIDDEN),
    domain.ConflictError: ('CONFLICT', status.HTTP_409_CONFLICT),
    domain.InsufficientFundsError: ('INSUFFICIENT_FUNDS', status.HTTP_422_UNPROCESSABLE_ENTITY),
    domain.UserNotVerifiedError: ('USER_NOT_VERIFIED', status.HTTP_422_UNPROCESSABLE_ENTITY),
    domain.UserSuspendedError: ('USER_SUSPENDED', status.HTTP_403_FORBIDDEN),
    domain.OtpInvalidError: ('OTP_INVALID', status.HTTP_422_UNPROCESSABLE_ENTITY),
    domain.DisputeStateError: ('DISPUTE_STATE_ERROR', status.HTTP_409_CONFLICT),
}


def custom_exception_handler(exc, context):
    for exc_type, (code, http_status) in ERROR_MAP.items():
        if isinstance(exc, exc_type):
            return Response(
                {
                    'error': {
                        'code': code,
                        'message': str(exc),
                        'details': {},
                    }
                },
                status=http_status,
            )

    response = drf_exception_handler(exc, context)
    if response is not None:
        if isinstance(response.data, dict) and 'detail' in response.data:
            message = str(response.data['detail'])
        else:
            message = 'Error de validación'
            details = response.data
            return Response(
                {
                    'error': {
                        'code': 'VALIDATION_ERROR',
                        'message': message,
                        'details': details,
                    }
                },
                status=response.status_code,
            )
        code = 'THROTTLED' if response.status_code == 429 else 'VALIDATION_ERROR'
        if response.status_code == 401:
            code = 'UNAUTHORIZED'
        elif response.status_code == 403:
            code = 'PERMISSION_DENIED'
        return Response(
            {'error': {'code': code, 'message': message, 'details': {}}},
            status=response.status_code,
        )
    return response
