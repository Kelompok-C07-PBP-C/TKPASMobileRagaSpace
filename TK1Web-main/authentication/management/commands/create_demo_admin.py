from __future__ import annotations

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.utils.crypto import get_random_string


class Command(BaseCommand):
    help = "Create (or update) a demo admin user for local evaluation."

    def add_arguments(self, parser):
        parser.add_argument(
            "--username",
            default="admin",
            help="Username for the admin user (default: admin).",
        )
        parser.add_argument(
            "--email",
            default="",
            help="Optional email for the admin user.",
        )
        parser.add_argument(
            "--password",
            default=None,
            help="Optional password. If omitted, a random password is generated.",
        )
        parser.add_argument(
            "--update",
            action="store_true",
            help="If the user exists, reset password and grant admin flags.",
        )

    def handle(self, *args, **options):
        username: str = options["username"]
        email: str = options["email"]
        provided_password: str | None = options["password"]
        update_existing: bool = options["update"]

        password = provided_password or get_random_string(16)

        User = get_user_model()
        user, created = User.objects.get_or_create(
            username=username,
            defaults={"email": email},
        )

        if not created and not update_existing:
            raise CommandError(
                f"User '{username}' already exists. Re-run with --update to reset it."
            )

        if email:
            user.email = email
        user.is_staff = True
        user.is_superuser = True
        user.set_password(password)
        user.save()

        action = "Created" if created else "Updated"
        self.stdout.write(self.style.SUCCESS(f"{action} admin user '{username}'."))

        if provided_password is None:
            self.stdout.write(self.style.WARNING(f"Generated password: {password}"))
            self.stdout.write(
                "Store it securely and share it with your teacher if needed."
            )
