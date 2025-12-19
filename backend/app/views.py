from datetime import datetime
import json
from typing import Any

from django.contrib.auth import authenticate, get_user_model, login, logout
from django.contrib.auth.forms import AuthenticationForm
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.core.paginator import Paginator
from django.db.models import Avg, Case, CharField, Count, Q, Sum, Value, When
from django.db.models.functions import Cast, Coalesce, Concat
from django.http import HttpRequest, HttpResponse, HttpResponseForbidden, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt, ensure_csrf_cookie
from django.views.decorators.http import require_GET, require_POST, require_http_methods

from .forms import BookingForm, VenueForm
from .models import Venue, Booking, BookingDate, Profile, Comment, CommentVenue, WishlistEntry



def _json_request(request: HttpRequest):
    try:
        body_unicode = request.body.decode("utf-8") or "{}"
        return json.loads(body_unicode)
    except json.JSONDecodeError:
        return {}


def _parse_date(value: str | None):
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except (ValueError, TypeError):
        return None


def _parse_datetime(value: str | None):
    if not value:
        return None
    cleaned = value.strip()
    if cleaned.endswith("Z"):
        cleaned = cleaned[:-1] + "+00:00"
    formats = [
        "%Y-%m-%dT%H:%M%z",
        "%Y-%m-%d %H:%M%z",
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%d %H:%M:%S%z",
        "%Y-%m-%dT%H:%M",
        "%Y-%m-%d %H:%M",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d",
    ]
    dt = None
    for fmt in formats:
        try:
            dt = datetime.strptime(cleaned, fmt)
            break
        except (ValueError, TypeError):
            continue
    if dt is None:
        try:
            dt = datetime.fromisoformat(cleaned)
        except (ValueError, TypeError):
            return None
    if timezone.is_naive(dt):
        dt = timezone.make_aware(dt, timezone.get_current_timezone())
    return dt


def _absolute_media_url(request: HttpRequest, url: str | None) -> str:
    if not url:
        return ""
    if url.startswith("http://") or url.startswith("https://"):
        return url
    try:
        return request.build_absolute_uri(url)
    except Exception:
        return url


def _resolve_request_user_id(request: HttpRequest, payload: dict | None = None) -> int | None:
    if request.user.is_authenticated and request.user.id:
        return request.user.id
    payload = payload or {}
    candidate = payload.get("user_id")
    if candidate is None:
        candidate = request.GET.get("user_id")
    if candidate is None:
        return None
    try:
        return int(candidate)
    except (ValueError, TypeError):
        return None


def _normalize_addon_entries(raw: Any) -> list[dict[str, object]]:
    if not raw:
        return []
    if isinstance(raw, dict):
        items = [raw]
    elif isinstance(raw, (list, tuple)):
        items = raw
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


def _calculate_addons_total(addons: list[dict[str, object]]) -> int:
    total = 0
    for addon in addons:
        try:
            total += int(addon.get("price", 0))
        except (TypeError, ValueError, AttributeError):
            continue
    return max(total, 0)


def _select_valid_addons(requested: Any, available: Any) -> list[dict[str, object]]:
    normalized_available = _normalize_addon_entries(available)
    normalized_requested = _normalize_addon_entries(requested)
    if not normalized_available or not normalized_requested:
        return []
    matches: list[dict[str, object]] = []
    for candidate in normalized_requested:
        name = candidate["name"].lower()
        price = candidate["price"]
        match = next(
            (
                option
                for option in normalized_available
                if option["name"].lower() == name and option["price"] == price
            ),
            None,
        )
        if match:
            matches.append(match)
    return matches


