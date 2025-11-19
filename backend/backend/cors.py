from __future__ import annotations

from django.http import HttpResponse


class SimpleCorsMiddleware:
    """
    Minimal CORS support for the JSON API.

    This is primarily to allow the Flutter web dev server (running on a
    random localhost port) to talk to the Django backend on port 8000.
    It handles CORS preflight requests and adds the appropriate headers
    for /api/ endpoints.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Handle CORS preflight requests for API endpoints.
        if request.method == "OPTIONS" and request.path.startswith("/api/"):
            response = HttpResponse()
        else:
            response = self.get_response(request)

        # Only attach CORS headers for API endpoints and if an Origin is present.
        origin = request.headers.get("Origin")
        if origin and request.path.startswith("/api/"):
            # Echo the requesting origin so that credentials can be used.
            response["Access-Control-Allow-Origin"] = origin
            response["Vary"] = "Origin"
            response["Access-Control-Allow-Credentials"] = "true"
            response["Access-Control-Allow-Methods"] = (
                "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            )
            requested_headers = request.headers.get("Access-Control-Request-Headers")
            if requested_headers:
                response["Access-Control-Allow-Headers"] = requested_headers
            else:
                response["Access-Control-Allow-Headers"] = (
                    "Origin, Content-Type, Accept, Authorization"
                )

        return response

