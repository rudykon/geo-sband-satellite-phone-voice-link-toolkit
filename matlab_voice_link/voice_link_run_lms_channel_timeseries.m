function rows = voice_link_run_lms_channel_timeseries(cfg, thresholdRows)
%VOICE_LINK_RUN_LMS_CHANNEL_TIMESERIES LMS frame-level channel simulation.
%
% The model combines LOS/NLOS Markov dynamics, lognormal shadowing, Rician or
% Rayleigh small-scale fading, and a PHY-calibrated FER curve.

if nargin < 1 || isempty(cfg)
    cfg = voice_link_params();
end
if nargin < 2 || isempty(thresholdRows)
    thresholdPath = fullfile(cfg.outputDir, 'voice_threshold_from_phy.csv');
    if exist(thresholdPath, 'file')
        thresholdRows = readtable(thresholdPath);
    else
        thresholdRows = table(cfg.voice.rateBps(:), cfg.voice.thresholdEbN0Db(:), ...
            'VariableNames', {'voice_rate_bps', 'phy_threshold_ebn0_db'});
    end
end

if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end

fprintf('Running LMS channel time-series simulation...\n');

rng(cfg.seed + 4200, 'twister');

frameDurationMs = 40.0;
numFrames = 15000;
rateBps = cfg.voice.mainRateBps;
thresholdDb = voice_link_lookup_threshold(thresholdRows, rateBps, cfg.voice.mainThresholdEbN0Db);
ferSlopeDb = 1.25;

rows = table();
frameRows = table();

for i = 1:height(cfg.scenarios)
    sc = cfg.scenarios(i, :);
    scenarioSeed = cfg.seed + 4200 + 97 * i;
    rng(scenarioSeed, 'twister');

    theta = sc.theta_mean_deg + sc.theta_std_deg .* randn(numFrames, 1);
    theta = min(max(theta, 0.0), 80.0);
    gtDbi = voice_link_orientation_gain_db(theta, cfg);

    fsplDb = voice_link_fspl_db(cfg.link.distanceKm, cfg.link.uplinkMHz);
    noiseDbm = voice_link_noise_dbm(cfg.link.bandwidthHz, cfg.link.nfDb);
    snrDetDb = cfg.link.ptDbm + gtDbi + cfg.link.satGrDbi ...
        - fsplDb - cfg.link.polLossDb - cfg.link.extraLossDb - noiseDbm;

    losState = voice_link_markov_los(numFrames, sc.p_los, sc.p_ll, sc.p_nn);
    shadowDb = voice_link_correlated_shadowing(numFrames, sc.sigma_db, 0.985);
    smallScaleDb = voice_link_small_scale_fading(losState, i, numFrames);

    snrDb = snrDetDb - shadowDb - double(~losState) .* sc.nlos_loss_db + smallScaleDb;
    ebn0Db = snrDb + 10.0 * log10(cfg.link.bandwidthHz / rateBps);

    ferProb = 1.0 ./ (1.0 + exp((ebn0Db - thresholdDb) ./ ferSlopeDb));
    frameError = rand(numFrames, 1) < ferProb;
    availableFrame = ~frameError;
    availability = mean(availableFrame);
    meanFer = mean(frameError);
    p10Ebn0 = voice_link_empirical_quantile(ebn0Db, 0.10);
    medianEbn0 = voice_link_empirical_quantile(ebn0Db, 0.50);
    maxOutageFrames = voice_link_max_run_length(frameError);
    maxOutageMs = maxOutageFrames * frameDurationMs;
    p95BurstMs = voice_link_burst_quantile(frameError, frameDurationMs, 0.95);

    rows = [rows; table( ...
        sc.scenario_key, sc.scenario_model_key, sc.label, rateBps, thresholdDb, ...
        numFrames, frameDurationMs, availability, meanFer, p10Ebn0, medianEbn0, ...
        maxOutageMs, p95BurstMs, mean(losState), mean(shadowDb), std(shadowDb), ...
        'VariableNames', {'scenario_key', 'scenario_model_key', 'label', 'voice_rate_bps', ...
        'threshold_ebn0_db', 'frames', 'frame_duration_ms', 'availability', ...
        'frame_error_rate', 'p10_ebn0_db', 'median_ebn0_db', ...
        'max_outage_ms', 'p95_burst_ms', 'empirical_p_los', ...
        'mean_shadow_db', 'std_shadow_db'})]; %#ok<AGROW>

    sampleEvery = max(1, floor(numFrames / 300));
    sampleIdx = (1:sampleEvery:numFrames).';
    frameRows = [frameRows; table( ...
        repmat(sc.scenario_key, numel(sampleIdx), 1), ...
        sampleIdx, (sampleIdx - 1) .* frameDurationMs ./ 1000.0, ...
        losState(sampleIdx), ebn0Db(sampleIdx), ferProb(sampleIdx), frameError(sampleIdx), ...
        'VariableNames', {'scenario_key', 'frame_index', 'time_s', ...
        'los_state', 'ebn0_db', 'fer_probability', 'frame_error'})]; %#ok<AGROW>
