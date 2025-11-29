#!/usr/bin/env python
"""Django's command-line utility for administrative tasks.

This wrapper now points to the TK1Web project (TK_PBP.settings) so running
`python backend/manage.py runserver` uses the integrated application instead of
the legacy `backend` project.
"""
import os
import sys
from pathlib import Path


def main():
    """Run administrative tasks."""
    project_root = Path(__file__).resolve().parent.parent  # repo root
    tk1web_dir = project_root / "TK1Web-main"
    if tk1web_dir.exists():
        sys.path.insert(0, str(tk1web_dir))
    # Force TK1Web settings even if the environment is pre-set.
    os.environ["DJANGO_SETTINGS_MODULE"] = "TK_PBP.settings"
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
