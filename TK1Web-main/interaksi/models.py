from __future__ import annotations

from django.apps import apps
from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver
from django.utils import timezone


class Wishlist(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="wishlists")
    venue = models.ForeignKey("manajemen_lapangan.Venue", on_delete=models.CASCADE, related_name="wishlisted_by")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("user", "venue")
        ordering = ["-created_at"]

    def __str__(self) -> str:  # pragma: no cover - trivial
        return f"{self.user} ❤ {self.venue}"


class Review(models.Model):
    """A review left by a user for a venue."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reviews")
    venue = models.ForeignKey("manajemen_lapangan.Venue", on_delete=models.CASCADE, related_name="reviews")
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:  # pragma: no cover - trivial
        return f"{self.user} rated {self.venue}"


def _resolve_app_venue_for_review(review: Review):
    AppVenue = apps.get_model("app", "Venue")
    app_venue = AppVenue.objects.filter(linked_venue_id=review.venue_id).first()
    if app_venue is not None:
        return app_venue

    name = (getattr(review.venue, "name", "") or "").strip()
    if name:
        app_venue = AppVenue.objects.filter(title__iexact=name).first()
        if app_venue is not None:
            return app_venue

    try:
        from app.sync import _ensure_app_venue_from_main  # type: ignore[attr-defined]
    except Exception:
        return None

    try:
        return _ensure_app_venue_from_main(review.venue)  # pragma: no cover - defensive
    except Exception:
        return None


@receiver(post_save, sender=Review)
def sync_review_to_app_comment(sender, instance: Review, **kwargs):
    """Mirror TK1Web reviews into the app Comment table so mobile/web stay in sync."""
    if getattr(instance, "_skip_app_comment_sync", False):
        return
    if not instance.user_id:
        return

    app_venue = _resolve_app_venue_for_review(instance)
    if app_venue is None:
        return

    Comment = apps.get_model("app", "Comment")
    CommentVenue = apps.get_model("app", "CommentVenue")

    comment = Comment.objects.filter(linked_review_id=instance.pk).first()
    if comment is None:
        desired_date = getattr(instance, "created_at", None)
        if desired_date:
            try:
                desired_date = desired_date.date()
            except Exception:
                desired_date = None
        desired_date = desired_date or timezone.localdate()
        comment = Comment.objects.create(
            user_id=instance.user_id,
            rating=int(instance.rating),
            comment=str(instance.comment or ""),
            date=desired_date,
            linked_review_id=instance.pk,
        )
    else:
        updates: list[str] = []
        if comment.user_id != instance.user_id:
            comment.user_id = instance.user_id
            updates.append("user")
        new_rating = int(instance.rating)
        if int(comment.rating) != new_rating:
            comment.rating = new_rating
            updates.append("rating")
        new_comment = str(instance.comment or "")
        if str(comment.comment or "") != new_comment:
            comment.comment = new_comment
            updates.append("comment")
        if comment.linked_review_id != instance.pk:
            comment.linked_review_id = instance.pk
            updates.append("linked_review_id")
        if updates:
            comment.save(update_fields=updates)

    CommentVenue.objects.get_or_create(comment=comment, venue=app_venue)


@receiver(post_delete, sender=Review)
def delete_review_from_app_comment(sender, instance: Review, **kwargs):
    """Remove the app Comment mirror when a TK1Web review is deleted."""
    Comment = apps.get_model("app", "Comment")
    Comment.objects.filter(linked_review_id=instance.pk).delete()