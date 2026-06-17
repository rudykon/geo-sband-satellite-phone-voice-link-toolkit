function rows = step1_run_lms_simulink_cosim(cfg, modelName, thresholdRows)
%STEP1_RUN_LMS_SIMULINK_COSIM Run LMS Simulink model over scenarios.

if nargin < 3 || isempty(thresholdRows)
    thresholdRows = readtable(fullfile(cfg.outputDir, 'voice_threshold_from_phy.csv'));
end

thresholdDb = thresholdRows.phy_threshold_ebn0_db( ...
    find(abs(thresholdRows.voice_rate_bps - cfg.voice.mainRateBps) < 1e-9, 1));
numFrames = 15000;
modelMode = local_detect_lms_model_mode(modelName);

rows = table();
for i = 1:height(cfg.scenarios)
    set_param(modelName + "/scenario_index", "Value", num2str(i));
    set_param(modelName + "/n_frames", "Value", num2str(numFrames));
    set_param(modelName + "/seed", "Value", num2str(cfg.seed));
    set_param(modelName + "/threshold_ebn0_db", "Value", num2str(thresholdDb));

    if strcmp(modelMode, 'precomputed_metrics')
        lmsPrecomputedMetrics = step1_simulink_lms_scenario([i; numFrames; cfg.seed; thresholdDb]);
        assignin("base", "lms_precomputed_metrics", lmsPrecomputedMetrics);
    end

    simOut = sim(modelName, "StopTime", "1");
    raw = local_get_lms_simulink_output(simOut);
    values = local_last_lms_row(raw);

    sc = cfg.scenarios(i, :);
    rows = [rows; table( ...
        sc.scenario_key, sc.step1_key, sc.label, cfg.voice.mainRateBps, ...
        values(9), numFrames, values(2), values(3), values(4), values(5), ...
        values(6), values(7), values(8), ...
        'VariableNames', {'scenario_key', 'step1_key', 'label', 'voice_rate_bps', ...
        'threshold_ebn0_db', 'frames', 'availability', 'frame_error_rate', ...
        'p10_ebn0_db', 'median_ebn0_db', 'max_outage_ms', ...
        'p95_burst_ms', 'empirical_p_los'})]; %#ok<AGROW>
end

outCsv = fullfile(cfg.outputDir, 'lms_simulink_channel_availability.csv');
writetable(rows, outCsv);
fprintf('Wrote %s\n', outCsv);
end

function modelMode = local_detect_lms_model_mode(modelName)
fallbackBlocks = find_system(modelName, "SearchDepth", 1, "Name", "precomputed_lms_metrics");
if isempty(fallbackBlocks)
    modelMode = 'matlab_function_block';
else
    modelMode = 'precomputed_metrics';
end
end

function raw = local_get_lms_simulink_output(simOut)
if evalin("base", "exist('lms_sim_metrics', 'var')")
    raw = evalin("base", "lms_sim_metrics");
    return;
end
if isa(simOut, "Simulink.SimulationOutput")
    simVars = simOut.who;
    if any(strcmp(simVars, "lms_sim_metrics"))
        raw = simOut.get("lms_sim_metrics");
        return;
    end
end
error("Simulink output variable lms_sim_metrics was not found.");
end

function values = local_last_lms_row(raw)
if istable(raw)
    raw = table2array(raw);
end
if isstruct(raw) && isfield(raw, "signals")
    raw = raw.signals.values;
end
if ~ismatrix(raw)
    raw = squeeze(raw);
end
last = raw(end, :);
if size(raw, 2) == 10
    values = raw(end, 2:end);
elseif size(raw, 2) == 9
    values = raw(end, :);
elseif size(raw, 1) == 10
    values = raw(2:end, end).';
elseif size(raw, 1) == 9
    values = raw(:, end).';
elseif numel(last) == 10
    values = last(2:end);
elseif numel(last) == 9
    values = last;
else
    error("Unexpected LMS Simulink output width: %d", numel(last));
end
values = double(values(:)).';
end
