from __future__ import annotations

from decimal import Decimal
from typing import Any

from django.apps import apps
from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.utils import timezone
from django.utils.text import slugify


class BookingDate(models.Model):
  start_date = models.DateTimeField()
  end_date = models.DateTimeField()

  class Meta:
      ordering = ["start_date", "end_date"]

  def __str__(self) -> str:
      return f"{self.start_date:%Y-%m-%d} → {self.end_date:%Y-%m-%d}"


class Venue(models.Model):
  class VenueType(models.TextChoices):
      PADEL = "Padel", "Padel"
      TENNIS = "Tennis", "Tennis"
      BADMINTON = "Badminton", "Badminton"
      BASKET = "Basket", "Basket"
      SEPAK_BOLA = "Sepak Bola", "Sepak Bola"
      MINI_SOCCER = "Mini Soccer", "Mini Soccer"
      FUTSAL = "Futsal", "Futsal"
      BILLIARD = "Billiard", "Billiard"
      TENIS_MEJA = "Tenis Meja", "Tenis Meja"
      VOLLY_BALL = "Volly Ball", "Volly Ball"

  title = models.CharField(max_length=255)
  description = models.TextField()
  facilities = models.JSONField(default=list, blank=True)
  addons = models.JSONField(default=list, blank=True)
  price = models.PositiveIntegerField(validators=[MinValueValidator(0)])
  location = models.CharField(max_length=255)
  image = models.ImageField(upload_to="venues/", blank=True)
  image_url = models.URLField(blank=True)
  linked_venue_id = models.PositiveIntegerField(null=True, blank=True, unique=True)
  type = models.CharField(
      max_length=20,
      choices=VenueType.choices,
      default=VenueType.TENNIS,
  )
  created_at = models.DateTimeField(auto_now_add=True)
  updated_at = models.DateTimeField(auto_now=True)

  class Meta:
      ordering = ["title"]

  def __str__(self) -> str:
      return self.title


class Booking(models.Model):
  user = models.ForeignKey(
      settings.AUTH_USER_MODEL,
      related_name="app_bookings",
      on_delete=models.CASCADE,
      null=True,
  )
  venue = models.ForeignKey(Venue, related_name="bookings", on_delete=models.CASCADE)
  has_been_paid = models.BooleanField(default=False)
  date_paid = models.DateField(null=True, blank=True)
  date = models.OneToOneField(
      BookingDate, related_name="booking", on_delete=models.CASCADE
  )
  notes = models.TextField(blank=True)
  contact_phone = models.CharField(max_length=32, blank=True)
  selected_addons = models.JSONField(default=list, blank=True)
  linked_booking_id = models.PositiveIntegerField(null=True, blank=True, unique=True)
  created_at = models.DateTimeField(auto_now_add=True)
  updated_at = models.DateTimeField(auto_now=True)

  class Meta:
      ordering = ["-created_at"]

  def __str__(self) -> str:
      username = self.user.get_username() if self.user else "Unknown user"
      return f"Booking for {username}"

  def save(self, *args, **kwargs) -> None:
      if self.has_been_paid:
          if self.date_paid is None:
              self.date_paid = timezone.localdate()
      else:
          self.date_paid = None
      super().save(*args, **kwargs)


class Comment(models.Model):
  user = models.ForeignKey(
      settings.AUTH_USER_MODEL,
      related_name="comments",
      on_delete=models.CASCADE,
      null=True,
      blank=True,
  )
  rating = models.PositiveSmallIntegerField(
      validators=[MinValueValidator(1), MaxValueValidator(5)]
  )
  comment = models.TextField()
  date = models.DateField(default=timezone.localdate)
  linked_review_id = models.PositiveIntegerField(null=True, blank=True, unique=True)
  venue = models.ManyToManyField(
      "Venue",
      related_name="comments",
      through="CommentVenue",
  )

  class Meta:
      ordering = ["-date", "-id"]

  def __str__(self) -> str:
      user = self.user.get_username() if self.user else "Anonim"
      return f"Comment by {user}"


class CommentVenue(models.Model):
  comment = models.ForeignKey(
      Comment, related_name="venue_links", on_delete=models.CASCADE
  )
  venue = models.ForeignKey(
      Venue, related_name="comment_links", on_delete=models.CASCADE
  )

  class Meta:
      unique_together = ("comment", "venue")


