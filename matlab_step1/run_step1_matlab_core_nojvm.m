%RUN_STEP1_MATLAB_CORE_NOJVM Minimal MATLAB core validation for no-JVM batch.
%
% R2026a on this workstation may crash in the home/recent-artifacts service
% when batch mode initializes JVM-backed services. This runner avoids table,
% string, graphics, and Simulink APIs so the Step 1 numerical cross-check can
% still be executed from:
%
%   matlab -nojvm -batch "cd('C:\tmp\matlab_step1_run\matlab_step1'); run_step1_matlab_core_nojvm"

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
outDir = fullfile(rootDir, 'outputs', 'matlab_step1');
if ~exist(outDir, 'dir'), mkdir(outDir); end

seed = 20260608;
nMcVoice = 200000;
nMcCap = 1000000;

scenarioKey = {'open_plain','forest_edge','canyon_valley','moving_trail','tent_shelter'};
step1Key = {'open','suburban','urban','car','indoor_window'};
label = {'Open plain','Forest edge','Canyon valley','Moving trail','Tent/shelter'};
pLos = [0.96, 0.78, 0.58, 0.65, 0.35];
sigmaDb = [2.5, 5.0, 8.0, 7.0, 9.0];
thetaMean = [8.0, 13.0, 22.0, 26.0, 32.0];
thetaStd = [5.0, 8.0, 13.0, 15.0, 17.0];
nlosLoss = [8.0, 14.0, 22.0, 18.0, 26.0];

rateBps = [1200.0, 2400.0, 4000.0];
thresholdDb = [-1.0, 0.7, 2.2];

bwHz = 31.25e3;
ptDbm = 34.0;
satGrDbi = 40.0;
distanceKm = 36000.0;
freqMHz = 1995.0;
polLossDb = 0.5;
extraLossDb = 1.0;
nfDb = 2.0;

fprintf('Step 1 MATLAB no-JVM core validation\n');
fprintf('Output dir: %s\n', outDir);

voicePath = fullfile(outDir, 'voice_availability_matlab.csv');
fid = fopen(voicePath, 'w');
fprintf(fid, 'scenario_key,step1_key,label,voice_rate_bps,threshold_ebn0_db,samples,p_los,sigma_db,theta_mean_deg,theta_std_deg,nlos_loss_db,availability,p10_ebn0_db,median_ebn0_db,mean_ebn0_db,std_ebn0_db\n');

mainAvail = zeros(1, numel(scenarioKey));
mainP10 = zeros(1, numel(scenarioKey));
mainMedian = zeros(1, numel(scenarioKey));

for i = 1:numel(scenarioKey)
    for j = 1:numel(rateBps)
        rng(seed + 1009 * i + round(rateBps(j)), 'twister');
        theta = thetaMean(i) + thetaStd(i) .* randn(nMcVoice, 1);
        theta = min(max(theta, 0.0), 80.0);
        gt = orientation_gain_db(theta);
        fspl = fspl_db(distanceKm, freqMHz);
        noise = noise_dbm(bwHz, nfDb);
        snrDet = ptDbm + gt + satGrDbi - fspl - polLossDb - extraLossDb - noise;
        los = rand(nMcVoice, 1) < pLos(i);
        shadow = sigmaDb(i) .* randn(nMcVoice, 1);
        snr = snrDet - shadow - double(~los) .* nlosLoss(i);
        ebn0 = snr + 10.0 * log10(bwHz / rateBps(j));
        availability = mean(ebn0 >= thresholdDb(j));
        p10 = empirical_quantile(ebn0, 0.10);
        med = empirical_quantile(ebn0, 0.50);
        mu = mean(ebn0);
        sd = std(ebn0);
        fprintf(fid, '%s,%s,%s,%.1f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.10f,%.10f,%.10f,%.10f,%.10f\n', ...
            scenarioKey{i}, step1Key{i}, label{i}, rateBps(j), thresholdDb(j), nMcVoice, ...
            pLos(i), sigmaDb(i), thetaMean(i), thetaStd(i), nlosLoss(i), availability, p10, med, mu, sd);
        if abs(rateBps(j) - 2400.0) < 1e-9
            mainAvail(i) = availability;
            mainP10(i) = p10;
            mainMedian(i) = med;
        end
    end
