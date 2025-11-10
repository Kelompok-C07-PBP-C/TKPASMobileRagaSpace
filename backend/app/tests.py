from django.test import TestCase, Client
from django.urls import reverse
from django.contrib.auth.models import User


class AuthApiTests(TestCase):
    def setUp(self):
        self.client = Client()

    def test_register_success_and_me(self):
        res = self.client.post(
            reverse('api-register'),
            data={"username": "alice", "password": "pass123", "email": "a@example.com"},
            content_type='application/json'
        )
        self.assertEqual(res.status_code, 200, res.content)
        data = res.json()
        self.assertEqual(data["username"], "alice")

        # now session should be authenticated
        me = self.client.get(reverse('api-me'))
        self.assertEqual(me.status_code, 200)
        self.assertTrue(me.json()["authenticated"]) 

    def test_register_duplicate_username(self):
        User.objects.create_user(username="bob", password="x")
        res = self.client.post(
            reverse('api-register'),
            data={"username": "bob", "password": "y"},
            content_type='application/json'
        )
        self.assertEqual(res.status_code, 409)

    def test_register_missing_fields(self):
        res = self.client.post(reverse('api-register'), data={}, content_type='application/json')
        self.assertEqual(res.status_code, 400)
        # invalid JSON also becomes missing fields
        res2 = self.client.post(reverse('api-register'), data='not-json', content_type='application/json')
        self.assertEqual(res2.status_code, 400)

    def test_login_success_and_logout(self):
        User.objects.create_user(username="carl", password="secret")
        res = self.client.post(
            reverse('api-login'),
            data={"username": "carl", "password": "secret"},
            content_type='application/json'
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["username"], "carl")

        # me should show authenticated
        me = self.client.get(reverse('api-me'))
        self.assertTrue(me.json()["authenticated"])

        # logout
        out = self.client.post(reverse('api-logout'))
        self.assertEqual(out.status_code, 200)
        me2 = self.client.get(reverse('api-me'))
        self.assertFalse(me2.json()["authenticated"])

    def test_login_invalid(self):
        res = self.client.post(
            reverse('api-login'),
            data={"username": "ghost", "password": "none"},
            content_type='application/json'
        )
        self.assertEqual(res.status_code, 401)

    def test_method_not_allowed(self):
        r1 = self.client.get(reverse('api-login'))
        self.assertEqual(r1.status_code, 405)
        r2 = self.client.get(reverse('api-register'))
        self.assertEqual(r2.status_code, 405)
        r3 = self.client.get(reverse('api-logout'))
        self.assertEqual(r3.status_code, 405)


# Create your tests here.
