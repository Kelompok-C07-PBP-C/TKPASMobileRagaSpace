from __future__ import annotations
from django.test import TestCase
from datetime import time
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from manajemen_lapangan.models import Category, Venue
from interaksi.models import Wishlist, Review


class WishlistViewTests(TestCase):
    """Ensure wishlist views and model logic work properly."""

    def setUp(self) -> None:
        user_model = get_user_model()
        self.user = user_model.objects.create_user(
            username="tester",
            password="Test123!",
        )
        self.category = Category.objects.get(slug="futsal")
        self.venue = Venue.objects.create(
            category=self.category,
            name="Raga Space",
            slug="raga-space",
            description="Best indoor futsal field",
            location="Jakarta Selatan",
            city="Jakarta",
            address="Jl. Sudirman No.1",
            price_per_hour=Decimal("150000.00"),
            capacity=10,
            facilities="wifi, parking",
            image_url="https://example.com/venue.jpg",
            available_start_time=time(8, 0),
            available_end_time=time(22, 0),
        )

    def test_user_can_add_venue_to_wishlist(self) -> None:
        """User can add a venue to wishlist."""
        self.client.force_login(self.user)
        response = self.client.post(
            reverse("wishlist-toggle", args=[self.venue.pk]),
            follow=True,
        )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(
            Wishlist.objects.filter(user=self.user, venue=self.venue).exists()
        )

    def test_user_can_remove_venue_from_wishlist(self) -> None:
        """User can remove a venue from wishlist."""
        Wishlist.objects.create(user=self.user, venue=self.venue)
        self.client.force_login(self.user)
        response = self.client.post(
            reverse("wishlist-toggle", args=[self.venue.pk]),
            follow=True,
        )

        self.assertEqual(response.status_code, 200)
        self.assertFalse(
            Wishlist.objects.filter(user=self.user, venue=self.venue).exists()
        )

    def test_wishlist_requires_login(self) -> None:
        """Anonymous user cannot access wishlist page."""
        response = self.client.get(reverse("wishlist"))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login", response.url)

    def test_wishlist_page_loads_for_logged_in_user(self) -> None:
        """Logged in user can view wishlist page."""
        self.client.force_login(self.user)
        Wishlist.objects.create(user=self.user, venue=self.venue)
        response = self.client.get(reverse("wishlist"))

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, "interaksi/wishlist.html")
        self.assertContains(response, "Raga Space")


class ReviewModelTests(TestCase):
    """Ensure Review model validations and constraints work."""

    def setUp(self) -> None:
        user_model = get_user_model()
        self.user = user_model.objects.create_user(
            username="reviewer",
            password="Review123!",
        )
        slug_suffix = getattr(self, "_testMethodName", "case").lower()
        self.category = Category.objects.create(
            name=f"Basket {slug_suffix}", slug=f"basket-{slug_suffix}"
        )
        self.venue = Venue.objects.create(
            category=self.category,
            name="Arena Basket",
            slug="arena-basket",
            description="Full court for basketball",
            location="Bandung",
            city="Bandung",
            address="Jl. Merdeka No.5",
            price_per_hour=Decimal("200000.00"),
            capacity=12,
            facilities="toilet, locker",
            image_url="https://example.com/basket.jpg",
            available_start_time=time(9, 0),
            available_end_time=time(21, 0),
        )

    def test_create_valid_review(self) -> None:
        """User can create a valid review."""
        review = Review.objects.create(
            user=self.user,
            venue=self.venue,
            rating=5,
            comment="Great place!",
        )
        self.assertEqual(str(review), f"{self.user} rated {self.venue}")
        self.assertEqual(review.rating, 5)
        self.assertEqual(review.comment, "Great place!")

    def test_duplicate_review_not_allowed(self) -> None:
        """A user cannot review the same venue twice."""
        Review.objects.create(user=self.user, venue=self.venue, rating=4, comment="Nice!")
        with self.assertRaises(Exception):
            Review.objects.create(user=self.user, venue=self.venue, rating=3, comment="Duplicate")

    def test_rating_must_be_between_1_and_5(self) -> None:
        """Invalid rating outside range should raise ValidationError."""
        from django.core.exceptions import ValidationError

        review = Review(
            user=self.user,
            venue=self.venue,
            rating=6,
            comment="Too high rating",
        )
        with self.assertRaises(ValidationError):
            review.full_clean()
