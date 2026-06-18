"""Filesystem paths for the standalone open-source voice-link toolkit."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

OUTPUTS_DIR = ROOT / "outputs"
RESULTS_DIR = OUTPUTS_DIR
FIGURES_DIR = OUTPUTS_DIR / "figures"
SHARED_FIGURES_DIR = OUTPUTS_DIR / "plots"

SCREENING_DIR = OUTPUTS_DIR / "voice_link_screening"
SCREENING_PLOTS_DIR = SCREENING_DIR / "plots"

GEO_SATPHONE_DIR = RESULTS_DIR / "geo_satphone"
OUTAGE_CAPACITY_DIR = RESULTS_DIR / "outage_capacity"
SCREENING_ANALYSIS_DIR = RESULTS_DIR / "screening_analysis"
MATLAB_VOICE_LINK_RESULTS_DIR = RESULTS_DIR / "matlab_voice_link"


def ensure_dirs(*paths: Path) -> None:
    for path in paths:
        path.mkdir(parents=True, exist_ok=True)
