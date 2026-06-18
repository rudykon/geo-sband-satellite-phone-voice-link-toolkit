#!/usr/bin/env python3
"""One-command entry point for quick GEO S-band voice-link screening."""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "src"))

from dashboard_model import evaluate_voice_link, load_scenarios, sensitivity_rows  # noqa: E402


ALIASES = {
    "all": "all",
    "open": "open_plain",
    "open_plain": "open_plain",
    "forest": "forest_edge",
    "forest_edge": "forest_edge",
    "canyon": "canyon_valley",
    "canyon_valley": "canyon_valley",
    "moving": "moving_trail",
    "moving_trail": "moving_trail",
    "shelter": "tent_shelter",
    "tent": "tent_shelter",
    "tent_shelter": "tent_shelter",
}


def pct(value: float) -> str:
    return f"{100.0 * value:6.2f}%"


def pp(value: float) -> str:
    return f"{value:+6.2f} pp"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run a quick Python-only voice-link screening. This does not require "
            "MATLAB/Simulink and writes a compact engineering report."
        )
    )
    parser.add_argument(
        "--scenario",
        default="all",
        choices=sorted(ALIASES),
        help="Scenario alias. Default: all.",
    )
    parser.add_argument(
        "--rate",
        type=float,
        default=2400.0,
        help="Voice bearer rate in bit/s. Default: 2400.",
    )
    parser.add_argument("--p-los", type=float, help="Override LOS probability.")
    parser.add_argument("--nlos-loss-db", type=float, help="Override NLOS excess loss in dB.")
    parser.add_argument("--sigma-db", type=float, help="Override shadowing sigma in dB.")
    parser.add_argument("--theta-shift-deg", type=float, default=0.0, help="Posture/elevation shift in degrees.")
    parser.add_argument("--added-loss-db", type=float, default=0.0, help="Extra implementation or channel loss in dB.")
    parser.add_argument("--threshold-delta-db", type=float, default=0.0, help="Extra PHY threshold margin in dB.")
    parser.add_argument("--samples", type=int, default=20_000, help="Monte-Carlo sample count. Default: 20000.")
    parser.add_argument("--list-scenarios", action="store_true", help="Print available scenarios and exit.")
    parser.add_argument("--no-write", action="store_true", help="Only print results; do not write outputs.")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=ROOT / "outputs" / "quick_run",
        help="Directory for quick-run CSV/JSON/Markdown files.",
    )
    return parser.parse_args()


def select_scenarios(args: argparse.Namespace) -> list[dict[str, object]]:
    scenarios = load_scenarios()
    by_key = {str(row["scenario_key"]): row for row in scenarios}
    selected = ALIASES[args.scenario]
    if selected == "all":
        return scenarios
    return [by_key[selected]]


def evaluate_row(args: argparse.Namespace, scenario: dict[str, object]) -> dict[str, Any]:
    result = evaluate_voice_link(
        scenario,
        voice_rate_bps=args.rate,
        p_los=args.p_los,
        nlos_loss_db=args.nlos_loss_db,
        sigma_db=args.sigma_db,
        theta_mean_shift_deg=args.theta_shift_deg,
        added_loss_db=args.added_loss_db,
        threshold_delta_db=args.threshold_delta_db,
        n_samples=args.samples,
    )
    return {
        "scenario_key": scenario["scenario_key"],
        "scenario": scenario["label"],
        "voice_rate_bps": args.rate,
        "availability_pct": 100.0 * result["availability"],
        "p10_ebn0_db": result["p10_ebn0_db"],
        "median_ebn0_db": result["median_ebn0_db"],
        "c0p01_bit_per_s_hz": result["c0p01_bit_per_s_hz"],
        "threshold_ebn0_db": result["threshold_ebn0_db"],
        "average_snr_screen_pct": 100.0 * result["average_snr_screening_availability"],
        "single_state_lognormal_pct": 100.0 * result["single_state_lognormal_availability"],
        "average_snr_margin_db": result["average_snr_margin_db"],
    }