def _serialize_booking(booking: Booking, *, request: HttpRequest | None = None):
    start = booking.date.start_date
    end = booking.date.end_date
    # Treat bookings as hour-based: compute total whole hours between
    # start and end, with a minimum of 1 hour.
    delta = end - start
    total_seconds = max(delta.total_seconds(), 0)
    hours = int(total_seconds // 3600)
    if hours <= 0:
        hours = 1
    selected_addons = _normalize_addon_entries(getattr(booking, "selected_addons", []))
    addons_total = _calculate_addons_total(selected_addons)
    image_url = booking.venue.image_url
    if not image_url and booking.venue.image:
        image_url = booking.venue.image.url
    absolute_image_url = _absolute_media_url(request, image_url) if request else image_url
    return {
        "id": booking.id,
        "venue": {
            "id": booking.venue.id,
            "title": booking.venue.title,
            "type": booking.venue.type,
            "price": booking.venue.price,
            "location": booking.venue.location,
            "description": booking.venue.description,
            "image_url": image_url,
            "image_absolute_url": absolute_image_url,
            "facilities": booking.venue.facilities,
            "addons": _normalize_addon_entries(getattr(booking.venue, "addons", [])),
        },
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "sessions": hours,
        "selected_addons": selected_addons,
        "addons_total": addons_total,
        "subtotal": hours * booking.venue.price + addons_total,
        "has_been_paid": booking.has_been_paid,
        "date_paid": booking.date_paid.isoformat() if booking.date_paid else None,
        "contact_phone": booking.contact_phone,
        "notes": booking.notes,
        "created_at": booking.created_at.isoformat(),
        "updated_at": booking.updated_at.isoformat(),
    }


def _serialize_wishlist_entry(entry: WishlistEntry, *, request: HttpRequest | None = None):
    venue = entry.venue
    image_url = venue.image_url
    if not image_url and venue.image:
        try:
            image_url = venue.image.url
        except (ValueError, AttributeError):
            image_url = ""
    absolute_image_url = _absolute_media_url(request, image_url)
    avg_rating = getattr(entry, "avg_rating", None)
    rating_value = float(avg_rating) if avg_rating is not None else None
    city = venue.location.split(",")[0].strip() if venue.location else ""
    return {
        "id": entry.id,
        "user_id": entry.user_id,
        "venue_id": entry.venue_id,
        "created_at": entry.created_at.isoformat(),
        "venue": {
            "id": venue.id,
            "title": venue.title,
            "type": venue.type,
            "description": venue.description,
            "location": venue.location,
            "city": city,
            "price": venue.price,
            "image_url": image_url,
            "image_absolute_url": absolute_image_url,
            "average_rating": rating_value,
            "addons": _normalize_addon_entries(getattr(venue, "addons", [])),
        },
    }


DEFAULT_PAGE_SIZE = 6
MAX_PAGE_SIZE = 50
DEMO_USERNAME_PREFIX = "demo."


def _serialize_comment(comment: Comment) -> dict[str, object]:
    first_link = comment.venue_links.first()
    venue_id = first_link.venue_id if first_link else None
    return {
        "id": comment.id,
        "venue_id": venue_id,
        "rating": comment.rating,
        "comment": comment.comment,
        "date": comment.date.isoformat(),
        "author": comment.user.get_username() if comment.user else "Anonim",
        "author_id": comment.user_id,
    }


@csrf_exempt
def register_view(request: HttpRequest):
    if request.method != "POST":
        return JsonResponse({"detail": "Method not allowed"}, status=405)

    payload = _json_request(request)
    username = (payload.get("username") or "").strip()
    password = payload.get("password") or ""
    email = (payload.get("email") or "").strip()

    if not username or not password:
        return JsonResponse({"detail": "username and password required"}, status=400)

    if User.objects.filter(username=username).exists():
        return JsonResponse({"detail": "username already exists"}, status=409)

    user = User.objects.create_user(username=username, password=password, email=email)
    login(request, user)
    return JsonResponse({"id": user.id, "username": user.username, "email": user.email})


@csrf_exempt
def login_view(request: HttpRequest):
    if request.method != "POST":
        return JsonResponse({"detail": "Method not allowed"}, status=405)

    payload = _json_request(request)
    username = (payload.get("username") or "").strip()
    password = payload.get("password") or ""

    user = authenticate(request, username=username, password=password)
    if user is None:
        return JsonResponse({"detail": "invalid credentials"}, status=401)

    login(request, user)
    return JsonResponse({"id": user.id, "username": user.username})


@csrf_exempt
def logout_view(request: HttpRequest):
    if request.method != "POST":
        return JsonResponse({"detail": "Method not allowed"}, status=405)
    logout(request)
    return JsonResponse({"detail": "logged out"})


def _get_or_create_profile(user):
    profile = getattr(user, "profile", None)
    if profile is None:
        profile, _ = Profile.objects.get_or_create(user=user)
    return profile


def _serialize_user_account(user, request: HttpRequest | None = None):
    profile = _get_or_create_profile(user)
    avatar_url = ""
    if profile.avatar:
        avatar_url = profile.avatar.url
        if request:
            avatar_url = request.build_absolute_uri(avatar_url)
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "avatar_url": avatar_url,
        "phone_number": profile.phone_number,
    }


def me_view(request: HttpRequest):
    if not request.user.is_authenticated:
        return JsonResponse({"authenticated": False})
    return JsonResponse({
        "authenticated": True,
        **_serialize_user_account(request.user, request=request),
    })


def top_venues_view(request: HttpRequest):
    try:
        limit = max(1, min(10, int(request.GET.get("limit", 3))))
    except (TypeError, ValueError):
        limit = 3

    queryset = (
        Venue.objects.annotate(
            avg_rating=Avg("comments__rating"),
            rating_count=Count("comments"),
        )
        .order_by("-avg_rating", "-rating_count", "-created_at")[:limit]
    )

    data = []
    for venue in queryset:
        avg_rating = venue.avg_rating or 0
        image_url = venue.image_url
        if not image_url and venue.image:
            try:
                image_url = venue.image.url
            except (ValueError, AttributeError):
                image_url = ""
        image_url = _absolute_media_url(request, image_url)
        data.append(
            {
                "id": venue.id,
                "title": venue.title,
                "type": venue.type,
                "location": venue.location,
                "price": venue.price,
                "description": venue.description,
                "facilities": venue.facilities,
                "addons": _normalize_addon_entries(getattr(venue, "addons", [])),
                "image_url": image_url,
                "avg_rating": round(float(avg_rating), 2),
                "rating_count": venue.rating_count,
            }
        )
    return JsonResponse(data, safe=False)


