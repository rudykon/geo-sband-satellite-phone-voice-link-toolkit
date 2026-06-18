function y = step1_simulink_scenario(u)
%STEP1_SIMULINK_SCENARIO Fixed-width output for the Simulink function block.
%
% Input:
%   u(1) scenario index
%   u(2) Monte Carlo samples
%   u(3) random seed
%   u(4) voice rate bps
%   u(5) threshold Eb/N0 dB
%
% Output:
%   [scenario_index, availability, p10_ebn0_db, median_ebn0_db,
%    mean_ebn0_db, std_ebn0_db, p_los, threshold_ebn0_db, mean_mos_proxy]

if evalin('base', "exist('step1_cosim_cfg', 'var')")
    cfg = evalin('base', 'step1_cosim_cfg');
else
    cfg = step1_params();
end
scenarioIndex = min(max(round(u(1)), 1), height(cfg.scenarios));
nMc = max(100, round(u(2)));
seed = round(u(3));
if numel(u) >= 4
    rateBps = double(u(4));
else
    rateBps = cfg.voice.mainRateBps;
end
if numel(u) >= 5
    thresholdDb = double(u(5));
else
    thresholdDb = cfg.voice.mainThresholdEbN0Db;
end

m = step1_scenario_voice_metrics( ...
    cfg, scenarioIndex, rateBps, thresholdDb, nMc, seed);

y = [
    scenarioIndex
    m.availability
    m.p10_ebn0_db
    m.median_ebn0_db
    m.mean_ebn0_db
    m.std_ebn0_db
    m.p_los
    m.threshold_ebn0_db
    m.mean_mos_proxy
];
end
