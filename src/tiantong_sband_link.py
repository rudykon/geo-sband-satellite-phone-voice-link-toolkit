#!/usr/bin/env python3
"""Generic GEO S-band satellite-phone link approximation.

This is not a reproduction of any vendor-specific implementation. It is an
engineering approximation based on publicly discussed GEO MSS S-band ranges and
standard narrowband satcom design ideas: circularly polarized handset antenna,
GEO S-band link budget, narrowband voice bearers, strong coding, orientation
loss, shadowing, and TCXO frequency acquisition.
"""
from __future__ import annotations

import csv
import json
import math
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.patches import Arc, Circle, FancyArrowPatch, Polygon, Rectangle
import numpy as np
from scipy.special import erfc

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "outputs" / "geo_satphone"
PLOTS = ROOT / "outputs" / "plots"
OUT.mkdir(parents=True, exist_ok=True)
PLOTS.mkdir(parents=True, exist_ok=True)

for fp in [
    "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
    "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
]:
    if Path(fp).exists():
        font_manager.fontManager.addfont(fp)
        _font_name = font_manager.FontProperties(fname=fp).get_name()
        plt.rcParams["font.family"] = _font_name
        plt.rcParams["font.sans-serif"] = [_font_name, "WenQuanYi Micro Hei", "Noto Sans CJK SC", "DejaVu Sans"]
        break
plt.rcParams["axes.unicode_minus"] = False
plt.rcParams["pdf.fonttype"] = 42
plt.rcParams["ps.fonttype"] = 42
plt.rcParams.update({
    "font.size": 9,
    "axes.labelsize": 9,
    "axes.titlesize": 9,
    "legend.fontsize": 8,
    "xtick.labelsize": 8,
    "ytick.labelsize": 8,
    "figure.dpi": 150,
})
COLORS = {
    "mc": "#D55E00", "exact": "#0072B2", "lb": "#6A3D9A", "ub": "#4D4D4D",
    "accent": "#009E73", "warn": "#E69F00", "bad": "#C44E52",
}

SCENARIO_LABELS = {
    "open": "open",
    "suburban": "forest",
    "urban": "canyon",
    "car": "vehicle",
    "indoor_window": "shelter",
}


def polish_axes(ax, grid_axis: str = "y") -> None:
    ax.grid(True, axis=grid_axis, color="#D9D9D9", linewidth=0.6, alpha=0.85)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)


def legend_above_bars(ax, *, ncol: int = 1, pad: float | None = None) -> None:
    handles, labels = ax.get_legend_handles_labels()
    rows = max(1, math.ceil(len(labels) / max(ncol, 1)))
    resolved_pad = 0.25 + 0.18 * (rows - 1) if pad is None else pad
    ymin, ymax = ax.get_ylim()
    if ax.get_yscale() == "log":
        ax.set_ylim(ymin, ymax * (10.0 ** resolved_pad))
    else:
        ax.set_ylim(ymin, ymax + (ymax - ymin) * resolved_pad)
    ax.legend(handles, labels, frameon=False, ncol=ncol, loc="upper center")


def save(fig, stem: str) -> None:
    fig.tight_layout()
    fig.savefig(PLOTS / f"{stem}.png", dpi=220)
    fig.savefig(PLOTS / f"{stem}.pdf")
    plt.close(fig)


def fspl_db(distance_km: float, freq_mhz: float) -> float:
    return 32.44 + 20.0 * math.log10(distance_km) + 20.0 * math.log10(freq_mhz)


def noise_dbm(bw_hz: float, nf_db: float = 2.0, temp_k: float = 290.0) -> float:
    return -228.6 + 10.0 * math.log10(temp_k) + 10.0 * math.log10(bw_hz) + nf_db + 30.0


def orientation_gain_db(theta_deg: float, g_peak_dbi: float = 2.0, exponent: float = 1.7,
                        g_min_dbi: float = -10.0) -> float:
    theta = min(abs(theta_deg), 85.0)
    gain_drop = 10.0 * exponent * math.log10(max(math.cos(math.radians(theta)), 1e-3))
    return max(g_min_dbi, g_peak_dbi + gain_drop)


def link_snr_db(bw_hz: float, theta_deg: float = 15.0, pt_dbm: float = 34.0, gr_dbi: float = 40.0,
                pol_loss_db: float = 0.5, extra_loss_db: float = 1.0, freq_mhz: float = 1995.0,
                distance_km: float = 36000.0) -> float:
    gt = orientation_gain_db(theta_deg)
    rx_dbm = pt_dbm + gt + gr_dbi - fspl_db(distance_km, freq_mhz) - pol_loss_db - extra_loss_db
    return rx_dbm - noise_dbm(bw_hz)


