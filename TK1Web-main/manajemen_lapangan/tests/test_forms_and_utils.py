from __future__ import annotations

from datetime import datetime, timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.forms.utils import ErrorList
from django.test import RequestFactory, TestCase
from django.urls import reverse

from add_on.formsets import build_addon_formset
from add_on.models import AddOn
from rent.models import Booking, Payment

from ..forms import BookingDecisionForm, VenueForm
from ..models import Category, Venue
from ..views import (
    build_addon_formset_errors,
    build_form_errors,
    dict_to_querydict,
    has_addon_payload,
    is_ajax,
    serialize_venue,
)


class VenueFormTests(TestCase):
    def setUp(self):
        self.category = Category.objects.get(slug="badminton")

    def _base_payload(self):
        return {
            "category": self.category,
            "name": "Galaxy Hall",
            "slug": "",
            "description": "Indoor hall",
            "location": "Jakarta",
            "city": "Jakarta",
            "address": "Jl. Merdeka",
            "price_per_hour": Decimal("200000.00"),
            "capacity": 8,
            "facilities": "AC, Locker",
            "image_url": "https://example.com/hall.jpg",
            "available_start_time": datetime.now().time(),
            "available_end_time": (datetime.now() + timedelta(hours=12)).time(),
        }

    def test_clean_slug_populates_value_from_name(self):
        form = VenueForm(data={**self._base_payload(), "slug": ""})
        self.assertTrue(form.is_valid())
        venue = form.save()
        self.assertEqual(venue.slug, "galaxy-hall")

    def test_duplicate_slug_raises_validation_error(self):
        Venue.objects.create(
            category=self.category,
            name="Existing Hall",
            slug="galaxy-hall",
            description="Existing",
            location="City",
            city="City",
            address="Address",
            price_per_hour="100000.00",
            capacity=10,
            facilities="WiFi",
            image_url="https://example.com/existing.jpg",
        )
        form = VenueForm(data={**self._base_payload(), "slug": "galaxy-hall"})
        self.assertFalse(form.is_valid())
        self.assertIn("slug", form.errors)

    def test_category_queryset_respects_configured_order(self):
        Category.objects.get(slug="padel")
        Category.objects.get(slug="tennis")
        form = VenueForm()
        queryset = list(form.fields["category"].queryset)
        self.assertEqual([category.slug for category in queryset[:2]], ["padel", "tennis"])


class BookingDecisionFormTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.admin = user_model.objects.create_user(username="admin", password="pass", is_staff=True)
        category = Category.objects.get(slug="futsal")
        self.venue = Venue.objects.create(
            category=category,
            name="Stadium",
            slug="stadium",
            description="Large stadium",
            location="Jakarta",
            city="Jakarta",
            address="Jl. Sudirman",
            price_per_hour=Decimal("150000.00"),
            capacity=12,
            facilities="Cafe",
            image_url="https://example.com/stadium.jpg",
        )

    def _create_booking(self) -> Booking:
        user_model = get_user_model()
        user = user_model.objects.create_user(username="member", password="pass")
        start = datetime(2024, 1, 1, 10, 0)
        end = start + timedelta(hours=2)
        return Booking.objects.create(user=user, venue=self.venue, start_datetime=start, end_datetime=end)

    def test_apply_decision_approve_creates_waiting_payment(self):
        booking = self._create_booking()
        form = BookingDecisionForm(data={"booking_id": booking.pk, "decision": BookingDecisionForm.APPROVE})
        self.assertTrue(form.is_valid())
        updated, decision = form.apply_decision(self.admin)
        self.assertEqual(decision, BookingDecisionForm.APPROVE)
        updated.refresh_from_db()
        self.assertEqual(updated.status, Booking.STATUS_ACTIVE)
        payment = Payment.objects.get(booking=updated)
        self.assertEqual(payment.status, "waiting")
        self.assertEqual(payment.total_amount, updated.total_cost)

    def test_apply_decision_cancel_updates_payment_status(self):
        booking = self._create_booking()
        payment = booking.ensure_payment()
        payment.status = "confirmed"
        payment.save(update_fields=["status"])
        form = BookingDecisionForm(data={"booking_id": booking.pk, "decision": BookingDecisionForm.CANCEL})
        self.assertTrue(form.is_valid())
        updated, decision = form.apply_decision(self.admin)
        self.assertEqual(decision, BookingDecisionForm.CANCEL)
        updated.refresh_from_db()
        self.assertEqual(updated.status, Booking.STATUS_CANCELLED)
        payment.refresh_from_db()
        self.assertEqual(payment.status, "waiting")

    def test_apply_decision_requires_valid_form(self):
        form = BookingDecisionForm(data={})
        self.assertFalse(form.is_valid())
        with self.assertRaises(ValueError):
            form.apply_decision(self.admin)


