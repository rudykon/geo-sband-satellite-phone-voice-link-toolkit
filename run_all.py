#!/usr/bin/env python3
"""Run the GEO S-Band VoiceLink workflow."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "src"))

import voice_link_reference

SCRIPTS = [
    ROOT / "src" / "tiantong_sband_link.py",
    ROOT / "src" / "outage_capacity_bound.py",
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--skip-reference-cosim",
        action="store_true",
        help="Development only: skip the MATLAB/Simulink voice-link reference path.",
    )
    args = parser.parse_args()

    for script in SCRIPTS:
        print(f"[run] running {script.relative_to(ROOT)}")
        subprocess.check_call([sys.executable, str(script)], cwd=ROOT)
    if args.skip_reference_cosim:
        voice_link_reference.mark_python_only("--skip-reference-cosim was used; outputs are Python-only development outputs.")
        print("[warn] skipped MATLAB/Simulink voice-link reference co-simulation")
        print("[warn] skipped screening artifacts that require MATLAB/Simulink reference outputs")
    else:
        manifest = voice_link_reference.run_matlab_cosim()
        voice_link_reference.validate_and_promote(manifest)

        script = ROOT / "src" / "screening_analysis.py"
        print(f"[run] running {script.relative_to(ROOT)}")
        subprocess.check_call([sys.executable, str(script)], cwd=ROOT)
    print("[run] complete")
    print(ROOT / "outputs")


if __name__ == "__main__":
    main()
