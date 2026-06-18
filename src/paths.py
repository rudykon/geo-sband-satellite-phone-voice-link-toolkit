"""Filesystem paths for the standalone open-source Step 1 toolkit."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

OUTPUTS_DIR = ROOT / "outputs"
RESULTS_DIR = OUTPUTS_DIR
FIGURES_DIR = OUTPUTS_DIR / "figures"
SHARED_FIGURES_DIR = OUTPUTS_DIR / "plots"

STEP1_DIR = OUTPUTS_DIR / "step1_link"
STEP1_PLOTS_DIR = STEP1_DIR / "plots"

GEO_SATPHONE_DIR = RESULTS_DIR / "geo_satphone"
OUTAGE_CAPACITY_DIR = RESULTS_DIR / "outage_capacity"
REQUESTED_EXTENSIONS_DIR = RESULTS_DIR / "requested_extensions"
MATLAB_STEP1_RESULTS_DIR = RESULTS_DIR / "matlab_step1"


def ensure_dirs(*paths: Path) -> None:
    for path in paths:
        path.mkdir(parents=True, exist_ok=True)
