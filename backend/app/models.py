from __future__ import annotations

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone
from django.db.models.signals import post_save
from django.dispatch import receiver


class BookingDate(models.Model):
  start_date = models.DateField()
  end_date = models.DateField()

  class Meta:
      ordering = ["start_date", "end_date"]

  def __str__(self) -> str:
      return f"{self.start_date:%Y-%m-%d} → {self.end_date:%Y-%m-%d}"


class Venue(models.Model):
  class VenueType(models.TextChoices):
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
  price = models.PositiveIntegerField(validators=[MinValueValidator(0)])
  location = models.CharField(max_length=255)
  image = models.ImageField(upload_to="venues/", blank=True)
  image_url = models.URLField(blank=True)
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
      related_name="bookings",
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


class Profile(models.Model):
  user = models.OneToOneField(
      settings.AUTH_USER_MODEL, related_name="profile", on_delete=models.CASCADE
  )
  avatar = models.ImageField(upload_to="profiles/", blank=True)

  def __str__(self) -> str:
      return f"Profile for {self.user.get_username()}"


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_profile(sender, instance, created, **kwargs):
  if created:
      Profile.objects.get_or_create(user=instance)