def venues_list_view(request: HttpRequest):
    queryset = _admin_base_venue_queryset().order_by("title")
    data = []
    for venue in queryset:
        image_url = venue.image_url
        if not image_url and venue.image:
            try:
                image_url = venue.image.url
            except (ValueError, AttributeError):
                image_url = ""
        image_url = _absolute_media_url(request, image_url)
        city = venue.location.split(",")[0].strip() if venue.location else ""
        data.append(
            {
                "id": venue.id,
                "title": venue.title,
                "type": venue.type,
                "description": venue.description,
                "location": venue.location,
                "city": city,
                "price": venue.price,
                "image_url": image_url,
                "addons": _normalize_addon_entries(getattr(venue, "addons", [])),
                "average_rating": float(venue.average_rating) if venue.average_rating is not None else None,
            }
        )
    return JsonResponse(data, safe=False)


@csrf_exempt
def account_detail_view(request: HttpRequest):
    if request.method != "GET":
        return JsonResponse({"detail": "Method not allowed"}, status=405)
    try:
        user_id = int(request.GET.get("user_id", ""))
    except (TypeError, ValueError):
        return JsonResponse({"detail": "user_id is required"}, status=400)
    user = get_object_or_404(User, pk=user_id)
    return JsonResponse({"success": True, "data": _serialize_user_account(user, request=request)})


@csrf_exempt
def account_update_view(request: HttpRequest):
    if request.method != "POST":
        return JsonResponse({"detail": "Method not allowed"}, status=405)
    try:
        user_id = int(request.POST.get("user_id", ""))
    except (TypeError, ValueError):
        return JsonResponse({"detail": "user_id is required"}, status=400)
    user = get_object_or_404(User, pk=user_id)

    username = (request.POST.get("username") or "").strip()
    email = (request.POST.get("email") or "").strip()
    first_name = (request.POST.get("first_name") or "").strip()
    last_name = (request.POST.get("last_name") or "").strip()

    if not username:
        return JsonResponse({"detail": "Username cannot be empty"}, status=400)
    if User.objects.exclude(pk=user.pk).filter(username=username).exists():
        return JsonResponse({"detail": "Username already taken"}, status=409)
    if email and User.objects.exclude(pk=user.pk).filter(email=email).exists():
        return JsonResponse({"detail": "Email already taken"}, status=409)

    user.username = username
    user.email = email
    user.first_name = first_name
    user.last_name = last_name
    user.save()

    profile = _get_or_create_profile(user)
    phone_number = (request.POST.get("phone_number") or "").strip()
    avatar = request.FILES.get("avatar")
    if avatar:
        profile.avatar = avatar
    profile.phone_number = phone_number
    profile.save()

    return JsonResponse({"success": True, "data": _serialize_user_account(user, request=request)})


@csrf_exempt
def account_password_view(request: HttpRequest):
    if request.method != "POST":
        return JsonResponse({"detail": "Method not allowed"}, status=405)
    payload = _json_request(request)
    try:
        user_id = int(payload.get("user_id"))
    except (TypeError, ValueError):
        return JsonResponse({"detail": "user_id is required"}, status=400)
    current_password = payload.get("current_password") or ""
    new_password = payload.get("new_password") or ""
    confirm_password = payload.get("confirm_password") or ""
    if not current_password or not new_password or not confirm_password:
        return JsonResponse({"detail": "All password fields are required"}, status=400)
    if new_password != confirm_password:
        return JsonResponse({"detail": "New passwords do not match"}, status=400)

    user = get_object_or_404(User, pk=user_id)
    if not user.check_password(current_password):
        return JsonResponse({"detail": "Current password is incorrect"}, status=400)

    user.set_password(new_password)
    user.save()
    return JsonResponse({"success": True})


