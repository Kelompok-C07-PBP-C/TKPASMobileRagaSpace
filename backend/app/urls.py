from django.urls import path
from . import views

urlpatterns = [
    path('register/', views.register_view, name='api-register'),
    path('login/', views.login_view, name='api-login'),
    path('logout/', views.logout_view, name='api-logout'),
    path('me/', views.me_view, name='api-me'),
    path('venues/top/', views.top_venues_view, name='api-top-venues'),
]