def print_summary(rows: list[dict[str, Any]]) -> None:
    header = (
        f"{'Scenario':<16} {'Avail.':>9} {'P10 Eb/N0':>10} {'C0.01':>9} "
        f"{'Avg-SNR':>9} {'Single':>9} {'Avg margin':>11}"
    )
    print(header)
    print("-" * len(header))
    for row in rows:
        print(
            f"{str(row['scenario']):<16} "
            f"{row['availability_pct']:8.2f}% "
            f"{row['p10_ebn0_db']:9.2f} "
            f"{row['c0p01_bit_per_s_hz']:9.3f} "
            f"{row['average_snr_screen_pct']:8.2f}% "
            f"{row['single_state_lognormal_pct']:8.2f}% "
            f"{row['average_snr_margin_db']:10.2f}"
        )


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def write_markdown(path: Path, rows: list[dict[str, Any]], args: argparse.Namespace) -> None:
    lines = [
        "# Quick Voice-Link Screening Report",
        "",
        f"- Voice bearer rate: {args.rate:g} bit/s",
        f"- Monte-Carlo samples per scenario: {args.samples}",
        f"- Extra link loss: {args.added_loss_db:g} dB",
        f"- Threshold delta: {args.threshold_delta_db:g} dB",
        "",
        "| Scenario | Availability | P10 Eb/N0 | C0.01 | Average-SNR screen | Single-state lognormal |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        lines.append(
            "| {scenario} | {availability_pct:.2f}% | {p10_ebn0_db:.2f} dB | "
            "{c0p01_bit_per_s_hz:.3f} | {average_snr_screen_pct:.2f}% | "
            "{single_state_lognormal_pct:.2f}% |".format(**row)
        )
    lines.extend(
        [
            "",
            "Interpretation:",
            "",
            "- Availability is the fraction of samples above the selected PHY Eb/N0 threshold.",
            "- Average-SNR screening is a hard pass/fail baseline.",
            "- Single-state lognormal screening removes persistent LOS/NLOS state structure.",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_sensitivity(path: Path, args: argparse.Namespace, scenario: dict[str, object]) -> None:
    base_kwargs: dict[str, float] = {
        "theta_mean_shift_deg": args.theta_shift_deg,
        "added_loss_db": args.added_loss_db,
        "threshold_delta_db": args.threshold_delta_db,
    }
    if args.p_los is not None:
        base_kwargs["p_los"] = args.p_los
    if args.nlos_loss_db is not None:
        base_kwargs["nlos_loss_db"] = args.nlos_loss_db
    if args.sigma_db is not None:
        base_kwargs["sigma_db"] = args.sigma_db

    rows = sensitivity_rows(
        scenario,
        voice_rate_bps=args.rate,
        n_samples=max(10_000, args.samples),
        base_kwargs=base_kwargs,
    )
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print("\nScenario-level sensitivity:")
    for row in rows:
        print(f"- {row['parameter']:<22} {row['perturbation']:<8} {pp(float(row['delta_pp']))}")


def main() -> int:
    args = parse_args()
    scenarios = load_scenarios()
    if args.list_scenarios:
        print("Available scenarios:")
        for row in scenarios:
            print(f"- {row['scenario_key']:<14} alias={str(row['scenario_key']).split('_')[0]:<7} label={row['label']}")
        print("Extra aliases: canyon, moving, shelter, tent")
        return 0

    selected = select_scenarios(args)
    rows = [evaluate_row(args, scenario) for scenario in selected]
    print_summary(rows)

    if args.no_write:
        return 0

    args.output_dir.mkdir(parents=True, exist_ok=True)
    write_csv(args.output_dir / "quick_summary.csv", rows)
    (args.output_dir / "quick_summary.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    write_markdown(args.output_dir / "quick_summary.md", rows, args)

    if len(selected) == 1:
        write_sensitivity(args.output_dir / "quick_sensitivity.csv", args, selected[0])

    print(f"\nWrote quick-run files to: {args.output_dir}")
    print("Next steps:")
    print("- Open the dashboard: streamlit run app.py")
    print("- Full reference path with MATLAB/Simulink: python run_all.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
