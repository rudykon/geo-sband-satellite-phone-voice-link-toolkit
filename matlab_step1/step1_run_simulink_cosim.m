function rows = step1_run_simulink_cosim(cfg, modelName, thresholdRows, strict)
%STEP1_RUN_SIMULINK_COSIM Run the generated Simulink model over scenarios.

if nargin < 3
    thresholdRows = table();
end
if nargin < 4
    strict = false;
end

modelMode = step1_detect_simulink_model_mode(modelName);
if strict && ~strcmp(modelMode, 'matlab_function_block')
    error("Strict Simulink co-simulation does not allow precomputed_metrics mode.");
end

rows = table();
for i = 1:height(cfg.scenarios)
    for j = 1:numel(cfg.voice.rateBps)
        rateBps = cfg.voice.rateBps(j);
        thresholdDb = step1_lookup_voice_threshold(cfg, thresholdRows, rateBps, j);
        thresholdSource = step1_threshold_source(thresholdRows);

        set_param(modelName + "/scenario_index", "Value", num2str(i));
        set_param(modelName + "/n_mc", "Value", num2str(cfg.nMcVoice));
        set_param(modelName + "/seed", "Value", num2str(cfg.seed));
        set_param(modelName + "/voice_rate_bps", "Value", num2str(rateBps));
        set_param(modelName + "/threshold_ebn0_db", "Value", num2str(thresholdDb));
        assignin("base", "step1_cosim_cfg", cfg);

        if strcmp(modelMode, 'precomputed_metrics')
            simPrecomputedMetrics = step1_simulink_scenario([i; cfg.nMcVoice; cfg.seed; rateBps; thresholdDb]);
            assignin("base", "sim_precomputed_metrics", simPrecomputedMetrics);
        end

        try
            simOut = sim(modelName, "StopTime", "1");
        catch simErr
            if strict || ~strcmp(modelMode, 'matlab_function_block')
                rethrow(simErr);
            end
            warning("step1:simulinkRuntimeFallback", ...
                "MATLAB Function block simulation failed (%s). Rebuilding as a precomputed-metrics Simulink orchestration model.", ...
                simErr.message);
            step1_switch_to_precomputed_model(modelName);
            modelMode = 'precomputed_metrics';
            simPrecomputedMetrics = step1_simulink_scenario([i; cfg.nMcVoice; cfg.seed; rateBps; thresholdDb]);
            assignin("base", "sim_precomputed_metrics", simPrecomputedMetrics);
            simOut = sim(modelName, "StopTime", "1");
        end
        raw = step1_get_simulink_output(simOut);
        values = step1_last_simulink_row(raw);

        sc = cfg.scenarios(i, :);
        row = table( ...
            sc.scenario_key, sc.step1_key, sc.label, ...
            rateBps, thresholdDb, string(thresholdSource), cfg.nMcVoice, ...
            values(2), values(3), values(4), values(5), values(6), values(7), values(9), string(modelMode), ...
            'VariableNames', {'scenario_key', 'step1_key', 'label', 'voice_rate_bps', ...
            'threshold_ebn0_db', 'threshold_source', 'samples', 'availability', 'p10_ebn0_db', ...
            'median_ebn0_db', 'mean_ebn0_db', 'std_ebn0_db', 'p_los', 'mean_mos_proxy', 'simulink_mode'});
        rows = [rows; row]; %#ok<AGROW>
    end
end

outCsv = fullfile(cfg.outputDir, "simulink_voice_availability.csv");
writetable(rows, outCsv);
fprintf("Wrote %s\n", outCsv);
end

function values = step1_last_simulink_row(raw)
if istable(raw)
    raw = table2array(raw);
end
if isstruct(raw) && isfield(raw, "signals")
    raw = raw.signals.values;
end
if ndims(raw) > 2
    raw = squeeze(raw);
end
if size(raw, 1) == 10
    values = raw(2:end, end).';
elseif size(raw, 1) == 9
    values = raw(:, end).';
else
last = raw(end, :);
if numel(last) == 10
    values = last(2:end); % Drop time column if To Workspace included it.
elseif numel(last) == 9
    values = last;
else
    error("Unexpected Simulink output width: %d", numel(last));
end
end
values = double(values(:)).';
end

function thresholdDb = step1_lookup_voice_threshold(cfg, thresholdRows, rateBps, rateIndex)
thresholdDb = cfg.voice.thresholdEbN0Db(rateIndex);
if isempty(thresholdRows)
    return;
end
if any(strcmp(thresholdRows.Properties.VariableNames, 'phy_threshold_ebn0_db'))
    valueName = 'phy_threshold_ebn0_db';
elseif any(strcmp(thresholdRows.Properties.VariableNames, 'threshold_ebn0_db'))
    valueName = 'threshold_ebn0_db';
else
    return;
end
idx = abs(thresholdRows.voice_rate_bps - rateBps) < 1e-9;
if any(idx)
    thresholdDb = thresholdRows.(valueName)(find(idx, 1));
end
end

function source = step1_threshold_source(thresholdRows)
if ~isempty(thresholdRows) && any(strcmp(thresholdRows.Properties.VariableNames, 'phy_threshold_ebn0_db'))
    source = "phy_calibrated";
else
    source = "legacy_proxy";
end
end

function raw = step1_get_simulink_output(simOut)
if evalin("base", "exist('sim_metrics', 'var')")
    raw = evalin("base", "sim_metrics");
    return;
end

if isa(simOut, "Simulink.SimulationOutput")
    simVars = simOut.who;
    if any(strcmp(simVars, "sim_metrics"))
        raw = simOut.get("sim_metrics");
        return;
    end
end

error("Simulink output variable sim_metrics was not found.");
end

function modelMode = step1_detect_simulink_model_mode(modelName)
fallbackBlocks = find_system(modelName, "SearchDepth", 1, "Name", "precomputed_metrics");
if isempty(fallbackBlocks)
    modelMode = 'matlab_function_block';
else
    modelMode = 'precomputed_metrics';
end
end

function step1_switch_to_precomputed_model(modelName)
linkBlock = modelName + "/Paper1 link closure";
fallbackBlock = modelName + "/precomputed_metrics";

if ~isempty(find_system(modelName, "SearchDepth", 1, "Name", "Paper1 link closure"))
    delete_block(linkBlock);
end
if isempty(find_system(modelName, "SearchDepth", 1, "Name", "precomputed_metrics"))
    add_block("simulink/Sources/Constant", fallbackBlock, ...
        "Value", "sim_precomputed_metrics", ...
        "Position", [320 135 475 185]);
end

lineHandles = get_param(modelName + "/metrics_to_workspace", "LineHandles");
if isfield(lineHandles, "Inport") && ~isempty(lineHandles.Inport) && lineHandles.Inport(1) > 0
    delete_line(lineHandles.Inport(1));
end
add_line(modelName, "precomputed_metrics/1", "metrics_to_workspace/1", "autorouting", "on");

modelFile = fullfile(fileparts(mfilename("fullpath")), modelName + ".slx");
save_system(modelName, modelFile);
fprintf("Rebuilt Simulink model %s (precomputed_metrics)\n", modelFile);
end
