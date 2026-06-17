function y = step1_simulink_lms_scenario(u)
%STEP1_SIMULINK_LMS_SCENARIO Fixed-width LMS output for Simulink.
%
% Input:
%   u(1) scenario index
%   u(2) number of frames
%   u(3) random seed
%   u(4) PHY-calibrated Eb/N0 threshold for the main voice rate
%
% Output:
%   [scenario_index, availability, frame_error_rate, p10_ebn0_db,
%    median_ebn0_db, max_outage_ms, p95_burst_ms, empirical_p_los,
%    threshold_ebn0_db]

cfg = step1_params();
scenarioIndex = min(max(round(u(1)), 1), height(cfg.scenarios));
numFrames = max(200, round(u(2)));
seed = round(u(3));
thresholdDb = u(4);
frameDurationMs = 40.0;
rateBps = cfg.voice.mainRateBps;
ferSlopeDb = 1.25;

sc = cfg.scenarios(scenarioIndex, :);
rng(seed + 4200 + 97 * scenarioIndex, 'twister');

theta = sc.theta_mean_deg + sc.theta_std_deg .* randn(numFrames, 1);
theta = min(max(theta, 0.0), 80.0);
gtDbi = step1_orientation_gain_db(theta, cfg);

fsplDb = step1_fspl_db(cfg.link.distanceKm, cfg.link.uplinkMHz);
noiseDbm = step1_noise_dbm(cfg.link.bandwidthHz, cfg.link.nfDb);
snrDetDb = cfg.link.ptDbm + gtDbi + cfg.link.satGrDbi ...
    - fsplDb - cfg.link.polLossDb - cfg.link.extraLossDb - noiseDbm;

losState = local_markov_los(numFrames, sc.p_los, sc.p_ll, sc.p_nn);
shadowDb = local_correlated_shadowing(numFrames, sc.sigma_db, 0.985);
smallScaleDb = local_small_scale_fading(losState, scenarioIndex, numFrames);

snrDb = snrDetDb - shadowDb - double(~losState) .* sc.nlos_loss_db + smallScaleDb;
ebn0Db = snrDb + 10.0 * log10(cfg.link.bandwidthHz / rateBps);

ferProb = 1.0 ./ (1.0 + exp((ebn0Db - thresholdDb) ./ ferSlopeDb));
frameError = rand(numFrames, 1) < ferProb;
availability = mean(~frameError);
frameErrorRate = mean(frameError);
p10Ebn0 = step1_empirical_quantile(ebn0Db, 0.10);
medianEbn0 = step1_empirical_quantile(ebn0Db, 0.50);
maxOutageMs = local_max_run_length(frameError) * frameDurationMs;
p95BurstMs = local_burst_quantile(frameError, frameDurationMs, 0.95);

y = [
    scenarioIndex
    availability
    frameErrorRate
    p10Ebn0
    medianEbn0
    maxOutageMs
    p95BurstMs
    mean(losState)
    thresholdDb
];
end

function los = local_markov_los(n, pLosTarget, pLL, pNN)
los = false(n, 1);
los(1) = rand() < pLosTarget;
for k = 2:n
    if los(k - 1)
        los(k) = rand() < pLL;
    else
        los(k) = rand() > pNN;
    end
end
if abs(mean(los) - pLosTarget) > 0.15
    los = rand(n, 1) < pLosTarget;
end
end

function shadowDb = local_correlated_shadowing(n, sigmaDb, rho)
w = randn(n, 1);
shadowDb = zeros(n, 1);
scale = sigmaDb * sqrt(max(1.0 - rho ^ 2, 0.0));
shadowDb(1) = sigmaDb * w(1);
for k = 2:n
    shadowDb(k) = rho * shadowDb(k - 1) + scale * w(k);
end
end

function fadingDb = local_small_scale_fading(losState, scenarioIndex, n)
kLosDb = [10.0, 7.0, 4.0, 5.0, 2.0];
kLin = 10.0 .^ (kLosDb(min(scenarioIndex, numel(kLosDb))) / 10.0);
losAmp = sqrt(kLin / (kLin + 1.0)) + sqrt(1.0 / (2.0 * (kLin + 1.0))) .* (randn(n, 1) + 1j .* randn(n, 1));
nlosAmp = (randn(n, 1) + 1j .* randn(n, 1)) ./ sqrt(2.0);
amp = nlosAmp;
amp(losState) = losAmp(losState);
powerGain = abs(amp) .^ 2;
fadingDb = 10.0 .* log10(max(powerGain, 1e-5));
end

function maxLen = local_max_run_length(flags)
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

function qMs = local_burst_quantile(flags, frameDurationMs, q)
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
    qMs = step1_empirical_quantile(lengths .* frameDurationMs, q);
end
end