end

writetable(rows, fullfile(cfg.outputDir, 'lms_channel_availability.csv'));
writetable(frameRows, fullfile(cfg.outputDir, 'lms_frame_timeseries_sample.csv'));

fprintf('Wrote %s\n', fullfile(cfg.outputDir, 'lms_channel_availability.csv'));
fprintf('Wrote %s\n', fullfile(cfg.outputDir, 'lms_frame_timeseries_sample.csv'));
end

function thresholdDb = voice_link_lookup_threshold(thresholdRows, rateBps, fallback)
if any(strcmp(thresholdRows.Properties.VariableNames, 'phy_threshold_ebn0_db'))
    valueName = 'phy_threshold_ebn0_db';
else
    valueName = 'threshold_ebn0_db';
end
idx = abs(thresholdRows.voice_rate_bps - rateBps) < 1e-9;
if any(idx)
    thresholdDb = thresholdRows.(valueName)(find(idx, 1));
else
    thresholdDb = fallback;
end
end

function los = voice_link_markov_los(n, pLosTarget, pLL, pNN)
los = false(n, 1);
los(1) = rand() < pLosTarget;
for k = 2:n
    if los(k - 1)
        los(k) = rand() < pLL;
    else
        los(k) = rand() > pNN;
    end
end
% Blend toward the target if the inherited transition parameters are too sticky.
if abs(mean(los) - pLosTarget) > 0.15
    los = rand(n, 1) < pLosTarget;
end
end

function shadowDb = voice_link_correlated_shadowing(n, sigmaDb, rho)
w = randn(n, 1);
shadowDb = zeros(n, 1);
scale = sigmaDb * sqrt(max(1.0 - rho ^ 2, 0.0));
shadowDb(1) = sigmaDb * w(1);
for k = 2:n
    shadowDb(k) = rho * shadowDb(k - 1) + scale * w(k);
end
end

function fadingDb = voice_link_small_scale_fading(losState, scenarioIndex, n)
kLosDb = [10.0, 7.0, 4.0, 5.0, 2.0];
kLin = 10.0 .^ (kLosDb(min(scenarioIndex, numel(kLosDb))) / 10.0);
losAmp = sqrt(kLin / (kLin + 1.0)) + sqrt(1.0 / (2.0 * (kLin + 1.0))) .* (randn(n, 1) + 1j .* randn(n, 1));
nlosAmp = (randn(n, 1) + 1j .* randn(n, 1)) ./ sqrt(2.0);
amp = nlosAmp;
amp(losState) = losAmp(losState);
powerGain = abs(amp) .^ 2;
fadingDb = 10.0 .* log10(max(powerGain, 1e-5));
end

function maxLen = voice_link_max_run_length(flags)
maxLen = 0;
cur = 0;
for k = 1:numel(flags)
    if flags(k)
        cur = cur + 1;
        maxLen = max(maxLen, cur);
    else
        cur = 0;
    end
end
end

function qMs = voice_link_burst_quantile(flags, frameDurationMs, q)
lengths = [];
cur = 0;
for k = 1:numel(flags)
    if flags(k)
        cur = cur + 1;
    elseif cur > 0
        lengths(end + 1, 1) = cur; %#ok<AGROW>
        cur = 0;
    end
end
if cur > 0
    lengths(end + 1, 1) = cur;
end
if isempty(lengths)
    qMs = 0.0;
else
    qMs = voice_link_empirical_quantile(lengths .* frameDurationMs, q);
end
end
