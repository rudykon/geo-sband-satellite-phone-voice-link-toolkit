"""Filesystem paths for the standalone open-source voice-link toolkit."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

OUTPUTS_DIR = ROOT / "outputs"
DATA_DIR = OUTPUTS_DIR / "data"
FIGURES_DIR = OUTPUTS_DIR / "figures"
RESULTS_DIR = DATA_DIR
SHARED_FIGURES_DIR = FIGURES_DIR / "all"

SCREENING_DIR = FIGURES_DIR / "screening_report"
SCREENING_PLOTS_DIR = SCREENING_DIR

GEO_SATPHONE_DIR = RESULTS_DIR / "voice_link"
OUTAGE_CAPACITY_DIR = RESULTS_DIR / "outage_capacity"
SCREENING_ANALYSIS_DIR = RESULTS_DIR / "screening_analysis"
MATLAB_VOICE_LINK_RESULTS_DIR = RESULTS_DIR / "reference_cosim"


def ensure_dirs(*paths: Path) -> None:
    for path in paths:
        path.mkdir(parents=True, exist_ok=True)