@csrf_exempt
def booking_create_view(request: HttpRequest):
    if request.method == "GET":
        username_query = (request.GET.get("username") or "").strip()
        bookings = Booking.objects.select_related("venue", "date", "user").order_by("-created_at")
        user_filter = None
        if request.user.is_authenticated:
            user_filter = request.user
        elif username_query:
            UserModel = get_user_model()
            user_filter = UserModel.objects.filter(
                Q(username__iexact=username_query) | Q(email__iexact=username_query)
            ).first()

        if user_filter is not None:
            bookings = bookings.filter(user=user_filter)
        elif username_query:
            bookings = bookings.none()
        else:
            return JsonResponse([], safe=False)

        data = [_serialize_booking(booking, request=request) for booking in bookings]
        return JsonResponse(data, safe=False)
    if request.method != "POST":
        return JsonResponse({"detail": "Method not allowed"}, status=405)

    payload = _json_request(request)
    try:
        venue_id = int(payload.get("venue_id"))
    except (TypeError, ValueError):
        venue_id = None

    start_date = _parse_datetime(payload.get("start_date"))
    end_date = _parse_datetime(payload.get("end_date"))
    phone_number = (payload.get("phone_number") or "").strip()
    notes = (payload.get("notes") or "").strip()
    has_been_paid = bool(payload.get("has_been_paid", False))
    username_hint = (payload.get("username") or "").strip()
    requested_addons = payload.get("selected_addons") or []

    if not venue_id:
        return JsonResponse({"detail": "venue_id is required"}, status=400)
    if not phone_number:
        return JsonResponse({"detail": "phone_number is required"}, status=400)
    if not start_date or not end_date:
        return JsonResponse({"detail": "start_date and end_date required"}, status=400)
    if end_date <= start_date:
        return JsonResponse({"detail": "end_date must be after start_date"}, status=400)

    try:
        venue = Venue.objects.get(pk=venue_id)
    except Venue.DoesNotExist:
        return JsonResponse({"detail": "Venue not found"}, status=404)

    # Treat booking ranges as half-open intervals: [start_date, end_date).
    # Two ranges overlap only if existing.start_date < new_end_date
    # and existing.end_date > new_start_date. This makes the end
    # instant exclusive so back-to-back bookings are allowed.
    overlapping_exists = Booking.objects.filter(
        venue=venue,
        date__start_date__lt=end_date,
        date__end_date__gt=start_date,
    ).exists()
    if overlapping_exists:
        return JsonResponse(
            {
                "detail": (
                    "Tanggal yang dipilih sudah dibooking. "
                    "Pilih rentang lain yang tidak bertumpukan."
                )
            },
            status=409,
        )

    user = request.user if request.user.is_authenticated else None
    if user is None and username_hint:
        UserModel = get_user_model()
        try:
            user = UserModel.objects.get(username__iexact=username_hint)
        except UserModel.DoesNotExist:
            try:
                user = UserModel.objects.get(email__iexact=username_hint)
            except UserModel.DoesNotExist:
                user = None

    booking_range = BookingDate.objects.create(
        start_date=start_date,
        end_date=end_date,
    )
    selected_addons = _select_valid_addons(requested_addons, venue.addons)
    booking = Booking.objects.create(
        user=user,
        venue=venue,
        date=booking_range,
        contact_phone=phone_number,
        notes=notes,
        has_been_paid=has_been_paid,
        selected_addons=selected_addons,
    )
    return JsonResponse(_serialize_booking(booking, request=request), status=201)


@csrf_exempt
def booking_detail_view(request: HttpRequest, booking_id: int):
    if request.method == "GET":
        try:
            booking = Booking.objects.select_related("venue", "date").get(pk=booking_id)
        except Booking.DoesNotExist:
            return JsonResponse({"detail": "Booking not found"}, status=404)
        return JsonResponse(_serialize_booking(booking, request=request))
    if request.method == "DELETE":
        try:
            booking = Booking.objects.select_related("venue", "date").get(pk=booking_id)
        except Booking.DoesNotExist:
            return JsonResponse({"detail": "Booking not found"}, status=404)
        if booking.has_been_paid:
            return JsonResponse({"detail": "Cannot cancel a paid booking"}, status=409)
        booking.delete()
        return JsonResponse({"detail": "deleted"})
    return JsonResponse({"detail": "Method not allowed"}, status=405)


@csrf_exempt
@require_GET
def venue_availability_view(request: HttpRequest, venue_id: int):
    cutoff = timezone.now()
    include_history = request.GET.get("include_history") in ("1", "true", "True")
    bookings = (
        Booking.objects.filter(venue_id=venue_id)
        .select_related("date")
        .order_by("date__start_date")
    )
    if not include_history:
        bookings = bookings.filter(date__end_date__gte=cutoff)

    data: list[dict[str, object]] = []
    for booking in bookings:
        if not booking.date_id:
            continue
        data.append(
            {
                "id": booking.id,
                "start_date": booking.date.start_date.isoformat(),
                "end_date": booking.date.end_date.isoformat(),
                "has_been_paid": booking.has_been_paid,
            }
        )
    return JsonResponse({"success": True, "data": data})


