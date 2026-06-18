function cfg = voice_link_params()
%VOICE_LINK_PARAMS Shared voice-link parameters for MATLAB/Simulink validation.

paths = voice_link_paths();
rootDir = paths.rootDir;

cfg = struct();
cfg.rootDir = rootDir;
cfg.outputDir = paths.outputDir;
cfg.figureDir = paths.figureDir;
cfg.voice_linkPlotDir = paths.voice_linkPlotDir;
cfg.seed = 20260608;

cfg.nMcVoice = 200000;
cfg.nMcCapacity = 1000000;

cfg.link = struct();
cfg.link.uplinkMHz = 1995.0;
cfg.link.downlinkMHz = 2185.0;
cfg.link.distanceKm = 36000.0;
cfg.link.bandwidthHz = 31.25e3;
cfg.link.ptDbm = 34.0;
cfg.link.satGrDbi = 40.0;
cfg.link.polLossDb = 0.5;
cfg.link.extraLossDb = 1.0;
cfg.link.nfDb = 2.0;
cfg.link.gPeakDbi = 2.0;
cfg.link.gMinDbi = -10.0;
cfg.link.postureExponent = 1.7;

cfg.voice = struct();
cfg.voice.rateBps = [1200.0, 2400.0, 4000.0];
cfg.voice.thresholdEbN0Db = [-1.0, 0.7, 2.2];
cfg.voice.mainRateBps = 2400.0;
cfg.voice.mainThresholdEbN0Db = 0.7;

scenarioKey = [
    "open_plain";
    "forest_edge";
    "canyon_valley";
    "moving_trail";
    "tent_shelter"
];
scenarioModelKey = [
    "open";
    "suburban";
    "urban";
    "car";
    "indoor_window"
];
label = [
    "Open plain";
    "Forest edge";
    "Canyon valley";
    "Moving trail";
    "Tent/shelter"
];
elevDeg = 45.0;
pLosShift = [12.0; 18.0; 26.0; 30.0; 38.0];
pLosScale = [6.0; 7.0; 8.0; 8.5; 9.5];
pLosCap = [0.98; 0.92; 0.78; 0.60; 0.38];
pLos = pLosCap ./ (1.0 + exp(-(elevDeg - pLosShift) ./ pLosScale));
sigmaDb = [2.5; 4.0; 7.0; 6.0; 9.0];
thetaMeanDeg = [8.0; 13.0; 20.0; 25.0; 30.0];
thetaStdDeg = [5.0; 8.0; 12.0; 14.0; 16.0];
nlosLossDb = [8.0; 12.0; 18.0; 20.0; 26.0];
pLL = pLos;
pNN = 1.0 - pLos;

cfg.scenarios = table( ...
    scenarioKey, scenarioModelKey, label, pLos, sigmaDb, thetaMeanDeg, thetaStdDeg, nlosLossDb, pLL, pNN, ...
    'VariableNames', {'scenario_key', 'scenario_model_key', 'label', 'p_los', 'sigma_db', ...
    'theta_mean_deg', 'theta_std_deg', 'nlos_loss_db', 'p_ll', 'p_nn'});

cfg.outage = struct();
cfg.outage.epsilon = 1e-2;
cfg.outage.gamma0Db = 11.706656016154298;
cfg.outage.sigmaScanDb = (2.0:1.0:12.0).';
end
