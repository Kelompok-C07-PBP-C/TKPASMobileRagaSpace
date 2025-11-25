import json
from datetime import datetime, timedelta, date

from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from django.core.exceptions import ValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.test import TestCase, Client, RequestFactory
from django.urls import reverse
from django.utils import timezone

from . import views, sample_data, forms as app_forms
from .models import (
    Venue,
    Booking,
    BookingDate,
    Comment,
    CommentVenue,
    WishlistEntry,
    Profile,
)

User = get_user_model()


class AuthApiTests(TestCase):
    def setUp(self):
        self.client = Client()

    def test_register_success_and_me(self):
        res = self.client.post(
            reverse('app:api-register'),
            data={"username": "alice", "password": "pass123", "email": "a@example.com"},
            content_type='application/json'
        )
        self.assertEqual(res.status_code, 200, res.content)
        data = res.json()
        self.assertEqual(data["username"], "alice")

        # now session should be authenticated
        me = self.client.get(reverse('app:api-me'))
        self.assertEqual(me.status_code, 200)
        self.assertTrue(me.json()["authenticated"]) 

    def test_register_duplicate_username(self):
        User.objects.create_user(username="bob", password="x")
        res = self.client.post(
            reverse('app:api-register'),
            data={"username": "bob", "password": "y"},
            content_type='application/json'
        )
        self.assertEqual(res.status_code, 409)

    def test_register_missing_fields(self):
        res = self.client.post(reverse('app:api-register'), data={}, content_type='application/json')
        self.assertEqual(res.status_code, 400)
        # invalid JSON also becomes missing fields
        res2 = self.client.post(reverse('app:api-register'), data='not-json', content_type='application/json')
        self.assertEqual(res2.status_code, 400)

    def test_login_success_and_logout(self):
        User.objects.create_user(username="carl", password="secret")
        res = self.client.post(
            reverse('app:api-login'),
            data={"username": "carl", "password": "secret"},
            content_type='application/json'
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["username"], "carl")

        # me should show authenticated
        me = self.client.get(reverse('app:api-me'))
        self.assertTrue(me.json()["authenticated"])

        # logout
        out = self.client.post(reverse('app:api-logout'))
        self.assertEqual(out.status_code, 200)
        me2 = self.client.get(reverse('app:api-me'))
        self.assertFalse(me2.json()["authenticated"])

    def test_login_invalid(self):
        res = self.client.post(
            reverse('app:api-login'),
            data={"username": "ghost", "password": "none"},
            content_type='application/json'
        )
        self.assertEqual(res.status_code, 401)

    def test_method_not_allowed(self):
        r1 = self.client.get(reverse('app:api-login'))
        self.assertEqual(r1.status_code, 405)
        r2 = self.client.get(reverse('app:api-register'))
        self.assertEqual(r2.status_code, 405)
        r3 = self.client.get(reverse('app:api-logout'))
        self.assertEqual(r3.status_code, 405)


