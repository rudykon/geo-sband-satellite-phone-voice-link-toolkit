function modelName = step1_build_lms_simulink_model(cfg)
%STEP1_BUILD_LMS_SIMULINK_MODEL Generate the LMS channel Simulink model.

modelName = "step1_lms_channel_timeseries_system";
modelFile = fullfile(fileparts(mfilename("fullpath")), modelName + ".slx");

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist(modelFile, "file")
    delete(modelFile);
end

new_system(modelName);
set_param(modelName, "Solver", "FixedStepDiscrete", "StopTime", "1", "FixedStep", "1");

add_block("simulink/Sources/Constant", modelName + "/scenario_index", ...
    "Value", "1", "Position", [80 70 155 100]);
add_block("simulink/Sources/Constant", modelName + "/n_frames", ...
    "Value", "15000", "Position", [80 125 155 155]);
add_block("simulink/Sources/Constant", modelName + "/seed", ...
    "Value", num2str(cfg.seed), "Position", [80 180 155 210]);
add_block("simulink/Sources/Constant", modelName + "/threshold_ebn0_db", ...
    "Value", num2str(cfg.voice.mainThresholdEbN0Db), "Position", [80 235 155 265]);

add_block("simulink/Signal Routing/Mux", modelName + "/lms_inputs", ...
    "Inputs", "4", "Position", [220 105 250 230]);

linkBlock = modelName + "/LMS channel time series";
try
    add_block("simulink/User-Defined Functions/MATLAB Function", ...
        linkBlock, "Position", [315 135 500 195]);
    local_configure_lms_matlab_function_block(linkBlock);
    modelMode = 'matlab_function_block';
catch blockErr
    warning("step1:lmsSimulinkBlockFallback", ...
        "Could not create a MATLAB Function block (%s). Falling back to precomputed LMS metrics.", ...
        blockErr.message);
    add_block("simulink/Sources/Constant", modelName + "/precomputed_lms_metrics", ...
        "Value", "lms_precomputed_metrics", ...
        "Position", [320 135 500 185]);
    modelMode = 'precomputed_metrics';
end

add_block("simulink/Sinks/To Workspace", modelName + "/metrics_to_workspace", ...
    "VariableName", "lms_sim_metrics", ...
    "SaveFormat", "Array", ...
    "Position", [570 145 700 175]);

add_line(modelName, "scenario_index/1", "lms_inputs/1", "autorouting", "on");
add_line(modelName, "n_frames/1", "lms_inputs/2", "autorouting", "on");
add_line(modelName, "seed/1", "lms_inputs/3", "autorouting", "on");
add_line(modelName, "threshold_ebn0_db/1", "lms_inputs/4", "autorouting", "on");

if strcmp(modelMode, 'matlab_function_block')
    add_line(modelName, "lms_inputs/1", "LMS channel time series/1", "autorouting", "on");
    add_line(modelName, "LMS channel time series/1", "metrics_to_workspace/1", "autorouting", "on");
else
    add_line(modelName, "precomputed_lms_metrics/1", "metrics_to_workspace/1", "autorouting", "on");
end

Simulink.Annotation(modelName, ...
    "Step 1 LMS time-series channel: LOS/NLOS Markov state, lognormal shadowing, Rician/Rayleigh fading, frame-level FER, and voice availability.");

save_system(modelName, modelFile);
fprintf("Wrote LMS Simulink model %s (%s)\n", modelFile, modelMode);
end

function local_configure_lms_matlab_function_block(blockPath)
rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", blockPath);
if isempty(chart)
    chart = rt.find("-isa", "Stateflow.EMChart", "Name", get_param(blockPath, "Name"));
end
if isempty(chart)
    error("Could not locate the Stateflow chart backing %s.", blockPath);
end
if numel(chart) > 1
    chart = chart(end);
end

chart.Script = sprintf([ ...
    'function y = fcn(u)\n' ...
    '%%#codegen\n' ...
    'coder.extrinsic(''step1_simulink_lms_scenario'');\n' ...
    'y = zeros(9,1);\n' ...
    'y = step1_simulink_lms_scenario(u);\n' ...
    'end\n']);
end
