"""Put DATE V3 scripts on sys.path so model/des can import date_v3."""

from __future__ import annotations

import sys
from pathlib import Path

EXPERIMENTS = Path(__file__).resolve().parents[2]
SCRIPTS = EXPERIMENTS / "scripts"
MODEL = EXPERIMENTS / "model"

if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))
if str(MODEL) not in sys.path:
    sys.path.insert(0, str(MODEL))
