from datetime import datetime
import json

from django.contrib.auth import authenticate, get_user_model, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.core.paginator import Paginator
from django.db.models import Avg, Case, CharField, Count, Q, Sum, Value, When
from django.db.models.functions import Cast, Coalesce, Concat
from django.http import HttpRequest, HttpResponse, HttpResponseForbidden, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.csrf import csrf_exempt, ensure_csrf_cookie
from django.views.decorators.http import require_GET, require_POST

from .forms import BookingForm, VenueForm
from .models import Venue, Booking, BookingDate



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


def _serialize_booking(booking: Booking):
    start = booking.date.start_date
    end = booking.date.end_date
    sessions = (end - start).days + 1
    image_url = booking.venue.image_url
    if not image_url and booking.venue.image:
        image_url = booking.venue.image.url
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
            "facilities": booking.venue.facilities,
        },
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "sessions": sessions,
        "subtotal": sessions * booking.venue.price,
        "has_been_paid": booking.has_been_paid,
        "date_paid": booking.date_paid.isoformat() if booking.date_paid else None,
        "contact_phone": booking.contact_phone,
        "notes": booking.notes,
        "created_at": booking.created_at.isoformat(),
        "updated_at": booking.updated_at.isoformat(),
    }


DEFAULT_PAGE_SIZE = 6
MAX_PAGE_SIZE = 50
DEMO_USERNAME_PREFIX = "demo."


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


def me_view(request: HttpRequest):
    if not request.user.is_authenticated:
        return JsonResponse({"authenticated": False})
    user = request.user
    return JsonResponse({
        "authenticated": True,
        "id": user.id,
        "username": user.username,
        "email": user.email,
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
        data.append(
            {
                "id": venue.id,
                "title": venue.title,
                "type": venue.type,
                "location": venue.location,
                "price": venue.price,
                "description": venue.description,
                "facilities": venue.facilities,
                "image_url": venue.image_url,
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
        city = venue.location.split(",")[0].strip() if venue.location else ""
        data.append(
            {
                "id": venue.id,
                "title": venue.title,
                "type": venue.type,
                "location": venue.location,
                "city": city,
                "price": venue.price,
                "image_url": image_url,
                "average_rating": float(venue.average_rating) if venue.average_rating is not None else None,
            }
        )
    return JsonResponse(data, safe=False)


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

        data = [_serialize_booking(booking) for booking in bookings]
        return JsonResponse(data, safe=False)
    if request.method != "POST":
        return JsonResponse({"detail": "Method not allowed"}, status=405)

    payload = _json_request(request)
    try:
        venue_id = int(payload.get("venue_id"))
    except (TypeError, ValueError):
        venue_id = None

    start_date = _parse_date(payload.get("start_date"))
    end_date = _parse_date(payload.get("end_date"))
    phone_number = (payload.get("phone_number") or "").strip()
    notes = (payload.get("notes") or "").strip()
    has_been_paid = bool(payload.get("has_been_paid", False))
    username_hint = (payload.get("username") or "").strip()

    if not venue_id:
        return JsonResponse({"detail": "venue_id is required"}, status=400)
    if not phone_number:
        return JsonResponse({"detail": "phone_number is required"}, status=400)
    if not start_date or not end_date:
        return JsonResponse({"detail": "start_date and end_date required"}, status=400)
    if end_date < start_date:
        return JsonResponse({"detail": "end_date cannot be before start_date"}, status=400)

    try:
        venue = Venue.objects.get(pk=venue_id)
    except Venue.DoesNotExist:
        return JsonResponse({"detail": "Venue not found"}, status=404)

    overlapping_exists = Booking.objects.filter(
        venue=venue,
        date__start_date__lte=end_date,
        date__end_date__gte=start_date,
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
    booking = Booking.objects.create(
        user=user,
        venue=venue,
        date=booking_range,
        contact_phone=phone_number,
        notes=notes,
        has_been_paid=has_been_paid,
    )
    return JsonResponse(_serialize_booking(booking), status=201)


@csrf_exempt
def booking_detail_view(request: HttpRequest, booking_id: int):
    if request.method == "GET":
        try:
            booking = Booking.objects.select_related("venue", "date").get(pk=booking_id)
        except Booking.DoesNotExist:
            return JsonResponse({"detail": "Booking not found"}, status=404)
        return JsonResponse(_serialize_booking(booking))
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
    return {
        "id": venue.id,
        "title": venue.title,
        "type": venue.type,
        "description": venue.description,
        "facilities": facilities,
        "price": venue.price,
        "location": venue.location,
        "image_url": image_url,
        "created_at": venue.created_at.isoformat(),
        "updated_at": venue.updated_at.isoformat(),
        "average_rating": float(venue.average_rating) if venue.average_rating is not None else None,
        "rating_count": int(venue.rating_count or 0),
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
        .order_by("-date__start_date", "-created_at")
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
        .order_by("-date__start_date", "-created_at")
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




