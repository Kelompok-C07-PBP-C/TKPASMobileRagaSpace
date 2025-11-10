from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.db.models import Avg, Count
from django.http import JsonResponse, HttpRequest
from django.views.decorators.csrf import csrf_exempt
import json

from .models import Venue


def _json_request(request: HttpRequest):
    try:
        body_unicode = request.body.decode("utf-8") or "{}"
        return json.loads(body_unicode)
    except json.JSONDecodeError:
        return {}


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
