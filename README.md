# GEO S-Band Satellite Phone Voice Link Toolkit

[中文说明](README.zh-CN.md)

This repository is a standalone open-source research toolkit for Step 1 of a
two-step satellite-phone direct-to-cell (D2C) service study. Step 1 focuses on
GEO S-band voice-link closure in remote areas and provides the link-side
baseline used by later service-layer work.

The toolkit provides a public-parameter, vendor-neutral screening workflow for
estimating whether a handheld satellite-phone style terminal can close a
low-rate voice bearer under posture loss, shadowing, LOS/NLOS mixing, terrain
blockage, and low-tail outage-capacity constraints.

The repository is designed to be self-contained for GitHub release: the Python
workflow regenerates the numerical tables and figures, and the optional
MATLAB/Simulink workflow cross-checks selected Step 1 validation outputs.

## What This Toolkit Does

- Builds a generic GEO S-band satellite-phone voice-link approximation.
- Computes narrowband carrier budgets, voice availability, and outage-capacity
  validation outputs.
- Compares average-SNR and single-state screening against a LOS/NLOS mixture
  model to expose low-tail risk.
- Ranks sensitivity to NLOS loss, LOS probability, PA compression, rain loss,
  voice threshold, posture, shadowing, and residual Doppler.
- Provides optional MATLAB/Simulink scripts for independent PHY/LMS validation.

This is not a proprietary handset implementation, field-test dataset, or vendor
calibration package.

## Key Results

For the 2.4 kbps voice bearer, the mixture model gives the following baseline
availability:

| Scenario | Availability | P10 Eb/N0 |
| --- | ---: | ---: |
| Open plain | 100.0% | 19.46 dB |
| Forest edge | 99.95% | 14.57 dB |
| Canyon valley | 91.43% | 1.68 dB |
| Moving trail | 79.88% | -2.93 dB |
| Tent/shelter | 46.73% | -14.47 dB |

The average-SNR screen predicts 100% availability in all five scenarios, which
overstates the low-tail result by up to 53.3 percentage points in the
tent/shelter case. The largest tested sensitivity is NLOS excess loss, with a
maximum availability swing of 15.46 percentage points.

See [RESULTS.md](RESULTS.md) for the fuller result summary and pointers to the
CSV/PDF artifacts under `expected_outputs/`.

## Repository Layout

```text
.
├── README.md
├── README.zh-CN.md
├── RESULTS.md
├── PUBLIC_RELEASE.md
├── LICENSE
├── requirements.txt
├── run_all.py
├── src/
│   ├── tiantong_sband_link.py
│   ├── outage_capacity_bound.py
│   └── step1_completion.py
├── expected_outputs/
│   ├── geo_satphone/
│   ├── matlab_step1/
│   └── plots/
└── matlab_step1/
```

## Quick Start

Create a Python environment and install the required packages:

```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
python -m pip install -r requirements.txt
```

Run the core Python workflow:

```bash
python run_all.py
```

The workflow writes newly generated artifacts to `outputs/`:

```text
outputs/
├── geo_satphone/
├── outage_capacity/
├── plots/
├── requested_extensions/
└── step1_link/
```

`outputs/` is intentionally ignored by Git. Reference CSV/PDF artifacts used by
the paper are committed under `expected_outputs/`.

## Expected Outputs

Important generated files include:

- `outputs/geo_satphone/voice_availability.csv`
- `outputs/geo_satphone/screening_baseline_comparison.csv`
- `outputs/geo_satphone/screening_sensitivity_ranking.csv`
- `outputs/geo_satphone/dwell_time_sensitivity.csv`
- `outputs/outage_capacity/outage_capacity_results.json`
- `outputs/requested_extensions/step1_completion_results.json`
- `outputs/plots/geo_satphone_c0p01_sensitivity_ranking.pdf`
- `outputs/plots/geo_satphone_dwell_time_sensitivity.pdf`

## Optional MATLAB/Simulink Validation

The MATLAB workflow is optional. It requires MATLAB and Simulink; the reference
PHY threshold calibration also requires Communications Toolbox.

From MATLAB:

```matlab
cd("matlab_step1")
run_step1_phy_lms_upgrade
```

Expected MATLAB outputs are written to `outputs/matlab_step1/`. See
[MATLAB_SIMULINK.md](MATLAB_SIMULINK.md) for details.

## Notes and Scope

- Random seeds are fixed in the Python scripts.
- The repository uses public-style proxy parameters and sensitivity sweeps, not
  proprietary measurements.
- Some plots may emit harmless Matplotlib layout/font warnings depending on the
  local environment.
- Numerical values can change slightly across NumPy/SciPy/Matplotlib versions,
  but the qualitative rankings should remain stable.

## License

This project is released under the MIT License. See [LICENSE](LICENSE).
