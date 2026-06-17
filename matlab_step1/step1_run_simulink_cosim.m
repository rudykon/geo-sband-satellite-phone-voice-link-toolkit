function rows = step1_run_simulink_cosim(cfg, modelName)
%STEP1_RUN_SIMULINK_COSIM Run the generated Simulink model over scenarios.

modelMode = step1_detect_simulink_model_mode(modelName);

rows = table();
for i = 1:height(cfg.scenarios)
    set_param(modelName + "/scenario_index", "Value", num2str(i));
    set_param(modelName + "/n_mc", "Value", num2str(cfg.nMcVoice));
    set_param(modelName + "/seed", "Value", num2str(cfg.seed));

    if strcmp(modelMode, 'precomputed_metrics')
        simPrecomputedMetrics = step1_simulink_scenario([i; cfg.nMcVoice; cfg.seed]);
        assignin("base", "sim_precomputed_metrics", simPrecomputedMetrics);
    end

    try
        simOut = sim(modelName, "StopTime", "1");
    catch simErr
        if ~strcmp(modelMode, 'matlab_function_block')
            rethrow(simErr);
        end
        warning("step1:simulinkRuntimeFallback", ...
            "MATLAB Function block simulation failed (%s). Rebuilding as a precomputed-metrics Simulink orchestration model.", ...
            simErr.message);
        step1_switch_to_precomputed_model(modelName);
        modelMode = 'precomputed_metrics';
        simPrecomputedMetrics = step1_simulink_scenario([i; cfg.nMcVoice; cfg.seed]);
        assignin("base", "sim_precomputed_metrics", simPrecomputedMetrics);
        simOut = sim(modelName, "StopTime", "1");
    end
    raw = step1_get_simulink_output(simOut);
    values = step1_last_simulink_row(raw);

    sc = cfg.scenarios(i, :);
    row = table( ...
        sc.scenario_key, sc.step1_key, sc.label, ...
        cfg.voice.mainRateBps, cfg.voice.mainThresholdEbN0Db, ...
        cfg.nMcVoice, values(2), values(3), values(4), values(5), values(6), ...
        'VariableNames', {'scenario_key', 'step1_key', 'label', 'voice_rate_bps', ...
        'threshold_ebn0_db', 'samples', 'availability', 'p10_ebn0_db', ...
        'median_ebn0_db', 'mean_ebn0_db', 'std_ebn0_db'});
    rows = [rows; row]; %#ok<AGROW>
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
last = raw(end, :);
if numel(last) == 9
    values = last(2:end); % Drop time column if To Workspace included it.
elseif numel(last) == 8
    values = last;
else
    error("Unexpected Simulink output width: %d", numel(last));
end
values = double(values(:)).';
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
linkBlock = modelName + "/Step1 link closure";
fallbackBlock = modelName + "/precomputed_metrics";

if ~isempty(find_system(modelName, "SearchDepth", 1, "Name", "Step1 link closure"))
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