end
fclose(fid);
fprintf('Wrote %s\n', voicePath);

outagePath = fullfile(outDir, 'outage_capacity_matlab.csv');
fid = fopen(outagePath, 'w');
fprintf(fid, 'sigma_db,epsilon,gamma0_db,samples,c_mc,c_exact,c_chernoff_lb,c_no_shadow_ub,mc_minus_exact,exact_minus_chernoff_lb,ub_minus_exact\n');

eps0 = 1e-2;
gamma0Db = 11.706656016154298;
gamma0 = 10.0 .^ (gamma0Db ./ 10.0);
sigmaScan = 2.0:1.0:12.0;
outSigma = zeros(size(sigmaScan));
outExact = zeros(size(sigmaScan));
outMc = zeros(size(sigmaScan));
outLb = zeros(size(sigmaScan));
outUb = zeros(size(sigmaScan));

rng(seed + 77, 'twister');
for k = 1:numel(sigmaScan)
    sigDb = sigmaScan(k);
    sigNat = log(10.0) / 10.0 * sigDb;
    zEps = sqrt(2.0) * erfinv(2.0 * eps0 - 1.0);
    cExact = log2(1.0 + gamma0 * exp(sigNat * zEps));
    cLb = log2(1.0 + gamma0 * exp(-sigNat * sqrt(2.0 * log(1.0 / eps0))));
    cUb = log2(1.0 + gamma0);
    xDb = sigDb .* randn(nMcCap, 1);
    gamma = gamma0 .* 10.0 .^ (-xDb ./ 10.0);
    cap = log2(1.0 + gamma);
    cMc = empirical_quantile(cap, eps0);
    fprintf(fid, '%.1f,%.8g,%.12f,%d,%.12f,%.12f,%.12f,%.12f,%.12f,%.12f,%.12f\n', ...
        sigDb, eps0, gamma0Db, nMcCap, cMc, cExact, cLb, cUb, cMc - cExact, cExact - cLb, cUb - cExact);
    outSigma(k) = sigDb;
    outExact(k) = cExact;
    outMc(k) = cMc;
    outLb(k) = cLb;
    outUb(k) = cUb;
end
fclose(fid);
fprintf('Wrote %s\n', outagePath);

% Cross-check against the existing Python reference values copied into the
% temporary run tree, if available.
validationPath = fullfile(outDir, 'matlab_python_validation.csv');
fid = fopen(validationPath, 'w');
fprintf(fid, 'metric,case_name,matlab_value,python_value,signed_error,absolute_error,unit\n');

pyVoicePath = fullfile(rootDir, 'outputs', 'geo_satphone', 'voice_availability.csv');
if exist(pyVoicePath, 'file')
    txt = fileread(pyVoicePath);
    for i = 1:numel(scenarioKey)
        pyVal = find_python_voice_availability(txt, step1Key{i}, 2400.0);
        if ~isnan(pyVal)
            err = mainAvail(i) - pyVal;
            fprintf(fid, 'voice_availability,%s,%.12f,%.12f,%.12f,%.12f,probability\n', ...
                scenarioKey{i}, mainAvail(i), pyVal, err, abs(err));
        end
    end
end

pyOutPath = fullfile(rootDir, 'outputs', 'outage_capacity', 'sigma_scan.csv');
if exist(pyOutPath, 'file')
    txt = fileread(pyOutPath);
    for k = 1:numel(outSigma)
        pyVal = find_python_outage_exact(txt, outSigma(k));
        if ~isnan(pyVal)
            err = outExact(k) - pyVal;
            fprintf(fid, 'outage_capacity_exact,sigma_%.1f_db,%.12f,%.12f,%.12f,%.12f,bit/s/Hz\n', ...
                outSigma(k), outExact(k), pyVal, err, abs(err));
        end
    end