class WishlistEntry(models.Model):
  user = models.ForeignKey(
      settings.AUTH_USER_MODEL,
      related_name="wishlist_entries",
      on_delete=models.CASCADE,
  )
  linked_wishlist_id = models.PositiveIntegerField(null=True, blank=True, unique=True)
  venue = models.ForeignKey(
      Venue,
      related_name="wishlisted_entries",
      on_delete=models.CASCADE,
  )
  created_at = models.DateTimeField(auto_now_add=True)

  class Meta:
      ordering = ["-created_at"]
      unique_together = ("user", "venue")

  def __str__(self) -> str:
      username = self.user.get_username() if self.user else "Unknown user"
      return f"WishlistEntry({username} -> {self.venue})"


class Profile(models.Model):
  user = models.OneToOneField(
      settings.AUTH_USER_MODEL, related_name="profile", on_delete=models.CASCADE
  )
  avatar = models.ImageField(upload_to="profiles/", blank=True)
  phone_number = models.CharField(max_length=32, blank=True)

  def __str__(self) -> str:
      return f"Profile for {self.user.get_username()}"


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_profile(sender, instance, created, **kwargs):
  if created:
      Profile.objects.get_or_create(user=instance)


def _normalize_addons(raw: Any) -> list[dict[str, object]]:
  """Convert various addon payloads into a clean list of dicts."""
  if not raw:
      return []
  items: list[Any]
  if isinstance(raw, dict):
      items = [raw]
  elif isinstance(raw, (list, tuple)):
      items = list(raw)
  else:
      return []

  normalized: list[dict[str, object]] = []
  for item in items:
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
      normalized.append({"name": name, "price": price, "description": description})
  return normalized


def _update_instance_link(model_cls, pk: int, field: str, value: int) -> None:
  """Assign a linkage field without retriggering signals."""
  if value:
      model_cls.objects.filter(pk=pk).update(**{field: value})


def _get_or_create_import_category():
  Category = apps.get_model("manajemen_lapangan", "Category")
  category, _ = Category.objects.get_or_create(name="Imported", defaults={"slug": "imported"})
  return category


def _resolve_category_for_app_venue(app_venue: "Venue"):
  """
  Choose an appropriate manajemen_lapangan.Category for the given app Venue.

  We prefer a category whose *name* matches the app venue type (e.g. "Tennis",
  "Futsal"). If no such category exists we gracefully fall back to the generic
  "Imported" category so existing data keeps working.
  """
  Category = apps.get_model("manajemen_lapangan", "Category")

  venue_type = (app_venue.type or "").strip()
  if venue_type:
      normalized_type = venue_type.lower()

      # Handle legacy/new spelling mismatch for volley/volly so venues don't drop to "Imported".
      if normalized_type in {"volly ball", "volley ball", "volly-ball", "volley-ball", "volleyball"}:
          category = (
              Category.objects.filter(slug__iexact="volly-ball").first()
              or Category.objects.filter(slug__iexact="volley-ball").first()
              or Category.objects.filter(name__iexact="Volly Ball").first()
              or Category.objects.filter(name__iexact="Volley Ball").first()
          )
          if category is None:
              category, _ = Category.objects.get_or_create(slug="volly-ball", defaults={"name": "Volly Ball"})
          else:
              updated_fields: list[str] = []
              if category.slug != "volly-ball":
                  category.slug = "volly-ball"
                  updated_fields.append("slug")
              if category.name != "Volly Ball":
                  category.name = "Volly Ball"
                  updated_fields.append("name")
              if updated_fields:
                  category.save(update_fields=updated_fields)
          return category

      # Try a case-insensitive name match first so that "Tennis" in the
      # admin UI maps to the Tennis category used by the catalog filters.
      category = Category.objects.filter(name__iexact=venue_type).first()
      if category:
          return category

      # As a secondary attempt, try matching by slugified name to catch near-matches.
      slug_candidate = slugify(venue_type)
      if slug_candidate:
          category = Category.objects.filter(slug=slug_candidate).first()
          if category:
              return category

  # As a safe fallback, keep using / creating the generic "Imported" bucket.
  return _get_or_create_import_category()


