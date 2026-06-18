function run_step1_cosim_strict(manifestPath)
%RUN_STEP1_COSIM_STRICT Authoritative Step 1 MATLAB/Simulink co-simulation.
%
% This entry point is called by Python. It reads the Python-written manifest,
% calibrates PHY thresholds with Communications Toolbox, runs the generated
% Simulink model in strict MATLAB Function block mode, and writes staging CSVs
% for Python promotion.

if nargin < 1 || strlength(string(manifestPath)) == 0
    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(thisDir);
    manifestPath = fullfile(rootDir, 'outputs', 'matlab_step1', 'step1_cosim_input_manifest.json');
end

clearvars -except manifestPath;
clc;

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

manifestText = fileread(manifestPath);
manifest = jsondecode(manifestText);

cfg = step1_params();
cfg = step1_apply_manifest(cfg, manifest);
if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end
if ~exist(cfg.figureDir, 'dir'), mkdir(cfg.figureDir); end

fprintf('Step 1 strict Python-MATLAB/Simulink co-simulation\n');
fprintf('Manifest:     %s\n', manifestPath);
fprintf('Project root: %s\n', cfg.rootDir);
fprintf('Output dir:   %s\n\n', cfg.outputDir);

toolboxStatus = step1_check_toolboxes(cfg);
if strcmp(getenv('STEP1_FORCE_SIMULINK_UNAVAILABLE'), '1')
    error('STEP1_FORCE_SIMULINK_UNAVAILABLE=1 forced strict Simulink failure.');
end
if ~usejava('jvm')
    error('Step 1 strict co-simulation requires MATLAB with JVM so Simulink can run.');
end
if ~toolboxStatus.has_simulink
    error('Step 1 strict co-simulation requires Simulink.');
end
if ~toolboxStatus.has_comm_toolbox
    error('Step 1 strict co-simulation requires Communications Toolbox.');
end

thresholdRows = step1_run_phy_threshold_calibration(cfg);
voiceRows = step1_voice_availability_matlab(cfg, thresholdRows);
outageRows = step1_outage_capacity_matlab(cfg); %#ok<NASGU>

[modelName, modelMode] = step1_build_simulink_model(cfg, true);
if ~strcmp(modelMode, 'matlab_function_block')
    error('Strict Simulink mode requires MATLAB Function block execution, got %s.', modelMode);
end
simRows = step1_run_simulink_cosim(cfg, modelName, thresholdRows, true);
if height(simRows) ~= height(cfg.scenarios) * numel(cfg.voice.rateBps)
    error('Strict Simulink output row count mismatch: %d.', height(simRows));
end

status = struct();
status.task = 'Step 1 Python-MATLAB/Simulink reference co-simulation';
status.status = 'completed';
status.authoritative_source = 'matlab_simulink_phy_threshold';
status.strict_simulink = true;
status.simulink_mode = modelMode;
status.matlab_version = version();
status.matlab_root = matlabroot;
status.manifest_path = char(string(manifestPath));
status.output_dir = cfg.outputDir;
status.simulink_model = fullfile(thisDir, modelName + ".slx");
status.voice_rows = height(simRows);
status.threshold_rows = height(thresholdRows);
status.scenarios = height(cfg.scenarios);
status.voice_rates = numel(cfg.voice.rateBps);
status.max_simulink_minus_matlab_availability = local_max_delta(simRows, voiceRows);
status.toolboxes = struct( ...
    'simulink', toolboxStatus.has_simulink, ...
    'communications_toolbox', toolboxStatus.has_comm_toolbox);

statusPath = fullfile(cfg.outputDir, 'step1_cosim_status.json');
fid = fopen(statusPath, 'w');
fprintf(fid, '%s\n', jsonencode(status));
fclose(fid);

if bdIsLoaded(modelName)
    save_system(modelName);
    close_system(modelName, 0);
end

fprintf('\nDone.\n');
fprintf('- %s\n', fullfile(cfg.outputDir, 'voice_threshold_from_phy.csv'));
fprintf('- %s\n', fullfile(cfg.outputDir, 'voice_availability_matlab.csv'));
fprintf('- %s\n', fullfile(cfg.outputDir, 'simulink_voice_availability.csv'));
fprintf('- %s\n', statusPath);
end

function maxDelta = local_max_delta(simRows, voiceRows)
maxDelta = 0.0;
for i = 1:height(simRows)
    idx = strcmp(string(voiceRows.scenario_key), string(simRows.scenario_key(i))) ...
        & abs(voiceRows.voice_rate_bps - simRows.voice_rate_bps(i)) < 1e-9;
    if any(idx)
        delta = abs(simRows.availability(i) - voiceRows.availability(find(idx, 1)));
        maxDelta = max(maxDelta, delta);
    end
end
end
