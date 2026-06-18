function cfg = step1_apply_manifest(cfg, manifest)
%STEP1_APPLY_MANIFEST Apply the Python-written co-simulation manifest.

if isfield(manifest, 'seed'), cfg.seed = double(manifest.seed); end
if isfield(manifest, 'n_mc_voice'), cfg.nMcVoice = double(manifest.n_mc_voice); end
if isfield(manifest, 'n_mc_capacity'), cfg.nMcCapacity = double(manifest.n_mc_capacity); end

if isfield(manifest, 'link')
    link = manifest.link;
    cfg.link.uplinkMHz = double(link.uplink_mhz);
    cfg.link.downlinkMHz = double(link.downlink_mhz);
    cfg.link.distanceKm = double(link.distance_km);
    cfg.link.bandwidthHz = double(link.bandwidth_hz);
    cfg.link.ptDbm = double(link.pt_dbm);
    cfg.link.satGrDbi = double(link.sat_gr_dbi);
    cfg.link.polLossDb = double(link.pol_loss_db);
    cfg.link.extraLossDb = double(link.extra_loss_db);
    cfg.link.nfDb = double(link.nf_db);
    cfg.link.gPeakDbi = double(link.g_peak_dbi);
    cfg.link.gMinDbi = double(link.g_min_dbi);
    cfg.link.postureExponent = double(link.posture_exponent);
end

if isfield(manifest, 'voice')
    voice = manifest.voice;
    cfg.voice.rateBps = double(voice.rate_bps(:)).';
    cfg.voice.thresholdEbN0Db = double(voice.legacy_threshold_ebn0_db(:)).';
    cfg.voice.mainRateBps = double(voice.main_rate_bps);
    mainIdx = find(abs(cfg.voice.rateBps - cfg.voice.mainRateBps) < 1e-9, 1);
    if ~isempty(mainIdx)
        cfg.voice.mainThresholdEbN0Db = cfg.voice.thresholdEbN0Db(mainIdx);
    end
end

if isfield(manifest, 'scenarios')
    scenarios = manifest.scenarios(:);
    n = numel(scenarios);
    scenarioKey = strings(n, 1);
    step1Key = strings(n, 1);
    label = strings(n, 1);
    pLos = zeros(n, 1);
    sigmaDb = zeros(n, 1);
    thetaMeanDeg = zeros(n, 1);
    thetaStdDeg = zeros(n, 1);
    nlosLossDb = zeros(n, 1);
    pLL = zeros(n, 1);
    pNN = zeros(n, 1);
    for i = 1:n
        sc = scenarios(i);
        scenarioKey(i) = string(sc.scenario_key);
        step1Key(i) = string(sc.step1_key);
        label(i) = string(sc.label);
        pLos(i) = double(sc.p_los);
        sigmaDb(i) = double(sc.sigma_db);
        thetaMeanDeg(i) = double(sc.theta_mean_deg);
        thetaStdDeg(i) = double(sc.theta_std_deg);
        nlosLossDb(i) = double(sc.nlos_loss_db);
        pLL(i) = double(sc.p_ll);
        pNN(i) = double(sc.p_nn);
    end
    cfg.scenarios = table( ...
        scenarioKey, step1Key, label, pLos, sigmaDb, thetaMeanDeg, thetaStdDeg, nlosLossDb, pLL, pNN, ...
        'VariableNames', {'scenario_key', 'step1_key', 'label', 'p_los', 'sigma_db', ...
        'theta_mean_deg', 'theta_std_deg', 'nlos_loss_db', 'p_ll', 'p_nn'});
end

cfg.cosimManifest = manifest;
end
