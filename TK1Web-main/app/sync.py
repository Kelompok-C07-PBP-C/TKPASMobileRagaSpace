from __future__ import annotations

"""Sync helpers to mirror TK1Web core models into the copied app models.

These helpers pull data from TK_PBP apps (manajemen_lapangan, add_on, rent)
into the local `app` tables so the custom admin UI renders existing records.
"""

from decimal import Decimal
from threading import Lock
from typing import Any

from django.apps import apps
from django.utils import timezone

from .models import Booking, BookingDate, Venue, _normalize_addons

_SYNC_LOCK = Lock()
_LAST_SYNC_AT = None


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


def _resolve_app_venue_type(main_venue) -> str:
    """Map manajemen_lapangan.Venue.category to app.Venue.type."""
    category = getattr(main_venue, "category", None)
    name = (getattr(category, "name", "") or "").strip()
    if name:
        for value, _label in Venue.VenueType.choices:
            if str(value).lower() == name.lower():
                return value
    slug = (getattr(category, "slug", "") or "").strip().lower()
    if slug:
        for value, _label in Venue.VenueType.choices:
            if str(value).strip().lower().replace(" ", "-") == slug:
                return value
    return Venue.VenueType.TENNIS


def _ensure_app_venue_from_main(main_venue) -> Venue:
    """Create or update a local Venue from manajemen_lapangan.Venue."""
    # Prefer existing record but keep it in sync with the main venue so mobile/web catalogs match.
    app_venue = (
        Venue.objects.filter(linked_venue_id=main_venue.pk).first()
        or Venue.objects.filter(title__iexact=main_venue.name).first()
    )

    facilities = [item.strip() for item in (main_venue.facilities or "").split(",") if item.strip()]
    try:
        addons = _build_addons_json(main_venue.addons.all())
    except Exception:
        AddOn = apps.get_model("add_on", "AddOn")
        addons = _build_addons_json(AddOn.objects.filter(venue=main_venue))

    desired_type = _resolve_app_venue_type(main_venue)
    raw_city = (getattr(main_venue, "city", "") or "").strip()
    raw_location = (getattr(main_venue, "location", "") or "").strip()
    desired_location = raw_city
    if raw_location and raw_city and raw_location.lower() != raw_city.lower():
        desired_location = f"{raw_city}, {raw_location}".strip(", ")
    elif raw_location and not raw_city:
        desired_location = raw_location
    desired_image_url = (main_venue.image_url or "").strip()

    if app_venue is None:
        app_venue = Venue.objects.create(
            linked_venue_id=main_venue.pk,
            title=main_venue.name,
            description=main_venue.description,
            facilities=facilities,
            addons=addons,
            price=int(main_venue.price_per_hour),
            location=desired_location,
            image_url=desired_image_url,
            type=desired_type,
            created_at=getattr(main_venue, "created_at", None) or None,
            updated_at=getattr(main_venue, "updated_at", None) or None,
        )
        return app_venue

    updates: list[str] = []
    if app_venue.linked_venue_id != main_venue.pk:
        app_venue.linked_venue_id = main_venue.pk
        updates.append("linked_venue_id")
    if (app_venue.title or "") != (main_venue.name or ""):
        app_venue.title = main_venue.name
        updates.append("title")
    if (app_venue.description or "") != (main_venue.description or ""):
        app_venue.description = main_venue.description
        updates.append("description")
    if app_venue.facilities != facilities:
        app_venue.facilities = facilities
        updates.append("facilities")
    if _normalize_addons(getattr(app_venue, "addons", [])) != _normalize_addons(addons):
        app_venue.addons = addons
        updates.append("addons")
    desired_price = int(main_venue.price_per_hour or 0)
    if int(getattr(app_venue, "price", 0) or 0) != desired_price:
        app_venue.price = desired_price
        updates.append("price")
    if (app_venue.location or "") != desired_location:
        app_venue.location = desired_location
        updates.append("location")
    if (app_venue.image_url or "") != desired_image_url:
        app_venue.image_url = desired_image_url
        updates.append("image_url")
    if (app_venue.type or "") != desired_type:
        app_venue.type = desired_type
        updates.append("type")
    if updates:
        app_venue.save(update_fields=updates + ["updated_at"])
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


def sync_all_main_to_app(
    *,
    min_interval_seconds: int = 10,
    sync_venues: bool = True,
    sync_bookings: bool = True,
    blocking: bool = True,
) -> None:
    """Pull core TK1Web data into the copied app tables.

    The public/mobile endpoints only need venue data most of the time, while the
    admin dashboard also relies on booking mirrors. Allow callers to skip the
    heavier booking sync to keep API responses fast and avoid request timeouts.
    """
    global _LAST_SYNC_AT
    min_interval_seconds = max(int(min_interval_seconds), 0)

    acquired = _SYNC_LOCK.acquire(blocking=blocking)
    if not acquired:
        return

    try:
        if min_interval_seconds > 0 and _LAST_SYNC_AT is not None:
            elapsed = (timezone.now() - _LAST_SYNC_AT).total_seconds()
            if elapsed < min_interval_seconds:
                return
        _LAST_SYNC_AT = timezone.now()

        MLVenue = apps.get_model("manajemen_lapangan", "Venue")
        RentBooking = apps.get_model("rent", "Booking")

        # Sync venues
        if sync_venues:
            for venue in MLVenue.objects.select_related("category").prefetch_related("addons").all():
                _ensure_app_venue_from_main(venue)

        # Sync bookings (includes related venue/add-ons)
        if sync_bookings:
            for booking in (
                RentBooking.objects.select_related("venue", "user")
                .prefetch_related("addons", "payment")
                .all()
            ):
                _ensure_app_booking_from_main(booking)
    finally:
        _SYNC_LOCK.release()
