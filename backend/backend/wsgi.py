"""
WSGI config for the repo.

This now routes to TK1Web (TK_PBP.settings) so any WSGI server using
`backend.wsgi:application` will serve the integrated project.
"""

import os
import sys
from pathlib import Path

from django.core.wsgi import get_wsgi_application

project_root = Path(__file__).resolve().parent.parent.parent  # repo root
tk1web_dir = project_root / "TK1Web-main"
if tk1web_dir.exists():
    sys.path.insert(0, str(tk1web_dir))

# Force TK1Web settings even if a different DJANGO_SETTINGS_MODULE is set.
os.environ["DJANGO_SETTINGS_MODULE"] = "TK_PBP.settings"

application = get_wsgi_application()
