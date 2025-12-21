from __future__ import annotations

import random
from datetime import timedelta
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from django.contrib.auth import get_user_model

from app.models import Booking, BookingDate, Venue

SEED_PREFIX = "[seed]"

FACILITY_POOL = [
    "Wi-Fi",
    "Parking",
    "Canteen",
    "Locker",
    "Shower",
    "Water dispenser",
    "Air conditioning",
    "Prayer room",
]

ADDON_POOL = [
    ("Premium couch", 75000, "Lounge-style seating near the court."),
    ("Coaching session", 120000, "30-minute coaching add-on."),
    ("Drinks package", 25000, "2 bottled drinks included."),
    ("Priority service", 50000, "Faster check-in & priority support."),
    ("Racket rental", 30000, "Borrow a racket for the session."),
    ("Shuttlecock pack", 40000, "One pack of shuttlecocks."),
]

LOCATION_POOL = [
    "Jakarta",
    "Depok",
    "Bogor",
    "Bekasi",
    "Tangerang",
    "Bandung",
]


def _existing_image_names() -> list[str]:
    names: set[str] = set()
    media_root = Path(settings.MEDIA_ROOT)
    for venue in Venue.objects.exclude(image=""):
        try:
            if venue.image and venue.image.name:
                candidate = venue.image.name
                if (media_root / candidate).exists():
                    names.add(candidate)
        except Exception:
            continue

    venues_dir = media_root / "venues"
    if venues_dir.exists():
        for file in venues_dir.iterdir():
            if not file.is_file():
                continue
            if file.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
                continue
            names.add(f"venues/{file.name}")
    return sorted(names)


def _random_addons() -> list[dict[str, object]]:
    count = random.randint(0, 3)
    if count <= 0:
        return []
    picks = random.sample(ADDON_POOL, k=min(count, len(ADDON_POOL)))
    return [
        {"name": name, "price": int(price), "description": desc}
        for name, price, desc in picks
    ]


class Command(BaseCommand):
    help = "Seed venues and bookings to simulate pagination in the admin UI."

    def add_arguments(self, parser) -> None:
        parser.add_argument("--venues", type=int, default=24)
        parser.add_argument("--bookings", type=int, default=72)
        parser.add_argument("--username", type=str, default="")
        parser.add_argument("--clear", action="store_true")

    @transaction.atomic
    def handle(self, *args, **options) -> None:
        venues_target: int = max(int(options["venues"]), 0)
        bookings_target: int = max(int(options["bookings"]), 0)
        clear: bool = bool(options["clear"])
        preferred_username: str = (options.get("username") or "").strip()

        UserModel = get_user_model()
        users = list(UserModel.objects.order_by("id"))
        if not users:
            raise CommandError("No users found. Create at least one user first.")
        if preferred_username:
            user = UserModel.objects.filter(username__iexact=preferred_username).first()
            if user is None:
                raise CommandError(
                    f"User '{preferred_username}' not found. "
                    f"Existing usernames: {', '.join([u.username for u in users])}"
                )
            users = [user]

        if clear:
            seeded_bookings = Booking.objects.filter(notes__startswith=SEED_PREFIX)
            date_ids = list(seeded_bookings.values_list("date_id", flat=True))
            deleted_bookings = seeded_bookings.count()
            seeded_bookings.delete()
            BookingDate.objects.filter(id__in=date_ids).delete()

            deleted_venues, _ = Venue.objects.filter(title__startswith=SEED_PREFIX).delete()
            BookingDate.objects.filter(booking__isnull=True).delete()

            self.stdout.write(
                self.style.WARNING(
                    f"Cleared {deleted_bookings} seeded bookings and {deleted_venues} seeded venues."
                )
            )

        images = _existing_image_names()
        if not images:
            self.stdout.write(
                self.style.WARNING(
                    "No existing venue images found in MEDIA_ROOT/venues. "
                    "Seeded venues will have no image."
                )
            )

        venue_types = [choice[0] for choice in Venue.VenueType.choices]
        created_venues = 0
        for i in range(venues_target):
            title = f"{SEED_PREFIX} Venue {i + 1:03d}"
            if Venue.objects.filter(title=title).exists():
                continue
            venue = Venue(
                title=title,
                type=random.choice(venue_types) if venue_types else "Tennis",
                description="Seeded venue for pagination testing.",
                facilities=random.sample(
                    FACILITY_POOL, k=random.randint(0, min(4, len(FACILITY_POOL)))
                ),
                addons=_random_addons(),
                price=random.choice([50000, 65000, 75000, 90000, 120000, 150000, 200000]),
                location=random.choice(LOCATION_POOL),
            )
            if images:
                venue.image = random.choice(images)
                venue.image_url = ""
            venue.save()
            created_venues += 1

        venues = list(Venue.objects.all())
        if not venues:
            raise CommandError("No venues exist. Cannot seed bookings.")

        now = timezone.now()
        created_bookings = 0
        for i in range(bookings_target):
            venue = random.choice(venues)
            user = random.choice(users)
            days_ago = random.randint(0, 18)
            start = now - timedelta(days=days_ago, hours=random.randint(0, 10))
            start = start.replace(minute=0, second=0, microsecond=0)
            duration_hours = random.choice([1, 2, 3])
            end = start + timedelta(hours=duration_hours)

            paid = random.random() < 0.65
            date_paid = (start.date() if paid else None)

            venue_addons = venue.addons if isinstance(venue.addons, list) else []
            addon_choices = [a for a in venue_addons if isinstance(a, dict)]
            selected_addons: list[dict[str, object]] = []
            if addon_choices:
                selected_addons = random.sample(
                    addon_choices, k=random.randint(0, min(2, len(addon_choices)))
                )

            booking_date = BookingDate.objects.create(start_date=start, end_date=end)
            Booking.objects.create(
                user=user,
                venue=venue,
                has_been_paid=paid,
                date_paid=date_paid,
                date=booking_date,
                notes=f"{SEED_PREFIX} Booking {i + 1:03d}",
                contact_phone="081234567890",
                selected_addons=selected_addons,
            )
            created_bookings += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Seeded +{created_venues} venues and +{created_bookings} bookings "
                f"(users used: {', '.join(sorted({u.username for u in users}))})."
            )
        )
