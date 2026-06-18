"""Reusable helpers for dashboard and notebook exploration."""
from __future__ import annotations

import csv
import json
import math
from pathlib import Path
from typing import Iterable

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
EXPECTED_DATA = ROOT / "expected_outputs" / "data"
EXPECTED_FIGURES = ROOT / "expected_outputs" / "figures" / "all"
OUTPUT_DATA = ROOT / "outputs" / "data"

VOICE_BW_HZ = 31.25e3
TX_POWER_DBM = 34.0
SAT_RX_GAIN_DBI = 40.0
GEO_DISTANCE_KM = 36_000.0
UPLINK_MHZ = 1995.0
POL_LOSS_DB = 0.5
IMPLEMENTATION_LOSS_DB = 1.0
NF_DB = 2.0


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def data_path(*parts: str, prefer_outputs: bool = False) -> Path:
    """Return an output data path, falling back to committed expected data."""
    preferred = OUTPUT_DATA.joinpath(*parts)
    expected = EXPECTED_DATA.joinpath(*parts)
    if prefer_outputs and preferred.exists():
        return preferred
    if expected.exists():
        return expected
    return preferred


def load_reference_baseline(prefer_outputs: bool = False) -> dict[str, object]:
    path = data_path("voice_link", "voice_link_reference_baseline.json", prefer_outputs=prefer_outputs)
    return json.loads(path.read_text(encoding="utf-8"))


def load_table(name: str, group: str = "voice_link", prefer_outputs: bool = False) -> list[dict[str, str]]:
    return _read_csv(data_path(group, name, prefer_outputs=prefer_outputs))


def load_scenarios(prefer_outputs: bool = False) -> list[dict[str, object]]:
    baseline = load_reference_baseline(prefer_outputs)
    scenarios: list[dict[str, object]] = []
    for row in baseline["scenarios"]:  # type: ignore[index]
        scenarios.append(
            {
                "scenario_key": str(row["scenario_key"]),
                "scenario_model_key": str(row["scenario_model_key"]),
                "label": str(row["label"]),
                "p_los": float(row["p_los"]),
                "sigma_db": float(row["sigma_db"]),
                "theta_mean_deg": float(row["theta_mean_deg"]),
                "theta_std_deg": float(row["theta_std_deg"]),
                "nlos_loss_db": float(row["nlos_loss_db"]),
                "availability_2400": float(row["voice_availability_2400"]),
                "p10_ebn0_2400_db": float(row["p10_ebn0_2400_db"]),
                "median_ebn0_2400_db": float(row["median_ebn0_2400_db"]),
            }
        )
    return scenarios


def load_thresholds(prefer_outputs: bool = False) -> dict[float, float]:
    baseline = load_reference_baseline(prefer_outputs)
    return {float(k): float(v) for k, v in baseline["thresholds"].items()}  # type: ignore[index]


def fspl_db(distance_km: float = GEO_DISTANCE_KM, freq_mhz: float = UPLINK_MHZ) -> float:
    return 32.44 + 20.0 * math.log10(distance_km) + 20.0 * math.log10(freq_mhz)


def noise_dbm(bw_hz: float = VOICE_BW_HZ, nf_db: float = NF_DB, temp_k: float = 290.0) -> float:
    return -228.6 + 10.0 * math.log10(temp_k) + 10.0 * math.log10(bw_hz) + nf_db + 30.0


def orientation_gain_db(theta_deg: np.ndarray | float, g_peak_dbi: float = 2.0, exponent: float = 1.7) -> np.ndarray:
    theta = np.minimum(np.abs(theta_deg), 85.0)
    gain_drop = 10.0 * exponent * np.log10(np.maximum(np.cos(np.radians(theta)), 1e-3))
    return np.maximum(-10.0, g_peak_dbi + gain_drop)


def stable_seed(scenario_model_key: str, seed: int = 20260608) -> int:
    return seed + sum((idx + 1) * ord(ch) for idx, ch in enumerate(scenario_model_key))


def scenario_samples(
    scenario: dict[str, object],
    *,
    n_samples: int = 80_000,
    seed: int = 20260608,
) -> dict[str, np.ndarray]:
    rng = np.random.default_rng(stable_seed(str(scenario["scenario_model_key"]), seed))
    theta = np.clip(
        rng.normal(float(scenario["theta_mean_deg"]), float(scenario["theta_std_deg"]), n_samples),
        0.0,
        80.0,
    )
    return {
        "theta": theta,
        "los_uniform": rng.random(n_samples),
        "shadow_normal": rng.normal(0.0, 1.0, n_samples),
    }


