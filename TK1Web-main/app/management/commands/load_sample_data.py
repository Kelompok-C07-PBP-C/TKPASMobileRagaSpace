from django.core.management.base import BaseCommand

from app.sample_data import ensure_sample_data


class Command(BaseCommand):
    help = "Seed the database with demo venues, bookings, and comments"

    def handle(self, *args, **options):
        ensure_sample_data()
        self.stdout.write(self.style.SUCCESS("Sample data loaded successfully."))
