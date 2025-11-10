from django.contrib import admin
from .models import Venue, Booking, BookingDate, Comment


@admin.register(Venue)
class VenueAdmin(admin.ModelAdmin):
    list_display = ("title", "type", "location", "price", "created_at")
    search_fields = ("title", "location", "type")
    list_filter = ("type", "location")


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ("venue", "user", "has_been_paid", "date_paid", "created_at")
    list_filter = ("has_been_paid", "created_at")
    search_fields = ("venue__title", "user__username")


@admin.register(BookingDate)
class BookingDateAdmin(admin.ModelAdmin):
    list_display = ("start_date", "end_date")


@admin.register(Comment)
class CommentAdmin(admin.ModelAdmin):
    list_display = ("user", "rating", "date")
    list_filter = ("rating", "date")
    search_fields = ("user__username", "comment")
