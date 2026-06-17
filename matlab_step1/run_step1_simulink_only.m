%RUN_STEP1_SIMULINK_ONLY Build and run only the Step 1 Simulink artifact.
%
% Use this when R2026a is unstable during long JVM-backed MATLAB sessions. The
% MATLAB numerical validation can be run separately in no-JVM mode.

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

cfg = step1_params();
if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end
if ~exist(cfg.figureDir, 'dir'), mkdir(cfg.figureDir); end

fprintf('Step 1 Simulink-only run\n');
fprintf('Project root: %s\n', cfg.rootDir);
fprintf('Output dir:   %s\n\n', cfg.outputDir);

if ~(usejava('jvm') && license('test', 'Simulink') && exist('simulink', 'file') == 2)
    error('Simulink is not available in this MATLAB runtime.');
end

modelName = step1_build_simulink_model(cfg);
simRows = step1_run_simulink_cosim(cfg, modelName); %#ok<NASGU>

statusPath = fullfile(cfg.outputDir, 'simulink_only_status.txt');
fid = fopen(statusPath, 'w');
fprintf(fid, 'completed\n%s\n', datestr(now, 31));
fclose(fid);

fprintf('\nSimulink-only run completed.\n');
fprintf('- %s\n', fullfile(cfg.outputDir, 'simulink_voice_availability.csv'));
fprintf('- %s\n', fullfile(thisDir, modelName + ".slx"));
