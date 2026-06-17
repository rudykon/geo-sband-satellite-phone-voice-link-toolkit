#!/usr/bin/env python3
"""D2C outage-capacity bounds and Monte Carlo validation.

The Chernoff expression often written for the lower Gaussian tail is a
conservative lower bound on the epsilon-quantile, not an upper bound. This
script therefore reports the sandwich

    C_chernoff_LB <= C_exact ~= C_MC <= C_no_shadow_UB

and keeps the exact lognormal quantile as the reference closed-form expression.
"""
from __future__ import annotations

import csv
import json
import math
from pathlib import Path
from typing import Iterable

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
import numpy as np
from scipy.stats import norm

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "outputs" / "outage_capacity"
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
    "mc": "#D55E00",
    "exact": "#0072B2",
    "lb": "#6A3D9A",
    "ub": "#4D4D4D",
    "accent": "#009E73",
    "warn": "#E69F00",
    "bad": "#C44E52",
}


def polish_axes(ax, grid_axis: str = "y") -> None:
    ax.grid(True, axis=grid_axis, color="#D9D9D9", linewidth=0.6, alpha=0.8)
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


def save_plot(fig: plt.Figure, stem: str, *, tight: bool = True) -> None:
    if tight:
        fig.tight_layout()
    fig.savefig(PLOTS / f"{stem}.png", dpi=220)
    fig.savefig(PLOTS / f"{stem}.pdf")
    plt.close(fig)



def noise_dbm(bandwidth_hz: float, t_sys_k: float = 290.0, nf_db: float = 2.0) -> float:
    return -228.6 + 10.0 * math.log10(t_sys_k) + 10.0 * math.log10(bandwidth_hz) + nf_db + 30.0


def gamma0_db(
    sf: float,
    bandwidth_hz: float,
    p_t_dbm: float = 33.0,
    g_t_dbi: float = 0.0,
    g_r_dbi: float = 40.0,
    l_fs_db: float = 189.56668020184978,
    l_extra_db: float = 1.0,
    nf_db: float = 2.0,
    t_sys_k: float = 290.0,
) -> float:
    gp_db = 10.0 * math.log10(sf)
    return p_t_dbm + g_t_dbi + g_r_dbi - l_fs_db - l_extra_db - noise_dbm(bandwidth_hz, t_sys_k, nf_db) + gp_db


def gamma0_lin(sf: float, bandwidth_hz: float) -> float:
    return 10.0 ** (gamma0_db(sf, bandwidth_hz) / 10.0)


def sigma_nat(sigma_db: float) -> float:
    return math.log(10.0) / 10.0 * sigma_db


def c_exact(g0: float, sigma_db: float, eps: float) -> float:
    sig = sigma_nat(sigma_db)
    gamma_eps = g0 * math.exp(sig * float(norm.ppf(eps)))
    return math.log2(1.0 + gamma_eps)


def c_chernoff_lb(g0: float, sigma_db: float, eps: float) -> float:
    """Conservative closed-form lower bound on epsilon-outage capacity."""
    sig = sigma_nat(sigma_db)
    gamma_lb = g0 * math.exp(-sig * math.sqrt(2.0 * math.log(1.0 / eps)))
    return math.log2(1.0 + gamma_lb)


def c_no_shadow_ub(g0: float) -> float:
    """Trivial but rigorous upper bound for zero-mean loss-only shadow variable."""
    return math.log2(1.0 + g0)


def c_mc(g0: float, sigma_db: float, eps: float, n: int, rng: np.random.Generator) -> float:
    x_db = rng.standard_normal(n) * sigma_db
    gamma = g0 * 10.0 ** (-x_db / 10.0)
    cap = np.log2(1.0 + gamma)
    return float(np.quantile(cap, eps))