@csrf_exempt
@require_http_methods(["GET", "POST", "DELETE"])
def wishlist_view(request: HttpRequest):
    payload = {} if request.method == "GET" else _json_request(request)
    user_id = _resolve_request_user_id(request, payload)
    if not user_id:
        return JsonResponse({"detail": "user_id is required"}, status=400)

    UserModel = get_user_model()
    try:
        user = UserModel.objects.get(pk=user_id)
    except UserModel.DoesNotExist:
        return JsonResponse({"detail": "User not found"}, status=404)

    def _extract_venue_id() -> int | None:
        value = payload.get("venue_id")
        if value is None:
            value = request.GET.get("venue_id")
        if value in (None, ""):
            return None
        try:
            return int(value)
        except (ValueError, TypeError):
            return None

    if request.method == "GET":
        entries = (
            WishlistEntry.objects.filter(user=user)
            .select_related("venue")
            .annotate(avg_rating=Avg("venue__comments__rating"))
            .order_by("-created_at")
        )
        data = [_serialize_wishlist_entry(entry, request=request) for entry in entries]
        return JsonResponse({"success": True, "data": data})

    venue_id = _extract_venue_id()
    if not venue_id:
        return JsonResponse({"detail": "venue_id is required"}, status=400)

    if request.method == "POST":
        venue = get_object_or_404(Venue, pk=venue_id)
        entry, created = WishlistEntry.objects.get_or_create(user=user, venue=venue)
        entry = (
            WishlistEntry.objects.filter(pk=entry.pk)
            .select_related("venue")
            .annotate(avg_rating=Avg("venue__comments__rating"))
            .first()
            or entry
        )
        data = _serialize_wishlist_entry(entry, request=request)
        status_code = 201 if created else 200
        return JsonResponse({"success": True, "data": data, "created": created}, status=status_code)

    deleted, _ = WishlistEntry.objects.filter(user=user, venue_id=venue_id).delete()
    if deleted == 0:
        return JsonResponse({"detail": "Wishlist entry not found"}, status=404)
    return JsonResponse({"success": True, "detail": "deleted"})


@csrf_exempt
@require_http_methods(["GET", "POST"])
def venue_reviews_view(request: HttpRequest, venue_id: int):
    venue = get_object_or_404(Venue, pk=venue_id)
    if request.method == "GET":
        comments = (
            Comment.objects.filter(venue_links__venue=venue)
            .exclude(user__username__startswith=DEMO_USERNAME_PREFIX)
            .select_related("user")
            .order_by("-date", "-id")
        )
        data = [_serialize_comment(comment) for comment in comments]
        return JsonResponse(data, safe=False)

    payload = _json_request(request)
    try:
        rating = int(payload.get("rating") or 0)
    except (ValueError, TypeError):
        rating = 0
    comment_text = (payload.get("comment") or "").strip()
    user = request.user if request.user.is_authenticated else None
    if user is None:
        user_id = _resolve_request_user_id(request, payload)
        username_hint = (payload.get("username") or "").strip()
        UserModel = get_user_model()
        if user_id:
            try:
                user = UserModel.objects.get(pk=user_id)
            except UserModel.DoesNotExist:
                user = None
        if user is None and username_hint:
            try:
                user = UserModel.objects.get(username__iexact=username_hint)
            except UserModel.DoesNotExist:
                user = None

    if not 1 <= rating <= 5:
        return JsonResponse({"detail": "Rating harus antara 1 sampai 5."}, status=400)
    if not comment_text:
        return JsonResponse({"detail": "Tulis ulasan terlebih dahulu."}, status=400)

    comment = Comment.objects.create(user=user, rating=rating, comment=comment_text)
    CommentVenue.objects.create(comment=comment, venue=venue)
    return JsonResponse(_serialize_comment(comment), status=201)


@csrf_exempt
@require_http_methods(["PUT", "PATCH", "DELETE"])
def venue_review_detail_view(request: HttpRequest, venue_id: int, review_id: int):
    venue = get_object_or_404(Venue, pk=venue_id)
    comment = get_object_or_404(
        Comment.objects.select_related("user").filter(id=review_id, venue_links__venue=venue)
    )
    payload = _json_request(request) if request.body else {}
    requester_id = _resolve_request_user_id(request, payload)

    if comment.user_id and requester_id != comment.user_id:
        return JsonResponse({"detail": "Tidak memiliki akses terhadap ulasan ini."}, status=403)

    if request.method in ("PUT", "PATCH"):
        try:
            rating = int(payload.get("rating") or comment.rating)
        except (ValueError, TypeError):
            rating = comment.rating
        comment_text = (payload.get("comment") or comment.comment).strip()
        if not 1 <= rating <= 5:
            return JsonResponse({"detail": "Rating harus antara 1 sampai 5."}, status=400)
        if not comment_text:
            return JsonResponse({"detail": "Tulis ulasan terlebih dahulu."}, status=400)
        comment.rating = rating
        comment.comment = comment_text
        comment.save(update_fields=["rating", "comment"])
        return JsonResponse(_serialize_comment(comment))

    comment.delete()
    return JsonResponse({"detail": "deleted"})


def _user_is_staff(user) -> bool:
    return bool(user and (user.is_staff or user.is_superuser))


def _admin_forbid_if_not_staff(request: HttpRequest) -> HttpResponse | None:
    if not _user_is_staff(request.user):
        return HttpResponseForbidden("You do not have permission to access this page.")
    return None


def _admin_serialize_user(user) -> dict[str, object] | None:
    if not user:
        return None
    full_name = (user.get_full_name() or "").strip()
    username = (user.get_username() or "").strip()
    email = (user.email or "").strip()
    display_name = full_name or username or email
    return {
        "id": user.id,
        "username": username,
        "full_name": full_name,
        "email": email,
        "display_name": display_name,
    }


