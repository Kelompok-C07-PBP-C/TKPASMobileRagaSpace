"""Authentication views."""
from __future__ import annotations

from typing import Any

from django.contrib import messages
from django.contrib.auth import logout, update_session_auth_hash
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.views import LoginView
from django.contrib.auth.forms import PasswordChangeForm
from django.db.models import Count
from django.http import HttpRequest, HttpResponse, JsonResponse
from django.shortcuts import redirect, render
from django.urls import reverse, reverse_lazy
from django.utils.http import url_has_allowed_host_and_scheme
from django.views import View
from django.views.generic import FormView, TemplateView

from interaksi.models import Wishlist
from katalog.filters import VenueFilter
from manajemen_lapangan.models import Venue
from rent.models import Booking, Payment

from .forms import LoginForm, RegistrationForm, ProfileUpdateForm
from .mixins import AdminRequiredMixin, EnsureCsrfCookieMixin



class AuthLoginView(LoginView):
    template_name = "authentication/login.html"
    authentication_form = LoginForm

    def get_success_url(self) -> str:
        redirect_url = self.get_redirect_url()
        return redirect_url or reverse("home")

    def _wants_json(self) -> bool:
        request = self.request
        return request.headers.get("x-requested-with") == "XMLHttpRequest" or "application/json" in request.headers.get("Accept", "")

    def form_valid(self, form):
        response = super().form_valid(form)
        if self._wants_json():
            return JsonResponse({"success": True, "redirect_url": response["Location"]})
        return response

    def form_invalid(self, form):
        if self._wants_json():
            error_data = {
                field: [entry.get("message", "") for entry in messages]
                for field, messages in form.errors.get_json_data().items()
            }
            payload = {
                "success": False,
                "non_field_errors": error_data.pop("__all__", []),
                "errors": error_data,
            }
            return JsonResponse(payload, status=400)
        return super().form_invalid(form)


class AuthLogoutView(LoginRequiredMixin, View):
    """Log out the current user and redirect them to the homepage."""

    success_url = reverse_lazy("home")

    def _logout(self, request: HttpRequest) -> None:
        logout(request)
        messages.success(request, "You have been logged out successfully.")

    def post(self, request: HttpRequest, *args, **kwargs) -> HttpResponse:
        self._logout(request)
        return redirect(self.success_url)

    def get(self, request: HttpRequest, *args, **kwargs) -> HttpResponse:
        return self.post(request, *args, **kwargs)


class RegisterView(FormView):
    template_name = "authentication/register.html"
    form_class = RegistrationForm
    success_url = reverse_lazy("authentication:login")

    def form_valid(self, form):
        form.save()
        messages.success(self.request, "Registration successful. Please log in.")
        return super().form_valid(form)


class ProfileView(LoginRequiredMixin, TemplateView):
    template_name = "authentication/profile.html"

    def _resolve_next_url(self, request: HttpRequest) -> str:
        raw_next = (request.POST.get("next") or request.GET.get("next") or "").strip()
        if not raw_next:
            return ""
        if not url_has_allowed_host_and_scheme(raw_next, allowed_hosts={request.get_host()}):
            return ""
        return raw_next

    def _build_password_form(self, data=None) -> PasswordChangeForm:
        form = PasswordChangeForm(user=self.request.user, data=data)
        for field in form.fields.values():
            field.widget.attrs.setdefault(
                "class",
                "w-full rounded-xl border border-white/20 bg-white/10 px-4 py-3 text-white placeholder-white/60 focus:border-cyan-300 focus:ring-2 focus:ring-cyan-400/40 backdrop-blur",
            )
        return form

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context.update(
            {
                "profile_form": ProfileUpdateForm(instance=self.request.user),
                "password_form": self._build_password_form(),
                "next_url": self._resolve_next_url(self.request),
            }
        )
        return context

    def post(self, request: HttpRequest, *args: Any, **kwargs: Any) -> HttpResponse:
        next_url = self._resolve_next_url(request)
        if "update_profile" in request.POST:
            profile_form = ProfileUpdateForm(request.POST, request.FILES, instance=request.user)
            password_form = self._build_password_form()
            if profile_form.is_valid():
                profile_form.save()
                messages.success(request, "Profile updated successfully.")
                return redirect(next_url or "authentication:profile")
            messages.error(request, "Unable to update profile. Please check the form.")
        elif "change_password" in request.POST:
            password_form = self._build_password_form(data=request.POST)
            profile_form = ProfileUpdateForm(instance=request.user)
            if password_form.is_valid():
                user = password_form.save()
                update_session_auth_hash(request, user)
                messages.success(request, "Password updated successfully.")
                return redirect(next_url or "authentication:profile")
            messages.error(request, "Unable to update password. Please check the form.")
        else:
            profile_form = ProfileUpdateForm(instance=request.user)
            password_form = self._build_password_form()

        return render(
            request,
            self.template_name,
            {
                "profile_form": profile_form,
                "password_form": password_form,
                "next_url": next_url,
            },
        )


