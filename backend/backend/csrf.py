from __future__ import annotations

from urllib.parse import urlparse

from django.conf import settings
from django.middleware.csrf import CsrfViewMiddleware


class LocalDevCsrfViewMiddleware(CsrfViewMiddleware):
    """Relax CSRF Origin checks for local dev Flutter web (random ports).

    Flutter web runs from a localhost dev-server with a random port, which
    triggers Django's Origin check for CSRF-protected POSTs to the API.
    In DEBUG, allow any `http://localhost:*` / `http://127.0.0.1:*` origin
    for `/api/` requests. Production behavior remains unchanged.
    """

    def _origin_verified(self, request) -> bool:  # type: ignore[override]
        if getattr(settings, "DEBUG", False) and request.path.startswith("/api/"):
            origin = request.META.get("HTTP_ORIGIN")
            if origin:
                parsed = urlparse(origin)
                if parsed.scheme in ("http", "https") and parsed.hostname in (
                    "localhost",
                    "127.0.0.1",
                ):
                    return True
        return super()._origin_verified(request)

