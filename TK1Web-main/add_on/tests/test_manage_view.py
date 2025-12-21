"""Tests covering the add-on management views."""
from __future__ import annotations

from datetime import time
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from add_on.models import AddOn
from manajemen_lapangan.models import Category, Venue


class AdminAddOnViewTests(TestCase):
    """Ensure staff can manage venue add-ons through the dedicated view."""

    def setUp(self) -> None:
        user_model = get_user_model()
        self.superuser = user_model.objects.create_user(
            username="superadmin",
            password="Admin123!",
            is_staff=True,
            is_superuser=True,
        )
        self.staff_user = user_model.objects.create_user(
            username="staffer",
            password="Staff123!",
            is_staff=True,
        )
        self.regular_user = user_model.objects.create_user(
            username="regular",
            password="User123!",
        )
        self.category = Category.objects.create(name="Sports Addons", slug="sports-addons")
        self.venue = Venue.objects.create(
            category=self.category,
            name="Aurora Arena",
            slug="aurora-arena-addons",
            description="Indoor arena",
            location="Central City",
            city="Metropolis",
            address="123 Main Street",
            price_per_hour="100000.00",
            capacity=120,
            facilities="wifi",
            image_url="https://example.com/arena.jpg",
            available_start_time=time(8, 0),
            available_end_time=time(22, 0),
        )

    def test_admin_can_create_and_update_addons(self) -> None:
        addon = AddOn.objects.create(
            venue=self.venue,
            name="Projector",
            description="HD projector",
            price="25000.00",
        )

        self.client.force_login(self.superuser)
        response = self.client.post(
            reverse("admin-venue-addons", args=[self.venue.pk]),
            {
                "addons-TOTAL_FORMS": "2",
                "addons-INITIAL_FORMS": "1",
                "addons-MIN_NUM_FORMS": "0",
                "addons-MAX_NUM_FORMS": "1000",
                "addons-0-id": str(addon.pk),
                "addons-0-venue": str(self.venue.pk),
                "addons-0-name": "Projector HD",
                "addons-0-description": "Updated HD projector",
                "addons-0-price": "35000.00",
                "addons-1-id": "",
                "addons-1-venue": str(self.venue.pk),
                "addons-1-name": "Water Bottles",
                "addons-1-description": "Fresh water for teams",
                "addons-1-price": "5000.00",
            },
            follow=False,
        )

        self.assertRedirects(
            response,
            reverse("admin-venue-addons", args=[self.venue.pk]),
        )
        addon.refresh_from_db()
        self.assertEqual(addon.name, "Projector HD")
        self.assertEqual(addon.price, Decimal("35000.00"))
        self.assertTrue(
            AddOn.objects.filter(venue=self.venue, name="Water Bottles").exists()
        )
        self.assertEqual(AddOn.objects.filter(venue=self.venue).count(), 2)

    def test_staff_without_permissions_cannot_modify_addons(self) -> None:
        self.client.force_login(self.staff_user)
        response = self.client.post(
            reverse("admin-venue-addons", args=[self.venue.pk]),
            {
                "addons-TOTAL_FORMS": "1",
                "addons-INITIAL_FORMS": "0",
                "addons-MIN_NUM_FORMS": "0",
                "addons-MAX_NUM_FORMS": "1000",
                "addons-0-id": "",
                "addons-0-venue": str(self.venue.pk),
                "addons-0-name": "Coach",
                "addons-0-description": "Personal coach",
                "addons-0-price": "75000.00",
            },
        )

        self.assertRedirects(response, reverse("admin-venues"))
        self.assertFalse(AddOn.objects.filter(venue=self.venue).exists())

    def test_non_staff_user_is_redirected(self) -> None:
        self.client.force_login(self.regular_user)
        response = self.client.get(reverse("admin-venue-addons", args=[self.venue.pk]))

        self.assertRedirects(response, reverse("home"))
