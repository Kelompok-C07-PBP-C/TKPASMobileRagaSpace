"""URL routes for authentication flows and shared pages."""
from django.urls import path

from .views import (
    AdminLandingView,
    AuthLoginView,
    AuthLogoutView,
    RegisterView,
    UserLandingView,
)

app_name = "authentication"

urlpatterns = [
    path("auth/dashboard/tenant/", UserLandingView.as_view(), name="tenant-dashboard"),
    path("auth/dashboard/owner/", AdminLandingView.as_view(), name="owner-dashboard"),
    path("auth/login/", AuthLoginView.as_view(), name="login"),
    path("auth/logout/", AuthLogoutView.as_view(), name="logout"),
    path("auth/register/", RegisterView.as_view(), name="register"),
]