def ebn0_db_from_snr(snr_db: float, bw_hz: float, rb_bps: float) -> float:
    return snr_db + 10.0 * math.log10(bw_hz / rb_bps)


def qpsk_ber_awgn(ebn0_db: np.ndarray) -> np.ndarray:
    eb = 10.0 ** (ebn0_db / 10.0)
    return 0.5 * erfc(np.sqrt(eb))


def p_los_elevation(elev_deg: np.ndarray, scenario: str) -> np.ndarray:
    # Heuristic visibility model: open areas have higher base visibility, indoor/window lower.
    shift = {"open": 12.0, "suburban": 18.0, "urban": 26.0, "car": 30.0, "indoor_window": 38.0}[scenario]
    scale = {"open": 6.0, "suburban": 7.0, "urban": 8.0, "car": 8.5, "indoor_window": 9.5}[scenario]
    cap = {"open": 0.98, "suburban": 0.92, "urban": 0.78, "car": 0.60, "indoor_window": 0.38}[scenario]
    return cap / (1.0 + np.exp(-(elev_deg - shift) / scale))


def rapp_snr_penalty_db(output_backoff_db: np.ndarray, smoothness: float = 2.2) -> np.ndarray:
    """Approximate in-band SNR loss caused by a Rapp PA near compression."""
    amp = 10.0 ** (-output_backoff_db / 20.0)
    out = amp / np.power(1.0 + np.power(amp, 2.0 * smoothness), 1.0 / (2.0 * smoothness))
    gain_loss = 20.0 * np.log10(np.maximum(out / amp, 1e-9))
    distortion_floor = 0.15 + 2.4 * np.exp(-output_backoff_db / 1.8)
    return -gain_loss + distortion_floor


def et_efficiency(output_backoff_db: np.ndarray) -> np.ndarray:
    """Simple envelope-tracking drain-efficiency proxy."""
    return 0.18 + 0.36 / (1.0 + np.exp((output_backoff_db - 4.2) / 1.35))


def canyon_plos(elev_deg: np.ndarray, h_over_w: float, azimuth_misalignment_deg: float = 20.0) -> np.ndarray:
    """Simplified canyon-valley terrain visibility probability from elevation and H/W."""
    elev = np.radians(np.maximum(elev_deg, 1.0))
    projection = max(math.cos(math.radians(azimuth_misalignment_deg)), 0.25)
    blockage_index = h_over_w / projection
    margin = np.tan(elev) - blockage_index
    return 1.0 / (1.0 + np.exp(-margin / 0.18))


