from __future__ import annotations

from django import forms
from django.db.models import Case, IntegerField, When

from manajemen_lapangan.constants import CATEGORY_SLUG_SEQUENCE

from katalog.constants import PREFERRED_CITY_ORDER
from manajemen_lapangan.models import Category, Venue


class SearchFilterForm(forms.Form):
    """Form displayed in navigation for quick searching."""

    city = forms.ChoiceField(
        required=False,
        choices=(),
        widget=forms.Select(
            attrs={
                "class": "custom-select w-full rounded-2xl border border-white/25 bg-slate-950/70 px-5 py-3 text-sm text-white/90 backdrop-blur",
            }
        ),
    )
    category = forms.ModelChoiceField(
        required=False,
        queryset=Category.objects.none(),
        empty_label="All categories",
        widget=forms.Select(
            attrs={
                "class": "custom-select w-full rounded-2xl border border-white/25 bg-slate-950/70 px-5 py-3 text-sm text-white/90 backdrop-blur",
            }
        ),
    )
    max_price = forms.DecimalField(
        required=False,
        min_value=0,
        widget=forms.NumberInput(
            attrs={
                "class": "w-full rounded-2xl border border-white/25 bg-slate-950/70 px-5 py-3 text-sm text-white/90 placeholder:text-white/60 backdrop-blur",
                "placeholder": "Max Price",
            }
        ),
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        city_choices = [(city, city) for city in PREFERRED_CITY_ORDER]

        remaining_cities = (
            Venue.objects.exclude(city__in=PREFERRED_CITY_ORDER)
            .order_by("city")
            .values_list("city", flat=True)
            .distinct()
        )
        city_choices.extend((city, city) for city in remaining_cities if city)

        self.fields["city"].choices = city_choices
        self.fields["city"].widget.choices = [("", "All cities"), *city_choices]

        order_expression = Case(
            *[When(slug=slug, then=position) for position, slug in enumerate(CATEGORY_SLUG_SEQUENCE)],
            default=len(CATEGORY_SLUG_SEQUENCE),
            output_field=IntegerField(),
        )
        self.fields["category"].queryset = (
            Category.objects.filter(slug__in=CATEGORY_SLUG_SEQUENCE)
            .annotate(_display_order=order_expression)
            .order_by("_display_order")
        )
