from django.urls import path
from . import views

app_name = "app"

urlpatterns = [
    path('register/', views.register_view, name='api-register'),
    path('login/', views.login_view, name='api-login'),
    path('logout/', views.logout_view, name='api-logout'),
    path('me/', views.me_view, name='api-me'),
    path('venues/', views.venues_list_view, name='api-venues'),
    path('account/', views.account_detail_view, name='api-account-detail'),
    path('account/update/', views.account_update_view, name='api-account-update'),
    path('account/password/', views.account_password_view, name='api-account-password'),
    path('venues/top/', views.top_venues_view, name='api-top-venues'),
    path('bookings/', views.booking_create_view, name='api-booking-create'),
    path('bookings/<int:booking_id>/', views.booking_detail_view, name='api-booking-detail'),
    path('admin-panel/', views.admin_panel, name='admin-panel'),
    path('admin-panel/logout/', views.admin_logout_view, name='admin-logout'),
    path('admin/venues/', views.admin_venues_list_api, name='admin-venues-list'),
    path('admin/venues/create/', views.admin_venues_create_api, name='admin-venues-create'),
    path('admin/venues/<int:venue_id>/update/', views.admin_venues_update_api, name='admin-venues-update'),
    path('admin/venues/<int:venue_id>/delete/', views.admin_venues_delete_api, name='admin-venues-delete'),
    path('admin/bookings/', views.admin_bookings_list_api, name='admin-bookings-list'),
    path('admin/bookings/create/', views.admin_bookings_create_api, name='admin-bookings-create'),
    path('admin/bookings/<int:booking_id>/update/', views.admin_bookings_update_api, name='admin-bookings-update'),
    path('admin/bookings/<int:booking_id>/delete/', views.admin_bookings_delete_api, name='admin-bookings-delete'),
    path('admin/users/search/', views.admin_users_search_api, name='admin-users-search'),
]
