from __future__ import annotations

from django.http import HttpResponse


class SimpleCorsMiddleware:
    """
    Minimal CORS support for the JSON API.

    This lets local frontends (Flutter/web/JS) call the Django backend on a
    different localhost port. It handles OPTIONS preflight and echoes the
    Origin for /api and /media paths.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Short-circuit preflight on allowed paths.
        if request.method == "OPTIONS" and self._is_cors_path(request.path):
            response = HttpResponse()
        else:
            response = self.get_response(request)

        origin = request.headers.get("Origin")
        if origin and self._is_cors_path(request.path):
            response["Access-Control-Allow-Origin"] = origin
            response["Vary"] = "Origin"
            response["Access-Control-Allow-Credentials"] = "true"
            response["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            requested_headers = request.headers.get("Access-Control-Request-Headers")
            response["Access-Control-Allow-Headers"] = (
                requested_headers
                if requested_headers
                else "Origin, Content-Type, Accept, Authorization"
            )

        return response

    @staticmethod
    def _is_cors_path(path: str) -> bool:
        return path.startswith("/api/") or path.startswith("/media/")