def _resolve_main_venue(app_venue: Venue):
  """Ensure a corresponding manajemen_lapangan.Venue exists and return it."""
  MLVenue = apps.get_model("manajemen_lapangan", "Venue")
  category = _resolve_category_for_app_venue(app_venue)

  slug_base = slugify(app_venue.title) or f"venue-{app_venue.pk}"
  slug = slug_base
  counter = 1
  while MLVenue.objects.exclude(pk=app_venue.linked_venue_id or None).filter(slug=slug).exists():
      counter += 1
      slug = f"{slug_base}-{counter}"

  raw_facilities = getattr(app_venue, "facilities", [])
  facilities_parts: list[str] = []
  if isinstance(raw_facilities, (list, tuple)):
      for item in raw_facilities:
          if isinstance(item, dict):
              name = str(item.get("name", "")).strip()
              if name:
                  facilities_parts.append(name)
          else:
              text = str(item).strip()
              if text:
                  facilities_parts.append(text)
  elif isinstance(raw_facilities, str):
      facilities_parts = [segment.strip() for segment in raw_facilities.split(",") if segment.strip()]
  facilities_text = ", ".join(facilities_parts)

  city = app_venue.location.split(",")[0].strip() if app_venue.location else ""
  image_url = app_venue.image_url
  if not image_url and app_venue.image:
      try:
          image_url = app_venue.image.url
      except Exception:
          image_url = ""

  defaults = {
      "category": category,
      "name": app_venue.title,
      "slug": slug,
      "description": app_venue.description,
      "location": app_venue.location,
      "city": city,
      "address": "",
      "price_per_hour": Decimal(app_venue.price or 0),
      "capacity": 1,
      "facilities": facilities_text,
      "image_url": image_url or "",
  }

  ml_venue = None
  if app_venue.linked_venue_id:
      ml_venue = MLVenue.objects.filter(pk=app_venue.linked_venue_id).first()
  if ml_venue:
      for field, value in defaults.items():
          setattr(ml_venue, field, value)
      if not ml_venue.slug:
          ml_venue.slug = slug
      ml_venue.save()
  else:
      ml_venue, _ = MLVenue.objects.get_or_create(slug=slug, defaults=defaults)

  _sync_addons_to_main(app_venue, ml_venue)
  return ml_venue


def _sync_addons_to_main(app_venue: Venue, ml_venue):
  """Mirror JSON addons to the AddOn model used by TK1Web."""
  AddOn = apps.get_model("add_on", "AddOn")
  addon_payloads = _normalize_addons(getattr(app_venue, "addons", []))
  existing = {
      addon.name.lower(): addon for addon in AddOn.objects.filter(venue=ml_venue)
  }
  for addon in addon_payloads:
      name = addon["name"].strip()
      price = Decimal(addon.get("price", 0))
      description = addon.get("description", "")
      key = name.lower()
      if key in existing:
          add_on_obj = existing[key]
          changed = False
          if add_on_obj.price != price:
              add_on_obj.price = price
              changed = True
          if add_on_obj.description != description:
              add_on_obj.description = description
              changed = True
          if changed:
              add_on_obj.save(update_fields=["price", "description", "updated_at"])
      else:
          AddOn.objects.create(
              venue=ml_venue,
              name=name,
              description=description,
              price=price,
          )


@receiver(post_save, sender=Venue)
def sync_venue_to_tk1web(sender, instance: Venue, **kwargs):
  """Keep TK1Web manajemen_lapangan.Venue in sync with this app's Venue."""
  ml_venue = _resolve_main_venue(instance)
  if ml_venue and instance.linked_venue_id != ml_venue.pk:
      _update_instance_link(Venue, instance.pk, "linked_venue_id", ml_venue.pk)


def _resolve_main_booking(app_booking: Booking):
  RentBooking = apps.get_model("rent", "Booking")
  Payment = apps.get_model("rent", "Payment")

  if not app_booking.user or not app_booking.date:
      return None

  venue = _resolve_main_venue(app_booking.venue)
  if venue is None:
      return None

  start = app_booking.date.start_date
  end = app_booking.date.end_date
  status = RentBooking.STATUS_CONFIRMED if app_booking.has_been_paid else RentBooking.STATUS_PENDING

  rent_booking = None
  if app_booking.linked_booking_id:
      rent_booking = RentBooking.objects.filter(pk=app_booking.linked_booking_id).first()

  if rent_booking:
      rent_booking.user = app_booking.user
      rent_booking.venue = venue
      rent_booking.start_datetime = start
      rent_booking.end_datetime = end
      rent_booking.notes = app_booking.notes
      rent_booking.status = status
      rent_booking.save()
  else:
      rent_booking = RentBooking.objects.create(
          user=app_booking.user,
          venue=venue,
          start_datetime=start,
          end_datetime=end,
          notes=app_booking.notes,
          status=status,
      )

  # Attach addons if they exist in TK1Web
  AddOn = apps.get_model("add_on", "AddOn")
  addon_payloads = _normalize_addons(getattr(app_booking, "selected_addons", []))
  addon_names = [item["name"].strip() for item in addon_payloads if item.get("name")]
  if addon_names:
      matched_addons = AddOn.objects.filter(venue=venue, name__in=addon_names)
      rent_booking.addons.set(matched_addons)

  payment_status = "confirmed" if app_booking.has_been_paid else "waiting"
  payment_defaults = {
      "method": "qris",
      "status": payment_status,
      "total_amount": venue.hourly_total(rent_booking.duration_hours),
      "deposit_amount": Decimal("10000"),
      "reference_code": f"APP-{rent_booking.pk}",
  }
  payment, created = Payment.objects.get_or_create(booking=rent_booking, defaults=payment_defaults)
  if not created:
      updates = []
      if payment.status != payment_status:
          payment.status = payment_status
          updates.append("status")
      new_total = venue.hourly_total(rent_booking.duration_hours)
      if payment.total_amount != new_total:
          payment.total_amount = new_total
          updates.append("total_amount")
      if updates:
          payment.save(update_fields=updates + ["updated_at"])

  return rent_booking