def _booking_guest_label(booking: Booking) -> str:
    if booking.user:
        user = booking.user
        full_name = (user.get_full_name() or "").strip()
        username = (user.get_username() or "").strip()
        email = (user.email or "").strip()
        if full_name:
            tag = username or email
            return f"{full_name} ({tag})" if tag else full_name
        if username:
            return username
        if email:
            return email
    fallback = (booking.contact_phone or booking.notes or "").strip()
    if fallback:
        return fallback
    return f"Booking #{booking.id}"


def _admin_base_venue_queryset():
    return Venue.objects.annotate(
        average_rating=Avg("comments__rating"),
        rating_count=Count("comments", distinct=True),
    )


def _admin_serialize_venue(venue: Venue) -> dict[str, object]:
    image_url = venue.image_url
    if not image_url and venue.image:
        try:
            image_url = venue.image.url
        except (ValueError, AttributeError):
            image_url = ""
    raw_facilities = venue.facilities or []
    if isinstance(raw_facilities, (list, tuple)):
        facilities = [str(item).strip() for item in raw_facilities if str(item).strip()]
    elif isinstance(raw_facilities, str):
        facilities = [segment.strip() for segment in raw_facilities.split(",") if segment.strip()]
    else:
        facilities = []
    average_rating = getattr(venue, "average_rating", None)
    rating_count = getattr(venue, "rating_count", None)
    if average_rating is None or rating_count is None:
        aggregates = venue.comments.aggregate(
            average_rating=Avg("rating"),
            rating_count=Count("rating"),
        )
        average_rating = aggregates.get("average_rating")
        rating_count = aggregates.get("rating_count")
    return {
        "id": venue.id,
        "title": venue.title,
        "type": venue.type,
        "description": venue.description,
        "facilities": facilities,
        "addons": _normalize_addon_entries(getattr(venue, "addons", [])),
        "price": venue.price,
        "location": venue.location,
        "image_url": image_url,
        "created_at": venue.created_at.isoformat(),
        "updated_at": venue.updated_at.isoformat(),
        "average_rating": float(average_rating) if average_rating is not None else None,
        "rating_count": int(rating_count or 0),
    }


def _admin_serialize_booking(booking: Booking) -> dict[str, object]:
    user_payload = _admin_serialize_user(booking.user)
    top_username = ""
    top_email = ""
    if user_payload:
        top_username = user_payload.get("username") or ""
        top_email = user_payload.get("email") or ""
    contact_phone = (booking.contact_phone or "").strip()
    guest_label = _booking_guest_label(booking)
    selected_addons = _normalize_addon_entries(getattr(booking, "selected_addons", []))
    return {
        "id": booking.id,
        "username": top_username or top_email or contact_phone,
        "email": top_email,
        "guest_label": guest_label,
        "contact_phone": contact_phone,
        "user": user_payload,
        "venue": {
            "id": booking.venue_id,
            "title": booking.venue.title,
            "price": booking.venue.price,
            "location": booking.venue.location,
        },
        "selected_addons": selected_addons,
        "addons_total": _calculate_addons_total(selected_addons),
        "has_been_paid": booking.has_been_paid,
        "date_paid": booking.date_paid.isoformat() if booking.date_paid else None,
        "start_date": booking.date.start_date.isoformat(),
        "end_date": booking.date.end_date.isoformat(),
        "notes": booking.notes,
        "created_at": booking.created_at.isoformat(),
        "updated_at": booking.updated_at.isoformat(),
    }


def _admin_form_errors(form) -> list[str]:
    return [error for errors in form.errors.values() for error in errors]


def _parse_positive_int(value: str | None, default: int, *, max_value: int | None = None) -> int:
    try:
        parsed = int(value) if value is not None else default
    except (TypeError, ValueError):
        return default
    if parsed < 1:
        return default
    if max_value is not None and parsed > max_value:
        return max_value
    return parsed


def _apply_venue_search(queryset, query: str):
    if not query:
        return queryset
    trimmed = query.strip()
    if not trimmed:
        return queryset
    queryset = queryset.annotate(price_text=Cast("price", output_field=CharField()))
    filters = (
        Q(title__icontains=trimmed)
        | Q(type__icontains=trimmed)
        | Q(location__icontains=trimmed)
        | Q(description__icontains=trimmed)
        | Q(facilities__icontains=trimmed)
        | Q(price_text__icontains=trimmed)
    )
    return queryset.filter(filters)


def _apply_booking_search(queryset, query: str):
    if not query:
        return queryset
    trimmed = query.strip()
    if not trimmed:
        return queryset

    queryset = queryset.annotate(
        start_date_text=Cast("date__start_date", output_field=CharField()),
        end_date_text=Cast("date__end_date", output_field=CharField()),
        user_full_name=Concat(
            Coalesce("user__first_name", Value("")),
            Value(" "),
            Coalesce("user__last_name", Value("")),
        ),
        paid_text=Case(
            When(has_been_paid=True, then=Value("paid")),
            default=Value("pending"),
            output_field=CharField(),
        ),
    )

    filters = (
        Q(user__username__icontains=trimmed)
        | Q(user_full_name__icontains=trimmed)
        | Q(venue__title__icontains=trimmed)
        | Q(notes__icontains=trimmed)
        | Q(start_date_text__icontains=trimmed)
        | Q(end_date_text__icontains=trimmed)
        | Q(paid_text__icontains=trimmed)
    )
    return queryset.filter(filters)