class ViewHelpersTests(TestCase):
    def setUp(self):
        self.factory = RequestFactory()

    def test_parse_date_valid_and_invalid(self):
        parsed = views._parse_date("2024-01-02")
        self.assertEqual(parsed.year, 2024)
        self.assertEqual(parsed.month, 1)
        self.assertEqual(parsed.day, 2)

        self.assertIsNone(views._parse_date(None))
        self.assertIsNone(views._parse_date("not-a-date"))

    def test_parse_datetime_variants_and_invalid(self):
        parsed = views._parse_datetime("2024-01-02T03:04")
        self.assertIsNotNone(parsed)
        self.assertFalse(timezone.is_naive(parsed))

        parsed_with_timezone = views._parse_datetime("2024-01-02T03:04+0000")
        self.assertIsNotNone(parsed_with_timezone)

        self.assertIsNone(views._parse_datetime(""))
        self.assertIsNone(views._parse_datetime("invalid"))

    def test_absolute_media_url_variants(self):
        request = self.factory.get("/")

        empty_url = views._absolute_media_url(request, None)
        self.assertEqual(empty_url, "")

        absolute_url = views._absolute_media_url(request, "https://example.com/image.jpg")
        self.assertEqual(absolute_url, "https://example.com/image.jpg")

        relative_url = views._absolute_media_url(request, "/media/test.jpg")
        self.assertTrue(relative_url.endswith("/media/test.jpg"))

        class BrokenRequest:
            def build_absolute_uri(self, url):
                raise RuntimeError("boom")

        broken_request = BrokenRequest()
        broken_result = views._absolute_media_url(broken_request, "/media/test.jpg")
        self.assertEqual(broken_result, "/media/test.jpg")

    def test_resolve_request_user_id_precedence_and_invalid(self):
        user = User.objects.create_user(username="user1", password="x")
        authenticated_request = self.factory.get("/")
        authenticated_request.user = user
        self.assertEqual(views._resolve_request_user_id(authenticated_request), user.id)

        anonymous_request = self.factory.get("/?user_id=42")
        anonymous_request.user = AnonymousUser()
        self.assertEqual(views._resolve_request_user_id(anonymous_request), 42)

        payload_request = self.factory.get("/")
        payload_request.user = AnonymousUser()
        payload = {"user_id": "123"}
        self.assertEqual(views._resolve_request_user_id(payload_request, payload), 123)

        invalid_request = self.factory.get("/?user_id=abc")
        invalid_request.user = AnonymousUser()
        self.assertIsNone(views._resolve_request_user_id(invalid_request))

    def test_addon_helpers_and_serializers(self):
        raw_addons = [
            {"name": "Ball", "price": 100, "description": "Match ball"},
            {"name": " ", "price": 200},
            {"name": "Water", "price": -50},
            "invalid",
        ]
        normalized = views._normalize_addon_entries(raw_addons)
        self.assertEqual(len(normalized), 2)
        self.assertEqual(normalized[0]["name"], "Ball")
        self.assertEqual(normalized[1]["price"], 0)

        total = views._calculate_addons_total(normalized + [{"price": "not-int"}])
        self.assertEqual(total, 100)

        selected = [{"name": "ball", "price": 100}, {"name": "unknown", "price": 999}]
        valid_selected = views._select_valid_addons(selected, raw_addons)
        self.assertEqual(len(valid_selected), 1)
        self.assertEqual(valid_selected[0]["name"], "Ball")

        venue = Venue.objects.create(
            title="Court A",
            description="Nice court",
            facilities=["Wi-Fi"],
            addons=normalized,
            price=100,
            location="City",
            image_url="https://example.com/image.jpg",
            type=Venue.VenueType.FUTSAL,
        )
        booking_date = BookingDate.objects.create(
            start_date=timezone.now(),
            end_date=timezone.now() + timedelta(hours=2),
        )
        booking = Booking.objects.create(
            user=None,
            venue=venue,
            date=booking_date,
            contact_phone="0800",
            notes="note",
            has_been_paid=True,
            selected_addons=normalized,
        )
        serialized = views._serialize_booking(booking)
        self.assertEqual(serialized["venue"]["id"], venue.id)
        self.assertGreaterEqual(serialized["sessions"], 1)
        self.assertEqual(serialized["addons_total"], 100)

        wishlist_entry = WishlistEntry.objects.create(
            user=User.objects.create_user("wish", password="x"),
            venue=venue,
        )
        serialized_wishlist = views._serialize_wishlist_entry(wishlist_entry)
        self.assertEqual(serialized_wishlist["venue"]["id"], venue.id)

        comment = Comment.objects.create(user=None, rating=4, comment="Good")
        CommentVenue.objects.create(comment=comment, venue=venue)
        serialized_comment = views._serialize_comment(comment)
        self.assertEqual(serialized_comment["rating"], 4)


class FormsHelpersTests(TestCase):
    def test_split_facilities_variants(self):
        self.assertEqual(app_forms._split_facilities(None), [])
        self.assertEqual(app_forms._split_facilities([]), [])
        self.assertEqual(
            app_forms._split_facilities("Wi-Fi, Parking, , Snacks"),
            ["Wi-Fi", "Parking", "Snacks"],
        )
        self.assertEqual(
            app_forms._split_facilities(["Wi-Fi", "", "Parking"]),
            ["Wi-Fi", "Parking"],
        )

    def test_parse_addons_and_filter_selected(self):
        raw = json.dumps(
            [
                {"name": "Ball", "price": 100, "description": "Match ball"},
                {"name": "Water", "price": -50, "description": "Bottle"},
                {"name": "", "price": 20},
            ]
        )
        parsed = app_forms._parse_addons(raw)
        self.assertEqual(len(parsed), 2)
        self.assertEqual(parsed[0]["price"], 100)
        self.assertEqual(parsed[1]["price"], 0)

        available = [
            {"name": "Ball", "price": 100, "description": ""},
            {"name": "Water", "price": 0, "description": ""},
        ]
        selected = [{"name": "ball", "price": 100}, {"name": "water", "price": 0}]
        filtered = app_forms._filter_selected_addons(selected, available)
        self.assertEqual(len(filtered), 2)

        self.assertEqual(app_forms._filter_selected_addons([], available), [])
        self.assertEqual(app_forms._filter_selected_addons(selected, None), [])

        with self.assertRaises(ValidationError):
            app_forms._parse_addons("not-json")

        mixed_available = [
            {"name": "Snack", "price": "invalid", "description": ""},
            "not-a-dict",
            {"name": "", "price": 10, "description": ""},
        ]
        mixed_selected = [
            {"name": "", "price": 10},
            {"name": "Snack", "price": "invalid"},
        ]
        filtered_mixed = app_forms._filter_selected_addons(mixed_selected, mixed_available)
        self.assertEqual(len(filtered_mixed), 1)

        self.assertEqual(app_forms._parse_addons(123), [])
        parsed_list = app_forms._parse_addons(
            [{"name": "Extra", "price": "invalid", "description": ""}, "not-dict"]
        )
        self.assertEqual(len(parsed_list), 1)
        self.assertEqual(parsed_list[0]["price"], 0)

        available_negative = [{"name": "Ball", "price": -5, "description": ""}]
        selected_negative = [{"name": "Ball", "price": 0}]
        filtered_negative = app_forms._filter_selected_addons(selected_negative, available_negative)
        self.assertEqual(filtered_negative[0]["price"], 0)


class BookingFormTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="formuser",
            email="form@example.com",
            password="x",
        )
        self.venue = Venue.objects.create(
            title="Form Venue",
            description="Desc",
            facilities=[],
            addons=[{"name": "Ball", "price": 100, "description": "Match ball"}],
            price=100,
            location="City",
            image_url="",
            type=Venue.VenueType.FUTSAL,
        )

    def test_booking_form_validation_and_save(self):
        start = timezone.now()
        end = start + timedelta(hours=2)
        form = app_forms.BookingForm(
            data={
                "username": self.user.username,
                "venue": self.venue.id,
                "has_been_paid": True,
                "notes": "note",
                "start_date": start.strftime("%Y-%m-%dT%H:%M"),
                "end_date": end.strftime("%Y-%m-%dT%H:%M"),
                "selected_addons": json.dumps([{"name": "Ball", "price": 100}]),
            }
        )
        self.assertTrue(form.is_valid(), form.errors)
        booking = form.save()
        self.assertIsNotNone(booking.date_id)
        self.assertEqual(len(booking.selected_addons), 1)
        self.assertEqual(booking.user, self.user)

    def test_booking_form_invalid_end_date_and_missing_user(self):
        User.objects.all().delete()
        start = timezone.now()
        end = start - timedelta(hours=1)
        form = app_forms.BookingForm(
            data={
                "username": "",
                "venue": self.venue.id,
                "has_been_paid": False,
                "notes": "",
                "start_date": start.strftime("%Y-%m-%dT%H:%M"),
                "end_date": end.strftime("%Y-%m-%dT%H:%M"),
            }
        )
        self.assertFalse(form.is_valid())

    def test_booking_form_username_not_found_error(self):
        User.objects.create_user(username="other", email="other@example.com", password="y")
        start = timezone.now()
        end = start + timedelta(hours=1)
        form = app_forms.BookingForm(
            data={
                "username": "unknown-user",
                "venue": self.venue.id,
                "has_been_paid": False,
                "notes": "",
                "start_date": start.strftime("%Y-%m-%dT%H:%M"),
                "end_date": end.strftime("%Y-%m-%dT%H:%M"),
            }
        )
        self.assertFalse(form.is_valid())
        self.assertIn("username", form.errors)

    def test_booking_form_selected_addons_empty_for_venue_without_addons(self):
        venue_no_addons = Venue.objects.create(
            title="No Addons Venue",
            description="Desc",
            facilities=[],
            addons=[],
            price=200,
            location="City",
            image_url="",
            type=Venue.VenueType.FUTSAL,
        )
        start = timezone.now()
        end = start + timedelta(hours=1)
        form = app_forms.BookingForm(
            data={
                "username": self.user.username,
                "venue": venue_no_addons.id,
                "has_been_paid": False,
                "notes": "",
                "start_date": start.strftime("%Y-%m-%dT%H:%M"),
                "end_date": end.strftime("%Y-%m-%dT%H:%M"),
                "selected_addons": json.dumps([{"name": "Ball", "price": 100}]),
            }
        )
        self.assertTrue(form.is_valid(), form.errors)
        booking = form.save()
        self.assertEqual(booking.selected_addons, [])

    def test_booking_form_clean_converts_naive_and_requires_existing_user(self):
        User.objects.all().delete()
        naive_start = datetime(2024, 1, 1, 10, 0, 0)
        naive_end = datetime(2024, 1, 1, 12, 0, 0)
        form = app_forms.BookingForm()
        form.instance = Booking()
        form.cleaned_data = {
            "start_date": naive_start,
            "end_date": naive_end,
            "user": None,
            "venue": self.venue,
            "username": "",
            "selected_addons": "[]",
        }
        with self.assertRaises(ValidationError):
            form.clean()

    def test_booking_form_save_commit_false_and_invalid_range_raises(self):
        start = timezone.now()
        end = start + timedelta(hours=1)
        form = app_forms.BookingForm(
            data={
                "username": self.user.username,
                "venue": self.venue.id,
                "has_been_paid": False,
                "notes": "",
                "start_date": start.strftime("%Y-%m-%dT%H:%M"),
                "end_date": end.strftime("%Y-%m-%dT%H:%M"),
                "selected_addons": json.dumps([]),
            }
        )
        self.assertTrue(form.is_valid(), form.errors)

        booking_unsaved = form.save(commit=False)
        self.assertIsNotNone(booking_unsaved.date)
        self.assertIsNone(booking_unsaved.date.id)

        form.cleaned_data["start_date"], form.cleaned_data["end_date"] = end, start
        with self.assertRaises(ValidationError):
            form.save()


