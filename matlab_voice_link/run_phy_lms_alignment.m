%RUN_VOICE_LINK_PHY_LMS_UPGRADE Run voice-link PHY threshold and LMS validation.

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

cfg = voice_link_params();
if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end
if ~exist(cfg.figureDir, 'dir'), mkdir(cfg.figureDir); end

fprintf('voice-link PHY/LMS validation upgrade\n');
fprintf('Project root: %s\n', cfg.rootDir);
fprintf('Output dir:   %s\n\n', cfg.outputDir);

voice_link_check_toolboxes(cfg);
thresholdRows = voice_link_calibrate_phy_thresholds(cfg);
voice_link_run_lms_channel_timeseries(cfg, thresholdRows);
voice_link_export_phy_lms_alignment(cfg);

fprintf('\nDone.\n');
fprintf('- %s\n', fullfile(cfg.outputDir, 'voice_threshold_from_phy.csv'));
fprintf('- %s\n', fullfile(cfg.outputDir, 'lms_channel_availability.csv'));
fprintf('- %s\n', fullfile(cfg.outputDir, 'three_way_alignment.csv'));
fprintf('- %s\n', fullfile(cfg.outputDir, 'phy_lms_alignment_summary.md'));