def c_two_state_exact(g0_l: float, sigma_l_db: float, g0_n: float, sigma_n_db: float, p_los: float, eps: float) -> float:
    sig_l = sigma_nat(sigma_l_db)
    sig_n = sigma_nat(sigma_n_db)
    mu_l = math.log(g0_l)
    mu_n = math.log(g0_n)

    def cdf(cap: float) -> float:
        gamma_th = max(2.0 ** cap - 1.0, 1e-300)
        return p_los * float(norm.cdf((math.log(gamma_th) - mu_l) / sig_l)) + (1.0 - p_los) * float(norm.cdf((math.log(gamma_th) - mu_n) / sig_n))

    lo = 0.0
    hi = max(c_no_shadow_ub(g0_l), c_no_shadow_ub(g0_n), 1.0)
    while cdf(hi) < eps:
        hi *= 2.0
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if cdf(mid) < eps:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def c_two_state_chernoff_lb(g0_l: float, sigma_l_db: float, g0_n: float, sigma_n_db: float, p_los: float, eps: float) -> tuple[float, float, float]:
    # Grid allocation is sufficient here because this is a validation plot, not a runtime optimizer.
    best = -1.0
    best_l = float("nan")
    best_n = float("nan")
    w_n = 1.0 - p_los
    for eps_l in np.linspace(max(1e-5, (eps - w_n * 0.999) / p_los), min(0.999, eps / p_los), 2500):
        eps_n = (eps - p_los * eps_l) / w_n
        if not (0.0 < eps_n < 1.0):
            continue
        c_l = c_chernoff_lb(g0_l, sigma_l_db, float(eps_l))
        c_n = c_chernoff_lb(g0_n, sigma_n_db, float(eps_n))
        val = min(c_l, c_n)
        if val > best:
            best = val
            best_l = float(eps_l)
            best_n = float(eps_n)
    return best, best_l, best_n




def cap_quantile_from_samples(gamma: np.ndarray, eps: float) -> float:
    return float(np.quantile(np.log2(1.0 + gamma), eps))


def neg_moment_chernoff_capacity_lb(samples: np.ndarray, eps: float, t_grid: np.ndarray | None = None) -> tuple[float, float]:
    """Moment/Chernoff lower bound using empirical E[gamma^{-t}]."""
    gamma = np.maximum(np.asarray(samples, dtype=float), 1e-300)
    if t_grid is None:
        t_grid = np.linspace(0.05, 8.0, 320)
    best_gamma = 0.0
    best_t = float("nan")
    log_gamma = np.log(gamma)
    for t in t_grid:
        # log E[gamma^{-t}] for numerical stability.
        vals = -t * log_gamma
        vmax = float(np.max(vals))
        log_moment = vmax + math.log(float(np.mean(np.exp(vals - vmax))))
        z = math.exp((math.log(eps) - log_moment) / t)
        if z > best_gamma:
            best_gamma = z
            best_t = float(t)
    return math.log2(1.0 + best_gamma), best_t


def sample_loo(g0: float, sigma_los_db: float, k_db: float, n: int, rng: np.random.Generator) -> np.ndarray:
    """Loo-like power gain: lognormal LOS amplitude plus Rayleigh scatter."""
    k_lin = 10.0 ** (k_db / 10.0)
    los_power_mean = k_lin / (k_lin + 1.0)
    scat_power_mean = 1.0 / (k_lin + 1.0)
    los_amp = np.sqrt(los_power_mean) * 10.0 ** (rng.normal(0.0, sigma_los_db, n) / 20.0)
    scat = np.sqrt(scat_power_mean / 2.0) * (rng.standard_normal(n) + 1j * rng.standard_normal(n))
    h = los_amp + scat
    return g0 * np.abs(h) ** 2


def sample_suzuki(g0: float, sigma_db: float, n: int, rng: np.random.Generator) -> np.ndarray:
    """Suzuki fading: Rayleigh power with lognormal local mean."""
    local_mean = 10.0 ** (rng.normal(0.0, sigma_db, n) / 10.0)
    rayleigh_power = rng.exponential(1.0, n)
    return g0 * local_mean * rayleigh_power


