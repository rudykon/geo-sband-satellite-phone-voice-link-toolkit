%RUN_STEP1_LMS_SIMULINK_ONLY Build and run the Step 1 LMS Simulink model.

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

cfg = step1_params();
if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end

fprintf('Step 1 LMS Simulink run\n');
fprintf('Project root: %s\n', cfg.rootDir);
fprintf('Output dir:   %s\n\n', cfg.outputDir);

if ~(usejava('jvm') && license('test', 'Simulink') && exist('simulink', 'file') == 2)
    error('Simulink is not available in this MATLAB runtime.');
end

thresholdRows = readtable(fullfile(cfg.outputDir, 'voice_threshold_from_phy.csv'));
modelName = step1_build_lms_simulink_model(cfg);
step1_run_lms_simulink_cosim(cfg, modelName, thresholdRows);

statusPath = fullfile(cfg.outputDir, 'lms_simulink_status.txt');
fid = fopen(statusPath, 'w');
fprintf(fid, 'completed\n%s\n', char(datetime("now", "Format", "yyyy-MM-dd'T'HH:mm:ss")));
fclose(fid);

fprintf('\nLMS Simulink run completed.\n');
fprintf('- %s\n', fullfile(cfg.outputDir, 'lms_simulink_channel_availability.csv'));
fprintf('- %s\n', fullfile(thisDir, modelName + ".slx"));
