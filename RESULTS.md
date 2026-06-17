# Result Summary

This page summarizes the main reference outputs committed under
`expected_outputs/`. Running `python run_all.py` regenerates the same types
of files under `outputs/`.

## Baseline Voice Availability

The main screening target is a 2.4 kbps voice bearer. The proposed LOS/NLOS
mixture model is compared with simpler average-SNR and single-state baselines.

| Scenario | Proposed mixture availability | Average-SNR screen | Single-state lognormal | P10 Eb/N0 | Median Eb/N0 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Open plain | 100.00% | 100.00% | 100.00% | 19.46 dB | 22.93 dB |
| Forest edge | 99.95% | 100.00% | 100.00% | 14.57 dB | 22.28 dB |
| Canyon valley | 91.43% | 100.00% | 99.90% | 1.68 dB | 18.90 dB |
| Moving trail | 79.88% | 100.00% | 99.98% | -2.93 dB | 12.58 dB |
| Tent/shelter | 46.73% | 100.00% | 98.91% | -14.47 dB | -0.39 dB |

Reference file:

```text
expected_outputs/geo_satphone/screening_baseline_comparison.csv
```

Interpretation: average-SNR screening is too optimistic in intermittent and
shelter-like states. It misses the low-tail outage risk that matters for
remote-area voice availability.

## Sensitivity Ranking

The strongest tested availability perturbation is NLOS excess loss.

| Parameter | Perturbation | Scenario at maximum | Max availability change |
| --- | --- | --- | ---: |
| NLOS excess loss | +/-5 dB | Tent/shelter | 15.46 pp |
| PA compression loss | +3 dB | Moving trail | 9.43 pp |
| LOS probability | +/-0.10 | Tent/shelter | 6.99 pp |
| Voice threshold | +/-2 dB | Moving trail | 6.25 pp |
| Rain/atmospheric loss | +2 dB | Moving trail | 6.25 pp |
| Shadowing sigma | +/-2 dB | Tent/shelter | 3.48 pp |
| Posture angle | +/-10 deg | Tent/shelter | 2.72 pp |
| Residual Doppler | 100 Hz tracked | Moving trail | 0.43 pp |

Reference file:

```text
expected_outputs/geo_satphone/screening_sensitivity_ranking.csv
```

Interpretation: blockage and excess NLOS loss dominate the low-tail voice
closure risk more than residual Doppler in the tracked narrowband case.

## Dwell-Time Sensitivity

At fixed stationary LOS probability, longer NLOS dwell time increases burst
lengths. The P95 NLOS burst length reaches:

| Scenario | Base P95 NLOS burst | 2x NLOS dwell P95 burst |
| --- | ---: | ---: |
| Open plain | 8 s | 18 s |
| Forest edge | 21 s | 40.2 s |
| Canyon valley | 30 s | 56.25 s |
| Moving trail | 15 s | 32 s |
| Tent/shelter | 41 s | 92.2 s |

Reference file:

```text
expected_outputs/geo_satphone/dwell_time_sensitivity.csv
```

Interpretation: even when average LOS probability is unchanged, burst duration
matters for bearer continuity and user-perceived voice availability.

## Public-Anchor Consistency

The public-anchor table maps broad public D2C measurement scales into the
model's narrowband voice setting.

Reference file:

```text
expected_outputs/geo_satphone/public_d2c_inverse_alignment.csv
```

The checks are not fitted to private raw measurements; they are sanity anchors
for whether the narrowband voice model sits in a plausible public measurement
space.

## MATLAB/Simulink Cross-Check

The optional MATLAB/Simulink validation compares Python, MATLAB, and Simulink
voice-availability outputs at 2.4 kbps.

| Scenario | Python | MATLAB | Simulink | MATLAB minus Python |
| --- | ---: | ---: | ---: | ---: |
| Open plain | 1.000000 | 1.000000 | 1.000000 | 0.000000 |
| Forest edge | 0.999490 | 0.999430 | 0.999430 | -0.000060 |
| Canyon valley | 0.914310 | 0.914470 | 0.914470 | 0.000160 |
| Moving trail | 0.798785 | 0.799615 | 0.799615 | 0.000830 |
| Tent/shelter | 0.467340 | 0.470290 | 0.470290 | 0.002950 |

Reference file:

```text
expected_outputs/matlab_step1/three_way_alignment.csv
```

Interpretation: MATLAB and Simulink match the Python system-level availability
model closely for the selected validation scenario.

## Reference Figures

The repository includes four PDF figures under `expected_outputs/plots/`:

- `geo_satphone_screening_baseline_comparison.pdf`
- `geo_satphone_sensitivity_ranking.pdf`
- `geo_satphone_c0p01_sensitivity_ranking.pdf`
- `geo_satphone_dwell_time_sensitivity.pdf`
