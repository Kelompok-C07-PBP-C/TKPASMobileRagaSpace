"""Models for managing sports venues."""
from __future__ import annotations

from decimal import Decimal
from datetime import time

from django.core.exceptions import ValidationError
from django.db import models
from django.db.models.signals import post_delete
from django.dispatch import receiver
from django.utils.text import slugify
from django.apps import apps


class TimestampedModel(models.Model):
    """Abstract base model providing timestamp fields."""

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class Category(TimestampedModel):
    """Represents a sports venue category."""

    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=120, unique=True)

    class Meta:
        ordering = ["name"]

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)

    def __str__(self) -> str:  # pragma: no cover - trivial
        return self.name


class Venue(TimestampedModel):
    """Venue model holding primary information."""

    category = models.ForeignKey(Category, on_delete=models.PROTECT, related_name="venues")
    name = models.CharField(max_length=150)
    slug = models.SlugField(max_length=170, unique=True)
    description = models.TextField()
    location = models.CharField(max_length=150)
    city = models.CharField(max_length=100)
    address = models.TextField(blank=True)
    price_per_hour = models.DecimalField(max_digits=10, decimal_places=2)
    capacity = models.PositiveIntegerField(default=1)
    facilities = models.TextField(help_text="Comma separated facilities list.")
    image_url = models.URLField(blank=True)
    available_start_time = models.TimeField(default=time(7, 0))
    available_end_time = models.TimeField(default=time(22, 0))

    class Meta:
        ordering = ["name"]

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)

    def __str__(self) -> str:  # pragma: no cover - trivial
        return self.name

    @property
    def facilities_list(self) -> list[str]:
        return [facility.strip() for facility in self.facilities.split(",") if facility.strip()]

    def hourly_total(self, hours: int) -> Decimal:
        return self.price_per_hour * Decimal(hours)


class VenueAvailability(TimestampedModel):
    """Represents a block of time when the venue is available for booking."""

    venue = models.ForeignKey(Venue, on_delete=models.CASCADE, related_name="availabilities")
    start_datetime = models.DateTimeField()
    end_datetime = models.DateTimeField()

    class Meta:
        ordering = ["start_datetime"]
        verbose_name_plural = "Venue availabilities"

    def clean(self):  # pragma: no cover - requires Django validation
        if self.end_datetime <= self.start_datetime:
            raise ValidationError("End datetime must be greater than start datetime")


@receiver(post_delete, sender=Venue)
def delete_mirrored_app_venue(sender, instance: Venue, **kwargs):  # pragma: no cover - integration glue
    """Remove mirrored app.Venue rows when a main venue is deleted.

    The Flutter app/admin panel reads from the mirrored `app.Venue` table. When
    admins delete a venue in the web workspace (manajemen_lapangan), we must
    also delete the mirror so it does not reappear in the app UI.
    """

    try:
        AppVenue = apps.get_model("app", "Venue")
    except Exception:
        return
    try:
        qs = AppVenue.objects.filter(linked_venue_id=instance.pk)
        title = (getattr(instance, "name", "") or "").strip()
        city = (getattr(instance, "city", "") or "").strip()
        if title:
            extras = AppVenue.objects.filter(title__iexact=title)
            if city:
                extras = extras.filter(location__istartswith=city)
            qs = qs | extras
        qs.distinct().delete()
    except Exception:
        return
