import uuid


class CorrelationIdMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        cid = request.headers.get("X-Correlation-Id") or str(uuid.uuid4())
        request.correlation_id = cid
        response = self.get_response(request)
        response["X-Correlation-Id"] = cid
        return response