def evaluate_voice_link(
    scenario: dict[str, object],
    *,
    voice_rate_bps: float = 2400.0,
    p_los: float | None = None,
    nlos_loss_db: float | None = None,
    sigma_db: float | None = None,
    theta_mean_shift_deg: float = 0.0,
    added_loss_db: float = 0.0,
    threshold_delta_db: float = 0.0,
    n_samples: int = 80_000,
    seed: int = 20260608,
) -> dict[str, float]:
    """Evaluate the dashboard's Monte-Carlo voice-link screening approximation."""
    thresholds = load_thresholds()
    if voice_rate_bps not in thresholds:
        raise ValueError(f"Unsupported voice rate: {voice_rate_bps}")

    p_los = float(scenario["p_los"] if p_los is None else p_los)
    nlos_loss_db = float(scenario["nlos_loss_db"] if nlos_loss_db is None else nlos_loss_db)
    sigma_db = float(scenario["sigma_db"] if sigma_db is None else sigma_db)

    sample = scenario_samples(scenario, n_samples=n_samples, seed=seed)
    theta = np.clip(sample["theta"] + theta_mean_shift_deg, 0.0, 80.0)
    gt = orientation_gain_db(theta)
    snr_det = (
        TX_POWER_DBM
        + gt
        + SAT_RX_GAIN_DBI
        - fspl_db()
        - POL_LOSS_DB
        - IMPLEMENTATION_LOSS_DB
        - noise_dbm()
        - added_loss_db
    )
    shadow = sample["shadow_normal"] * max(0.1, sigma_db)
    los_state = sample["los_uniform"] < float(np.clip(p_los, 0.01, 0.99))
    snr_db = snr_det - shadow - (~los_state) * max(0.0, nlos_loss_db)
    ebn0_db = snr_db + 10.0 * math.log10(VOICE_BW_HZ / voice_rate_bps)
    threshold_db = thresholds[voice_rate_bps] + threshold_delta_db
    capacity = np.log2(1.0 + 10.0 ** (snr_db / 10.0))

    single_state_snr = snr_det - shadow
    single_state_ebn0 = single_state_snr + 10.0 * math.log10(VOICE_BW_HZ / voice_rate_bps)
    avg_ebn0 = (
        float(
            TX_POWER_DBM
            + orientation_gain_db(float(scenario["theta_mean_deg"]) + theta_mean_shift_deg)
            + SAT_RX_GAIN_DBI
            - fspl_db()
            - POL_LOSS_DB
            - IMPLEMENTATION_LOSS_DB
            - noise_dbm()
            - added_loss_db
        )
        - (1.0 - p_los) * nlos_loss_db
        + 10.0 * math.log10(VOICE_BW_HZ / voice_rate_bps)
    )

    return {
        "availability": float(np.mean(ebn0_db >= threshold_db)),
        "p10_ebn0_db": float(np.quantile(ebn0_db, 0.10)),
        "median_ebn0_db": float(np.median(ebn0_db)),
        "c0p01_bit_per_s_hz": float(np.quantile(capacity, 0.01)),
        "threshold_ebn0_db": float(threshold_db),
        "average_snr_margin_db": float(avg_ebn0 - threshold_db),
        "average_snr_screening_availability": 1.0 if avg_ebn0 >= threshold_db else 0.0,
        "single_state_lognormal_availability": float(np.mean(single_state_ebn0 >= threshold_db)),
    }


def sensitivity_rows(
    scenario: dict[str, object],
    *,
    voice_rate_bps: float = 2400.0,
    n_samples: int = 60_000,
    base_kwargs: dict[str, float] | None = None,
) -> list[dict[str, float | str]]:
    base_kwargs = dict(base_kwargs or {})
    p_los = float(base_kwargs.get("p_los", float(scenario["p_los"])))
    nlos_loss_db = float(base_kwargs.get("nlos_loss_db", float(scenario["nlos_loss_db"])))
    sigma_db = float(base_kwargs.get("sigma_db", float(scenario["sigma_db"])))
    theta_shift = float(base_kwargs.get("theta_mean_shift_deg", 0.0))
    added_loss_db = float(base_kwargs.get("added_loss_db", 0.0))
    threshold_delta_db = float(base_kwargs.get("threshold_delta_db", 0.0))

    base = evaluate_voice_link(
        scenario,
        voice_rate_bps=voice_rate_bps,
        n_samples=n_samples,
        **base_kwargs,
    )
    specs = [
        ("NLOS excess loss", "+5 dB", {"nlos_loss_db": nlos_loss_db + 5.0}),
        ("LOS probability", "-0.10", {"p_los": p_los - 0.10}),
        ("Shadowing sigma", "+2 dB", {"sigma_db": sigma_db + 2.0}),
        ("Posture angle", "+10 deg", {"theta_mean_shift_deg": theta_shift + 10.0}),
        ("Voice threshold", "+2 dB", {"threshold_delta_db": threshold_delta_db + 2.0}),
        ("Rain/atmospheric loss", "+2 dB", {"added_loss_db": added_loss_db + 2.0}),
        ("PA compression loss", "+3 dB", {"added_loss_db": added_loss_db + 3.0}),
    ]
    rows: list[dict[str, float | str]] = []
    for parameter, perturbation, kwargs in specs:
        stressed_kwargs = {**base_kwargs, **kwargs}
        stressed = evaluate_voice_link(
            scenario,
            voice_rate_bps=voice_rate_bps,
            n_samples=n_samples,
            **stressed_kwargs,
        )
        rows.append(
            {
                "parameter": parameter,
                "perturbation": perturbation,
                "baseline_availability_pct": 100.0 * base["availability"],
                "stressed_availability_pct": 100.0 * stressed["availability"],
                "delta_pp": 100.0 * (stressed["availability"] - base["availability"]),
            }
        )
    rows.sort(key=lambda row: abs(float(row["delta_pp"])), reverse=True)
    return rows


def figure_paths(names: Iterable[str]) -> dict[str, Path]:
    return {name: EXPECTED_FIGURES / name for name in names}