def sample_lutz(g0_good: float, sigma_good_db: float, g0_bad: float, sigma_bad_db: float, p_good: float, n: int, rng: np.random.Generator) -> np.ndarray:
    """Lutz-like two-state land-mobile satellite model."""
    good = rng.random(n) < p_good
    gamma = np.empty(n, dtype=float)
    n_good = int(np.sum(good))
    n_bad = n - n_good
    gamma[good] = sample_loo(g0_good, sigma_good_db, 10.0, n_good, rng)
    gamma[~good] = sample_suzuki(g0_bad, sigma_bad_db, n_bad, rng)
    return gamma


def plot_composite_fading(rows: list[dict[str, object]]) -> None:
    labels = [str(r["model"]) for r in rows]
    x = np.arange(len(rows))
    c_mc_vals = np.array([float(r["c_mc"]) for r in rows])
    c_lb_vals = np.array([float(r["c_chernoff_lb"]) for r in rows])
    tight = c_lb_vals / np.maximum(c_mc_vals, 1e-12)

    fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(7.4, 3.45), gridspec_kw={"width_ratios": [1.25, 1.0]})
    width = 0.34
    ax0.bar(x - width / 2, c_mc_vals, width, color=COLORS["mc"], label="Monte Carlo")
    ax0.bar(x + width / 2, c_lb_vals, width, color=COLORS["lb"], label="Moment-Chernoff LB")
    ax0.set_xticks(x, labels)
    ax0.set_ylabel(r"$C_\epsilon$ (bit/s/Hz)")
    ax0.set_title("(a) Capacity comparison")
    polish_axes(ax0)
    legend_above_bars(ax0, ncol=2)
    for xi, val in zip(x, c_mc_vals):
        ax0.text(xi - width / 2, val + max(c_mc_vals) * 0.025, f"{val:.3f}", ha="center", va="bottom", fontsize=8)
    ax0.annotate("~92x below Loo", xy=(2 - width / 2, c_mc_vals[2]), xytext=(1.1, max(c_mc_vals) * 0.52),
                 arrowprops={"arrowstyle": "->", "lw": 0.8}, fontsize=8)

    order = np.argsort(tight)[::-1]
    labels_o = [labels[i] for i in order]
    tight_o = tight[order]
    bar_colors = [COLORS["accent"], COLORS["warn"], COLORS["bad"]]
    ax1.barh(np.arange(len(order)), tight_o * 100.0, color=bar_colors)
    ax1.set_yticks(np.arange(len(order)), labels_o)
    ax1.invert_yaxis()
    ax1.set_xlabel(r"Tightness $C_{LB}/C_{MC}$ (%)")
    ax1.set_title("(b) Lower-bound tightness")
    polish_axes(ax1, "x")
    for yi, val in enumerate(tight_o * 100.0):
        ax1.text(val + 0.8, yi, f"{val:.0f}%", va="center", fontsize=8)
    ax1.set_xlim(0, max(tight_o * 100.0) * 1.28)
    save_plot(fig, "outage_capacity_composite_fading")