class ModelsTests(TestCase):
    def test_model_str_and_booking_save_logic_and_profile_signal(self):
        user = User.objects.create_user(username="modeluser", password="x")
        venue = Venue.objects.create(
            title="Model Venue",
            description="Desc",
            facilities=[],
            addons=[],
            price=100,
            location="City",
            image_url="",
            type=Venue.VenueType.FUTSAL,
        )
        booking_date = BookingDate.objects.create(
            start_date=timezone.now(),
            end_date=timezone.now() + timedelta(hours=1),
        )
        booking = Booking.objects.create(
            user=user,
            venue=venue,
            has_been_paid=False,
            date=booking_date,
            notes="",
            contact_phone="",
        )
        self.assertIn("Booking for", str(booking))
        self.assertIsNone(booking.date_paid)

        booking.has_been_paid = True
        booking.save()
        self.assertIsNotNone(booking.date_paid)

        comment = Comment.objects.create(user=user, rating=5, comment="Nice")
        self.assertIn("Comment by", str(comment))

        wishlist_entry = WishlistEntry.objects.create(user=user, venue=venue)
        self.assertIn("WishlistEntry(", str(wishlist_entry))

        profile = Profile.objects.get(user=user)
        self.assertIn("Profile for", str(profile))


class TopVenuesAndListViewTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.venue_one = Venue.objects.create(
            title="Venue One",
            description="Desc",
            facilities=["Wi-Fi"],
            addons=[{"name": "Ball", "price": 100, "description": ""}],
            price=100,
            location="City A",
            image_url="https://example.com/v1.jpg",
            type=Venue.VenueType.FUTSAL,
        )
        self.venue_two = Venue.objects.create(
            title="Venue Two",
            description="Desc",
            facilities=["Parking"],
            addons=[],
            price=200,
            location="City B",
            image_url="",
            type=Venue.VenueType.BADMINTON,
        )
        Comment.objects.create(user=None, rating=5, comment="Great").venue.add(self.venue_one)
        Comment.objects.create(user=None, rating=3, comment="Ok").venue.add(self.venue_two)

    def test_top_venues_default_and_invalid_limit(self):
        response = self.client.get(reverse("app:api-top-venues"))
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertGreaterEqual(len(data), 2)

        invalid_limit_response = self.client.get(
            reverse("app:api-top-venues"),
            {"limit": "invalid"},
        )
        self.assertEqual(invalid_limit_response.status_code, 200)

    def test_venues_list_view(self):
        response = self.client.get(reverse("app:api-venues"))
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 2)
        cities = {item["city"] for item in data}
        self.assertIn("City A", cities)


class AccountViewsTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user(
            username="accountuser",
            password="x",
            email="acc@example.com",
            first_name="First",
            last_name="Last",
        )

    def test_account_detail_and_update_and_password_flow(self):
        response_invalid_method = self.client.post(reverse("app:api-account-detail"))
        self.assertEqual(response_invalid_method.status_code, 405)

        response_missing_id = self.client.get(reverse("app:api-account-detail"))
        self.assertEqual(response_missing_id.status_code, 400)

        response_detail = self.client.get(
            reverse("app:api-account-detail"),
            {"user_id": self.user.id},
        )
        self.assertEqual(response_detail.status_code, 200)

        response_update_invalid = self.client.get(reverse("app:api-account-update"))
        self.assertEqual(response_update_invalid.status_code, 405)

        response_update_missing_id = self.client.post(reverse("app:api-account-update"))
        self.assertEqual(response_update_missing_id.status_code, 400)

        response_update_empty_username = self.client.post(
            reverse("app:api-account-update"),
            {"user_id": self.user.id, "username": ""},
        )
        self.assertEqual(response_update_empty_username.status_code, 400)

        User.objects.create_user(username="other", email="other@example.com", password="y")
        response_username_taken = self.client.post(
            reverse("app:api-account-update"),
            {
                "user_id": self.user.id,
                "username": "other",
                "email": "acc@example.com",
            },
        )
        self.assertEqual(response_username_taken.status_code, 409)

        response_email_taken = self.client.post(
            reverse("app:api-account-update"),
            {
                "user_id": self.user.id,
                "username": "accountuser",
                "email": "other@example.com",
            },
        )
        self.assertEqual(response_email_taken.status_code, 409)

        avatar_file = SimpleUploadedFile("avatar.jpg", b"filecontent", content_type="image/jpeg")
        response_update_ok = self.client.post(
            reverse("app:api-account-update"),
            {
                "user_id": self.user.id,
                "username": "updateduser",
                "email": "new@example.com",
                "first_name": "New",
                "last_name": "Name",
                "phone_number": "123",
            },
            FILES={"avatar": avatar_file},
        )
        self.assertEqual(response_update_ok.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.username, "updateduser")

        response_password_invalid_method = self.client.get(reverse("app:api-account-password"))
        self.assertEqual(response_password_invalid_method.status_code, 405)

        password_payload_missing_id = {
            "current_password": "old",
            "new_password": "new",
            "confirm_password": "new",
        }
        response_password_missing_id = self.client.post(
            reverse("app:api-account-password"),
            data=json.dumps(password_payload_missing_id),
            content_type="application/json",
        )
        self.assertEqual(response_password_missing_id.status_code, 400)

        password_payload_missing_fields = {"user_id": self.user.id}
        response_password_missing_fields = self.client.post(
            reverse("app:api-account-password"),
            data=json.dumps(password_payload_missing_fields),
            content_type="application/json",
        )
        self.assertEqual(response_password_missing_fields.status_code, 400)

        password_payload_mismatch = {
            "user_id": self.user.id,
            "current_password": "x",
            "new_password": "newpw",
            "confirm_password": "other",
        }
        response_password_mismatch = self.client.post(
            reverse("app:api-account-password"),
            data=json.dumps(password_payload_mismatch),
            content_type="application/json",
        )
        self.assertEqual(response_password_mismatch.status_code, 400)

        password_payload_wrong_current = {
            "user_id": self.user.id,
            "current_password": "wrong",
            "new_password": "newpw",
            "confirm_password": "newpw",
        }
        response_password_wrong_current = self.client.post(
            reverse("app:api-account-password"),
            data=json.dumps(password_payload_wrong_current),
            content_type="application/json",
        )
        self.assertEqual(response_password_wrong_current.status_code, 400)

        password_payload_ok = {
            "user_id": self.user.id,
            "current_password": "x",
            "new_password": "newpw",
            "confirm_password": "newpw",
        }
        response_password_ok = self.client.post(
            reverse("app:api-account-password"),
            data=json.dumps(password_payload_ok),
            content_type="application/json",
        )
        self.assertEqual(response_password_ok.status_code, 200)


class BookingViewsTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user(
            username="bookuser",
            password="x",
            email="book@example.com",
        )
        self.venue = Venue.objects.create(
            title="Book Venue",
            description="Desc",
            facilities=[],
            addons=[{"name": "Ball", "price": 100, "description": ""}],
            price=150,
            location="City",
            image_url="",
            type=Venue.VenueType.FUTSAL,
        )

    def _create_booking(self, start, end, has_been_paid=False):
        booking_date = BookingDate.objects.create(start_date=start, end_date=end)
        return Booking.objects.create(
            user=self.user,
            venue=self.venue,
            has_been_paid=has_been_paid,
            date=booking_date,
            notes="",
            contact_phone="123",
        )

    def test_booking_create_get_variants(self):
        now = timezone.now()
        self._create_booking(now, now + timedelta(hours=1))

        self.client.force_login(self.user)
        response_authenticated = self.client.get(reverse("app:api-booking-create"))
        self.assertEqual(response_authenticated.status_code, 200)
        self.assertGreaterEqual(len(response_authenticated.json()), 1)

        self.client.logout()
        response_username = self.client.get(
            reverse("app:api-booking-create"),
            {"username": self.user.username},
        )
        self.assertEqual(response_username.status_code, 200)

        response_unknown_username = self.client.get(
            reverse("app:api-booking-create"),
            {"username": "unknown"},
        )
        self.assertEqual(response_unknown_username.status_code, 200)
        self.assertEqual(response_unknown_username.json(), [])

        response_no_filter = self.client.get(reverse("app:api-booking-create"))
        self.assertEqual(response_no_filter.status_code, 200)
        self.assertEqual(response_no_filter.json(), [])

    def test_booking_create_post_validation_and_success(self):
        payload_missing_all = {
            "venue_id": None,
            "start_date": None,
            "end_date": None,
            "phone_number": "",
        }
        response_missing_all = self.client.post(
            reverse("app:api-booking-create"),
            data=json.dumps(payload_missing_all),
            content_type="application/json",
        )
        self.assertEqual(response_missing_all.status_code, 400)

        now = timezone.now()
        payload_bad_dates = {
            "venue_id": self.venue.id,
            "start_date": (now + timedelta(hours=2)).isoformat(),
            "end_date": now.isoformat(),
            "phone_number": "123",
        }
        response_bad_dates = self.client.post(
            reverse("app:api-booking-create"),
            data=json.dumps(payload_bad_dates),
            content_type="application/json",
        )
        self.assertEqual(response_bad_dates.status_code, 400)

        payload_unknown_venue = {
            "venue_id": 9999,
            "start_date": now.isoformat(),
            "end_date": (now + timedelta(hours=2)).isoformat(),
            "phone_number": "123",
        }
        response_unknown_venue = self.client.post(
            reverse("app:api-booking-create"),
            data=json.dumps(payload_unknown_venue),
            content_type="application/json",
        )
        self.assertEqual(response_unknown_venue.status_code, 404)

        start = now
        end = now + timedelta(hours=2)
        self._create_booking(start + timedelta(minutes=30), end + timedelta(minutes=30))
        overlapping_payload = {
            "venue_id": self.venue.id,
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "phone_number": "123",
        }
        response_overlapping = self.client.post(
            reverse("app:api-booking-create"),
            data=json.dumps(overlapping_payload),
            content_type="application/json",
        )
        self.assertEqual(response_overlapping.status_code, 409)

        non_overlapping_payload = {
            "venue_id": self.venue.id,
            "start_date": (end + timedelta(hours=1)).isoformat(),
            "end_date": (end + timedelta(hours=2)).isoformat(),
            "phone_number": "123",
            "selected_addons": [{"name": "Ball", "price": 100}],
            "has_been_paid": True,
        }
        response_ok = self.client.post(
            reverse("app:api-booking-create"),
            data=json.dumps(non_overlapping_payload),
            content_type="application/json",
        )
        self.assertEqual(response_ok.status_code, 201)
        data = response_ok.json()
        self.assertTrue(data["has_been_paid"])

    def test_booking_detail_get_delete_and_method_not_allowed(self):
        now = timezone.now()
        booking = self._create_booking(now, now + timedelta(hours=1))

        response_get = self.client.get(reverse("app:api-booking-detail", args=[booking.id]))
        self.assertEqual(response_get.status_code, 200)

        response_get_missing = self.client.get(reverse("app:api-booking-detail", args=[9999]))
        self.assertEqual(response_get_missing.status_code, 404)

        booking.has_been_paid = True
        booking.save()
        response_delete_paid = self.client.delete(
            reverse("app:api-booking-detail", args=[booking.id])
        )
        self.assertEqual(response_delete_paid.status_code, 409)

        booking.has_been_paid = False
        booking.save()
        response_delete = self.client.delete(
            reverse("app:api-booking-detail", args=[booking.id])
        )
        self.assertEqual(response_delete.status_code, 200)

        response_invalid_method = self.client.post(
            reverse("app:api-booking-detail", args=[booking.id])
        )
        self.assertEqual(response_invalid_method.status_code, 405)

    def test_venue_availability_view(self):
        now = timezone.now()
        past_start = now - timedelta(days=2)
        past_end = now - timedelta(days=1)
        future_start = now + timedelta(days=1)
        future_end = now + timedelta(days=2)
        self._create_booking(past_start, past_end)
        self._create_booking(future_start, future_end)

        response_default = self.client.get(
            reverse("app:api-venue-availability", args=[self.venue.id])
        )
        data_default = response_default.json()["data"]
        self.assertEqual(len(data_default), 1)

        response_all = self.client.get(
            reverse("app:api-venue-availability", args=[self.venue.id]),
            {"include_history": "1"},
        )
        data_all = response_all.json()["data"]
        self.assertEqual(len(data_all), 2)


class WishlistAndReviewViewsTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user(username="wishuser", password="x")
        self.venue = Venue.objects.create(
            title="Wish Venue",
            description="Desc",
            facilities=[],
            addons=[],
            price=100,
            location="City",
            image_url="",
            type=Venue.VenueType.FUTSAL,
        )

    def test_wishlist_get_post_delete_and_errors(self):
        response_missing_user = self.client.get(reverse("app:api-wishlist"))
        self.assertEqual(response_missing_user.status_code, 400)

        payload_unknown_user = {"user_id": 9999}
        response_unknown_user = self.client.post(
            reverse("app:api-wishlist"),
            data=json.dumps(payload_unknown_user),
            content_type="application/json",
        )
        self.assertEqual(response_unknown_user.status_code, 404)

        response_get_empty = self.client.get(
            reverse("app:api-wishlist"),
            {"user_id": self.user.id},
        )
        self.assertEqual(response_get_empty.status_code, 200)
        self.assertEqual(response_get_empty.json()["data"], [])

        payload_missing_venue = {"user_id": self.user.id}
        response_missing_venue = self.client.post(
            reverse("app:api-wishlist"),
            data=json.dumps(payload_missing_venue),
            content_type="application/json",
        )
        self.assertEqual(response_missing_venue.status_code, 400)

        payload_add = {"user_id": self.user.id, "venue_id": self.venue.id}
        response_add = self.client.post(
            reverse("app:api-wishlist"),
            data=json.dumps(payload_add),
            content_type="application/json",
        )
        self.assertEqual(response_add.status_code, 201)

        response_add_again = self.client.post(
            reverse("app:api-wishlist"),
            data=json.dumps(payload_add),
            content_type="application/json",
        )
        self.assertEqual(response_add_again.status_code, 200)

        response_get_after_add = self.client.get(
            reverse("app:api-wishlist"),
            {"user_id": self.user.id},
        )
        self.assertEqual(response_get_after_add.status_code, 200)
        self.assertEqual(len(response_get_after_add.json()["data"]), 1)

        response_delete_missing_venue = self.client.delete(
            reverse("app:api-wishlist"),
            data=json.dumps({"user_id": self.user.id}),
            content_type="application/json",
        )
        self.assertEqual(response_delete_missing_venue.status_code, 400)

        response_delete_unknown_entry = self.client.delete(
            reverse("app:api-wishlist"),
            data=json.dumps({"user_id": self.user.id, "venue_id": 9999}),
            content_type="application/json",
        )
        self.assertEqual(response_delete_unknown_entry.status_code, 404)

        response_delete = self.client.delete(
            reverse("app:api-wishlist"),
            data=json.dumps({"user_id": self.user.id, "venue_id": self.venue.id}),
            content_type="application/json",
        )
        self.assertEqual(response_delete.status_code, 200)

    def test_venue_reviews_and_detail(self):
        response_get_empty = self.client.get(
            reverse("app:api-venue-reviews", args=[self.venue.id])
        )
        self.assertEqual(response_get_empty.status_code, 200)
        self.assertEqual(response_get_empty.json(), [])

        invalid_payload = {"rating": 0, "comment": ""}
        response_invalid = self.client.post(
            reverse("app:api-venue-reviews", args=[self.venue.id]),
            data=json.dumps(invalid_payload),
            content_type="application/json",
        )
        self.assertEqual(response_invalid.status_code, 400)

        user_payload = {
            "rating": 5,
            "comment": "Great venue",
            "user_id": self.user.id,
        }
        response_create = self.client.post(
            reverse("app:api-venue-reviews", args=[self.venue.id]),
            data=json.dumps(user_payload),
            content_type="application/json",
        )
        self.assertEqual(response_create.status_code, 201)
        review_id = response_create.json()["id"]

        response_list = self.client.get(
            reverse("app:api-venue-reviews", args=[self.venue.id])
        )
        self.assertEqual(len(response_list.json()), 1)

        other_user = User.objects.create_user(username="other", password="y")
        forbidden_payload = {"user_id": other_user.id, "rating": 3, "comment": "Edit"}
        response_forbidden = self.client.put(
            reverse("app:api-venue-review-detail", args=[self.venue.id, review_id]),
            data=json.dumps(forbidden_payload),
            content_type="application/json",
        )
        self.assertEqual(response_forbidden.status_code, 403)

        update_payload = {"user_id": self.user.id, "rating": 4, "comment": "Updated"}
        response_update = self.client.put(
            reverse("app:api-venue-review-detail", args=[self.venue.id, review_id]),
            data=json.dumps(update_payload),
            content_type="application/json",
        )
        self.assertEqual(response_update.status_code, 200)

        bad_update_payload = {"user_id": self.user.id, "rating": 10, "comment": ""}
        response_bad_update = self.client.patch(
            reverse("app:api-venue-review-detail", args=[self.venue.id, review_id]),
            data=json.dumps(bad_update_payload),
            content_type="application/json",
        )
        self.assertEqual(response_bad_update.status_code, 400)

        delete_payload = {"user_id": self.user.id}
        response_delete = self.client.delete(
            reverse("app:api-venue-review-detail", args=[self.venue.id, review_id]),
            data=json.dumps(delete_payload),
            content_type="application/json",
        )
        self.assertEqual(response_delete.status_code, 200)


class AdminHelpersAndViewsTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.staff_user = User.objects.create_user(
            username="admin",
            password="x",
            is_staff=True,
        )
        self.non_staff_user = User.objects.create_user(
            username="regular",
            password="x",
            is_staff=False,
        )
        self.venue = Venue.objects.create(
            title="Admin Venue",
            description="Desc",
            facilities=["Wi-Fi"],
            addons=[{"name": "Ball", "price": 100, "description": ""}],
            price=100,
            location="City",
            image_url="",
            type=Venue.VenueType.FUTSAL,
        )
        booking_date = BookingDate.objects.create(
            start_date=timezone.now(),
            end_date=timezone.now() + timedelta(hours=1),
        )
        self.booking = Booking.objects.create(
            user=self.staff_user,
            venue=self.venue,
            has_been_paid=True,
            date_paid=timezone.localdate(),
            date=booking_date,
            notes="Admin booking",
            contact_phone="123",
        )

    def test_admin_helper_functions(self):
        self.assertTrue(views._user_is_staff(self.staff_user))
        self.assertFalse(views._user_is_staff(self.non_staff_user))

        request = RequestFactory().get("/")
        request.user = self.non_staff_user
        forbidden = views._admin_forbid_if_not_staff(request)
        self.assertIsNotNone(forbidden)

        allowed_request = RequestFactory().get("/")
        allowed_request.user = self.staff_user
        self.assertIsNone(views._admin_forbid_if_not_staff(allowed_request))

        user_payload = views._admin_serialize_user(self.staff_user)
        self.assertEqual(user_payload["username"], "admin")

        guest_label = views._booking_guest_label(self.booking)
        self.assertIn("admin", guest_label)

        venue_payload = views._admin_serialize_venue(self.venue)
        self.assertEqual(venue_payload["id"], self.venue.id)

        booking_payload = views._admin_serialize_booking(self.booking)
        self.assertEqual(booking_payload["id"], self.booking.id)

        parsed_default = views._parse_positive_int(None, 5)
        parsed_invalid = views._parse_positive_int("invalid", 5)
        parsed_too_small = views._parse_positive_int("0", 5)
        parsed_capped = views._parse_positive_int("100", 5, max_value=10)
        self.assertEqual(parsed_default, 5)
        self.assertEqual(parsed_invalid, 5)
        self.assertEqual(parsed_too_small, 5)
        self.assertEqual(parsed_capped, 10)

        venue_queryset = Venue.objects.all()
        filtered_venue_queryset = views._apply_venue_search(venue_queryset, "Admin")
        self.assertEqual(filtered_venue_queryset.count(), 1)

        booking_queryset = Booking.objects.select_related("date", "venue", "user")
        filtered_booking_queryset = views._apply_booking_search(booking_queryset, "Admin")
        self.assertEqual(filtered_booking_queryset.count(), 1)

        data, meta = views._build_paginated_payload(
            venue_queryset,
            page=1,
            page_size=10,
            serializer=views._admin_serialize_venue,
            query="Admin",
        )
        self.assertEqual(len(data), 1)
        self.assertEqual(meta["page"], 1)

        analytics = views._build_booking_analytics()
        self.assertIn("sales", analytics)
        self.assertIn("popularity", analytics)

    def test_admin_login_panel_logout_and_json_apis(self):
        response_get_login = self.client.get(reverse("html-admin-login"))
        self.assertEqual(response_get_login.status_code, 200)

        login_failed = self.client.post(
            reverse("html-admin-login"),
            {"username": "admin", "password": "wrong"},
        )
        self.assertEqual(login_failed.status_code, 200)

        login_ok = self.client.post(
            reverse("html-admin-login"),
            {"username": "admin", "password": "x"},
        )
        self.assertEqual(login_ok.status_code, 302)

        self.client.force_login(self.staff_user)
        panel_response = self.client.get(reverse("html-admin-panel"))
        self.assertEqual(panel_response.status_code, 200)

        logout_response = self.client.get(reverse("html-admin-logout"))
        self.assertEqual(logout_response.status_code, 302)

        self.client.force_login(self.staff_user)
        venues_list = self.client.get(reverse("app:admin-venues-list"))
        self.assertEqual(venues_list.status_code, 200)

        venues_create_invalid = self.client.post(reverse("app:admin-venues-create"))
        self.assertEqual(venues_create_invalid.status_code, 400)

        venues_create = self.client.post(
            reverse("app:admin-venues-create"),
            {
                "title": "New Venue",
                "type": Venue.VenueType.FUTSAL,
                "description": "Desc",
                "facilities": "Wi-Fi",
                "addons": json.dumps([]),
                "price": 100,
                "location": "City",
            },
        )
        self.assertEqual(venues_create.status_code, 200)
        created_id = venues_create.json()["data"]["id"]

        venues_update_invalid = self.client.post(
            reverse("app:admin-venues-update", args=[created_id]),
            {},
        )
        self.assertEqual(venues_update_invalid.status_code, 400)

        venues_update = self.client.post(
            reverse("app:admin-venues-update", args=[created_id]),
            {
                "title": "Updated Venue",
                "type": Venue.VenueType.FUTSAL,
                "description": "Desc",
                "facilities": "Wi-Fi",
                "addons": json.dumps([]),
                "price": 200,
                "location": "City",
            },
        )
        self.assertEqual(venues_update.status_code, 200)

        venues_delete = self.client.post(
            reverse("app:admin-venues-delete", args=[created_id])
        )
        self.assertEqual(venues_delete.status_code, 200)

        bookings_list = self.client.get(reverse("app:admin-bookings-list"))
        self.assertEqual(bookings_list.status_code, 200)

        bookings_create_invalid = self.client.post(reverse("app:admin-bookings-create"))
        self.assertEqual(bookings_create_invalid.status_code, 400)

        start = timezone.now()
        end = start + timedelta(hours=1)
        bookings_create = self.client.post(
            reverse("app:admin-bookings-create"),
            {
                "user": self.staff_user.id,
                "venue": self.venue.id,
                "has_been_paid": True,
                "notes": "note",
                "start_date": start.strftime("%Y-%m-%dT%H:%M"),
                "end_date": end.strftime("%Y-%m-%dT%H:%M"),
                "selected_addons": json.dumps([]),
            },
        )
        self.assertEqual(bookings_create.status_code, 200)
        booking_id = bookings_create.json()["data"]["id"]

        bookings_update_invalid = self.client.post(
            reverse("app:admin-bookings-update", args=[booking_id]),
            {},
        )
        self.assertEqual(bookings_update_invalid.status_code, 400)

        bookings_update = self.client.post(
            reverse("app:admin-bookings-update", args=[booking_id]),
            {
                "user": self.staff_user.id,
                "venue": self.venue.id,
                "has_been_paid": False,
                "notes": "updated",
                "start_date": start.strftime("%Y-%m-%dT%H:%M"),
                "end_date": end.strftime("%Y-%m-%dT%H:%M"),
                "selected_addons": json.dumps([]),
            },
        )
        self.assertEqual(bookings_update.status_code, 200)

        bookings_delete = self.client.post(
            reverse("app:admin-bookings-delete", args=[booking_id])
        )
        self.assertEqual(bookings_delete.status_code, 200)

        users_search_empty = self.client.get(reverse("app:admin-users-search"))
        self.assertEqual(users_search_empty.status_code, 200)

        users_search = self.client.get(
            reverse("app:admin-users-search"),
            {"q": "admin"},
        )
        self.assertEqual(users_search.status_code, 200)


class SampleDataAndCommandTests(TestCase):
    def test_sample_data_helpers_and_command(self):
        base_date = date(2024, 1, 1)
        sample_data.ensure_sample_data(base_date=base_date)

        self.assertGreaterEqual(Venue.objects.count(), 1)
        self.assertGreaterEqual(User.objects.count(), 1)
        self.assertGreaterEqual(Booking.objects.count(), 1)
        self.assertGreaterEqual(Comment.objects.count(), 1)

        call_command("load_sample_data")