class ViewUtilityTests(TestCase):
    def setUp(self):
        category = Category.objects.get(slug="basket")
        self.venue = Venue.objects.create(
            category=category,
            name="Hoops Center",
            slug="hoops-center",
            description="Basketball court",
            location="Bandung",
            city="Bandung",
            address="Jl. Basket",
            price_per_hour=Decimal("175000.00"),
            capacity=10,
            facilities="Scoreboard",
            image_url="https://example.com/hoops.jpg",
        )

    def test_build_form_errors_returns_serializable_structure(self):
        form = VenueForm(data={})
        self.assertFalse(form.is_valid())
        errors = build_form_errors(form)
        self.assertIn("name", errors)
        self.assertIsInstance(errors["name"], list)

    def test_build_addon_formset_errors_includes_field_and_form_errors(self):
        formset = build_addon_formset(data={
            "addons-TOTAL_FORMS": "1",
            "addons-INITIAL_FORMS": "0",
            "addons-MIN_NUM_FORMS": "0",
            "addons-MAX_NUM_FORMS": "1000",
            "addons-0-name": "",
            "addons-0-description": "Missing",
            "addons-0-price": "",
        }, instance=self.venue)
        self.assertFalse(formset.is_valid())
        errors = build_addon_formset_errors(formset)
        self.assertIn("addons-0-name", errors)
        self.assertIn("addons-0-price", errors)

    def test_dict_to_querydict_handles_lists_and_nulls(self):
        querydict = dict_to_querydict({"addons-0-name": "Ball", "addons-0-price": None, "addons-0-tags": [1, None]})
        self.assertEqual(querydict.get("addons-0-name"), "Ball")
        self.assertEqual(querydict.get("addons-0-price"), "")
        self.assertEqual(querydict.getlist("addons-0-tags"), ["1", ""])

    def test_has_addon_payload_detects_addon_keys(self):
        self.assertTrue(has_addon_payload({"addons-0-name": "Shoes"}))
        self.assertFalse(has_addon_payload({"name": "Venue"}))

    def test_is_ajax_checks_header(self):
        factory = RequestFactory()
        request = factory.get("/", HTTP_X_REQUESTED_WITH="XMLHttpRequest")
        self.assertTrue(is_ajax(request))
        request = factory.get("/")
        self.assertFalse(is_ajax(request))

    def test_serialize_venue_returns_expected_structure(self):
        AddOn.objects.create(venue=self.venue, name="Water", description="", price="5000.00")
        payload = serialize_venue(self.venue)
        self.assertEqual(payload["id"], self.venue.pk)
        self.assertEqual(payload["category"]["id"], self.venue.category_id)
        self.assertEqual(payload["addons"][0]["name"], "Water")
        self.assertEqual(payload["detail_url"], reverse("venue-detail", kwargs={"slug": self.venue.slug}))
        self.assertEqual(payload["edit_url"], reverse("admin-venue-edit", kwargs={"pk": self.venue.pk}))
        self.assertEqual(payload["delete_url"], reverse("admin-venue-delete", kwargs={"pk": self.venue.pk}))

    def test_build_addon_formset_errors_with_non_form_errors(self):
        formset = build_addon_formset(
            data={
                "addons-TOTAL_FORMS": "1",
                "addons-INITIAL_FORMS": "0",
                "addons-MIN_NUM_FORMS": "0",
                "addons-MAX_NUM_FORMS": "1000",
                "addons-0-name": "Ball",
                "addons-0-description": "Missing",
                "addons-0-price": "10000",
            },
            instance=self.venue,
        )
        # Force a non-form error by marking the formset as not clean
        formset._non_form_errors = ErrorList(["General error"])
        errors = build_addon_formset_errors(formset)
        self.assertIn("addons", errors)
        self.assertEqual(errors["addons"], ["General error"])
