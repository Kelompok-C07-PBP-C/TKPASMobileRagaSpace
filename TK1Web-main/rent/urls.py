"""Routes for booking workflows."""
from django.urls import path

from .views import (
    BookingCancelView,
    BookingPaymentView,
    BookedPlacesView,
    BookedPlacesJSONView,
    BookingPaymentJSONView,
)

urlpatterns = [
    path("bookings/", BookedPlacesView.as_view(), name="booked-places"),
    path("bookings/<int:pk>/cancel/", BookingCancelView.as_view(), name="booking-cancel"),
    path("bookings/<int:pk>/payment/", BookingPaymentView.as_view(), name="payment"),
    path("bookings/json/", BookedPlacesJSONView.as_view(), name="booked-places-json"),
    path("bookings/<int:pk>/payment/json/", BookingPaymentJSONView.as_view(), name="booking-payment-json"),
]