def _build_paginated_payload(
    queryset,
    *,
    page: int,
    page_size: int,
    serializer,
    query: str,
    extra_meta: dict[str, object] | None = None,
):
    paginator = Paginator(queryset, page_size)
    page_obj = paginator.get_page(page)

    data = [serializer(item) for item in page_obj.object_list]
    meta: dict[str, object] = {
        "page": page_obj.number,
        "page_size": page_obj.paginator.per_page,
        "total_pages": page_obj.paginator.num_pages,
        "total_items": page_obj.paginator.count,
        "has_next": page_obj.has_next(),
        "has_previous": page_obj.has_previous(),
        "query": query.strip(),
    }
    if extra_meta:
        meta.update(extra_meta)
    return data, meta


def _build_booking_analytics() -> dict[str, dict[str, list]]:
    paid_bookings = Booking.objects.filter(has_been_paid=True, date_paid__isnull=False)

    sales_queryset = (
        paid_bookings.values("date_paid")
        .annotate(total_sales=Sum("venue__price"))
        .order_by("date_paid")
    )
    sales_labels: list[str] = []
    sales_totals: list[int] = []
    for item in sales_queryset:
        date_value = item.get("date_paid")
        if date_value is None:
            continue
        sales_labels.append(date_value.isoformat())
        sales_totals.append(int(item.get("total_sales") or 0))

    popularity_queryset = (
        paid_bookings.values("venue__title")
        .annotate(total_bookings=Count("id"))
        .order_by("venue__title")
    )
    popularity_labels: list[str] = []
    popularity_totals: list[int] = []
    for item in popularity_queryset:
        title = item.get("venue__title") or "Unknown venue"
        popularity_labels.append(title)
        popularity_totals.append(int(item.get("total_bookings") or 0))

    return {
        "sales": {"labels": sales_labels, "data": sales_totals},
        "popularity": {"labels": popularity_labels, "data": popularity_totals},
    }


@ensure_csrf_cookie
def admin_login_view(request: HttpRequest):
    if request.user.is_authenticated and request.user.is_staff:
        return redirect(request.GET.get("next") or "/admin/")

    form = AuthenticationForm(request, data=request.POST or None)
    error_message = None

    if request.method == "POST":
        if form.is_valid():
            user = form.get_user()
            if not user.is_staff:
                error_message = "Akun ini tidak memiliki akses ke Control Center."
            else:
                login(request, user)
                next_url = request.POST.get("next") or request.GET.get("next") or "/admin/"
                return redirect(next_url)
        else:
            error_message = "Username atau password salah."

    next_url = request.GET.get("next") or request.POST.get("next") or "/admin/"
    context = {"form": form, "error": error_message, "next": next_url}
    return render(request, "app/admin_login.html", context)


@login_required
@ensure_csrf_cookie
def admin_panel(request: HttpRequest):
    forbidden = _admin_forbid_if_not_staff(request)
    if forbidden:
        return forbidden

    venues_queryset = _admin_base_venue_queryset().order_by("title")
    total_venues = Venue.objects.count()
    venues_data, venues_meta = _build_paginated_payload(
        venues_queryset,
        page=1,
        page_size=DEFAULT_PAGE_SIZE,
        serializer=_admin_serialize_venue,
        query="",
        extra_meta={"total_available": total_venues},
    )

    bookings_queryset = (
        Booking.objects.select_related("venue", "date", "user")
        .exclude(user__username__startswith=DEMO_USERNAME_PREFIX)
        .order_by("-created_at", "-date__start_date")
    )
    analytics = _build_booking_analytics()
    UserModel = get_user_model()
    bookings_data, bookings_meta = _build_paginated_payload(
        bookings_queryset,
        page=1,
        page_size=DEFAULT_PAGE_SIZE,
        serializer=_admin_serialize_booking,
        query="",
        extra_meta={"has_users": UserModel.objects.exists(), "analytics": analytics},
    )

    context = {
        "venues": {"data": venues_data, "meta": venues_meta},
        "bookings": {"data": bookings_data, "meta": bookings_meta},
        "has_users": bookings_meta["has_users"],
        "analytics": analytics,
    }
    return render(request, "app/admin_panel.html", context)


@login_required
def admin_logout_view(request: HttpRequest):
    logout(request)
    return redirect("/admin/login/")


