from __future__ import annotations

from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone

from .models import Booking, BookingDate, Comment, Venue

UserModel = get_user_model()

SAMPLE_USERS = [
    {
        "username": "demo.alex",
        "first_name": "Alex",
        "last_name": "Rivera",
        "email": "alex.rivera@example.com",
        "password": "demo12345",
    },
    {
        "username": "demo.briana",
        "first_name": "Briana",
        "last_name": "Singh",
        "email": "briana.singh@example.com",
        "password": "demo12345",
    },
    {
        "username": "demo.chloe",
        "first_name": "Chloe",
        "last_name": "Mendez",
        "email": "chloe.mendez@example.com",
        "password": "demo12345",
    },
    {
        "username": "demo.darius",
        "first_name": "Darius",
        "last_name": "Ng",
        "email": "darius.ng@example.com",
        "password": "demo12345",
    },
]

SAMPLE_VENUES = [
    {
        "title": "Aurora Sports Dome",
        "type": Venue.VenueType.FUTSAL,
        "description": "Indoor futsal pitch with climate control, lounge seating, and LED scoreboards.",
        "facilities": [
            "Locker rooms",
            "On-site cafe",
            "LED scoreboards",
        ],
        "price": 550000,
        "location": "Jakarta, Indonesia",
        "image_url": "https://media.istockphoto.com/id/2172873491/photo/university-student-and-man-in-portrait-outdoor-on-campus-with-book-for-education-learning-and.jpg?s=612x612&w=0&k=20&c=0jJ62Pxg9qWg2DKCl0pVQmN1j618h01SXJ7DGdlpsZM=",
    },
    {
        "title": "Harborview Badminton Center",
        "type": Venue.VenueType.BADMINTON,
        "description": "Six international-standard courts with sprung flooring and pro shop services.",
        "facilities": [
            "Stringing service",
            "Equipment rental",
            "Private coaching rooms",
        ],
        "price": 320000,
        "location": "Surabaya, Indonesia",
        "image_url": "https://media.gettyimages.com/id/2063799507/photo/business-portrait-and-black-man-in-city-outdoor-for-career-or-job-of-businessman-face.jpg?s=612x612&w=gi&k=20&c=aV_6jGmVEE5WQR6F__JPMwAxJZiPBBIg-a0pdzKgL6A=",
    },
    {
        "title": "Summit Court Arena",
        "type": Venue.VenueType.BASKET,
        "description": "Full-sized basketball court with seating for 500 and premium locker facilities.",
        "facilities": [
            "Courtside seating",
            "Hydration station",
            "Strength studio",
        ],
        "price": 680000,
        "location": "Bandung, Indonesia",
        "image_url": "https://plus.unsplash.com/premium_photo-1689530775582-83b8abdb5020?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8cmFuZG9tJTIwcGVyc29ufGVufDB8fDB8fHww&fm=jpg&q=60&w=3000",
    },
]

SAMPLE_BOOKINGS = [
    {
        "username": "demo.alex",
        "venue": "Aurora Sports Dome",
        "has_been_paid": True,
        "notes": "League match booking",
        "date_delta": 3,
    },
    {
        "username": "demo.briana",
        "venue": "Harborview Badminton Center",
        "has_been_paid": True,
        "notes": "Weekend doubles",
        "date_delta": 5,
    },
    {
        "username": "demo.darius",
        "venue": "Summit Court Arena",
        "has_been_paid": False,
        "notes": "Training session pending payment",
        "date_delta": 7,
    },
]

SAMPLE_COMMENTS = [
    {
        "username": "demo.alex",
        "rating": 5,
        "comment": (
            "Climate control keeps the futsal pitch comfortable and the LED scoreboards "
            "make our league nights feel professional."
        ),
        "venue": "Aurora Sports Dome",
        "days_ago": 5,
    },
    {
        "username": "demo.briana",
        "rating": 4,
        "comment": (
            "Harborview's sprung flooring feels great and the stringing service tuned my rackets before play."
        ),
        "venue": "Harborview Badminton Center",
        "days_ago": 8,
    },
    {
        "username": "demo.chloe",
        "rating": 5,
        "comment": (
            "Summit Court Arena has incredible locker facilities and plenty of courtside seating."
        ),
        "venue": "Summit Court Arena",
        "days_ago": 2,
    },
]


def ensure_sample_data(base_date: date | None = None) -> None:
    with transaction.atomic():
        venues = _create_venues()
        users = _create_users()
        _create_bookings(users, venues, base_date)
        _create_comments(users, venues, base_date)


def _create_venues() -> dict[str, Venue]:
    mapping: dict[str, Venue] = {}
    for payload in SAMPLE_VENUES:
        venue, _ = Venue.objects.update_or_create(
            title=payload["title"],
            defaults=payload,
        )
        mapping[venue.title] = venue
    return mapping


def _create_users() -> dict[str, UserModel]:
    mapping: dict[str, UserModel] = {}
    for payload in SAMPLE_USERS:
        username = payload["username"]
        user, created = UserModel.objects.get_or_create(username=username)
        if created:
            user.set_password(payload["password"])
        user.first_name = payload["first_name"]
        user.last_name = payload["last_name"]
        user.email = payload["email"]
        user.save()
        mapping[username] = user
    return mapping


def _create_bookings(users, venues, base_date):
    today = timezone.localdate()
    base_reference = base_date or today - timedelta(days=10)
    for payload in SAMPLE_BOOKINGS:
        user = users.get(payload["username"])
        venue = venues.get(payload["venue"])
        if not user or not venue:
            continue
        start_date = base_reference + timedelta(days=payload["date_delta"])
        end_date = start_date + timedelta(days=1)
        booking_date = BookingDate.objects.create(start_date=start_date, end_date=end_date)
        Booking.objects.create(
            user=user,
            venue=venue,
            has_been_paid=payload["has_been_paid"],
            date=booking_date,
            notes=payload["notes"],
            date_paid=start_date if payload["has_been_paid"] else None,
        )


def _create_comments(users, venues, base_date):
    today = timezone.localdate()
    base_reference = base_date or today
    for payload in SAMPLE_COMMENTS:
        user = users.get(payload["username"])
        venue = venues.get(payload["venue"])
        if not user or not venue:
            continue
        comment_date = base_reference - timedelta(days=payload["days_ago"])
        comment = Comment.objects.create(
            user=user,
            rating=payload["rating"],
            comment=payload["comment"],
            date=comment_date,
        )
        comment.venue.add(venue)
