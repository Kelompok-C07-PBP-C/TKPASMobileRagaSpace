"""
URL configuration for backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import path, include

from app import views as app_views

urlpatterns = [
    # Custom admin panel (brokuFalih UI)
    path('admin/login/', app_views.admin_login_view, name='html-admin-login'),
    path('admin/logout/', app_views.admin_logout_view, name='html-admin-logout'),
    path('admin/', app_views.admin_panel, name='html-admin-panel'),

    # Keep Django's built-in admin under a different path
    path('dj-admin/', admin.site.urls),

    # API endpoints (including admin JSON APIs)
    path('api/', include('app.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