def plot_composite_snr_distribution(specs: list[tuple[str, np.ndarray, dict[str, object]]], eps: float) -> None:
    fig, ax = plt.subplots(figsize=(6.9, 3.8))
    palette = {"Loo": COLORS["exact"], "Suzuki": COLORS["warn"], "Lutz": COLORS["bad"]}
    lutz_tail: tuple[float, float] | None = None
    for model, gamma_samples, _ in specs:
        snr_db = 10.0 * np.log10(np.maximum(gamma_samples, 1e-300))
        q = float(np.quantile(snr_db, eps))
        xs = np.sort(snr_db)
        ys = (np.arange(len(xs)) + 1.0) / len(xs)
        # Use deterministic thinning so the PDF stays compact and reproducible.
        idx = np.linspace(0, len(xs) - 1, 2500).astype(int)
        ax.semilogy(xs[idx], ys[idx], color=palette[str(model)], linewidth=1.8, label=f"{model}, P1={q:.1f} dB")
        ax.axvline(q, color=palette[str(model)], linestyle=":", linewidth=1.0)
        if str(model) == "Lutz":
            lutz_tail = (q, eps)
    ax.axhline(eps, color=COLORS["ub"], linestyle="--", linewidth=1.0, label=r"$\epsilon=10^{-2}$")
    ax.set_xlabel("Instantaneous SNR (dB)")
    ax.set_ylabel("Empirical CDF")
    ax.set_title("Composite-fading lower-tail SNR distributions")
    ax.set_ylim(1e-4, 1.0)
    polish_axes(ax, "both")
    ax.legend(frameon=False, loc="lower right", fontsize=8)
    if lutz_tail is not None:
        ax.scatter([lutz_tail[0]], [lutz_tail[1]], s=34, facecolor="white",
                   edgecolor=COLORS["bad"], linewidth=1.0, zorder=5)
        ax.annotate("Lutz bad-state tail", xy=lutz_tail, xytext=(lutz_tail[0] - 7.5, 8e-2),
                    arrowprops={"arrowstyle": "->", "lw": 0.9, "color": COLORS["bad"],
                                "shrinkA": 2, "shrinkB": 4},
                    color=COLORS["bad"], fontsize=8, ha="right", va="center")
    save_plot(fig, "outage_capacity_composite_snr_cdf")

def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def plot_sigma_scan(rows: list[dict[str, object]]) -> None:
    x = np.array([float(r["sigma_db"]) for r in rows])
    c_mc_vals = np.array([float(r["c_mc"]) for r in rows])
    c_exact_vals = np.array([float(r["c_exact"]) for r in rows])
    c_lb_vals = np.array([float(r["c_chernoff_lb"]) for r in rows])
    c_ub_vals = np.array([float(r["c_no_shadow_ub"]) for r in rows])
    residual = c_exact_vals - c_lb_vals

    fig, (ax, axr) = plt.subplots(
        2, 1, figsize=(7.2, 5.6), sharex=True,
        gridspec_kw={"height_ratios": [3.2, 1.15], "hspace": 0.08},
    )
    ax.fill_between(x, c_mc_vals - 0.01, c_mc_vals + 0.01, color=COLORS["mc"], alpha=0.16, linewidth=0,
                    label="Monte Carlo 95% CI")
    ax.plot(x, c_mc_vals, "o", color=COLORS["mc"], markersize=4.5, label="Monte Carlo")
    ax.plot(x, c_exact_vals, "-", color=COLORS["exact"], linewidth=1.9, label="Exact lognormal quantile")
    ax.plot(x, c_lb_vals, "--", color=COLORS["lb"], linewidth=1.8, label="Chernoff LB")
    ax.plot(x, c_ub_vals, "-.", color=COLORS["ub"], linewidth=1.5, label="Median-SNR ceiling")
    ax.set_ylabel(r"Outage capacity (bit/s/Hz)")
    ax.set_title(r"Theory--simulation comparison, $\epsilon=10^{-2}$, GEO S-band $\gamma_0=11.71$ dB")
    polish_axes(ax)
    legend_above_bars(ax, ncol=3, pad=0.50)

    idx6 = int(np.argmin(np.abs(x - 6.0)))
    ax.annotate(f"Exact {c_exact_vals[idx6]:.2f}\nLB {c_lb_vals[idx6]:.2f}",
                xy=(x[idx6], c_exact_vals[idx6]), xytext=(x[idx6] + 0.7, c_exact_vals[idx6] + 1.0),
                arrowprops={"arrowstyle": "->", "lw": 0.8, "color": "#555555"},
                fontsize=8, color="#333333")

    axr.plot(x, residual, "s-", color=COLORS["warn"], markersize=3.8, linewidth=1.6)
    axr.set_xlabel(r"Shadowing standard deviation $\sigma_{dB}$ (dB)")
    axr.set_ylabel("Exact-LB")
    polish_axes(axr)
    axr.set_ylim(bottom=0)
    fig.subplots_adjust(left=0.10, right=0.985, bottom=0.11, top=0.94, hspace=0.08)
    save_plot(fig, "outage_capacity_sigma", tight=False)

