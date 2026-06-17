%RUN_STEP1_MATLAB_SIMULINK Independent MATLAB/Simulink validation for Step 1.
%
% This script reproduces the Step 1 link-side voice-availability and
% outage-capacity calculations in MATLAB. When Simulink is installed, it also
% builds and runs a generated system-level Simulink orchestration model.

clear; clc;

thisDir = fileparts(mfilename("fullpath"));
addpath(thisDir);

cfg = step1_params();
if ~exist(cfg.outputDir, "dir"), mkdir(cfg.outputDir); end
if ~exist(cfg.figureDir, "dir"), mkdir(cfg.figureDir); end

fprintf("Step 1 MATLAB/Simulink validation\n");
fprintf("Project root: %s\n", cfg.rootDir);
fprintf("Output dir:   %s\n\n", cfg.outputDir);

voiceRows = step1_voice_availability_matlab(cfg);
outageRows = step1_outage_capacity_matlab(cfg);

simStatus = "skipped";
simRows = table();
if usejava("jvm") && license("test", "Simulink") && exist("simulink", "file") == 2
    fprintf("\nSimulink detected. Building and running generated model...\n");
    try
        modelName = step1_build_simulink_model(cfg);
        simRows = step1_run_simulink_cosim(cfg, modelName);
        simStatus = "completed";
    catch simErr
        simStatus = "blocked";
        fprintf(2, "\n[warn] Simulink execution failed: %s\n", simErr.message);
        for k = 1:numel(simErr.stack)
            fprintf(2, "  at %s:%d\n", simErr.stack(k).file, simErr.stack(k).line);
        end
    end
else
    fprintf("\n[skip] Simulink is not available in this MATLAB runtime, or MATLAB is running without JVM.\n");
end

compareRows = step1_compare_with_python(cfg, voiceRows, outageRows, simRows);
step1_export_summary_latex(cfg, voiceRows, outageRows, simRows, compareRows, simStatus);

fprintf("\nDone.\n");
fprintf("- %s\n", fullfile(cfg.outputDir, "voice_availability_matlab.csv"));
fprintf("- %s\n", fullfile(cfg.outputDir, "outage_capacity_matlab.csv"));
fprintf("- %s\n", fullfile(cfg.outputDir, "matlab_python_validation.csv"));
fprintf("- %s\n", fullfile(cfg.outputDir, "matlab_step1_validation_summary.md"));
