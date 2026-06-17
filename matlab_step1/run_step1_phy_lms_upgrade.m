%RUN_STEP1_PHY_LMS_UPGRADE Run Step 1 PHY threshold and LMS validation.

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

cfg = step1_params();
if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end
if ~exist(cfg.figureDir, 'dir'), mkdir(cfg.figureDir); end

fprintf('Step 1 PHY/LMS validation upgrade\n');
fprintf('Project root: %s\n', cfg.rootDir);
fprintf('Output dir:   %s\n\n', cfg.outputDir);

step1_check_toolboxes(cfg);
thresholdRows = step1_run_phy_threshold_calibration(cfg);
step1_run_lms_channel_timeseries(cfg, thresholdRows);
step1_export_phy_lms_alignment(cfg);

fprintf('\nDone.\n');
fprintf('- %s\n', fullfile(cfg.outputDir, 'voice_threshold_from_phy.csv'));
fprintf('- %s\n', fullfile(cfg.outputDir, 'lms_channel_availability.csv'));
fprintf('- %s\n', fullfile(cfg.outputDir, 'three_way_alignment.csv'));
fprintf('- %s\n', fullfile(cfg.outputDir, 'phy_lms_alignment_summary.md'));
