from django.contrib import admin
from django.urls import path, include
from main.views import *
from django.urls import path
from .views import VenueListCreateView

app_name = 'main'

urlpatterns = [
    path('login/', show_login, name="login"),
    path('register/', show_register, name="register"),
    path('', show_landing, name="landing"),
    path('catalog/', show_catalog, name="catalog"),
    path('logout/', logged_out, name="logout"),
    path('venues/', VenueListCreateView.as_view(), name='venue-list'),
]



