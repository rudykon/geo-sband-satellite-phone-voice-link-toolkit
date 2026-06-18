# Step 1 MATLAB/Simulink Co-Simulation

This folder contains the Step 1 MATLAB/Simulink reference path for:

`Outage-Capacity Modeling and Voice-Bearer Pre-Validation for Direct-to-Cell GEO S-Band Links in Remote Areas`

Python remains the top-level orchestrator. The normal entry point is:

```powershell
python run_all.py
```

That command writes `outputs/matlab_step1/step1_cosim_input_manifest.json`,
calls MATLAB with `matlab.exe -batch`, runs `run_step1_cosim_strict.m`, validates
the staging outputs, and promotes strict Simulink results into:

```text
outputs/geo_satphone/voice_availability.csv
outputs/geo_satphone/step1_service_baseline.json
outputs/geo_satphone/voice_availability_provenance.json
```

## Strict MATLAB Entry Point

Manual MATLAB invocation is mainly for debugging:

```matlab
cd("<project-root>\matlab_step1")
run_step1_cosim_strict("<project-root>\outputs\matlab_step1\step1_cosim_input_manifest.json")
```

The strict path:

1. reads the Python-written manifest;
2. calibrates voice PHY thresholds with Communications Toolbox;
3. runs MATLAB voice-availability and outage-capacity tables;
4. builds `step1_geo_sband_link_system.slx` in MATLAB Function block mode;
5. calls `sim()` over all scenarios and 1.2/2.4/4.0 kbps rates;
6. writes `step1_cosim_status.json` with strict mode, MATLAB version, toolbox
   status, model name, seed, and Simulink-vs-MATLAB consistency metrics.

`precomputed_metrics` is allowed only in legacy/debug non-strict paths. The
reference run errors if the generated Simulink model is not a MATLAB
Function block or if `sim()` cannot execute.

## Main Staging Outputs

```text
outputs/matlab_step1/
├── step1_cosim_input_manifest.json
├── voice_threshold_from_phy.csv
├── voice_availability_matlab.csv
├── outage_capacity_matlab.csv
├── simulink_voice_availability.csv
├── step1_cosim_status.json
└── figures/
```

The generated Simulink model is:

```text
step1_geo_sband_link_system.slx
```

The LMS time-series scripts and `step1_lms_channel_timeseries_system.slx` remain
as appendix-level channel checks; they are not the source of canonical
`voice_availability.csv`.

## Required MATLAB Products

Minimum:

- MATLAB
- Simulink
- Communications Toolbox

No Statistics Toolbox is required. The scripts use `erfinv` and local empirical
quantile helpers instead of `norminv`/`quantile`.

Optional for future PHY-level extension:

- DSP System Toolbox
- Satellite Communications Toolbox