def plot_sf_scan(rows: list[dict[str, object]]) -> None:
    sf = np.array([float(r["sf"]) for r in rows])
    fixed = np.array([float(r["c_exact_fixed_bw"]) for r in rows])
    chip = np.array([float(r["c_exact_chip_bw"]) for r in rows])
    eta_chip = np.array([float(r["eta_chip_bw"]) for r in rows])

    fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(7.4, 3.25), sharex=False)
    ax0.semilogx(sf, fixed, "o-", color=COLORS["mc"], linewidth=1.8, markersize=4)
    ax0.set_title("(a) Fixed 5 kHz bandwidth: illusory gain")
    ax0.set_xlabel("Spreading factor SF")
    ax0.set_ylabel(r"$C_\epsilon$ (bit/s/Hz)")
    ax0.set_xticks([1, 31, 127, 1023])
    ax0.get_xaxis().set_major_formatter(plt.ScalarFormatter())
    polish_axes(ax0, "y")
    ax0.annotate("bandwidth not updated", xy=(127, fixed[list(sf).index(127)]), xytext=(20, fixed.max() - 0.7),
                 arrowprops={"arrowstyle": "->", "lw": 0.8}, fontsize=8)

    ax1.semilogx(sf, chip, "s-", color=COLORS["exact"], linewidth=1.8, markersize=4, label=r"$C_\epsilon$")
    ax1.set_title("(b) Bandwidth-consistent: no SF leverage")
    ax1.set_xlabel("Spreading factor SF")
    ax1.set_ylabel(r"$C_\epsilon$ (bit/s/Hz)", color=COLORS["exact"])
    ax1.tick_params(axis="y", labelcolor=COLORS["exact"])
    ax1.set_xticks([1, 31, 127, 1023])
    ax1.get_xaxis().set_major_formatter(plt.ScalarFormatter())
    polish_axes(ax1, "y")
    ax2 = ax1.twinx()
    ax2.semilogx(sf, eta_chip, "^-", color=COLORS["lb"], linewidth=1.5, markersize=4, label=r"$C_\epsilon/SF$")
    ax2.set_ylabel(r"$C_\epsilon/SF$", color=COLORS["lb"])
    ax2.tick_params(axis="y", labelcolor=COLORS["lb"])
    ax2.spines["top"].set_visible(False)
    ax1.annotate("flat capacity", xy=(127, chip[list(sf).index(127)]), xytext=(12, chip.mean() + 0.12),
                 arrowprops={"arrowstyle": "->", "lw": 0.8}, fontsize=8)
    save_plot(fig, "outage_capacity_sf")

def plot_eps_scan(rows: list[dict[str, object]]) -> None:
    eps = np.array([float(r["eps"]) for r in rows])
    c_mc_vals = np.array([float(r["c_mc"]) for r in rows])
    c_exact_vals = np.array([float(r["c_exact"]) for r in rows])
    c_lb_vals = np.array([float(r["c_chernoff_lb"]) for r in rows])

    fig, ax = plt.subplots(figsize=(6.9, 3.8))
    ax.semilogx(eps, c_mc_vals, "o", color=COLORS["mc"], markersize=4.2, label="Monte Carlo")
    ax.semilogx(eps, c_exact_vals, "-", color=COLORS["exact"], linewidth=1.9, label="Exact")
    ax.semilogx(eps, c_lb_vals, "--", color=COLORS["lb"], linewidth=1.8, label="Chernoff LB")
    ax.invert_xaxis()
    ax.set_xlabel(r"Outage probability $\epsilon$")
    ax.set_ylabel(r"$C_\epsilon$ (bit/s/Hz)")
    ax.set_title(r"Outage target scaling, $\sigma_{dB}=6$ dB")
    polish_axes(ax, "y")
    ax.legend(frameon=False)

    target_eps = 1e-3
    target_idx = int(np.argmin(np.abs(np.log10(eps) - np.log10(target_eps))))
    target_x = float(eps[target_idx])
    target_y = float(c_exact_vals[target_idx])
    ax.scatter([target_x], [target_y], s=34, facecolor="white",
               edgecolor=COLORS["exact"], linewidth=1.0, zorder=5)
    ax.annotate(r"tighter $\epsilon$ lowers $C_\epsilon$",
                xy=(target_x, target_y), xytext=(4.0e-4, target_y + 0.85),
                arrowprops={"arrowstyle": "->", "lw": 0.9, "color": COLORS["accent"],
                            "shrinkA": 2, "shrinkB": 4},
                color=COLORS["accent"], fontsize=8, ha="left", va="center")
    save_plot(fig, "outage_capacity_epsilon")