def run(seed: int = 20260608, n_mc: int = 200_000) -> None:
    rng = np.random.default_rng(seed)
    carrier_rows = []
    bws = [31.25e3, 41.7e3, 200e3]
    rb_options = [1200.0, 2400.0, 4000.0]
    theta0 = 15.0
    for bw in bws:
        snr = link_snr_db(bw, theta0)
        for rb in rb_options:
            carrier_rows.append({
                "band": "GEO S-band uplink",
                "uplink_mhz": 1995.0,
                "downlink_mhz": 2185.0,
                "bandwidth_hz": bw,
                "voice_rate_bps": rb,
                "pt_dbm": 34.0,
                "gt_peak_dbi": 2.0,
                "orientation_deg": theta0,
                "pol_loss_db": 0.5,
                "snr_db": snr,
                "ebn0_db": ebn0_db_from_snr(snr, bw, rb),
            })

    # Coded pi/4-QPSK approximation: pi/4-QPSK has QPSK-like BER; coding gain shifts Eb/N0.
    eb_axis = np.linspace(-4, 10, 29)
    ber_rows = []
    req = {1200.0: -1.0, 2400.0: 0.7, 4000.0: 2.2}
    for rate, threshold in req.items():
        coding_gain = {1200.0: 5.0, 2400.0: 4.2, 4000.0: 3.5}[rate]
        ber = qpsk_ber_awgn(eb_axis + coding_gain)
        for x, b in zip(eb_axis, ber):
            ber_rows.append({"voice_rate_bps": rate, "ebn0_db": float(x), "coded_ber_proxy": float(max(b, 1e-7)), "required_ebn0_db": threshold})

    scenarios = {
        "open": {"sigma_db": 2.5, "theta_mean": 8.0, "theta_std": 5.0, "extra_nlos_db": 8.0},
        "suburban": {"sigma_db": 4.0, "theta_mean": 13.0, "theta_std": 8.0, "extra_nlos_db": 12.0},
        "urban": {"sigma_db": 7.0, "theta_mean": 20.0, "theta_std": 12.0, "extra_nlos_db": 18.0},
        "car": {"sigma_db": 6.0, "theta_mean": 25.0, "theta_std": 14.0, "extra_nlos_db": 20.0},
        "indoor_window": {"sigma_db": 9.0, "theta_mean": 30.0, "theta_std": 16.0, "extra_nlos_db": 26.0},
    }
    availability_rows = []
    samples_by_scenario: dict[str, np.ndarray] = {}
    elev_deg = 45.0
    bw_main = 31.25e3
    for scenario, sp in scenarios.items():
        plos = float(p_los_elevation(np.array([elev_deg]), scenario)[0])
        theta = np.clip(rng.normal(sp["theta_mean"], sp["theta_std"], n_mc), 0, 80)
        gt = np.array([orientation_gain_db(float(t)) for t in theta])
        snr_det = 34.0 + gt + 40.0 - fspl_db(36000.0, 1995.0) - 0.5 - 1.0 - noise_dbm(bw_main)
        los_state = rng.random(n_mc) < plos
        shadow = rng.normal(0.0, sp["sigma_db"], n_mc)
        snr = snr_det - shadow - (~los_state) * sp["extra_nlos_db"]
        samples_by_scenario[scenario] = snr
        for rb, threshold in req.items():
            ebn0 = snr + 10.0 * math.log10(bw_main / rb)
            ok = ebn0 >= threshold
            mos = 1.2 + 2.4 / (1.0 + np.exp(-(ebn0 - threshold) / 1.8))
            availability_rows.append({
                "scenario": scenario,
                "elevation_deg": elev_deg,
                "p_los": plos,
                "voice_rate_bps": rb,
                "threshold_ebn0_db": threshold,
                "availability": float(np.mean(ok)),
                "p10_ebn0_db": float(np.quantile(ebn0, 0.10)),
                "median_ebn0_db": float(np.median(ebn0)),
                "mean_mos_proxy": float(np.mean(np.clip(mos, 1.0, 4.0))),
            })

    # Sensitivity to the proxy voice threshold. This prevents a single assumed
    # decoder/voice threshold from being over-interpreted as a proprietary value.
    threshold_sensitivity_rows = []
    for scenario, snr in samples_by_scenario.items():
        for rb, threshold in req.items():
            base_shift = 10.0 * math.log10(bw_main / rb)
            for delta in np.arange(-3.0, 3.01, 0.5):
                ebn0 = snr + base_shift
                threshold_sensitivity_rows.append({
                    "scenario": scenario,
                    "voice_rate_bps": rb,
                    "threshold_shift_db": float(delta),
                    "effective_threshold_ebn0_db": float(threshold + delta),
                    "availability": float(np.mean(ebn0 >= threshold + delta)),
                })

    # Urban ablation at 2.4 kbps. Impairments are added cumulatively so the
    # dominant loss mechanisms are visible in a compact table.
    urban = scenarios["urban"]
    n_ab = n_mc
    plos_urban = float(p_los_elevation(np.array([elev_deg]), "urban")[0])
    theta_ab = np.clip(rng.normal(urban["theta_mean"], urban["theta_std"], n_ab), 0, 80)
    gt_ab = np.array([orientation_gain_db(float(t)) for t in theta_ab])
    los_ab = rng.random(n_ab) < plos_urban
    shadow_ab = rng.normal(0.0, urban["sigma_db"], n_ab)
    rb_ab = 2400.0
    threshold_ab = req[rb_ab]
    eb_shift_ab = 10.0 * math.log10(bw_main / rb_ab)
    base_snr = 34.0 + 2.0 + 40.0 - fspl_db(36000.0, 1995.0) - noise_dbm(bw_main)
    ablation_specs = [
        ("free_space_thermal", base_snr),
        ("plus_posture", 34.0 + gt_ab + 40.0 - fspl_db(36000.0, 1995.0) - noise_dbm(bw_main)),
        ("plus_polarization_extra", 34.0 + gt_ab + 40.0 - fspl_db(36000.0, 1995.0) - 0.5 - 1.0 - noise_dbm(bw_main)),
        ("plus_los_nlos_shadow", 34.0 + gt_ab + 40.0 - fspl_db(36000.0, 1995.0) - 0.5 - 1.0 - noise_dbm(bw_main) - shadow_ab - (~los_ab) * urban["extra_nlos_db"]),
        ("plus_residual_frequency_loss", 34.0 + gt_ab + 40.0 - fspl_db(36000.0, 1995.0) - 0.5 - 1.0 - noise_dbm(bw_main) - shadow_ab - (~los_ab) * urban["extra_nlos_db"] - 0.7),
    ]
    ablation_rows = []
    prev = None
    for label, snr_val in ablation_specs:
        ebn0 = np.asarray(snr_val) + eb_shift_ab
        availability = float(np.mean(ebn0 >= threshold_ab))
        ablation_rows.append({
            "scenario": "urban",
            "voice_rate_bps": rb_ab,
            "configuration": label,
            "availability": availability,
            "absolute_drop_from_previous": 0.0 if prev is None else float(prev - availability),
            "median_ebn0_db": float(np.median(ebn0)),
            "p10_ebn0_db": float(np.quantile(ebn0, 0.10)),
        })
        prev = availability

    # Frequency acquisition: TCXO error and two-stage compensation residual.
    ppm = np.linspace(-2.0, 2.0, 161)
    f0 = 1995e6
    raw_hz = ppm * 1e-6 * f0
    residual_hz = raw_hz * 0.04 + rng.normal(0, 25.0, len(raw_hz))
    search_bin_hz = 50.0
    dwell_ms = 12.0
    acq_rows = []
    for p, raw, res in zip(ppm, raw_hz, residual_hz):
        raw_bins = math.ceil(abs(raw) / search_bin_hz) + 1
        res_bins = math.ceil(abs(res) / search_bin_hz) + 1
        acq_rows.append({
            "tcxo_ppm": float(p), "raw_offset_hz": float(raw), "residual_offset_hz": float(res),
            "raw_search_time_ms": raw_bins * dwell_ms, "closed_loop_search_time_ms": res_bins * dwell_ms,
        })


    # RF front-end proxy: Rapp PA compression plus envelope-tracking efficiency.
    pa_rows = []
    backoff_axis = np.linspace(0.5, 8.0, 31)
    for obo, loss, eff in zip(backoff_axis, rapp_snr_penalty_db(backoff_axis), et_efficiency(backoff_axis)):
        for scenario in ["urban", "car"]:
            sp = scenarios[scenario]
            plos = float(p_los_elevation(np.array([elev_deg]), scenario)[0])
            theta = np.clip(rng.normal(sp["theta_mean"], sp["theta_std"], n_mc // 4), 0, 80)
            gt = np.array([orientation_gain_db(float(t)) for t in theta])
            snr_det = 34.0 + gt + 40.0 - fspl_db(36000.0, 1995.0) - 0.5 - 1.0 - noise_dbm(bw_main)
            los_state = rng.random(n_mc // 4) < plos
            shadow = rng.normal(0.0, sp["sigma_db"], n_mc // 4)
            snr = snr_det - shadow - (~los_state) * sp["extra_nlos_db"] - loss
            ebn0 = snr + 10.0 * math.log10(bw_main / 2400.0)
            pa_rows.append({
                "scenario": scenario,
                "output_backoff_db": float(obo),
                "rapp_snr_penalty_db": float(loss),
                "et_efficiency": float(eff),
                "voice_rate_bps": 2400.0,
                "availability": float(np.mean(ebn0 >= req[2400.0])),
                "median_ebn0_db": float(np.median(ebn0)),
            })

    # End-to-end cold-start access proxy: BCH listen, RACH retry, TA, and frequency search.
    access_rows = []
    elev_axis = np.arange(10.0, 75.0, 5.0)
    for scenario in ["suburban", "urban", "car", "indoor_window"]:
        for el in elev_axis:
            plos = float(p_los_elevation(np.array([el]), scenario)[0])
            n = n_mc // 5
            bch = rng.uniform(1.0, 6.0, n) / np.maximum(plos, 0.08)
            rach_success = np.clip(0.18 + 0.75 * plos, 0.08, 0.96)
            rach_attempts = rng.geometric(rach_success, n)
            rach = 1.6 * rach_attempts
            ta = 1.0 + rng.lognormal(mean=0.1, sigma=0.35, size=n)
            closed_loop_freq = np.abs(rng.normal(120.0 * (1.0 - plos), 45.0, n))
            freq = (np.ceil(closed_loop_freq / search_bin_hz) + 1.0) * dwell_ms / 1000.0
            total = bch + rach + ta + freq
            access_rows.append({
                "scenario": scenario,
                "elevation_deg": float(el),
                "p_los": plos,
                "median_access_s": float(np.median(total)),
                "p90_access_s": float(np.quantile(total, 0.90)),
                "success_60s": float(np.mean(total <= 60.0)),
            })

    # Geometry-derived LOS probability for a simplified canyon-valley terrain mask.
    geometry_rows = []
    for hw in [0.5, 1.0, 2.0, 3.0]:
        for el in np.arange(5.0, 85.0, 2.5):
            geometry_rows.append({
                "h_over_w": hw,
                "elevation_deg": float(el),
                "p_los_geometry": float(canyon_plos(np.array([el]), hw)[0]),
            })

    write_csv(OUT / "carrier_budget.csv", carrier_rows)
    write_csv(OUT / "pi4qpsk_voice_ber.csv", ber_rows)
    write_csv(OUT / "voice_availability.csv", availability_rows)
    write_csv(OUT / "frequency_acquisition.csv", acq_rows)
    write_csv(OUT / "pa_et_tradeoff.csv", pa_rows)
    write_csv(OUT / "access_latency.csv", access_rows)
    write_csv(OUT / "geometry_plos.csv", geometry_rows)
    write_csv(OUT / "voice_threshold_sensitivity.csv", threshold_sensitivity_rows)
    write_csv(OUT / "urban_ablation.csv", ablation_rows)
    (OUT / "geo_satphone_results.json").write_text(json.dumps({
        "carrier_budget": carrier_rows,
        "pi4qpsk_voice_ber": ber_rows,
        "voice_availability": availability_rows,
        "frequency_acquisition": acq_rows,
        "pa_et_tradeoff": pa_rows,
        "access_latency": access_rows,
        "geometry_plos": geometry_rows,
        "voice_threshold_sensitivity": threshold_sensitivity_rows,
        "urban_ablation": ablation_rows,
        "notes": [
            "No vendor-specific implementation is modeled; this is a generic GEO S-band satellite-phone scenario approximation.",
            "DSSS is treated as a comparison baseline; the main bearer is narrowband voice.",
        ],
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    plot_budget(carrier_rows)
    plot_voice_ber(ber_rows)
    plot_availability(availability_rows)
    plot_acquisition(acq_rows)
    plot_pa_et(pa_rows)
    plot_access_latency(access_rows)
    plot_geometry_plos(geometry_rows)
    plot_threshold_sensitivity(threshold_sensitivity_rows)
    plot_urban_ablation(ablation_rows)
    print("Generic GEO S-band satellite-phone link simulation complete")
    print(OUT / "geo_satphone_results.json")


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def plot_budget(rows: list[dict[str, object]]) -> None:
    rates = [1200.0, 2400.0, 4000.0]
    bws = sorted({float(r["bandwidth_hz"]) for r in rows})
    fig, ax = plt.subplots(figsize=(6.7, 3.7))
    x = np.arange(len(bws))
    width = 0.22
    styles = {
        1200.0: {"color": COLORS["accent"], "alpha": 1.0, "hatch": "", "edgecolor": "none"},
        2400.0: {"color": COLORS["exact"], "alpha": 1.0, "hatch": "", "edgecolor": "none"},
        4000.0: {"color": "#BDBDBD", "alpha": 0.65, "hatch": "//", "edgecolor": "#666666"},
    }
    for i, rb in enumerate(rates):
        vals = [next(float(r["ebn0_db"]) for r in rows if float(r["bandwidth_hz"]) == bw and float(r["voice_rate_bps"]) == rb) for bw in bws]
        ax.bar(x + (i-1)*width, vals, width, label=f"{rb/1000:.1f} kbps", **styles[rb])
    ax.set_xticks(x, ["31.25 kHz", "41.7 kHz", "200 kHz"])
    ax.set_ylabel(r"$E_b/N_0$ (dB)")
    ax.set_title("GEO S-band narrowband bearer link budget")
    polish_axes(ax)
    legend_above_bars(ax, ncol=3)
    save(fig, "geo_satphone_link_budget")


def plot_voice_ber(rows: list[dict[str, object]]) -> None:
    fig, ax = plt.subplots(figsize=(6.6, 3.75))
    for rb, color in [(1200.0, COLORS["accent"]), (2400.0, COLORS["exact"]), (4000.0, COLORS["mc"] )]:
        subset = [r for r in rows if float(r["voice_rate_bps"]) == rb]
        ax.semilogy([r["ebn0_db"] for r in subset], [r["coded_ber_proxy"] for r in subset], "-", color=color, linewidth=1.8, label=f"{rb/1000:.1f} kbps voice")
        th = subset[0]["required_ebn0_db"]
        ax.axvline(th, color=color, linestyle=":", linewidth=1.0)
    ax.set_xlabel(r"$E_b/N_0$ (dB)")
    ax.set_ylabel("BER proxy")
    ax.set_ylim(1e-7, 1)
    ax.set_title(r"$\pi/4$-QPSK + strong-coding voice bearer proxy")
    polish_axes(ax)
    ax.legend(frameon=False, loc="lower left")
    save(fig, "geo_satphone_pi4qpsk_voice_ber")


def plot_availability(rows: list[dict[str, object]]) -> None:
    scenarios = ["open", "suburban", "urban", "car", "indoor_window"]
    rates = [1200.0, 2400.0, 4000.0]
    fig, ax = plt.subplots(figsize=(7.2, 3.9))
    x = np.arange(len(scenarios))
    width = 0.23
    styles = {
        1200.0: {"color": COLORS["accent"], "alpha": 1.0, "hatch": "", "edgecolor": "none"},
        2400.0: {"color": COLORS["exact"], "alpha": 1.0, "hatch": "", "edgecolor": "none"},
        4000.0: {"color": "#BDBDBD", "alpha": 0.65, "hatch": "//", "edgecolor": "#666666"},
    }
    for i, rb in enumerate(rates):
        vals = [next(float(r["availability"]) for r in rows if r["scenario"] == sc and float(r["voice_rate_bps"]) == rb) for sc in scenarios]
        ax.bar(x + (i-1)*width, vals, width, label=f"{rb/1000:.1f} kbps", **styles[rb])
    ax.set_xticks(x, [SCENARIO_LABELS[sc] for sc in scenarios])
    ax.set_ylim(0, 1.05)
    ax.set_ylabel("Voice availability")
    ax.set_title("GEO S-band voice availability by scenario")
    polish_axes(ax)
    ax.legend(frameon=False, ncol=3, loc="upper center", bbox_to_anchor=(0.5, 1.18), borderaxespad=0.0)
    ax.set_ylim(0, 1.05)
    save(fig, "geo_satphone_voice_availability")


def plot_acquisition(rows: list[dict[str, object]]) -> None:
    ppm = np.array([r["tcxo_ppm"] for r in rows])
    raw = np.array([r["raw_search_time_ms"] for r in rows])
    closed = np.array([r["closed_loop_search_time_ms"] for r in rows])
    fig, ax = plt.subplots(figsize=(6.6, 3.75))
    ax.plot(ppm, raw, color=COLORS["bad"], linewidth=1.8, label="TCXO only")
    ax.plot(ppm, closed, color=COLORS["exact"], linewidth=1.8, label="Network precomp + UE residual")
    ax.set_xlabel("TCXO frequency error (ppm)")
    ax.set_ylabel("Acquisition search time (ms)")
    ax.set_title("Two-stage frequency compensation proxy")
    polish_axes(ax)
    ax.legend(frameon=False, loc="upper center")
    save(fig, "geo_satphone_frequency_acquisition")


def plot_pa_et(rows: list[dict[str, object]]) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(7.2, 3.5))
    obo = np.array(sorted({float(r["output_backoff_db"]) for r in rows}))
    eff = np.array([next(float(r["et_efficiency"]) for r in rows if abs(float(r["output_backoff_db"]) - x) < 1e-9) for x in obo])
    loss = np.array([next(float(r["rapp_snr_penalty_db"]) for r in rows if abs(float(r["output_backoff_db"]) - x) < 1e-9) for x in obo])
    ax = axes[0]
    ax.plot(obo, loss, color=COLORS["bad"], linewidth=1.8, label="Rapp SNR penalty")
    ax2 = ax.twinx()
    ax2.plot(obo, eff * 100.0, color=COLORS["accent"], linewidth=1.8, label="ET efficiency")
    ax.set_xlabel("Output backoff (dB)")
    ax.set_ylabel("SNR penalty (dB)", color=COLORS["bad"])
    ax2.set_ylabel("Drain efficiency (%)", color=COLORS["accent"])
    ax.set_title("PA compression and ET proxy")
    polish_axes(ax)
    ax2.spines["top"].set_visible(False)

    ax = axes[1]
    for scenario, color in [("urban", COLORS["exact"]), ("car", COLORS["mc"])]:
        vals = [float(r["availability"]) for r in rows if r["scenario"] == scenario]
        ax.plot(obo, vals, marker="o", markersize=3, linewidth=1.6, color=color, label=SCENARIO_LABELS[scenario])
    ax.set_xlabel("Output backoff (dB)")
    ax.set_ylabel("2.4 kbps availability")
    ax.set_ylim(0, 1.02)
    ax.set_title("Voice availability under PA loss")
    polish_axes(ax)
    ax.legend(frameon=False, loc="lower right")
    save(fig, "geo_satphone_pa_et_tradeoff")


def plot_access_latency(rows: list[dict[str, object]]) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(7.2, 3.5), sharex=True)
    scenarios = [("suburban", COLORS["accent"]), ("urban", COLORS["exact"]), ("car", COLORS["mc"]), ("indoor_window", COLORS["bad"])]
    for scenario, color in scenarios:
        subset = [r for r in rows if r["scenario"] == scenario]
        x = [r["elevation_deg"] for r in subset]
        axes[0].plot(x, [r["median_access_s"] for r in subset], color=color, linewidth=1.7, label=SCENARIO_LABELS[scenario])
        axes[0].plot(x, [r["p90_access_s"] for r in subset], color=color, linewidth=1.0, linestyle="--")
        axes[1].plot(x, [r["success_60s"] for r in subset], color=color, linewidth=1.7, label=SCENARIO_LABELS[scenario])
    axes[0].set_ylabel("Access time (s)")
    axes[0].set_xlabel("Elevation angle (deg)")
    axes[0].set_title("Median / P90 cold-start time")
    axes[1].set_ylabel("Success within 60 s")
    axes[1].set_xlabel("Elevation angle (deg)")
    axes[1].set_ylim(0, 1.02)
    axes[1].set_title("Acquisition success probability")
    for ax in axes:
        polish_axes(ax)
    axes[1].legend(frameon=False, loc="lower right")
    save(fig, "geo_satphone_access_latency")


def plot_geometry_plos(rows: list[dict[str, object]]) -> None:
    fig, axes = plt.subplots(2, 1, figsize=(6.7, 5.05), gridspec_kw={"height_ratios": [1.02, 1.0]})
    ax_geo, ax_curve = axes

    # Top panel: make the canyon-valley terrain proxy visually explicit before the curves.
    ax_geo.set_xlim(0, 10)
    ax_geo.set_ylim(0, 6)
    ax_geo.axis("off")
    valley_color = "#ECEFF1"
    ridge_color = "#BCAAA4"
    ridge_shadow = "#8D6E63"
    edge_color = "#5D4037"
    los_color = "#009E73"
    blocked_color = "#C44E52"
    ue = (5.0, 0.62)

    ax_geo.add_patch(Rectangle((0, 0), 10, 0.42, facecolor=valley_color, edgecolor="none"))
    ax_geo.add_patch(Polygon([(0.0, 0.42), (0.0, 5.28), (1.05, 4.15), (2.05, 2.35),
                              (3.45, 0.66), (3.85, 0.42)], closed=True,
                             facecolor=ridge_color, edgecolor=edge_color, linewidth=0.8))
    ax_geo.add_patch(Polygon([(6.15, 0.42), (6.55, 0.66), (7.95, 2.35), (8.95, 4.15),
                              (10.0, 5.28), (10.0, 0.42)], closed=True,
                             facecolor=ridge_color, edgecolor=edge_color, linewidth=0.8))
    ax_geo.add_patch(Polygon([(0.0, 0.42), (0.0, 5.28), (0.62, 4.66), (1.18, 3.48),
                              (0.92, 1.52), (2.12, 0.42)], closed=True,
                             facecolor=ridge_shadow, edgecolor="none", alpha=0.25))
    ax_geo.add_patch(Polygon([(7.88, 0.42), (9.08, 1.52), (8.82, 3.48), (9.38, 4.66),
                              (10.0, 5.28), (10.0, 0.42)], closed=True,
                             facecolor=ridge_shadow, edgecolor="none", alpha=0.25))

    ax_geo.add_patch(Circle(ue, 0.13, facecolor="#263238", edgecolor="white", linewidth=0.8, zorder=5))
    ax_geo.text(ue[0], 0.2, "UE", ha="center", va="center")
    sat = (6.45, 5.55)
    ax_geo.scatter([sat[0]], [sat[1]], marker="*", s=95, color="#F9A825", edgecolor="#6D4C41", linewidth=0.5, zorder=6)
    ax_geo.text(sat[0] + 0.25, sat[1] + 0.05, "satellite", ha="left", va="center")

    low_end = (6.85, 1.25)
    ax_geo.add_patch(FancyArrowPatch(ue, sat, arrowstyle="->", mutation_scale=10,
                                     linewidth=1.2, color=los_color))
    ax_geo.add_patch(FancyArrowPatch(ue, low_end, arrowstyle="->", mutation_scale=10,
                                     linewidth=1.0, linestyle="--", color=blocked_color))
    ax_geo.text(4.6, 3.35, "high-elevation LOS", color=los_color, ha="left")
    ax_geo.text(5.65, 1.72, "ridge-wall blockage", color=blocked_color, ha="left")

    ax_geo.annotate("", xy=(3.45, 0.75), xytext=(6.55, 0.75),
                    arrowprops={"arrowstyle": "<->", "lw": 0.8, "color": edge_color})
    ax_geo.text(5.0, 0.92, "valley opening W", color=edge_color, ha="center")
    ax_geo.annotate("", xy=(0.36, 0.42), xytext=(0.36, 5.28),
                    arrowprops={"arrowstyle": "<->", "lw": 0.8, "color": edge_color})
    ax_geo.text(0.18, 2.9, "ridge relief H", color=edge_color, rotation=90,
                ha="center", va="center")
    ax_geo.add_patch(Arc(ue, 1.05, 1.05, theta1=0, theta2=72, color=edge_color, linewidth=0.8))
    ax_geo.text(5.64, 0.95, r"$\theta$", color=edge_color)
    ax_geo.text(5.0, 5.05, r"larger $H/W$ needs higher $\theta$",
                ha="center", color=edge_color)

    palette = ["#009E73", "#0072B2", "#E69F00", "#C44E52"]
    for hw, color in zip([0.5, 1.0, 2.0, 3.0], palette):
        subset = sorted([r for r in rows if abs(float(r["h_over_w"]) - hw) < 1e-9], key=lambda r: float(r["elevation_deg"]))
        ax_curve.plot([float(r["elevation_deg"]) for r in subset], [float(r["p_los_geometry"]) for r in subset],
                      linewidth=1.7, color=color, label=f"H/W={hw:g}")
    ax_curve.set_xlabel("Satellite elevation angle (deg)")
    ax_curve.set_ylabel(r"$P_{LOS}^{geo}$")
    ax_curve.set_ylim(0, 1.02)
    ax_curve.set_xlim(5, 82.5)
    ax_curve.set_title("Visibility probability from the same proxy")
    polish_axes(ax_curve)
    ax_curve.legend(frameon=False, ncol=2, loc="lower right", handlelength=1.7)

    def point_at_probability(hw: float, target: float = 0.5) -> tuple[float, float]:
        subset = sorted(
            (float(r["elevation_deg"]), float(r["p_los_geometry"]))
            for r in rows
            if abs(float(r["h_over_w"]) - hw) < 1e-9
        )
        for (x0, y0), (x1, y1) in zip(subset, subset[1:]):
            if (y0 - target) * (y1 - target) <= 0 and y1 != y0:
                frac = (target - y0) / (y1 - y0)
                return x0 + frac * (x1 - x0), target
        return min(subset, key=lambda item: abs(item[1] - target))

    low_x, low_y = point_at_probability(0.5)
    high_x, high_y = point_at_probability(2.0)
    ax_curve.scatter([low_x, high_x], [low_y, high_y], s=22, color=[palette[0], palette[2]],
                     edgecolor="white", linewidth=0.6, zorder=5)
    ax_curve.annotate("50% LOS", xy=(low_x, low_y), xytext=(18, 0.30),
                      arrowprops={"arrowstyle": "->", "lw": 0.8, "color": palette[0]},
                      color=palette[0], ha="left", va="center")
    ax_curve.annotate("50% LOS", xy=(high_x, high_y), xytext=(48, 0.72),
                      arrowprops={"arrowstyle": "->", "lw": 0.8, "color": palette[2]},
                      color=palette[2], ha="left", va="center")
    fig.subplots_adjust(left=0.10, right=0.985, top=0.98, bottom=0.10, hspace=0.28)
    fig.savefig(PLOTS / "geo_satphone_geometry_plos.png", dpi=220, bbox_inches="tight", pad_inches=0.04)
    fig.savefig(PLOTS / "geo_satphone_geometry_plos.pdf", bbox_inches="tight", pad_inches=0.04)
    plt.close(fig)


def plot_threshold_sensitivity(rows: list[dict[str, object]]) -> None:
    fig, ax = plt.subplots(figsize=(6.7, 3.7))
    scenarios = [("urban", COLORS["exact"]), ("car", COLORS["mc"]), ("indoor_window", COLORS["bad"])]
    rb = 2400.0
    for scenario, color in scenarios:
        subset = [r for r in rows if r["scenario"] == scenario and abs(float(r["voice_rate_bps"]) - rb) < 1e-9]
        ax.plot([r["threshold_shift_db"] for r in subset], [r["availability"] for r in subset],
                marker="o", markersize=3, linewidth=1.7, color=color, label=SCENARIO_LABELS[scenario])
    ax.set_xlabel(r"Voice threshold shift $\Delta\Gamma$ (dB)")
    ax.set_ylabel("2.4 kbps availability")
    ax.set_ylim(0, 1.02)
    ax.set_title("Sensitivity to proxy voice threshold")
    polish_axes(ax)
    ax.legend(frameon=False, loc="lower left")
    save(fig, "geo_satphone_voice_threshold_sensitivity")


def plot_urban_ablation(rows: list[dict[str, object]]) -> None:
    labels = [
        "FS+noise",
        "+posture",
        "+pol/impl",
        "+LOS/NLOS",
        "+freq loss",
    ]
    vals = [float(r["availability"]) for r in rows]
    fig, ax = plt.subplots(figsize=(6.7, 3.7))
    ax.bar(np.arange(len(vals)), vals, color=[COLORS["accent"], COLORS["exact"], COLORS["warn"], COLORS["mc"], COLORS["bad"]])
    ax.set_xticks(np.arange(len(vals)), labels, rotation=18, ha="right")
    ax.set_ylim(0, 1.05)
    ax.set_ylabel("Canyon 2.4 kbps availability")
    ax.set_title("Cumulative impairment ablation")
    polish_axes(ax)
    save(fig, "geo_satphone_urban_ablation")


if __name__ == "__main__":
    run()
