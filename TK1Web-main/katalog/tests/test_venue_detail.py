"""Tests for the venue detail view and add-on presentation."""
from __future__ import annotations

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from add_on.models import AddOn
from manajemen_lapangan.models import Category, Venue


class VenueDetailViewTests(TestCase):
    def setUp(self) -> None:
        self.user = get_user_model().objects.create_user(
            username="viewer",
            email="viewer@example.com",
            password="Secret123",
        )
        self.category = Category.objects.get(slug="futsal")
        self.venue = Venue.objects.create(
            category=self.category,
            name="Elite Futsal Hall",
            description="Indoor futsal venue with premium flooring.",
            location="City Center",
            city="Depok",
            address="Jl. Merdeka 10",
            price_per_hour="120000.00",
            capacity=50,
            facilities="Lighting, Shower",
            image_url="https://example.com/futsal.jpg",
        )
        self.photographer = AddOn.objects.create(
            venue=self.venue,
            name="Photographer",
            description="Capture your match moments.",
            price="250000.00",
        )
        self.ball = AddOn.objects.create(
            venue=self.venue,
            name="Bola futsal",
            description="Official size futsal ball.",
            price="50000.00",
        )

    def test_addons_are_exposed_in_context(self) -> None:
        self.client.force_login(self.user)
        response = self.client.get(reverse("venue-detail", kwargs={"slug": self.venue.slug}))

        self.assertEqual(response.status_code, 200)
        self.assertIn("addon_lookup", response.context)
        addon_lookup = response.context["addon_lookup"]
        self.assertIn(str(self.photographer.pk), addon_lookup)
        photographer_data = addon_lookup[str(self.photographer.pk)]
        self.assertEqual(photographer_data["name"], "Photographer")
        self.assertIn("price_display", photographer_data)
        content = response.content.decode()
        self.assertIn("Enhance your booking", content)
        self.assertIn("Photographer", content)
        self.assertIn("Rp", content)
