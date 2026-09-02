"""Post-synthesis timing/energy-calibrated CMR DES (DATE V3 Phase 5)."""

from __future__ import annotations

MODEL_VERSION = "date-des-v1"
PHYSICAL_CLASS = "post-synthesis"
CALIBRATION_SEED = 900001  # not a paper traffic seed
PAPER_SEEDS = (202701, 202702, 202703)

__all__ = ["MODEL_VERSION", "PHYSICAL_CLASS", "CALIBRATION_SEED", "PAPER_SEEDS"]
