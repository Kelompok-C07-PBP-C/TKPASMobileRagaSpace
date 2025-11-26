"""Root URL configuration for TK PBP project."""
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import path, include
from django.views.generic import RedirectView

from app import views as backend_views
from authentication.views import HomeView

urlpatterns = [
    # Custom admin panel from the integrated backend app
    path("admin/login/", backend_views.admin_login_view, name="html-admin-login"),
    path("admin/logout/", backend_views.admin_logout_view, name="html-admin-logout"),
    path("admin/", backend_views.admin_panel, name="html-admin-panel"),
    # Keep Django's default admin available
    path("dj-admin/", admin.site.urls),
    path("", HomeView.as_view(), name="home"),
    path("", include("authentication.urls")),
    path("workspace/", include("manajemen_lapangan.urls")),
    path("", include("katalog.urls")),
    path("", include("rent.urls")),
    path("", include("interaksi.urls")),
    path("api/", include("app.urls")),
    path("favicon.ico", RedirectView.as_view(url="/static/images/favicon.ico")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
