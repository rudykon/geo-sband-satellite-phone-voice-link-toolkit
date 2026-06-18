#!/usr/bin/env python3
"""Run the Step 1 open-source research toolkit workflow."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "src"))

import step1_cosim

SCRIPTS = [
    ROOT / "src" / "tiantong_sband_link.py",
    ROOT / "src" / "outage_capacity_bound.py",
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--skip-matlab-step1",
        action="store_true",
        help="Development only: skip the MATLAB/Simulink Step 1 reference path.",
    )
    args = parser.parse_args()

    for script in SCRIPTS:
        print(f"[run] running {script.relative_to(ROOT)}")
        subprocess.check_call([sys.executable, str(script)], cwd=ROOT)
    if args.skip_matlab_step1:
        step1_cosim.mark_python_only("--skip-matlab-step1 was used; outputs are Python-only development outputs.")
        print("[warn] skipped MATLAB/Simulink Step 1 reference co-simulation")
        print("[warn] skipped completion artifacts that require MATLAB/Simulink reference outputs")
    else:
        manifest = step1_cosim.run_matlab_cosim()
        step1_cosim.validate_and_promote(manifest)

        script = ROOT / "src" / "step1_completion.py"
        print(f"[run] running {script.relative_to(ROOT)}")
        subprocess.check_call([sys.executable, str(script)], cwd=ROOT)
    print("[run] complete")
    print(ROOT / "outputs")


if __name__ == "__main__":
    main()
