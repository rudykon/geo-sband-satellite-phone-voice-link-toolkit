# voice-link PHY/LMS MATLAB-Simulink Alignment Summary

## PHY Threshold Calibration

| Voice rate | Target FER | PHY Eb/N0 threshold | Legacy threshold | Delta |
|---:|---:|---:|---:|---:|
| 1200.0 bps | 0.01 | 4.737 dB | -1.000 dB | 5.737 dB |
| 2400.0 bps | 0.01 | 5.032 dB | 0.700 dB | 4.332 dB |
| 4000.0 bps | 0.01 | 5.211 dB | 2.200 dB | 3.011 dB |

## LMS Time-Series Availability

| Scenario | Availability | FER | P10 Eb/N0 | Max outage | P95 burst |
|---|---:|---:|---:|---:|---:|
| Open plain | 0.99653 | 0.00347 | 17.537 dB | 40.0 ms | 40.0 ms |
| Forest edge | 0.96787 | 0.03213 | 12.181 dB | 80.0 ms | 80.0 ms |
| Canyon valley | 0.79413 | 0.20587 | -1.962 dB | 440.0 ms | 120.0 ms |
| Moving trail | 0.66180 | 0.33820 | -5.554 dB | 440.0 ms | 160.0 ms |
| Tent/shelter | 0.35693 | 0.64307 | -18.638 dB | 2880.0 ms | 400.0 ms |

## Python/MATLAB/Simulink Alignment

| Scenario | Python | MATLAB | Simulink | LMS MATLAB | LMS Simulink | Sim-MATLAB | MATLAB-Python |
|---|---:|---:|---:|---:|---:|---:|---:|
| Open plain | 1.00000 | 1.00000 | 1.00000 | 0.99653 | 0.99653 | 0 | 0 |
| Forest edge | 0.99949 | 0.99943 | 0.99943 | 0.96787 | 0.96787 | 0 | -6e-05 |
| Canyon valley | 0.91431 | 0.91447 | 0.91447 | 0.79413 | 0.79413 | 0 | 0.00016 |
| Moving trail | 0.79878 | 0.79961 | 0.79961 | 0.66180 | 0.66180 | 0 | 0.00083 |
| Tent/shelter | 0.46734 | 0.47029 | 0.47029 | 0.35693 | 0.35693 | 0 | 0.00295 |

## Files

- `ber_fer_vs_ebn0.csv`
- `voice_threshold_from_phy.csv`
- `lms_channel_availability.csv`
- `lms_simulink_channel_availability.csv`
- `lms_frame_timeseries_sample.csv`
- `three_way_alignment.csv`
- `simulink_voice_availability.csv`
