"""Tests covering the AJAX-enabled authentication flow."""
from __future__ import annotations

from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client, TestCase, override_settings
from django.urls import reverse


middleware_without_whitenoise = [
    middleware
    for middleware in settings.MIDDLEWARE
    if middleware != "whitenoise.middleware.WhiteNoiseMiddleware"
]


@override_settings(MIDDLEWARE=middleware_without_whitenoise)
class AuthLoginAjaxViewTests(TestCase):
    """Validate the behaviour of the AJAX login endpoint."""

    def setUp(self) -> None:
        self.login_url = reverse("authentication:login")
        self.client = Client()
        self.user = get_user_model().objects.create_user(
            username="ajax-user",
            password="secure-password",
        )

    def test_ajax_login_success_returns_json_payload(self) -> None:
        response = self.client.post(
            self.login_url,
            data={"username": "ajax-user", "password": "secure-password"},
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
            HTTP_ACCEPT="application/json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "application/json")
        payload = response.json()
        self.assertTrue(payload.get("success"))
        self.assertIn("redirect_url", payload)
        self.assertTrue(payload["redirect_url"])

    def test_ajax_login_invalid_credentials_returns_errors(self) -> None:
        response = self.client.post(
            self.login_url,
            data={"username": "ajax-user", "password": "wrong"},
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
            HTTP_ACCEPT="application/json",
        )
        self.assertEqual(response.status_code, 400)
        payload = response.json()
        self.assertFalse(payload.get("success"))
        self.assertIn("non_field_errors", payload)
        self.assertGreater(len(payload["non_field_errors"]), 0)

    def test_standard_form_submission_still_redirects(self) -> None:
        response = self.client.post(
            self.login_url,
            data={"username": "ajax-user", "password": "secure-password"},
        )
        self.assertEqual(response.status_code, 302)
        self.assertTrue(response["Location"])  # Redirect to success page
