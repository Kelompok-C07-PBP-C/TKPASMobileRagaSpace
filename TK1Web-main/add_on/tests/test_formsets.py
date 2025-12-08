from django.forms import BaseInlineFormSet
from django.test import TestCase

from manajemen_lapangan.models import Category, Venue

from ..formsets import AddOnInlineFormSet, build_addon_formset
from ..models import AddOn


class AddOnFormsetTests(TestCase):
    def setUp(self):
        self.category = Category.objects.get(slug="padel")
        self.venue = Venue.objects.create(
            category=self.category,
            name="Central Court",
            slug="central-court",
            description="Indoor padel court",
            location="Jakarta",
            city="Jakarta",
            address="Jl. Sudirman",
            price_per_hour="150000",
            capacity=4,
            facilities="Shower, Locker",
            image_url="https://example.com/court.jpg",
        )

    def test_add_fields_hides_delete_checkbox(self):
        formset = build_addon_formset(instance=self.venue)
        # Instantiate a form in the formset to trigger add_fields
        form = formset.empty_form
        self.assertIsInstance(formset, BaseInlineFormSet)
        self.assertIsInstance(formset, AddOnInlineFormSet)
        delete_field = form.fields["DELETE"]
        self.assertIn("hidden", delete_field.widget.attrs.get("class"))
        self.assertEqual(delete_field.widget.attrs.get("data-addon-delete-input"), "true")

    def test_build_addon_formset_with_initial_instance(self):
        AddOn.objects.create(venue=self.venue, name="Racket", description="Premium racket", price="50000")
        formset = build_addon_formset(instance=self.venue)
        self.assertEqual(formset.prefix, "addons")
        self.assertEqual(formset.total_form_count(), 1)
        self.assertEqual(formset.initial_forms[0].instance.name, "Racket")

    def test_build_addon_formset_with_submitted_data(self):
        data = {
            "addons-TOTAL_FORMS": "1",
            "addons-INITIAL_FORMS": "0",
            "addons-MIN_NUM_FORMS": "0",
            "addons-MAX_NUM_FORMS": "1000",
            "addons-0-name": "Grip",
            "addons-0-description": "Comfort grip",
            "addons-0-price": "15000",
        }
        formset = build_addon_formset(data=data, instance=self.venue)
        self.assertTrue(formset.is_valid())
        instances = formset.save(commit=False)
        self.assertEqual(len(instances), 1)
        self.assertEqual(instances[0].name, "Grip")
