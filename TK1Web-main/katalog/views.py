"""User facing catalog views."""
from __future__ import annotations

from typing import Any

from django.contrib import messages
from django.apps import apps
from django.contrib.auth.decorators import login_required
from django.contrib.auth.mixins import LoginRequiredMixin
from django.forms.forms import NON_FIELD_ERRORS
from django.http import HttpRequest, HttpResponse, JsonResponse
from django.shortcuts import redirect
from django.urls import reverse
from django.utils.http import url_has_allowed_host_and_scheme
from django.utils.formats import number_format
from django.utils.text import Truncator
from django.views.decorators.http import require_GET
from django.views.generic import DetailView, ListView

from authentication.mixins import EnsureCsrfCookieMixin
from interaksi.forms import ReviewForm
from interaksi.models import Review, Wishlist
from manajemen_lapangan.models import Venue
from rent.forms import BookingForm
from rent.models import Booking

from .filters import VenueFilter


class CatalogView(EnsureCsrfCookieMixin, LoginRequiredMixin, ListView):
    model = Venue
    template_name = "katalog/catalog.html"
    context_object_name = "venues"
    paginate_by = 9

    def get_queryset(self):
        queryset = Venue.objects.select_related("category").prefetch_related("addons")
        self.filterset = VenueFilter(self.request.GET, queryset=queryset)
        return self.filterset.qs

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["filter"] = self.filterset
        context["wishlist_ids"] = set(
            Wishlist.objects.filter(user=self.request.user).values_list("venue_id", flat=True)
        )
        return context


def _serialise_filter_errors(filterset: VenueFilter) -> tuple[dict[str, list[str]], list[str]]:
    """Convert filter validation errors into a JSON serialisable structure."""

    error_data = filterset.form.errors.get_json_data()
    field_errors: dict[str, list[str]] = {}
    non_field_errors: list[str] = []

    for field, messages in error_data.items():
        parsed_messages = [
            message.get("message", "") for message in messages if message.get("message")
        ]
        if field == NON_FIELD_ERRORS:
            non_field_errors.extend(parsed_messages)
            continue
        field_errors[field] = parsed_messages

    return field_errors, non_field_errors


@login_required
@require_GET
def catalog_filter(request: HttpRequest) -> JsonResponse:
    queryset = Venue.objects.select_related("category").prefetch_related("addons")
    filterset = VenueFilter(request.GET, queryset=queryset)

    if not filterset.is_valid():
        field_errors, non_field_errors = _serialise_filter_errors(filterset)
        return JsonResponse(
            {
                "success": False,
                "message": "Invalid filter values submitted.",
                "errors": field_errors,
                "non_field_errors": non_field_errors,
            },
            status=400,
        )

    wishlist_ids = set(
        Wishlist.objects.filter(user=request.user).values_list("venue_id", flat=True)
    )
    rendered_cards = [
        {
            "id": venue.id,
            "name": venue.name,
            "city": venue.city,
            "price": str(venue.price_per_hour),
            "category": venue.category.name,
            "image_url": venue.image_url,
            "url": reverse("venue-detail", kwargs={"slug": venue.slug}),
            "description": Truncator(venue.description).chars(120),
            "wishlisted": venue.id in wishlist_ids,
            "toggle_url": reverse("wishlist-toggle-api", args=[venue.id]),
        }
        for venue in filterset.qs
    ]
    return JsonResponse(
        {
            "success": True,
            "count": len(rendered_cards),
            "venues": rendered_cards,
        }
    )


