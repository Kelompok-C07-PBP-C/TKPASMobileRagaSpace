"""Lightweight stub implementation of the ``django-filter`` API for tests."""
from __future__ import annotations

from copy import deepcopy
from typing import Any, Dict

from django import forms
from django.db.models import QuerySet



class Filter:
    def __init__(self, *, field_name: str | None = None, field: forms.Field | None = None, lookup_expr: str | None = None, **kwargs: Any) -> None:
        self.field_name = field_name
        self.lookup_expr = lookup_expr or kwargs.get("lookup_expr", "exact")
        self.extra = kwargs
        self.field = field or self.build_field()

    def build_field(self) -> forms.Field:
        return forms.Field(required=False)

    def clone(self) -> "Filter":
        cloned = deepcopy(self)
        cloned.field = deepcopy(self.field)
        return cloned

    def filter(self, queryset: QuerySet, value: Any) -> QuerySet:
        if value in (None, "", [], (), {}):
            return queryset
        lookup = self.lookup_expr or "exact"
        field_name = self.field_name or ""
        if not field_name:
            return queryset
        lookup_expr = field_name if lookup == "exact" else f"{field_name}__{lookup}"
        return queryset.filter(**{lookup_expr: value})


class ChoiceFilter(Filter):
    def build_field(self) -> forms.Field:
        choices = self.extra.get("choices", [])
        empty_label = self.extra.get("empty_label")
        field = forms.ChoiceField(
            choices=choices,
            required=False,
            widget=self.extra.get("widget"),
        )
        field.empty_value = None
        field._empty_value = None
        if empty_label is not None:
            field.empty_label = empty_label
        return field


class ModelChoiceFilter(Filter):
    def build_field(self) -> forms.Field:
        return forms.ModelChoiceField(
            queryset=self.extra.get("queryset"),
            empty_label=self.extra.get("empty_label"),
            required=False,
            widget=self.extra.get("widget"),
        )


class NumberFilter(Filter):
    def build_field(self) -> forms.Field:
        return forms.DecimalField(
            required=False,
            widget=self.extra.get("widget"),
        )


class FilterSetMeta(type):
    def __new__(mcls, name, bases, attrs):
        filters: Dict[str, Filter] = {}
        for base in bases:
            filters.update(getattr(base, "base_filters", {}))
        declared = {
            key: value for key, value in list(attrs.items()) if isinstance(value, Filter)
        }
        for key, value in declared.items():
            value.field_name = value.field_name or key
            attrs.pop(key)
        filters.update(declared)
        cls = super().__new__(mcls, name, bases, attrs)
        cls.base_filters = filters
        return cls


class FilterSet(metaclass=FilterSetMeta):
    base_filters: Dict[str, Filter]

    def __init__(self, data=None, queryset=None, *, request=None, prefix=None) -> None:
        self.data = data
        self.request = request
        self.queryset = queryset
        self.prefix = prefix
        self.filters = {name: flt.clone() for name, flt in self.base_filters.items()}
        self.form = self._build_form(prefix=prefix, data=data)
        self._qs = None
        self._is_valid: bool | None = None

    def _build_form(self, *, prefix, data):
        fields = {name: flt.field for name, flt in self.filters.items()}
        form_class = type("FilterForm", (forms.Form,), fields)
        return form_class(data=data, prefix=prefix)

    def is_valid(self) -> bool:
        if self._is_valid is None:
            self._is_valid = self.form.is_valid()
            if self._is_valid:
                self._qs = self.filter_queryset(self.queryset)
        return self._is_valid

    def filter_queryset(self, queryset: QuerySet) -> QuerySet:
        if queryset is None:
            return queryset
        if not self.form.is_valid():
            return queryset
        for name, value in self.form.cleaned_data.items():
            filter_obj = self.filters.get(name)
            if filter_obj is None:
                continue
            queryset = filter_obj.filter(queryset, value)
        return queryset

    @property
    def qs(self):
        if self._qs is not None:
            return self._qs
        if self.queryset is None:
            return self.queryset
        if self.form.is_valid():
            self._qs = self.filter_queryset(self.queryset)
        else:
            self._qs = self.queryset
        return self._qs


__all__ = [
    "FilterSet",
    "Filter",
    "ChoiceFilter",
    "ModelChoiceFilter",
    "NumberFilter",
]