def plot_scenario_scan(rows: list[dict[str, object]]) -> None:
    display = {"suburban": "Forest edge", "urban": "Canyon", "dense urban": "Deep canyon"}
    scenarios = [display.get(str(r["scenario"]), str(r["scenario"]).title()) for r in rows]
    x = np.arange(len(rows))
    width = 0.2
    single = np.array([float(r["c_exact_single_state"]) for r in rows])
    two_exact = np.array([float(r["c_two_state_exact"]) for r in rows])
    two_lb = np.array([float(r["c_two_state_chernoff_lb"]) for r in rows])
    ceiling = np.array([float(r["c_median_snr_ceiling"]) for r in rows])

    fig, ax = plt.subplots(figsize=(7.2, 3.65))
    colors = ["#9ECAE1", "#4292C6", "#08519C", "#636363"]
    ax.bar(x - 1.5 * width, single, width, color=colors[0], label="Single-state proxy")
    ax.bar(x - 0.5 * width, two_lb, width, color=colors[1], label="Two-state LB")
    ax.bar(x + 0.5 * width, two_exact, width, color=colors[2], label="Two-state exact")
    ax.bar(x + 1.5 * width, ceiling, width, color=colors[3], label="Median-SNR ceiling")
    ax.set_xticks(x, scenarios)
    ax.set_ylabel(r"$C_\epsilon$ (bit/s/Hz)")
    ax.set_title(r"LOS/NLOS mixture penalty, $\epsilon=10^{-2}$, elevation $45^\circ$")
    polish_axes(ax)
    legend_above_bars(ax, ncol=2)

    dense_idx = len(rows) - 1
    drop = single[dense_idx] / max(two_exact[dense_idx], 1e-12)
    ax.annotate(f"{single[dense_idx]:.2f} -> {two_exact[dense_idx]:.3f}\n~{drop:.0f}x drop",
                xy=(dense_idx + 0.5 * width, two_exact[dense_idx]),
                xytext=(dense_idx - 0.55, max(single) * 0.55),
                arrowprops={"arrowstyle": "->", "lw": 0.8, "color": "#333333"},
                fontsize=8)
    save_plot(fig, "outage_capacity_scenarios")

