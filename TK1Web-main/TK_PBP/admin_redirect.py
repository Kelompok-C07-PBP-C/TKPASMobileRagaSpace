from __future__ import annotations

"""
Middleware that routes staff users to the custom admin panel.

If a user is authenticated and marked as staff, regular HTML page
requests are redirected to the `/admin/` dashboard so that admins
always land in the new admin experience instead of the public site.
JSON/API and static/media requests are left untouched so the
admin UI can still call its APIs.
"""

from django.http import HttpRequest, HttpResponse
from django.shortcuts import redirect


class AdminRedirectMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        if self._should_redirect(request):
            return redirect("/admin/")
        return self.get_response(request)

    @staticmethod
    def _should_redirect(request: HttpRequest) -> bool:
        user = getattr(request, "user", None)
        if not user or not user.is_authenticated or not user.is_staff:
            return False

        path = request.path or "/"

        # Never interfere with the admin panel itself, the default
        # Django admin, or static/media assets.
        if path.startswith(("/admin/", "/dj-admin/", "/static/", "/media/")):
            return False

        # Only redirect full-page HTML navigations, not API calls or XHR.
        accept = request.META.get("HTTP_ACCEPT", "")
        if "text/html" not in accept:
            return False

        if request.headers.get("x-requested-with") == "XMLHttpRequest":
            return False

        return True

