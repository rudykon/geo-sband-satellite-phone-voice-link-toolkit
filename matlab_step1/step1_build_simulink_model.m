function modelName = step1_build_simulink_model(cfg)
%STEP1_BUILD_SIMULINK_MODEL Generate the Step 1 system-level Simulink model.
%
% The generated model intentionally keeps equations in readable MATLAB files.
% Simulink orchestrates the scenario index, sample count, random seed, and link
% closure metrics to provide a system-level co-simulation artifact.

modelName = "step1_geo_sband_link_system";
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
    "Value", "1", "Position", [80 80 150 110]);
add_block("simulink/Sources/Constant", modelName + "/n_mc", ...
    "Value", num2str(cfg.nMcVoice), "Position", [80 145 150 175]);
add_block("simulink/Sources/Constant", modelName + "/seed", ...
    "Value", num2str(cfg.seed), "Position", [80 210 150 240]);

add_block("simulink/Signal Routing/Mux", modelName + "/scenario_inputs", ...
    "Inputs", "3", "Position", [215 105 245 220]);

linkBlock = modelName + "/Paper1 link closure";
forcePrecomputed = strcmp(getenv('STEP1_FORCE_PRECOMPUTED_SIMULINK'), '1');
try
    if forcePrecomputed
        error('step1:forcedPrecomputed', 'Forced precomputed-metrics Simulink orchestration mode.');
    end
    add_block("simulink/User-Defined Functions/MATLAB Function", ...
        linkBlock, "Position", [310 130 475 190]);
    step1_configure_matlab_function_block(linkBlock);
    modelMode = 'matlab_function_block';
catch blockErr
    warning("step1:simulinkBlockFallback", ...
        "Could not create a MATLAB Function block (%s). Falling back to a precomputed-metrics Simulink orchestration model.", ...
        blockErr.message);
    add_block("simulink/Sources/Constant", modelName + "/precomputed_metrics", ...
        "Value", "sim_precomputed_metrics", ...
        "Position", [320 135 475 185]);
    modelMode = 'precomputed_metrics';
end

add_block("simulink/Sinks/To Workspace", modelName + "/metrics_to_workspace", ...
    "VariableName", "sim_metrics", ...
    "SaveFormat", "Array", ...
    "Position", [545 145 665 175]);

add_line(modelName, "scenario_index/1", "scenario_inputs/1", "autorouting", "on");
add_line(modelName, "n_mc/1", "scenario_inputs/2", "autorouting", "on");
add_line(modelName, "seed/1", "scenario_inputs/3", "autorouting", "on");
if strcmp(modelMode, 'matlab_function_block')
    add_line(modelName, "scenario_inputs/1", "Paper1 link closure/1", "autorouting", "on");
    add_line(modelName, "Paper1 link closure/1", "metrics_to_workspace/1", "autorouting", "on");
else
    add_line(modelName, "precomputed_metrics/1", "metrics_to_workspace/1", "autorouting", "on");
end

Simulink.Annotation(modelName, ...
    "Step 1 GEO S-band system-level co-simulation: scenario -> posture/link budget -> LOS/NLOS shadowing -> Eb/N0 threshold -> voice availability.");
Simulink.Annotation(modelName, ...
    "The executable link equations are stored in step1_simulink_scenario.m and step1_scenario_voice_metrics.m for auditability.");

save_system(modelName, modelFile);
fprintf("Wrote Simulink model %s (%s)\n", modelFile, modelMode);
end

function step1_configure_matlab_function_block(blockPath)
%STEP1_CONFIGURE_MATLAB_FUNCTION_BLOCK Write simulation-only MATLAB code.
%
% The MATLAB Function block is used only for normal-mode simulation here. The
% actual Monte Carlo link equations remain in regular MATLAB files for easier
% review, and coder.extrinsic delegates the calculation back to MATLAB.

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
    'coder.extrinsic(''step1_simulink_scenario'');\n' ...
    'y = zeros(8,1);\n' ...
    'y = step1_simulink_scenario(u);\n' ...
    'end\n']);
end