end
fclose(fid);
fprintf('Wrote %s\n', validationPath);

summaryPath = fullfile(outDir, 'matlab_step1_validation_summary.md');
fid = fopen(summaryPath, 'w');
fprintf(fid, '# Step 1 MATLAB Core Validation Summary\n\n');
fprintf(fid, '- MATLAB mode: R2026a `-nojvm -batch`\n');
fprintf(fid, '- Voice Monte Carlo samples: %d\n', nMcVoice);
fprintf(fid, '- Outage-capacity Monte Carlo samples: %d\n', nMcCap);
fprintf(fid, '- Simulink status: skipped in this run because R2026a JVM-backed services crash on this workstation.\n\n');
fprintf(fid, '## 2.4 kbps Voice Availability\n\n');
fprintf(fid, '| Scenario | Availability | P10 Eb/N0 (dB) | Median Eb/N0 (dB) |\n');
fprintf(fid, '|---|---:|---:|---:|\n');
for i = 1:numel(scenarioKey)
    fprintf(fid, '| %s | %.5f | %.3f | %.3f |\n', label{i}, mainAvail(i), mainP10(i), mainMedian(i));
end
idx6 = find(abs(outSigma - 6.0) < 1e-9, 1);
fprintf(fid, '\n## Reference Outage Capacity\n\n');
fprintf(fid, 'At gamma0 = %.4f dB, sigma = 6 dB, epsilon = %.1e:\n\n', gamma0Db, eps0);
fprintf(fid, '- MATLAB MC: %.6f bit/s/Hz\n', outMc(idx6));
fprintf(fid, '- Exact lognormal: %.6f bit/s/Hz\n', outExact(idx6));
fprintf(fid, '- Chernoff lower bound: %.6f bit/s/Hz\n', outLb(idx6));
fclose(fid);
fprintf('Wrote %s\n', summaryPath);

fprintf('NOJVM_CORE_DONE\n');

function g = orientation_gain_db(thetaDeg)
gPeak = 2.0;
gMin = -10.0;
exponent = 1.7;
theta = min(abs(thetaDeg), 85.0);
drop = 10.0 .* exponent .* log10(max(cosd(theta), 1e-3));
g = max(gMin, gPeak + drop);
end

function y = fspl_db(distanceKm, freqMHz)
y = 32.44 + 20.0 .* log10(distanceKm) + 20.0 .* log10(freqMHz);
end

function y = noise_dbm(bwHz, nfDb)
y = -228.6 + 10.0 .* log10(290.0) + 10.0 .* log10(bwHz) + nfDb + 30.0;
end

function q = empirical_quantile(x, p)
x = sort(x(:));
n = numel(x);
idx = min(max(ceil(p .* n), 1), n);
q = x(idx);
end

function val = find_python_voice_availability(txt, scenarioName, rate)
val = NaN;
lines = regexp(txt, '\r?\n', 'split');
for ii = 2:numel(lines)
    if isempty(lines{ii}), continue; end
    parts = regexp(lines{ii}, ',', 'split');
    if numel(parts) < 6, continue; end
    if strcmp(parts{1}, scenarioName) && abs(str2double(parts{4}) - rate) < 1e-9
        val = str2double(parts{6});
        return;
    end
end
end

function val = find_python_outage_exact(txt, sigmaDb)
val = NaN;
lines = regexp(txt, '\r?\n', 'split');
header = regexp(lines{1}, ',', 'split');
sigmaIdx = find(strcmp(header, 'sigma_db'), 1);
exactIdx = find(strcmp(header, 'c_exact'), 1);
if isempty(sigmaIdx) || isempty(exactIdx), return; end
for ii = 2:numel(lines)
    if isempty(lines{ii}), continue; end
    parts = regexp(lines{ii}, ',', 'split');
    if numel(parts) < max(sigmaIdx, exactIdx), continue; end
    if abs(str2double(parts{sigmaIdx}) - sigmaDb) < 1e-9
        val = str2double(parts{exactIdx});
        return;
    end
end
end
