"""Tests for admin venue management actions."""
from __future__ import annotations

from datetime import time

from django.contrib.auth import get_user_model
import json

from django.test import TestCase
from django.urls import reverse

from django.utils.text import slugify

from add_on.models import AddOn
from manajemen_lapangan.models import Category, Venue


class AdminVenueManagementTests(TestCase):
    """Ensure admin-only venue CRUD operations behave correctly."""

    def setUp(self):
        user_model = get_user_model()
        self.admin = user_model.objects.create_user(
            username="admin",
            password="Admin123!",
            is_staff=True,
            is_superuser=True,
        )
        self.user = user_model.objects.create_user(username="user", password="User123!")
        self.category = Category.objects.get(slug="padel")

    def _valid_payload(self, name: str = "Sky Arena", slug: str | None = None) -> dict[str, str]:
        return {
            "category": str(self.category.pk),
            "name": name,
            "slug": slug or slugify(name),
            "description": "Spacious indoor arena.",
            "location": "Central City",
            "city": "Metropolis",
            "address": "123 Main Street",
            "price_per_hour": "150000.00",
            "capacity": "250",
            "facilities": "wifi, parking",
            "image_url": "https://example.com/arena.jpg",
            "available_start_time": "08:00",
            "available_end_time": "23:00",
        }

    def test_admin_can_create_venue_from_list_view(self):
        self.client.force_login(self.admin)
        response = self.client.post(reverse("admin-venues"), self._valid_payload())

        errors = None
        if hasattr(response, "context") and response.context:
            context = response.context
            if isinstance(context, list):
                context = context[0]
            errors = context.get("venue_form").errors if context.get("venue_form") else None

        self.assertEqual(response.status_code, 302, errors)
        self.assertRedirects(response, reverse("admin-venues"))
        self.assertTrue(Venue.objects.filter(name="Sky Arena").exists())

    def test_admin_can_create_venue_with_addons(self):
        self.client.force_login(self.admin)
        payload = self._valid_payload(name="Arena Addons")
        payload.update(
            {
                "addons-TOTAL_FORMS": "2",
                "addons-INITIAL_FORMS": "0",
                "addons-MIN_NUM_FORMS": "0",
                "addons-MAX_NUM_FORMS": "1000",
                "addons-0-name": "Photographer",
                "addons-0-description": "Professional match documentation",
                "addons-0-price": "250000.00",
                "addons-1-name": "Bola futsal",
                "addons-1-description": "",  # optional description
                "addons-1-price": "50000.00",
            }
        )

        response = self.client.post(reverse("admin-venue-create"), payload)

        self.assertRedirects(response, reverse("admin-venues"))
        venue = Venue.objects.get(name="Arena Addons")
        addon_names = list(venue.addons.order_by("name").values_list("name", flat=True))
        self.assertIn("Photographer", addon_names)
        self.assertIn("Bola futsal", addon_names)
        self.assertEqual(AddOn.objects.filter(venue=venue).count(), 2)

    def test_non_admin_cannot_create_venue(self):
        self.client.force_login(self.user)
        response = self.client.post(reverse("admin-venues"), self._valid_payload(name="Fail Arena"))

        self.assertRedirects(response, reverse("home"))
        self.assertFalse(Venue.objects.filter(name="Fail Arena").exists())

    def test_admin_can_delete_venue(self):
        venue = Venue.objects.create(
            category=self.category,
            name="Sunset Field",
            slug="sunset-field",
            description="Outdoor field",
            location="West District",
            city="Metropolis",
            address="45 Sunset Boulevard",
            price_per_hour="120000.00",
            capacity=150,
            facilities="lighting",
            image_url="https://example.com/field.jpg",
            available_start_time=time(7, 0),
            available_end_time=time(21, 0),
        )

        self.client.force_login(self.admin)
        response = self.client.post(reverse("admin-venue-delete", args=[venue.pk]))

        self.assertRedirects(response, reverse("admin-venues"))
        self.assertFalse(Venue.objects.filter(pk=venue.pk).exists())

    def test_non_admin_cannot_delete_venue(self):
        venue = Venue.objects.create(
            category=self.category,
            name="Aurora Court",
            slug="aurora-court",
            description="Indoor court",
            location="East Park",
            city="Metropolis",
            address="67 Aurora Lane",
            price_per_hour="95000.00",
            capacity=80,
            facilities="scoreboard",
            image_url="https://example.com/court.jpg",
            available_start_time=time(9, 0),
            available_end_time=time(20, 0),
        )

        self.client.force_login(self.user)
        response = self.client.post(reverse("admin-venue-delete", args=[venue.pk]))

        self.assertRedirects(response, reverse("home"))
        self.assertTrue(Venue.objects.filter(pk=venue.pk).exists())

    def test_duplicate_slug_on_create_view_returns_error(self):
        Venue.objects.create(
            category=self.category,
            name="Existing Arena",
            slug="sky-arena",
            description="Existing venue",
            location="Central",
            city="Metropolis",
            address="1 Main Street",
            price_per_hour="150000.00",
            capacity=200,
            facilities="wifi",
            image_url="https://example.com/existing.jpg",
            available_start_time=time(8, 0),
            available_end_time=time(22, 0),
        )

        self.client.force_login(self.admin)
        payload = self._valid_payload(name="Sky Arena")
        payload.update(
            {
                "addons-TOTAL_FORMS": "0",
                "addons-INITIAL_FORMS": "0",
                "addons-MIN_NUM_FORMS": "0",
                "addons-MAX_NUM_FORMS": "1000",
            }
        )

        response = self.client.post(reverse("admin-venue-create"), payload)

        self.assertEqual(response.status_code, 200)
        self.assertIn("slug", response.context["form"].errors)
        self.assertIn(
            "Slug venue ini sudah digunakan.", response.context["form"].errors["slug"][0]
        )

    def test_ajax_list_endpoint_returns_json_payload(self):
        self.client.force_login(self.admin)

        response = self.client.get(
            reverse("admin-venues-api"),
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        self.assertIn("venues", payload)

    def test_ajax_create_endpoint_persists_venue(self):
        self.client.force_login(self.admin)
        payload = self._valid_payload(name="Galaxy Court")

        response = self.client.post(
            reverse("admin-venues-api"),
            data=json.dumps(payload),
            content_type="application/json",
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )

        self.assertEqual(response.status_code, 200, response.content)
        data = response.json()
        self.assertTrue(data["success"])
        self.assertTrue(Venue.objects.filter(name="Galaxy Court").exists())
        self.assertIn("addons", data["venue"])
        self.assertEqual(data["venue"]["addons"], [])

    def test_ajax_create_endpoint_can_create_addons(self):
        self.client.force_login(self.admin)
        payload = self._valid_payload(name="Galaxy Court Extras")
        payload.update(
            {
                "addons-TOTAL_FORMS": "2",
                "addons-INITIAL_FORMS": "0",
                "addons-MIN_NUM_FORMS": "0",
                "addons-MAX_NUM_FORMS": "1000",
                "addons-0-name": "Coach",
                "addons-0-description": "Personal trainer for the team",
                "addons-0-price": "75000.00",
                "addons-1-name": "Water Bottles",
                "addons-1-description": "Refreshing drinks",
                "addons-1-price": "15000.00",
            }
        )

        response = self.client.post(
            reverse("admin-venues-api"),
            data=json.dumps(payload),
            content_type="application/json",
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )

        self.assertEqual(response.status_code, 200, response.content)
        data = response.json()
        self.assertTrue(data["success"])
        venue = Venue.objects.get(name="Galaxy Court Extras")
        addon_names = set(venue.addons.values_list("name", flat=True))
        self.assertSetEqual(addon_names, {"Coach", "Water Bottles"})

    def test_ajax_update_endpoint_updates_fields(self):
        venue = Venue.objects.create(
            category=self.category,
            name="Aurora Field",
            slug="aurora-field",
            description="Outdoor field",
            location="North District",
            city="Metropolis",
            address="123 Aurora Lane",
            price_per_hour="85000.00",
            capacity=120,
            facilities="lighting",
            image_url="https://example.com/aurora.jpg",
            available_start_time=time(7, 0),
            available_end_time=time(21, 0),
        )

        self.client.force_login(self.admin)
        update_payload = self._valid_payload(name="Aurora Field Updated", slug="aurora-field")

        response = self.client.put(
            reverse("admin-venue-detail-api", args=[venue.pk]),
            data=json.dumps(update_payload),
            content_type="application/json",
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )

        self.assertEqual(response.status_code, 200, response.content)
        venue.refresh_from_db()
        self.assertEqual(venue.name, "Aurora Field Updated")

    def test_ajax_update_endpoint_can_manage_addons(self):
        venue = Venue.objects.create(
            category=self.category,
            name="Aurora Field",
            slug="aurora-field",
            description="Outdoor field",
            location="North District",
            city="Metropolis",
            address="123 Aurora Lane",
            price_per_hour="85000.00",
            capacity=120,
            facilities="lighting",
            image_url="https://example.com/aurora.jpg",
            available_start_time=time(7, 0),
            available_end_time=time(21, 0),
        )
        existing_addon = AddOn.objects.create(
            venue=venue,
            name="Projector",
            description="HD projector",
            price="50000.00",
        )

        self.client.force_login(self.admin)
        update_payload = self._valid_payload(name="Aurora Field", slug="aurora-field")
        update_payload.update(
            {
                "addons-TOTAL_FORMS": "2",
                "addons-INITIAL_FORMS": "1",
                "addons-MIN_NUM_FORMS": "0",
                "addons-MAX_NUM_FORMS": "1000",
                "addons-0-id": str(existing_addon.pk),
                "addons-0-venue": str(venue.pk),
                "addons-0-name": "Projector HD",
                "addons-0-description": "Updated HD projector",
                "addons-0-price": "65000.00",
                "addons-1-id": "",
                "addons-1-venue": str(venue.pk),
                "addons-1-name": "Scoreboard",
                "addons-1-description": "Digital scoreboard",
                "addons-1-price": "120000.00",
            }
        )

        response = self.client.put(
            reverse("admin-venue-detail-api", args=[venue.pk]),
            data=json.dumps(update_payload),
            content_type="application/json",
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )

        self.assertEqual(response.status_code, 200, response.content)
        venue.refresh_from_db()
        addon_names = set(venue.addons.values_list("name", flat=True))
        self.assertSetEqual(addon_names, {"Projector HD", "Scoreboard"})

    def test_ajax_delete_endpoint_removes_venue(self):
        venue = Venue.objects.create(
            category=self.category,
            name="Starlight Arena",
            slug="starlight-arena",
            description="Indoor arena",
            location="South District",
            city="Metropolis",
            address="1 Starlight Street",
            price_per_hour="99000.00",
            capacity=90,
            facilities="locker room",
            image_url="https://example.com/starlight.jpg",
            available_start_time=time(8, 0),
            available_end_time=time(22, 0),
        )

        self.client.force_login(self.admin)

        response = self.client.delete(
            reverse("admin-venue-detail-api", args=[venue.pk]),
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )

        self.assertEqual(response.status_code, 200, response.content)
        self.assertFalse(Venue.objects.filter(pk=venue.pk).exists())
