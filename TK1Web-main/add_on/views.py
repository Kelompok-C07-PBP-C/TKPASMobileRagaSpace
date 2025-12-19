"""Views for managing optional equipment add-ons."""
from __future__ import annotations

import logging
from typing import Any

from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin
from django.http import HttpRequest, HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.views import View

from authentication.mixins import AdminRequiredMixin
from manajemen_lapangan.models import Venue

from .formsets import build_addon_formset

logger = logging.getLogger(__name__)


class AdminVenueAddOnManageView(AdminRequiredMixin, LoginRequiredMixin, View):
    """Allow administrators to manage add-ons for a specific venue."""

    template_name = "add_on/manage.html"

    def get_success_url(self, venue: Venue) -> str:
        """Return the URL to redirect to after a successful submission."""

        return reverse("admin-venue-addons", args=[venue.pk])

    def get(self, request: HttpRequest, venue_pk: int, *args: Any, **kwargs: Any) -> HttpResponse:
        """Display the inline formset used to manage add-ons."""

        venue = get_object_or_404(Venue, pk=venue_pk)
        formset = build_addon_formset(instance=venue)
        context = {"venue": venue, "formset": formset}
        return render(request, self.template_name, context)

    def post(self, request: HttpRequest, venue_pk: int, *args: Any, **kwargs: Any) -> HttpResponse:
        """Persist the add-on formset and report success or failure to the user."""

        venue = get_object_or_404(Venue, pk=venue_pk)

        if not (
            request.user.has_perm("add_on.change_addon")
            or request.user.has_perm("add_on.add_addon")
            or request.user.has_perm("add_on.delete_addon")
        ):
            messages.error(request, "You do not have permission to modify add-ons.")
            return redirect("admin-venues")

        formset = build_addon_formset(data=request.POST, instance=venue)
        if formset.is_valid():
            formset.save()
            logger.info("Add-ons updated for venue %s by %s", venue.pk, request.user)
            messages.success(request, "Add-ons saved successfully.")
            return redirect(self.get_success_url(venue))

        messages.error(request, "Please correct the errors below to save the add-ons.")
        context = {"venue": venue, "formset": formset}
        return render(request, self.template_name, context)
