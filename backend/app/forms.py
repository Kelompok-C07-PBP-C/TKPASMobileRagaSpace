from __future__ import annotations

import json
from typing import Any

from django import forms
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError

from .models import Booking, BookingDate, Venue

User = get_user_model()


def _split_facilities(value: str | list[str] | None) -> list[str]:
    if not value:
        return []
    if isinstance(value, (list, tuple)):
        return [item for item in value if item]
    facilities = [item.strip() for item in str(value).split(',')]
    return [item for item in facilities if item]


def _parse_addons(value: Any) -> list[dict[str, object]]:
    if not value:
        return []
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError as exc:
            raise ValidationError("Unable to parse add-ons data.") from exc
    if not isinstance(value, (list, tuple)):
        return []
    cleaned: list[dict[str, object]] = []
    for item in value:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name", "")).strip()
        if not name:
            continue
        try:
            price = int(item.get("price", 0))
        except (TypeError, ValueError):
            price = 0
        if price < 0:
            price = 0
        description = str(item.get("description", "")).strip()
        cleaned.append({"name": name, "price": price, "description": description})
    return cleaned


def _filter_selected_addons(
    selected: list[dict[str, object]],
    available: Any,
) -> list[dict[str, object]]:
    if not available or not selected:
        return []
    pool: list[dict[str, object]] = []
    if isinstance(available, (list, tuple)):
        for item in available:
            if not isinstance(item, dict):
                continue
            name = str(item.get("name", "")).strip()
            if not name:
                continue
            try:
                price = int(item.get("price", 0))
            except (TypeError, ValueError):
                price = 0
            if price < 0:
                price = 0
            pool.append(
                {
                    "name": name,
                    "price": price,
                    "description": str(item.get("description", "")).strip(),
                }
            )
    normalized: list[dict[str, object]] = []
    remaining = pool.copy()
    for chosen in selected:
        name = str(chosen.get("name", "")).strip()
        if not name:
            continue
        try:
            price = int(chosen.get("price", 0))
        except (TypeError, ValueError):
            price = 0
        match = next(
            (
                option
                for option in remaining
                if option["name"].lower() == name.lower() and option["price"] == price
            ),
            None,
        )
        if match:
            normalized.append(match)
            remaining.remove(match)
    return normalized


class VenueForm(forms.ModelForm):
    facilities = forms.CharField(
        required=False,
        help_text="Separate facilities with commas",
        widget=forms.TextInput(attrs={"placeholder": "Wi-Fi, Parking, Catering"}),
    )
    addons = forms.CharField(required=False, widget=forms.HiddenInput())

    class Meta:
        model = Venue
        fields = [
            "title",
            "type",
            "description",
            "facilities",
            "addons",
            "price",
            "location",
            "image",
        ]

    def clean_facilities(self) -> list[str]:
        return _split_facilities(self.cleaned_data.get("facilities"))

    def clean_addons(self) -> list[dict[str, object]]:
        return _parse_addons(self.cleaned_data.get("addons"))


class BookingForm(forms.ModelForm):
    username = forms.CharField(required=False, max_length=255)
    start_date = forms.DateField(input_formats=["%Y-%m-%d"])
    end_date = forms.DateField(input_formats=["%Y-%m-%d"])
    selected_addons = forms.CharField(required=False, widget=forms.HiddenInput())

    class Meta:
        model = Booking
        fields = ["user", "venue", "has_been_paid", "notes", "selected_addons"]
        widgets = {
            "user": forms.HiddenInput(),
            "venue": forms.HiddenInput(),
            "notes": forms.Textarea(attrs={"rows": 3}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["user"].required = False
        self.fields["venue"].required = True
        if self.instance and self.instance.pk:
            self.fields["username"].initial = (
                self.instance.user.get_username() if self.instance.user else ""
            )
            self.fields["start_date"].initial = self.instance.date.start_date
            self.fields["end_date"].initial = self.instance.date.end_date

    def clean(self) -> dict[str, object]:
        cleaned = super().clean()
        start = cleaned.get("start_date")
        end = cleaned.get("end_date")
        if start and end and end < start:
            raise ValidationError("End date cannot be before the start date.")

        if not User.objects.exists():
            raise ValidationError("Create a user account before adding bookings.")

        user_obj = cleaned.get("user")
        venue = cleaned.get("venue") or (self.instance.venue if self.instance.pk else None)

        if not user_obj:
            username = (cleaned.get("username") or "").strip()
            if not username:
                self.add_error("username", "Please choose a username from the list.")
                return cleaned

            try:
                user_obj = User.objects.get(username__iexact=username)
            except User.DoesNotExist:
                try:
                    user_obj = User.objects.get(email__iexact=username)
                except User.DoesNotExist:
                    self.add_error(
                        "username",
                        "The specified username does not exist. Please select an existing user.",
                    )
                    return cleaned

        cleaned["user"] = user_obj

        selected_addons_raw = cleaned.get("selected_addons")
        selected_addons = _parse_addons(selected_addons_raw)
        if venue and getattr(venue, "addons", None):
            cleaned["selected_addons"] = _filter_selected_addons(selected_addons, venue.addons)
        else:
            cleaned["selected_addons"] = []
        return cleaned

    def save(self, commit: bool = True) -> Booking:
        booking = super().save(commit=False)
        start = self.cleaned_data["start_date"]
        end = self.cleaned_data["end_date"]
        if start and end and end < start:
            raise ValidationError("End date cannot be before the start date.")

        if booking.pk and booking.date_id:
            booking_date = booking.date
            booking_date.start_date = start
            booking_date.end_date = end
        else:
            booking_date = BookingDate(start_date=start, end_date=end)

        if commit:
            booking_date.save()
            booking.date = booking_date
            booking.selected_addons = self.cleaned_data.get("selected_addons", [])
            booking.save()
        else:
            booking.date = booking_date
            booking.selected_addons = self.cleaned_data.get("selected_addons", [])
        return booking
