from __future__ import annotations

from datetime import datetime, timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase

from add_on.models import AddOn
from manajemen_lapangan.models import Category, Venue

from ..models import Booking, Payment


class BookingModelTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.user = user_model.objects.create_user(username="member", password="pass")
        category = Category.objects.get(slug="padel")
        self.venue = Venue.objects.create(
            category=category,
            name="Padel Pro",
            slug="padel-pro",
            description="Premium padel court",
            location="Jakarta",
            city="Jakarta",
            address="Jl. Padel",
            price_per_hour=Decimal("180000.00"),
            capacity=4,
            facilities="Locker",
            image_url="https://example.com/padel.jpg",
        )
        self.start = datetime(2024, 1, 1, 9, 0)
        self.end = self.start + timedelta(hours=3)

    def _create_booking(self) -> Booking:
        booking = Booking.objects.create(
            user=self.user,
            venue=self.venue,
            start_datetime=self.start,
            end_datetime=self.end,
        )
        addon = AddOn.objects.create(venue=self.venue, name="Racket", description="", price=Decimal("25000.00"))
        booking.addons.add(addon)
        return booking

    def test_duration_and_cost_properties(self):
        booking = self._create_booking()
        self.assertEqual(booking.duration_hours, 3)
        self.assertEqual(booking.base_cost, Decimal("540000.00"))
        self.assertEqual(booking.addons_total, Decimal("25000.00"))
        self.assertEqual(booking.total_cost, Decimal("565000.00"))

    def test_ensure_payment_creates_or_updates_payment(self):
        booking = self._create_booking()
        payment = booking.ensure_payment()
        self.assertEqual(payment.total_amount, booking.total_cost)
        # Changing add-ons should update the payment total when ensure_payment is called again
        additional = AddOn.objects.create(venue=self.venue, name="Balls", description="", price=Decimal("15000.00"))
        booking.addons.add(additional)
        updated_payment = booking.ensure_payment()
        self.assertEqual(updated_payment.pk, payment.pk)
        self.assertEqual(updated_payment.total_amount, booking.total_cost)

    def test_approve_sets_status_and_payment(self):
        booking = self._create_booking()
        admin = get_user_model().objects.create_user(username="admin", password="pass", is_staff=True)
        booking.approve(admin)
        booking.refresh_from_db()
        self.assertEqual(booking.status, Booking.STATUS_ACTIVE)
        self.assertIsNotNone(booking.approved_at)
        self.assertEqual(booking.approved_by, admin)
        payment = booking.payment
        self.assertEqual(payment.status, "waiting")

    def test_cancel_resets_approval_fields(self):
        booking = self._create_booking()
        booking.approve(self.user)
        booking.cancel()
        booking.refresh_from_db()
        self.assertEqual(booking.status, Booking.STATUS_CANCELLED)
        self.assertIsNone(booking.approved_at)
        self.assertIsNone(booking.approved_by)


class PaymentModelTests(TestCase):
    def test_string_representation(self):
        user_model = get_user_model()
        user = user_model.objects.create_user(username="payer", password="pass")
        category = Category.objects.get(slug="futsal")
        venue = Venue.objects.create(
            category=category,
            name="Futsal Arena",
            slug="futsal-arena-test",
            description="Indoor futsal arena",
            location="Bandung",
            city="Bandung",
            address="Jl. Futsal",
            price_per_hour=Decimal("120000.00"),
            capacity=10,
            facilities="Cafe",
            image_url="https://example.com/futsal.jpg",
        )
        booking = Booking.objects.create(
            user=user,
            venue=venue,
            start_datetime=datetime(2024, 1, 1, 10, 0),
            end_datetime=datetime(2024, 1, 1, 12, 0),
        )
        payment = booking.ensure_payment()
        payment.reference_code = "ABC123"
        payment.save(update_fields=["reference_code"])
        self.assertIn("ABC123", str(payment))
