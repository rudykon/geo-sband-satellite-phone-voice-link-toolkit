function metrics = step1_scenario_voice_metrics(cfg, scenarioIndex, rateBps, thresholdEbN0Db, nMc, seed)
%STEP1_SCENARIO_VOICE_METRICS Link closure metrics for one scenario/rate.

if nargin < 5 || isempty(nMc), nMc = cfg.nMcVoice; end
if nargin < 6 || isempty(seed), seed = cfg.seed; end

sc = cfg.scenarios(scenarioIndex, :);
rng(seed + 1009 * scenarioIndex + round(rateBps), "twister");

theta = sc.theta_mean_deg + sc.theta_std_deg .* randn(nMc, 1);
theta = min(max(theta, 0.0), 80.0);
gtDbi = step1_orientation_gain_db(theta, cfg);

fsplDb = step1_fspl_db(cfg.link.distanceKm, cfg.link.uplinkMHz);
noiseDbm = step1_noise_dbm(cfg.link.bandwidthHz, cfg.link.nfDb);
snrDetDb = cfg.link.ptDbm + gtDbi + cfg.link.satGrDbi ...
    - fsplDb - cfg.link.polLossDb - cfg.link.extraLossDb - noiseDbm;

los = rand(nMc, 1) < sc.p_los;
shadowDb = sc.sigma_db .* randn(nMc, 1);
snrDb = snrDetDb - shadowDb - double(~los) .* sc.nlos_loss_db;
ebn0Db = snrDb + 10.0 * log10(cfg.link.bandwidthHz / rateBps);

ok = ebn0Db >= thresholdEbN0Db;

metrics = struct();
metrics.scenario_key = sc.scenario_key;
metrics.step1_key = sc.step1_key;
metrics.label = sc.label;
metrics.voice_rate_bps = rateBps;
metrics.threshold_ebn0_db = thresholdEbN0Db;
metrics.samples = nMc;
metrics.p_los = sc.p_los;
metrics.sigma_db = sc.sigma_db;
metrics.theta_mean_deg = sc.theta_mean_deg;
metrics.theta_std_deg = sc.theta_std_deg;
metrics.nlos_loss_db = sc.nlos_loss_db;
metrics.availability = mean(ok);
metrics.p10_ebn0_db = step1_empirical_quantile(ebn0Db, 0.10);
metrics.median_ebn0_db = step1_empirical_quantile(ebn0Db, 0.50);
metrics.mean_ebn0_db = mean(ebn0Db);
metrics.std_ebn0_db = std(ebn0Db);
end
