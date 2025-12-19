from __future__ import annotations

from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse

from manajemen_lapangan.models import Category, Venue


middleware_without_whitenoise = [
    middleware
    for middleware in settings.MIDDLEWARE
    if middleware != "whitenoise.middleware.WhiteNoiseMiddleware"
]


@override_settings(MIDDLEWARE=middleware_without_whitenoise)
class CatalogFilterApiTests(TestCase):
    def setUp(self) -> None:
        self.user = get_user_model().objects.create_user(
            username="catalog-user",
            email="catalog@example.com",
            password="password123",
        )
        slug_suffix = getattr(self, "_testMethodName", "case").lower()
        self.category_futsal = Category.objects.create(
            name=f"Futsal {slug_suffix}", slug=f"futsal-{slug_suffix}"
        )
        self.category_basket = Category.objects.create(
            name=f"Basketball {slug_suffix}", slug=f"basketball-{slug_suffix}"
        )
        self.venue_primary = Venue.objects.create(
            category=self.category_futsal,
            name="Downtown Arena",
            description="Indoor futsal venue with premium facilities.",
            location="Central City",
            city="Jakarta",
            address="Jl. Sudirman No. 1",
            price_per_hour="250000",
            capacity=10,
            facilities="Locker,Shower",
            image_url="https://example.com/arena.jpg",
        )
        self.venue_secondary = Venue.objects.create(
            category=self.category_basket,
            name="Uptown Court",
            description="Basketball court with stadium lighting.",
            location="North City",
            city="Bandung",
            address="Jl. Merdeka No. 5",
            price_per_hour="400000",
            capacity=12,
            facilities="Locker,Shower",
            image_url="https://example.com/court.jpg",
        )

    def _login(self) -> None:
        self.client.login(username="catalog-user", password="password123")

    def test_requires_authentication(self) -> None:
        response = self.client.get(reverse("catalog-filter"))
        self.assertEqual(response.status_code, 302)
        self.assertIn(reverse("authentication:login"), response["Location"])

    def test_returns_filtered_results(self) -> None:
        self._login()
        response = self.client.get(
            reverse("catalog-filter"),
            {"city": "Jakarta"},
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        self.assertEqual(payload["count"], 1)
        self.assertEqual(len(payload["venues"]), 1)
        venue = payload["venues"][0]
        self.assertEqual(venue["id"], self.venue_primary.id)
        self.assertEqual(venue["city"], "Jakarta")
        self.assertFalse(venue["wishlisted"])

    def test_invalid_filter_returns_error_payload(self) -> None:
        self._login()
        response = self.client.get(
            reverse("catalog-filter"),
            {"max_price": "invalid"},
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )
        self.assertEqual(response.status_code, 400)
        payload = response.json()
        self.assertFalse(payload["success"])
        self.assertIn("max_price", payload["errors"])
        self.assertGreater(len(payload["errors"]["max_price"]), 0)
        self.assertEqual(payload["message"], "Invalid filter values submitted.")