class HomeView(EnsureCsrfCookieMixin, TemplateView):
    template_name = "authentication/home.html"

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        venue_filter = VenueFilter(self.request.GET, queryset=Venue.objects.all())
        popular_venues = (
            Venue.objects.annotate(bookings_count=Count("bookings"))
            .order_by("-bookings_count", "-id")
            .prefetch_related("addons")[:3]
        )
        wishlist_ids: set[int] = set()
        if self.request.user.is_authenticated:
            wishlist_ids = set(
                Wishlist.objects.filter(user=self.request.user).values_list("venue_id", flat=True)
            )
        context.update(
            {
                "filter": venue_filter,
                "venues": venue_filter.qs[:6],
                "popular_venues": popular_venues,
                "wishlist_ids": wishlist_ids,
                "testimonials": [
                    {
                        "name": "Rindu Aurellia",
                        "role": "Koordinator Tim Futsal Anak Padi",
                        "image": "https://blogger.googleusercontent.com/img/a/AVvXsEha0jebkzt4VdaSYEd7LkT-ti2-zrf2MC5h6VjkSQNIf8x_6MgiJU6Qe3F7qF5F7mxXFXzTkSJoYhrf_YBy0rMEM-Hm8lg7iD063VW9TUvYaIhLVW5w_F5yUkZOfyPwG_gKp8ZEBKyyNLHDHrXXRuc5iEyTL4gUUIbdKHnenH50xaaPT6YmERUXZtneZlM",
                        "paragraphs": [
                            "Jujur, sebagai koordinator tim futsal 'Anak Padi', dulu saya yang paling stres setiap mau ngatur jadwal main. Prosesnya manual sekali: harus cari rekomendasi lapangan di Google, telepon atau WhatsApp adminnya satu-satu, lalu menunggu balasan mereka yang seringkali lama.",
                            "Sejak menemukan RagaSpace, semua masalah itu selesai. Aplikasinya benar-benar game-changer buat kami. Saya bisa lihat semua jadwal lapangan yang tersedia di sekitar kami secara real-time. Tinggal pilih jam, bayar, dan langsung dapat konfirmasi instan.",
                        ],
                    },
                    {
                        "name": "Tirta Siahaan",
                        "role": "Pelatih Basket SMA Bima",
                        "image": "https://media.licdn.com/dms/image/v2/D4D03AQFor0aXg96udw/profile-displayphoto-scale_200_200/B4DZlQXhWGGQAY-/0/1757989968230?e=2147483647&v=beta&t=UM9XUoFuSC0-yfgjVC8ASzxQ-XrizT4Ru3hFCg9N6A0",
                        "paragraphs": [
                            "RagaSpace bikin koordinasi latihan jadi jauh lebih gampang. Jadwalnya jelas dan bisa langsung saya bagi ke semua anak asuh lewat satu tautan.",
                            "Sebelumnya saya sering batalin latihan mendadak karena lapangan double booking. Sekarang semua terkontrol dengan notifikasi otomatisnya.",
                        ],
                    },
                    {
                        "name": "Shafa Aurelia",
                        "role": "Founder Komunitas Yoga Senja",
                        "image": "https://media.licdn.com/dms/image/v2/D4E03AQHvn66GQSiAXA/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1724491188800?e=1762992000&v=beta&t=OI7oxBqbH9YG8_ZxuzZsfoFfFa8QdH2i2fHIOhMVVjA",
                        "paragraphs": [
                            "Komunitas kami sering pindah venue, dan itu biasanya makan waktu untuk survei satu per satu. Lewat RagaSpace, saya bisa bandingkan fasilitas dengan cepat sebelum booking.",
                            "Pembayarannya praktis, ada invoice resmi, dan tim venue juga responsif karena sudah terintegrasi di sistem.",
                        ],
                    },
                    {
                        "name": "Bilqis Nisrina",
                        "role": "Marketing Manager Event Lokal",
                        "image": "https://media.licdn.com/dms/image/v2/D5603AQELb2yGe_q0JQ/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1724513244165?e=1762992000&v=beta&t=oGa9zAMXOcfxUd-hO3N2lBfYPh9OUZ54lklyGbagTik",
                        "paragraphs": [
                            "Kami sering gelar event komunitas, dan butuh venue yang bisa di-book jauh hari. RagaSpace kasih visibilitas penuh soal ketersediaan dan harga.",
                            "Tim supportnya juga proaktif, bantu negosiasi kebutuhan tambahan seperti sound system dan dekorasi.",
                        ],
                    },
                    {
                        "name": "RPM Dimaz",
                        "role": "Manajer Operasional Klub Badminton Orion",
                        "image": "https://media.licdn.com/dms/image/v2/D4E03AQHOOsQevd2tfA/profile-displayphoto-crop_800_800/B4EZh.F_LjGoAM-/0/1754462158131?e=1762992000&v=beta&t=M5UyV43yFFtaWP5q8NRyznSVA4WHuN1K5FcKtQMsnP4",
                        "paragraphs": [
                            "Dulu kami kesulitan memonitor jam sewa di semua lapangan. Sekarang, jadwal terpusat dan anggota klub bisa booking sesuai slot yang kami buka.",
                            "Laporan transaksi bulanannya rapi, jadi mudah untuk evaluasi performa lapangan dan promo membership.",
                        ],
                    },
                    {
                        "name": "Haekal Dinova",
                        "role": "Manajer Operasional Klub Badminton Orion",
                        "image": "https://media.licdn.com/dms/image/v2/D5603AQHMK1Sfeqx7TQ/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1724483982997?e=1762992000&v=beta&t=1-NFzYQQLxZbqPJP-UVUaAcNqYJUl1w1vlJEYGgeoZs",
                        "paragraphs": [
                            "Dulu kami kesulitan memonitor jam sewa di semua lapangan. Sekarang, jadwal terpusat dan anggota klub bisa booking sesuai slot yang kami buka.",
                            "Laporan transaksi bulanannya rapi, jadi mudah untuk evaluasi performa lapangan dan promo membership.",
                        ],
                    },
                ],
            }
        )
        return context


class UserLandingView(LoginRequiredMixin, TemplateView):
    template_name = "authentication/user_dashboard.html"

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context.update(
            {
                "active_bookings": Booking.objects.filter(
                    user=self.request.user,
                    status__in=[
                        Booking.STATUS_ACTIVE,
                        Booking.STATUS_CONFIRMED,
                        Booking.STATUS_COMPLETED,
                    ],
                ).select_related("venue"),
                "wishlist_count": Wishlist.objects.filter(user=self.request.user).count(),
            }
        )
        return context


class AdminLandingView(AdminRequiredMixin, LoginRequiredMixin, TemplateView):
    template_name = "authentication/admin_dashboard.html"

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context.update(
            {
                "total_venues": Venue.objects.count(),
                "pending_bookings": Booking.objects.filter(status=Booking.STATUS_PENDING).count(),
                "confirmed_payments": Payment.objects.filter(status="confirmed").count(),
            }
        )
        return context