"""Inline formset helpers for managing add-ons alongside venues."""
from __future__ import annotations

from typing import Any

from django import forms
from django.forms import BaseInlineFormSet, inlineformset_factory
from django.http import QueryDict

from manajemen_lapangan.models import Venue

from .forms import AddOnForm
from .models import AddOn


class AddOnInlineFormSet(BaseInlineFormSet):
    """Inline formset that hides delete checkboxes and exposes JS hooks."""

    def add_fields(self, form, index):  # type: ignore[override]
        super().add_fields(form, index)
        delete_field = form.fields.get("DELETE")
        if delete_field:
            delete_field.widget.attrs.setdefault("class", "")
            delete_field.widget.attrs["class"] = " ".join(
                filter(None, [delete_field.widget.attrs.get("class"), "hidden"])
            )
            delete_field.widget.attrs.setdefault("data-addon-delete-input", "true")
            if isinstance(delete_field.widget, forms.CheckboxInput):
                delete_field.widget.check_test = lambda value: bool(value)


def build_addon_formset(*, data: dict[str, Any] | None = None, instance: Venue | None = None) -> BaseInlineFormSet:
    """Return a configured inline formset for editing add-ons.

    Keeping the factory inside the ``add_on`` module helps isolate the logic
    for managing optional equipment while allowing admin views in
    ``manajemen_lapangan`` to reuse the same HTML fragment.
    """

    formset_class = inlineformset_factory(
        Venue,
        AddOn,
        form=AddOnForm,
        # ``extra`` is set to zero so that no empty add-on forms are rendered by
        # default. Administrators can still add forms dynamically via the "Add
        # add-on" button, keeping the interface uncluttered until they choose to
        # create an add-on.
        extra=0,
        can_delete=True,
        formset=AddOnInlineFormSet,
    )
    formset_data = None
    if data is not None:
        if isinstance(data, QueryDict):
            formset_data = data.copy()
            formset_data._mutable = True
        else:
            formset_data = QueryDict("", mutable=True)
            for key, value in data.items():
                if isinstance(value, (list, tuple)):
                    formset_data.setlist(key, ["" if item is None else str(item) for item in value])
                else:
                    formset_data.setlist(key, ["" if value is None else str(value)])
        if not any(key.startswith("addons-") for key in formset_data.keys()):
            formset_data["addons-TOTAL_FORMS"] = "0"
            formset_data["addons-INITIAL_FORMS"] = "0"
            formset_data["addons-MIN_NUM_FORMS"] = "0"
            formset_data["addons-MAX_NUM_FORMS"] = "1000"
    return formset_class(data=formset_data, instance=instance, prefix="addons")
