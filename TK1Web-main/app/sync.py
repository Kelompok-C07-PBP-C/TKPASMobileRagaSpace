from __future__ import annotations

"""Sync helpers to mirror TK1Web core models into the copied app models.

These helpers pull data from TK_PBP apps (manajemen_lapangan, add_on, rent)
into the local `app` tables so the custom admin UI renders existing records.
"""

from decimal import Decimal
from typing import Any

from django.apps import apps
from django.utils import timezone

from .models import Booking, BookingDate, Venue, _normalize_addons


def _build_addons_json(main_addons) -> list[dict[str, object]]:
    payloads: list[dict[str, object]] = []
    for addon in main_addons:
        payloads.append(
            {
                "name": addon.name,
                "price": int(addon.price),
                "description": addon.description or "",
            }
        )
    return payloads


def _ensure_app_venue_from_main(main_venue) -> Venue:
    """Create or update a local Venue from manajemen_lapangan.Venue."""
    addons_model = apps.get_model("add_on", "AddOn")
    # Prefer existing app data; only create if missing.
    app_venue = (
        Venue.objects.filter(linked_venue_id=main_venue.pk).first()
        or Venue.objects.filter(title__iexact=main_venue.name).first()
    )

    if app_venue is None:
        app_venue = Venue.objects.create(
            linked_venue_id=main_venue.pk,
            title=main_venue.name,
            description=main_venue.description,
            facilities=[item.strip() for item in main_venue.facilities.split(",") if item.strip()],
            addons=_build_addons_json(addons_model.objects.filter(venue=main_venue)),
            price=int(main_venue.price_per_hour),
            location=f"{main_venue.city}, {main_venue.location}".strip(", "),
            image_url=main_venue.image_url or "",
            type=Venue.VenueType.TENNIS,
            created_at=getattr(main_venue, "created_at", None) or None,
            updated_at=getattr(main_venue, "updated_at", None) or None,
        )
        return app_venue

    # Existing app data wins; only set linkage and fill blanks.
    updates: list[str] = []
    if not app_venue.linked_venue_id:
        app_venue.linked_venue_id = main_venue.pk
        updates.append("linked_venue_id")
    if not app_venue.image_url and main_venue.image_url:
        app_venue.image_url = main_venue.image_url
        updates.append("image_url")
    if updates:
        app_venue.save(update_fields=updates)
    return app_venue


def _ensure_app_booking_from_main(main_booking) -> Booking:
    """Create or update a local Booking from rent.Booking."""
    payment = getattr(main_booking, "payment", None)
    has_been_paid = False
    date_paid = None
    if payment and payment.status in ("confirmed", "completed"):
        has_been_paid = True
        date_paid = payment.updated_at.date() if payment.updated_at else timezone.localdate()

    app_venue = _ensure_app_venue_from_main(main_booking.venue)
    # Prefer existing app booking if any; only create if missing.
    app_booking = Booking.objects.filter(linked_booking_id=main_booking.pk).first()
    if app_booking is None:
        booking_date = BookingDate.objects.create(
            start_date=main_booking.start_datetime,
            end_date=main_booking.end_datetime,
        )
        app_booking = Booking.objects.create(
            linked_booking_id=main_booking.pk,
            user=main_booking.user,
            venue=app_venue,
            has_been_paid=has_been_paid,
            date_paid=date_paid,
            notes=main_booking.notes or "",
            contact_phone="",
            date=booking_date,
            created_at=getattr(main_booking, "created_at", None) or None,
            updated_at=getattr(main_booking, "updated_at", None) or None,
        )

    # BookingDate
    if app_booking.date_id:
        booking_date = app_booking.date
        booking_date.start_date = main_booking.start_datetime
        booking_date.end_date = main_booking.end_datetime
        booking_date.save(update_fields=["start_date", "end_date"])
    else:
        booking_date = BookingDate.objects.create(
            start_date=main_booking.start_datetime,
            end_date=main_booking.end_datetime,
        )
        app_booking.date = booking_date

    # Add-ons
    # Keep app data authoritative but fix linkage/timestamps if missing or wrong.
    updates: list[str] = []
    if not app_booking.linked_booking_id:
        app_booking.linked_booking_id = main_booking.pk
        updates.append("linked_booking_id")
    if getattr(main_booking, "created_at", None) and app_booking.created_at != main_booking.created_at:
        app_booking.created_at = main_booking.created_at
        updates.append("created_at")
    if getattr(main_booking, "updated_at", None) and app_booking.updated_at != main_booking.updated_at:
        app_booking.updated_at = main_booking.updated_at
        updates.append("updated_at")
    if updates:
        app_booking.save(update_fields=updates)
    return app_booking


def sync_all_main_to_app() -> None:
    """Pull core TK1Web data into the copied app tables."""
    MLVenue = apps.get_model("manajemen_lapangan", "Venue")
    RentBooking = apps.get_model("rent", "Booking")

    # Sync venues
    for venue in MLVenue.objects.all():
        _ensure_app_venue_from_main(venue)

    # Sync bookings (includes related venue/add-ons)
    for booking in (
        RentBooking.objects.select_related("venue", "user")
        .prefetch_related("addons", "payment")
        .all()
    ):
        _ensure_app_booking_from_main(booking)