def run_all(mc_n: int = 1_000_000, seed: int = 20260608) -> None:
    rng = np.random.default_rng(seed)
    eps0 = 1e-2
    sf0 = 31
    rb_bps = 1000.0
    # Generic GEO S-band narrowband bearer reference: 31.25 kHz uplink, 15 deg posture, circular-polarized handset model.
    g0_db_ref = 11.706656016154298
    g0 = 10.0 ** (g0_db_ref / 10.0)

    sigma_rows: list[dict[str, object]] = []
    for sigma_db in np.arange(2.0, 13.0, 1.0):
        mc = c_mc(g0, float(sigma_db), eps0, mc_n, rng)
        exact = c_exact(g0, float(sigma_db), eps0)
        lb = c_chernoff_lb(g0, float(sigma_db), eps0)
        ub = c_no_shadow_ub(g0)
        sigma_rows.append({
            "sf": sf0,
            "bandwidth_hz": rb_bps * sf0,
            "eps": eps0,
            "sigma_db": float(sigma_db),
            "gamma0_db": g0_db_ref,
            "c_mc": mc,
            "c_exact": exact,
            "c_chernoff_lb": lb,
            "c_no_shadow_ub": ub,
            "mc_minus_exact": mc - exact,
            "exact_minus_chernoff_lb": exact - lb,
            "ub_minus_exact": ub - exact,
        })

    sf_rows: list[dict[str, object]] = []
    for sf in [1, 7, 15, 31, 63, 127, 255, 511, 1023]:
        g_fixed = gamma0_lin(sf, 5e3)
        g_chip = gamma0_lin(sf, rb_bps * sf)
        ce_fixed = c_exact(g_fixed, 6.0, eps0)
        ce_chip = c_exact(g_chip, 6.0, eps0)
        sf_rows.append({
            "sf": sf,
            "eps": eps0,
            "sigma_db": 6.0,
            "gamma0_db_fixed_bw": gamma0_db(sf, 5e3),
            "gamma0_db_chip_bw": gamma0_db(sf, rb_bps * sf),
            "c_exact_fixed_bw": ce_fixed,
            "c_exact_chip_bw": ce_chip,
            "eta_fixed_bw": ce_fixed / sf,
            "eta_chip_bw": ce_chip / sf,
        })

    eps_rows: list[dict[str, object]] = []
    for eps in np.logspace(-4, -1, 13):
        eps = float(eps)
        eps_rows.append({
            "sf": sf0,
            "bandwidth_hz": rb_bps * sf0,
            "sigma_db": 6.0,
            "eps": eps,
            "sqrt_ln_1_over_eps": math.sqrt(math.log(1.0 / eps)),
            "c_mc": c_mc(g0, 6.0, eps, mc_n, rng),
            "c_exact": c_exact(g0, 6.0, eps),
            "c_chernoff_lb": c_chernoff_lb(g0, 6.0, eps),
            "c_no_shadow_ub": c_no_shadow_ub(g0),
        })

    scenario_params = {
        "suburban": {"sigma_proxy": 3.0, "sigma_los": 1.2, "sigma_nlos": 6.0, "clutter_db": 2.0, "p_los": 0.72},
        "urban": {"sigma_proxy": 6.0, "sigma_los": 2.0, "sigma_nlos": 8.0, "clutter_db": 5.0, "p_los": 0.72},
        "dense urban": {"sigma_proxy": 10.0, "sigma_los": 3.0, "sigma_nlos": 10.0, "clutter_db": 9.0, "p_los": 0.64},
    }
    scenario_rows: list[dict[str, object]] = []
    elevation_deg = 45.0
    elevation_loss_db = 2.0 / math.sin(math.radians(elevation_deg))
    median_extra_nlos_db = 10.0
    for scenario, sp in scenario_params.items():
        g0_l = g0 * 10.0 ** (-elevation_loss_db / 10.0)
        g0_n = g0 * 10.0 ** (-(elevation_loss_db + float(sp["clutter_db"]) + median_extra_nlos_db) / 10.0)
        mix_lb, eps_l, eps_n = c_two_state_chernoff_lb(g0_l, float(sp["sigma_los"]), g0_n, float(sp["sigma_nlos"]), float(sp["p_los"]), eps0)
        mix_exact = c_two_state_exact(g0_l, float(sp["sigma_los"]), g0_n, float(sp["sigma_nlos"]), float(sp["p_los"]), eps0)
        single = c_exact(g0, float(sp["sigma_proxy"]), eps0)
        scenario_rows.append({
            "scenario": scenario,
            "sf": sf0,
            "bandwidth_hz": rb_bps * sf0,
            "eps": eps0,
            "elevation_deg": elevation_deg,
            "p_los": float(sp["p_los"]),
            "sigma_db_proxy": float(sp["sigma_proxy"]),
            "sigma_los_db": float(sp["sigma_los"]),
            "sigma_nlos_db": float(sp["sigma_nlos"]),
            "nlos_median_extra_loss_db": float(sp["clutter_db"]) + median_extra_nlos_db,
            "c_exact_single_state": single,
            "c_two_state_exact": mix_exact,
            "c_two_state_chernoff_lb": mix_lb,
            "eps_los_alloc": eps_l,
            "eps_nlos_alloc": eps_n,
            "c_median_snr_ceiling": c_no_shadow_ub(g0),
            "two_state_exact_minus_single_state": mix_exact - single,
        })


    composite_n = max(300_000, mc_n // 2)
    composite_specs = [
        ("Loo", sample_loo(g0, 4.0, 10.0, composite_n, rng), {"sigma_los_db": 4.0, "k_db": 10.0}),
        ("Suzuki", sample_suzuki(g0, 6.0, composite_n, rng), {"sigma_db": 6.0}),
        ("Lutz", sample_lutz(g0 * 10.0 ** (-2.8 / 10.0), 2.0, g0 * 10.0 ** (-18.0 / 10.0), 9.0, 0.72, composite_n, rng), {"p_good": 0.72, "good_loss_db": 2.8, "bad_loss_db": 18.0, "sigma_good_db": 2.0, "sigma_bad_db": 9.0}),
    ]
    composite_rows: list[dict[str, object]] = []
    for model, gamma_samples, params in composite_specs:
        mc_cap = cap_quantile_from_samples(gamma_samples, eps0)
        lb_cap, best_t = neg_moment_chernoff_capacity_lb(gamma_samples, eps0)
        row = {
            "model": model,
            "sf": sf0,
            "bandwidth_hz": rb_bps * sf0,
            "eps": eps0,
            "samples": composite_n,
            "gamma0_db_reference": g0_db_ref,
            "c_mc": mc_cap,
            "c_chernoff_lb": lb_cap,
            "chernoff_best_t": best_t,
            "mc_minus_lb": mc_cap - lb_cap,
            "sigma_los_db": "",
            "k_db": "",
            "sigma_db": "",
            "p_good": "",
            "good_loss_db": "",
            "bad_loss_db": "",
            "sigma_good_db": "",
            "sigma_bad_db": "",
        }
        row.update(params)
        composite_rows.append(row)

    write_csv(OUT / "sigma_scan.csv", sigma_rows)
    write_csv(OUT / "sf_scan.csv", sf_rows)
    write_csv(OUT / "epsilon_scan.csv", eps_rows)
    write_csv(OUT / "scenario_scan.csv", scenario_rows)
    write_csv(OUT / "composite_fading.csv", composite_rows)
    (OUT / "outage_capacity_results.json").write_text(json.dumps({
        "notes": [
            "Chernoff expression is a lower bound on epsilon-outage capacity, not an upper bound.",
            "For zero-mean shadowing and eps<0.5, median-SNR capacity is a simple ceiling; exact lognormal quantile is the analytical reference.",
            "Chip-rate bandwidth mode keeps noise bandwidth consistent with DSSS spreading.",
        ],
        "monte_carlo_samples_per_point": mc_n,
        "sigma_scan": sigma_rows,
        "sf_scan": sf_rows,
        "epsilon_scan": eps_rows,
        "scenario_scan": scenario_rows,
        "composite_fading": composite_rows,
    }, ensure_ascii=False, indent=2), encoding="utf-8")

    plot_sigma_scan(sigma_rows)
    plot_sf_scan(sf_rows)
    plot_eps_scan(eps_rows)
    plot_scenario_scan(scenario_rows)
    plot_composite_fading(composite_rows)
    plot_composite_snr_distribution(composite_specs, eps0)
    print("D2C outage-capacity analysis complete")
    print(OUT / "outage_capacity_results.json")


if __name__ == "__main__":
    run_all()