@login_required
@require_GET
def admin_venues_list_api(request: HttpRequest):
    forbidden = _admin_forbid_if_not_staff(request)
    if forbidden:
        return forbidden

    query = request.GET.get("q", "")
    page = _parse_positive_int(request.GET.get("page"), 1)
    page_size = _parse_positive_int(
        request.GET.get("page_size"),
        DEFAULT_PAGE_SIZE,
        max_value=MAX_PAGE_SIZE,
    )

    total_available = Venue.objects.count()
    queryset = _apply_venue_search(_admin_base_venue_queryset().order_by("title"), query)
    data, meta = _build_paginated_payload(
        queryset,
        page=page,
        page_size=page_size,
        serializer=_admin_serialize_venue,
        query=query,
        extra_meta={"total_available": total_available},
    )
    return JsonResponse({"success": True, "data": data, "meta": meta})


@login_required
@require_POST
def admin_venues_create_api(request: HttpRequest):
    forbidden = _admin_forbid_if_not_staff(request)
    if forbidden:
        return forbidden

    form = VenueForm(request.POST, request.FILES)
    if not form.is_valid():
        return JsonResponse({"success": False, "errors": _admin_form_errors(form)}, status=400)

    venue = form.save()
    return JsonResponse({"success": True, "data": _admin_serialize_venue(venue)})


@login_required
@require_POST
def admin_venues_update_api(request: HttpRequest, venue_id: int):
    forbidden = _admin_forbid_if_not_staff(request)
    if forbidden:
        return forbidden

    venue = get_object_or_404(Venue, pk=venue_id)
    form = VenueForm(request.POST, request.FILES, instance=venue)
    if not form.is_valid():
        return JsonResponse({"success": False, "errors": _admin_form_errors(form)}, status=400)

    venue = form.save()
    return JsonResponse({"success": True, "data": _admin_serialize_venue(venue)})


@login_required
@require_POST
def admin_venues_delete_api(request: HttpRequest, venue_id: int):
    forbidden = _admin_forbid_if_not_staff(request)
    if forbidden:
        return forbidden

    venue = get_object_or_404(Venue, pk=venue_id)
    venue.delete()
    return JsonResponse({"success": True})


@login_required
@require_GET
def admin_bookings_list_api(request: HttpRequest):
    forbidden = _admin_forbid_if_not_staff(request)
    if forbidden:
        return forbidden

    query = request.GET.get("q", "")
    page = _parse_positive_int(request.GET.get("page"), 1)
    page_size = _parse_positive_int(
        request.GET.get("page_size"),
        DEFAULT_PAGE_SIZE,
        max_value=MAX_PAGE_SIZE,
    )

    queryset = (
        Booking.objects.select_related("venue", "date", "user")
        .exclude(user__username__startswith=DEMO_USERNAME_PREFIX)
        .order_by("-created_at", "-date__start_date")
    )
    queryset = _apply_booking_search(queryset, query)
    analytics = _build_booking_analytics()
    UserModel = get_user_model()
    data, meta = _build_paginated_payload(
        queryset,
        page=page,
        page_size=page_size,
        serializer=_admin_serialize_booking,
        query=query,
        extra_meta={"has_users": UserModel.objects.exists(), "analytics": analytics},
    )
    return JsonResponse({"success": True, "data": data, "meta": meta})


@login_required
@require_POST
def admin_bookings_create_api(request: HttpRequest):
    forbidden = _admin_forbid_if_not_staff(request)
    if forbidden:
        return forbidden

    form = BookingForm(request.POST)
    if not form.is_valid():
        return JsonResponse({"success": False, "errors": _admin_form_errors(form)}, status=400)

    booking = form.save()
    return JsonResponse({"success": True, "data": _admin_serialize_booking(booking)})


@login_required
@require_POST
def admin_bookings_update_api(request: HttpRequest, booking_id: int):
    forbidden = _admin_forbid_if_not_staff(request)
    if forbidden:
        return forbidden

    booking = get_object_or_404(Booking.objects.select_related("date"), pk=booking_id)
    form = BookingForm(request.POST, instance=booking)
    if not form.is_valid():
        return JsonResponse({"success": False, "errors": _admin_form_errors(form)}, status=400)

    booking = form.save()
    return JsonResponse({"success": True, "data": _admin_serialize_booking(booking)})


@login_required
@require_POST
def admin_bookings_delete_api(request: HttpRequest, booking_id: int):
    forbidden = _admin_forbid_if_not_staff(request)
    if forbidden:
        return forbidden

    booking = get_object_or_404(Booking.objects.select_related("date"), pk=booking_id)
    if booking.date_id:
        booking.date.delete()
    booking.delete()
    return JsonResponse({"success": True})


@login_required
@require_GET
def admin_users_search_api(request: HttpRequest):
    forbidden = _admin_forbid_if_not_staff(request)
    if forbidden:
        return forbidden

    query = request.GET.get("q", "").strip()
    UserModel = get_user_model()

    if not query:
        results: list[dict[str, object]] = []
    else:
        results = [
            _admin_serialize_user(user)
            for user in UserModel.objects.filter(
                Q(username__icontains=query)
                | Q(email__icontains=query)
                | Q(first_name__icontains=query)
                | Q(last_name__icontains=query)
            ).order_by("username")[:10]
        ]

    return JsonResponse(
        {
            "success": True,
            "data": results,
            "meta": {"has_users": UserModel.objects.exists()},
        }
    )




