from django.test import TestCase

from manajemen_lapangan.models import Category, Venue

from ..filters import VenueFilter


class VenueFilterTests(TestCase):
    def setUp(self):
        self.category = Category.objects.get(slug="padel")
        self.other_category = Category.objects.create(name="Other", slug="other-custom")
        Venue.objects.create(
            category=self.category,
            name="Jakarta Court",
            slug="jakarta-court",
            description="Court in Jakarta",
            location="Jakarta",
            city="Jakarta",
            address="Jl. Jakarta",
            price_per_hour="150000.00",
            capacity=4,
            facilities="Locker",
            image_url="https://example.com/jakarta.jpg",
        )
        Venue.objects.create(
            category=self.other_category,
            name="Solo Court",
            slug="solo-court",
            description="Court in Solo",
            location="Solo",
            city="Solo",
            address="Jl. Solo",
            price_per_hour="120000.00",
            capacity=4,
            facilities="Locker",
            image_url="https://example.com/solo.jpg",
        )

    def test_city_choices_include_preferred_and_dynamic_cities(self):
        venue_filter = VenueFilter()
        choices = venue_filter.filters["city"].field.choices
        # The first preferred city should be Jakarta as defined in PREFERRED_CITY_ORDER
        self.assertEqual(choices[0][0], "Jakarta")
        self.assertEqual(venue_filter.filters["city"].extra.get("empty_label"), "All cities")
        # "Solo" should appear at the end because it is not in the preferred list
        self.assertEqual(choices[-1][0], "Solo")
        # The bound form should mirror the filter field choices
        self.assertEqual(venue_filter.form.fields["city"].choices, choices)

    def test_category_queryset_is_sorted_by_predefined_order(self):
        venue_filter = VenueFilter()
        queryset = venue_filter.filters["category"].field.queryset
        self.assertIn(self.category, queryset)
        self.assertNotIn(self.other_category, queryset)
        self.assertEqual(queryset[0].slug, "padel")
        self.assertEqual(list(venue_filter.form.fields["category"].queryset), list(queryset))

    def test_number_filter_uses_decimal_field(self):
        venue_filter = VenueFilter()
        field = venue_filter.filters["max_price"].field
        self.assertEqual(field.widget.attrs.get("type"), None)
        self.assertFalse(field.required)
