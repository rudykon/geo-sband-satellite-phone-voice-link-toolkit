#!/usr/bin/env python3
"""Run the Step 1 open-source research toolkit workflow."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SCRIPTS = [
    ROOT / "src" / "tiantong_sband_link.py",
    ROOT / "src" / "outage_capacity_bound.py",
    ROOT / "src" / "step1_completion.py",
]


def main() -> None:
    for script in SCRIPTS:
        print(f"[run] running {script.relative_to(ROOT)}")
        subprocess.check_call([sys.executable, str(script)], cwd=ROOT)
    print("[run] complete")
    print(ROOT / "outputs")


if __name__ == "__main__":
    main()
