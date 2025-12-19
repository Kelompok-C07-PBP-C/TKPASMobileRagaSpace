"""Admin URLs for venue management."""
from django.urls import path

from add_on.views import AdminVenueAddOnManageView

from .views import (
    AdminBookingApprovalView,
    AdminDashboardView,
    AdminVenueApiView,
    AdminVenueCreateView,
    AdminVenueDeleteView,
    AdminVenueDetailApiView,
    AdminVenueListView,
    AdminVenueUpdateView,
)

urlpatterns = [
    path("", AdminDashboardView.as_view(), name="admin-dashboard"),
    path("bookings/", AdminBookingApprovalView.as_view(), name="admin-bookings"),
    path("venues/", AdminVenueListView.as_view(), name="admin-venues"),
    path("venues/add/", AdminVenueCreateView.as_view(), name="admin-venue-create"),
    path("venues/<int:pk>/edit/", AdminVenueUpdateView.as_view(), name="admin-venue-edit"),
    path("venues/<int:pk>/delete/", AdminVenueDeleteView.as_view(), name="admin-venue-delete"),
    path("venues/<int:venue_pk>/addons/", AdminVenueAddOnManageView.as_view(), name="admin-venue-addons"),
    path("venues/api/", AdminVenueApiView.as_view(), name="admin-venues-api"),
    path("venues/api/<int:pk>/", AdminVenueDetailApiView.as_view(), name="admin-venue-detail-api"),
]
