from django.contrib.auth.models import Permission, User
from django.test import TestCase
from django.urls import reverse

from manajemen_lapangan.models import Category, Venue

from ..models import AddOn


class AdminVenueAddOnManageViewTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="admin", password="pass", is_staff=True)
        self.category = Category.objects.get(slug="futsal")
        self.venue = Venue.objects.create(
            category=self.category,
            name="Arena",
            slug="arena-addons",
            description="Spacious futsal arena",
            location="Bandung",
            city="Bandung",
            address="Jl. Asia Afrika",
            price_per_hour="120000",
            capacity=10,
            facilities="Cafe, Parking",
            image_url="https://example.com/arena.jpg",
        )
        self.url = reverse("admin-venue-addons", args=[self.venue.pk])

    def test_get_renders_formset(self):
        self.client.force_login(self.user)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)
        self.assertIn("formset", response.context)
        formset = response.context["formset"]
        self.assertEqual(formset.prefix, "addons")

    def test_post_without_permission_redirects(self):
        self.client.force_login(self.user)
        response = self.client.post(self.url, follow=True)
        self.assertRedirects(response, reverse("admin-venues"))
        self.assertEqual(AddOn.objects.count(), 0)

    def test_post_creates_addons_when_authorised(self):
        permission = Permission.objects.get(codename="change_addon")
        self.user.user_permissions.add(permission)
        self.client.force_login(self.user)
        data = {
            "addons-TOTAL_FORMS": "1",
            "addons-INITIAL_FORMS": "0",
            "addons-MIN_NUM_FORMS": "0",
            "addons-MAX_NUM_FORMS": "1000",
            "addons-0-name": "Gloves",
            "addons-0-description": "Goalkeeper gloves",
            "addons-0-price": "35000",
        }
        response = self.client.post(self.url, data, follow=True)
        self.assertRedirects(response, self.url)
        addon = AddOn.objects.get()
        self.assertEqual(addon.name, "Gloves")
        self.assertEqual(addon.venue, self.venue)

    def test_post_with_invalid_data_shows_errors(self):
        permission = Permission.objects.get(codename="change_addon")
        self.user.user_permissions.add(permission)
        self.client.force_login(self.user)
        data = {
            "addons-TOTAL_FORMS": "1",
            "addons-INITIAL_FORMS": "0",
            "addons-MIN_NUM_FORMS": "0",
            "addons-MAX_NUM_FORMS": "1000",
            "addons-0-name": "",  # missing name triggers validation error
            "addons-0-description": "No name",
            "addons-0-price": "25000",
        }
        response = self.client.post(self.url, data)
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Please correct the errors below")
        self.assertEqual(AddOn.objects.count(), 0)
