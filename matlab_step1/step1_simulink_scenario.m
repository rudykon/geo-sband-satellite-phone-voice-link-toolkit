function y = step1_simulink_scenario(u)
%STEP1_SIMULINK_SCENARIO Fixed-width output for the Simulink function block.
%
% Input:
%   u(1) scenario index
%   u(2) Monte Carlo samples
%   u(3) random seed
%
% Output:
%   [scenario_index, availability, p10_ebn0_db, median_ebn0_db,
%    mean_ebn0_db, std_ebn0_db, p_los, threshold_ebn0_db]

cfg = step1_params();
scenarioIndex = min(max(round(u(1)), 1), height(cfg.scenarios));
nMc = max(100, round(u(2)));
seed = round(u(3));

m = step1_scenario_voice_metrics( ...
    cfg, scenarioIndex, cfg.voice.mainRateBps, cfg.voice.mainThresholdEbN0Db, nMc, seed);

y = [
    scenarioIndex
    m.availability
    m.p10_ebn0_db
    m.median_ebn0_db
    m.mean_ebn0_db
    m.std_ebn0_db
    m.p_los
    m.threshold_ebn0_db
];
end