class VenueDetailView(EnsureCsrfCookieMixin, LoginRequiredMixin, DetailView):
    model = Venue
    template_name = "katalog/venue_detail.html"
    slug_field = "slug"
    context_object_name = "venue"

    def get_queryset(self):
        return (
            super()
            .get_queryset()
            .select_related("category")
            .prefetch_related("addons", "reviews__user")
        )

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        venue: Venue = context["venue"]
        can_book = not self.request.user.is_staff
        booking_form = None
        if can_book:
            booking_form = BookingForm(self.request.POST or None, venue=venue)

        # Backfill any legacy app-only comments that were created before the sync
        # pipeline stabilised (e.g. failed requests that left a Comment without a
        # linked Review). This ensures the web catalog displays the same reviews
        # as the mobile API.
        try:
            from app.models import Comment as AppComment  # type: ignore
            from app.models import Venue as AppVenue  # type: ignore
            from app.models import _sync_comment_to_tk1web_review  # type: ignore

            app_venue = (
                AppVenue.objects.filter(linked_venue_id=venue.pk).first()
                or AppVenue.objects.filter(title__iexact=venue.name).first()
            )
            if app_venue is not None:
                orphan_comments = (
                    AppComment.objects.filter(
                        venue_links__venue=app_venue,
                        linked_review_id__isnull=True,
                    )
                    .select_related("user")
                    .order_by("id")
                )
                for comment in orphan_comments:
                    _sync_comment_to_tk1web_review(comment, app_venue=app_venue)
        except Exception:
            pass

        review_form = ReviewForm(self.request.POST or None)
        addons = [
            {
                "id": str(addon.pk),
                "name": addon.name,
                "description": addon.description,
                "price_display": number_format(
                    addon.price,
                    decimal_pos=0,
                    use_l10n=True,
                    force_grouping=True,
                ),
            }
            for addon in venue.addons.all()
        ]
        context.update(
            {
                "booking_form": booking_form,
                "review_form": review_form,
                "can_book": can_book,
                "wishlist_ids": set(
                    Wishlist.objects.filter(user=self.request.user).values_list("venue_id", flat=True)
                ),
                "reviews": Review.objects.filter(venue=venue).select_related("user"),
                "available_addons": addons,
                "addon_lookup": {addon["id"]: addon for addon in addons},
            }
        )
        return context

    def _resolve_canonical_venue(self, venue: Venue) -> Venue:
        """Prefer the venue record that is linked to the mobile app (and has data).

        Some databases contain duplicate Venue rows with identical name/city but different slugs.
        This helper picks a single canonical record so reviews/bookings stay consistent between
        the mobile API and the website UI.
        """
        def pick_best(candidates):
            ids = list(candidates.values_list("id", flat=True))
            linked_ids: set[int] = set()
            try:
                AppVenue = apps.get_model("app", "Venue")
                linked_ids = set(
                    AppVenue.objects.filter(linked_venue_id__in=ids).values_list("linked_venue_id", flat=True)
                )
            except Exception:
                linked_ids = set()

            best = venue
            best_score: tuple[int, int, int, int, int] | None = None
            for candidate in candidates:
                score = (
                    1 if candidate.id in linked_ids else 0,
                    Review.objects.filter(venue=candidate).count(),
                    Booking.objects.filter(venue=candidate).count(),
                    Wishlist.objects.filter(venue=candidate).count(),
                    candidate.id,
                )
                if best_score is None or score > best_score:
                    best_score = score
                    best = candidate
            return best, linked_ids

        duplicates_same_city = (
            Venue.objects.filter(name__iexact=venue.name, city__iexact=venue.city)
            .only("id", "slug", "name", "city")
            .order_by("id")
        )
        if duplicates_same_city.count() > 1:
            best, _ = pick_best(duplicates_same_city)
            return best

        # If there's no same-city duplicate but there *are* other venues with the same name,
        # treat "empty + unlinked" rows as likely duplicates from old sync/seed runs and
        # redirect to the most populated / app-linked record.
        duplicates_same_name = (
            Venue.objects.filter(name__iexact=venue.name)
            .only("id", "slug", "name", "city")
            .order_by("id")
        )
        if duplicates_same_name.count() <= 1:
            return venue

        best, linked_ids = pick_best(duplicates_same_name)
        if best.pk == venue.pk:
            return venue

        is_linked = venue.pk in linked_ids
        has_any_data = (
            Review.objects.filter(venue=venue).exists()
            or Booking.objects.filter(venue=venue).exists()
            or Wishlist.objects.filter(venue=venue).exists()
        )
        if is_linked or has_any_data:
            return venue
        return best

    def get(self, request: HttpRequest, *args: Any, **kwargs: Any) -> HttpResponse:
        self.object = self.get_object()
        canonical = self._resolve_canonical_venue(self.object)
        if canonical.pk != self.object.pk:
            return redirect("venue-detail", slug=canonical.slug)
        context = self.get_context_data(object=self.object)
        return self.render_to_response(context)

    def post(self, request: HttpRequest, *args: Any, **kwargs: Any) -> HttpResponse:
        self.object = self.get_object()
        canonical = self._resolve_canonical_venue(self.object)
        if canonical.pk != self.object.pk:
            self.object = canonical
        if "delete_review" in request.POST:
            return self.handle_delete_review(request)
        if "submit_review" in request.POST:
            return self.handle_review(request)
        return self.handle_booking(request)

    def handle_delete_review(self, request: HttpRequest) -> HttpResponse:
        review_id = (request.POST.get("review_id") or "").strip()
        try:
            review_pk = int(review_id)
        except (TypeError, ValueError):
            review_pk = None
        if not review_pk:
            messages.error(request, "Unable to delete review.")
            return redirect("venue-detail", slug=self.object.slug)

        review = Review.objects.filter(pk=review_pk, user=request.user, venue=self.object).first()
        if review is None:
            messages.error(request, "Unable to delete review.")
            return redirect("venue-detail", slug=self.object.slug)

        review.delete()
        messages.success(request, "Your review has been deleted.")
        return redirect("venue-detail", slug=self.object.slug)

    def handle_review(self, request: HttpRequest) -> HttpResponse:
        review_id = (request.POST.get("review_id") or "").strip()
        review = None
        if review_id:
            try:
                review_pk = int(review_id)
            except (TypeError, ValueError):
                review_pk = None
            if review_pk:
                review = Review.objects.filter(pk=review_pk, user=request.user, venue=self.object).first()

        form = ReviewForm(request.POST, instance=review)
        if form.is_valid():
            review = form.save(commit=False)
            review.user = request.user
            review.venue = self.object
            review.save()
            messages.success(request, "Your review has been saved.")
        else:
            messages.error(request, "Unable to save review. Please check the form.")
        return redirect("venue-detail", slug=self.object.slug)

    def handle_booking(self, request: HttpRequest) -> HttpResponse:
        if request.user.is_staff:
            messages.error(
                request,
                "Administrators cannot create bookings. Please use a regular user account.",
            )
            return redirect("venue-detail", slug=self.object.slug)

        profile = getattr(request.user, "profile", None)
        phone_number = (getattr(profile, "phone_number", "") or "").strip()
        if not phone_number:
            messages.error(request, "Please add a phone number in your account settings before making a booking.")
            next_url = reverse("venue-detail", kwargs={"slug": self.object.slug})
            if url_has_allowed_host_and_scheme(next_url, allowed_hosts={request.get_host()}):
                return redirect(f"{reverse('authentication:profile')}?next={next_url}")
            return redirect("authentication:profile")

        form = BookingForm(request.POST, venue=self.object)
        if form.is_valid():
            booking: Booking = form.save(commit=False)
            booking.user = request.user
            booking.venue = self.object
            booking.save()
            form.save_m2m()
            messages.success(
                request,
                "Your booking request was submitted and is awaiting admin approval.",
            )
            return redirect("booked-places")
        messages.error(request, "Unable to create booking. Please check availability details.")
        return redirect("venue-detail", slug=self.object.slug)
