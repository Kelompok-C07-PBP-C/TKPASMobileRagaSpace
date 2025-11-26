"""Views handling booking and payment flows."""
from __future__ import annotations

from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin
from django.http import HttpRequest, HttpResponse, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.views import View
from django.views.generic import ListView
import json
from typing import Any, Dict

from .forms import PaymentForm
from .models import Booking, Payment


class BookingCancelView(LoginRequiredMixin, View):
    """Allow a user to cancel their own booking."""

    def post(self, request: HttpRequest, pk: int) -> HttpResponse:
        booking = get_object_or_404(Booking.objects.select_related("payment"), pk=pk, user=request.user)
        if booking.status in {Booking.STATUS_COMPLETED, Booking.STATUS_CANCELLED}:
            messages.error(request, "This booking can no longer be cancelled.")
            return redirect("booked-places")
        booking.cancel()

        payment = None
        try:
            payment = booking.payment
        except Payment.DoesNotExist:
            # Ensure a payment record exists so the user can book again later.
            payment = booking.ensure_payment()

        if payment is not None:
            payment.status = "waiting"
            payment.save(update_fields=["status", "updated_at"])
        messages.success(request, "Booking cancelled successfully.")
        return redirect("booked-places")


class BookingPaymentView(LoginRequiredMixin, View):
    template_name = "rent/booking_payment.html"

    def _get_booking(self, request: HttpRequest, pk: int) -> Booking:
        booking = get_object_or_404(
            Booking.objects.select_related("venue", "payment").prefetch_related("addons"), pk=pk, user=request.user
        )
        booking.ensure_payment()
        return booking

    def get(self, request: HttpRequest, pk: int) -> HttpResponse:
        booking = self._get_booking(request, pk)
        if booking.status == Booking.STATUS_PENDING:
            messages.error(request, "This booking still requires admin approval before payment.")
            return redirect("wishlist")
        if booking.status in {Booking.STATUS_CANCELLED, Booking.STATUS_COMPLETED}:
            messages.error(request, "This booking can no longer be paid.")
            return redirect("booked-places")
        form = PaymentForm(instance=booking.payment)
        return render(request, self.template_name, {"booking": booking, "form": form})

    def post(self, request: HttpRequest, pk: int) -> HttpResponse:
        booking = self._get_booking(request, pk)
        if booking.status == Booking.STATUS_PENDING:
            messages.error(request, "This booking still requires admin approval before payment.")
            return redirect("wishlist")
        if booking.status in {Booking.STATUS_CANCELLED, Booking.STATUS_COMPLETED}:
            messages.error(request, "This booking can no longer be paid.")
            return redirect("booked-places")
        form = PaymentForm(request.POST, instance=booking.payment)
        if form.is_valid():
            payment: Payment = form.save(commit=False)
            payment.status = "confirmed"
            payment.save()
            booking.status = Booking.STATUS_CONFIRMED
            booking.save(update_fields=["status", "updated_at"])
            messages.success(request, "Payment completed! Your booking is confirmed.")
            return redirect("booked-places")
        messages.error(request, "Could not process the payment. Please try again.")
        return render(request, self.template_name, {"booking": booking, "form": form})


class BookedPlacesView(LoginRequiredMixin, ListView):
    """Display all bookings made by the current user."""

    template_name = "rent/booked_places.html"
    context_object_name = "bookings"

    def get_queryset(self):
        return (
            Booking.objects.filter(
                user=self.request.user,
                status__in=[
                    Booking.STATUS_ACTIVE,
                    Booking.STATUS_CONFIRMED,
                    Booking.STATUS_COMPLETED,
                ],
            )
            .select_related("venue")
            .prefetch_related("addons")
            .order_by("-start_datetime")
        )


def _serialize_booking(booking: Booking) -> Dict[str, Any]:
    """Return a JSON-serializable representation of a booking and its payment."""

    def _dt(v):
        return v.isoformat() if v is not None else None

    venue = booking.venue
    venue_name = getattr(venue, "name", str(venue))

    payment = None
    try:
        p = booking.payment
        payment = {
            "id": p.id,
            "method": p.method,
            "status": p.status,
            "total_amount": str(p.total_amount),
            "deposit_amount": str(p.deposit_amount),
            "reference_code": p.reference_code,
            "created_at": _dt(p.created_at),
            "updated_at": _dt(p.updated_at),
        }
    except Payment.DoesNotExist:
        payment = None

    return {
        "id": booking.id,
        "venue": {"id": getattr(venue, "id", None), "name": venue_name},
        "start_datetime": _dt(booking.start_datetime),
        "end_datetime": _dt(booking.end_datetime),
        "status": booking.status,
        "total_cost": str(booking.total_cost),
        "addons_total": str(booking.addons_total),
        "payment": payment,
    }


class BookedPlacesJSONView(LoginRequiredMixin, View):
    """Return the current user's active/confirmed/completed bookings as JSON."""

    def get(self, request: HttpRequest) -> JsonResponse:
        qs = (
            Booking.objects.filter(
                user=request.user,
                status__in=[
                    Booking.STATUS_ACTIVE,
                    Booking.STATUS_CONFIRMED,
                    Booking.STATUS_COMPLETED,
                ],
            )
            .select_related("venue")
            .prefetch_related("addons")
            .order_by("-start_datetime")
        )
        data = [_serialize_booking(b) for b in qs]
        return JsonResponse({"bookings": data})


class BookingPaymentJSONView(LoginRequiredMixin, View):
    """Provide JSON access to a booking's payment and allow confirming via POST.

    POST will attempt to mark the payment as confirmed and the booking as confirmed.
    Expects no body or a JSON body; responds with updated booking/payment data.
    """

    def _get_booking(self, request: HttpRequest, pk: int) -> Booking:
        booking = get_object_or_404(
            Booking.objects.select_related("venue", "payment").prefetch_related("addons"),
            pk=pk,
            user=request.user,
        )
        booking.ensure_payment()
        return booking

    def get(self, request: HttpRequest, pk: int) -> JsonResponse:
        booking = self._get_booking(request, pk)
        if booking.status == Booking.STATUS_PENDING:
            return JsonResponse({"error": "This booking still requires admin approval before payment."}, status=400)
        if booking.status in {Booking.STATUS_CANCELLED, Booking.STATUS_COMPLETED}:
            return JsonResponse({"error": "This booking can no longer be paid."}, status=400)
        return JsonResponse({"booking": _serialize_booking(booking)})

    def post(self, request: HttpRequest, pk: int) -> JsonResponse:
        booking = self._get_booking(request, pk)
        if booking.status == Booking.STATUS_PENDING:
            return JsonResponse({"error": "This booking still requires admin approval before payment."}, status=400)
        if booking.status in {Booking.STATUS_CANCELLED, Booking.STATUS_COMPLETED}:
            return JsonResponse({"error": "This booking can no longer be paid."}, status=400)

        # Accept JSON or form data; for now we don't require payment fields for the
        # simple confirm action — production code should validate method/amount.
        try:
            # Attempt to parse JSON body if present
            payload = json.loads(request.body.decode()) if request.body else {}
        except Exception:
            payload = {}

        # Confirm the payment and booking
        try:
            payment = booking.payment
        except Payment.DoesNotExist:
            payment = booking.ensure_payment()

        payment.status = "confirmed"
        payment.save()
        booking.status = Booking.STATUS_CONFIRMED
        booking.save(update_fields=["status", "updated_at"]) 
        return JsonResponse({"booking": _serialize_booking(booking)})
