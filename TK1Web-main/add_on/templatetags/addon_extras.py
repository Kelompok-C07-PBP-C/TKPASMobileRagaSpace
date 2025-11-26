"""Custom template helpers for add-on rendering."""
from __future__ import annotations

from collections.abc import Iterable, Mapping
from typing import Any

from django import template

register = template.Library()


@register.filter(name="get_item")
def get_item(mapping: Mapping[str, Any] | Iterable[Any] | None, key: Any) -> Any:
    """Safely retrieve ``key`` from dictionaries, querysets, or iterables."""

    if mapping is None:
        return None

    key_str = str(key)

    if isinstance(mapping, Mapping):
        if key in mapping:
            return mapping[key]
        if key_str in mapping:
            return mapping[key_str]
        return None

    getter = getattr(mapping, "get", None)
    if callable(getter):
        result = getter(key)
        if result is not None:
            return result
        return getter(key_str)

    for item in mapping:
        item_id = getattr(item, "pk", getattr(item, "id", None))
        if item_id is None:
            continue
        if str(item_id) == key_str or item_id == key:
            return item
    return None