@receiver(post_save, sender=Booking)
def sync_booking_to_tk1web(sender, instance: Booking, **kwargs):
  """Mirror bookings into TK1Web's rent.Booking so both sides see the same data."""
  rent_booking = _resolve_main_booking(instance)
  if rent_booking and instance.linked_booking_id != rent_booking.pk:
      _update_instance_link(Booking, instance.pk, "linked_booking_id", rent_booking.pk)


@receiver(post_save, sender=WishlistEntry)
def sync_wishlist_to_tk1web(sender, instance: WishlistEntry, **kwargs):
  """Mirror wishlist entries into TK1Web's interaksi.Wishlist."""
  Wishlist = apps.get_model("interaksi", "Wishlist")
  venue = _resolve_main_venue(instance.venue)
  if venue is None:
      return
  wishlist, _ = Wishlist.objects.get_or_create(user=instance.user, venue=venue)
  if instance.linked_wishlist_id != wishlist.pk:
      _update_instance_link(WishlistEntry, instance.pk, "linked_wishlist_id", wishlist.pk)


@receiver(post_delete, sender=WishlistEntry)
def delete_wishlist_from_tk1web(sender, instance: WishlistEntry, **kwargs):
  """
  Ensure TK1Web's interaksi.Wishlist is kept in sync when an app-level
  WishlistEntry is removed (e.g. via the Flutter API).
  """
  Wishlist = apps.get_model("interaksi", "Wishlist")
  # Prefer the explicit link if present.
  if instance.linked_wishlist_id:
      Wishlist.objects.filter(pk=instance.linked_wishlist_id).delete()
      return
  # Fallback: resolve the main venue and delete by (user, venue).
  venue = None
  try:
      venue = _resolve_main_venue(instance.venue)
  except Exception:
      venue = None
  if venue is not None and instance.user_id:
      Wishlist.objects.filter(user_id=instance.user_id, venue=venue).delete()


@receiver(post_save, sender=Comment)
def sync_comment_to_tk1web(sender, instance: Comment, **kwargs):
  """Mirror comments to TK1Web's interaksi.Review for visibility across apps."""
  _sync_comment_to_tk1web_review(instance)


def _sync_comment_to_tk1web_review(comment: Comment, *, app_venue: Venue | None = None) -> None:
  """Upsert an interaksi.Review entry for the given app Comment."""
  if not comment.user:
      return

  if app_venue is None:
      link = comment.venue_links.select_related("venue").first()
      if not link:
          return
      app_venue = link.venue

  venue = _resolve_main_venue(app_venue)
  if venue is None:
      return

  Review = apps.get_model("interaksi", "Review")
  review, created = Review.objects.get_or_create(
      user=comment.user,
      venue=venue,
      defaults={"rating": comment.rating, "comment": comment.comment},
  )
  if not created:
      changed = False
      if review.rating != comment.rating:
          review.rating = comment.rating
          changed = True
      if review.comment != comment.comment:
          review.comment = comment.comment
          changed = True
      if changed:
          review.save(update_fields=["rating", "comment", "updated_at"])
  if comment.linked_review_id != review.pk:
      _update_instance_link(Comment, comment.pk, "linked_review_id", review.pk)


@receiver(post_save, sender=CommentVenue)
def sync_comment_venue_to_tk1web(sender, instance: CommentVenue, created: bool, **kwargs):
  """Ensure newly-linked comments are mirrored to the web Review model."""
  if not created:
      return
  _sync_comment_to_tk1web_review(instance.comment, app_venue=instance.venue)
