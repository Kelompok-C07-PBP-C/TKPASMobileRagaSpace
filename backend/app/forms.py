from __future__ import annotations

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


class VenueForm(forms.ModelForm):
    facilities = forms.CharField(
        required=False,
        help_text="Separate facilities with commas",
        widget=forms.TextInput(attrs={"placeholder": "Wi-Fi, Parking, Catering"}),
    )

    class Meta:
        model = Venue
        fields = [
            "title",
            "type",
            "description",
            "facilities",
            "price",
            "location",
            "image",
        ]

    def clean_facilities(self) -> list[str]:
        return _split_facilities(self.cleaned_data.get("facilities"))


class BookingForm(forms.ModelForm):
    username = forms.CharField(required=False, max_length=255)
    start_date = forms.DateField(input_formats=["%Y-%m-%d"])
    end_date = forms.DateField(input_formats=["%Y-%m-%d"])

    class Meta:
        model = Booking
        fields = ["user", "venue", "has_been_paid", "notes"]
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
        if user_obj:
            cleaned["user"] = user_obj
            return cleaned

        username = (cleaned.get("username") or "").strip()
        if not username:
            self.add_error("username", "Please choose a username from the list.")
            return cleaned

        try:
            user = User.objects.get(username__iexact=username)
        except User.DoesNotExist:
            try:
                user = User.objects.get(email__iexact=username)
            except User.DoesNotExist:
                self.add_error(
                    "username",
                    "The specified username does not exist. Please select an existing user.",
                )
                return cleaned

        cleaned["user"] = user
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
            booking.save()
        else:
            booking.date = booking_date

        return booking
