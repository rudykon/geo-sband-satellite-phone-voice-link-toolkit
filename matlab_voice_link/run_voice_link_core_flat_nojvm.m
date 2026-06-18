%RUN_VOICE_LINK_MATLAB_CORE_FLAT_NOJVM Flat no-local-function MATLAB validation.
%
% This file intentionally avoids local functions, table, string, graphics, and
% Simulink APIs. It is used when R2026a crashes while parsing richer script
% files in no-JVM batch mode.

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
outDir = fullfile(rootDir, 'outputs', 'matlab_voice_link');
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('FLAT_NOJVM_START\n');
fprintf('Output dir: %s\n', outDir);

seed = 20260608;
nMcVoice = 200000;
nMcCap = 1000000;

scenarioKey = {'open_plain','forest_edge','canyon_valley','moving_trail','tent_shelter'};
scenarioModelKey = {'open','suburban','urban','car','indoor_window'};
label = {'Open plain','Forest edge','Canyon valley','Moving trail','Tent/shelter'};
% Match src/tiantong_sband_link.py, which generates the current voice-link
% voice-availability result table and figure.
elevDeg = 45.0;
pLosShift = [12.0, 18.0, 26.0, 30.0, 38.0];
pLosScale = [6.0, 7.0, 8.0, 8.5, 9.5];
pLosCap = [0.98, 0.92, 0.78, 0.60, 0.38];
pLos = pLosCap ./ (1.0 + exp(-(elevDeg - pLosShift) ./ pLosScale));
sigmaDb = [2.5, 4.0, 7.0, 6.0, 9.0];
thetaMean = [8.0, 13.0, 20.0, 25.0, 30.0];
thetaStd = [5.0, 8.0, 12.0, 14.0, 16.0];
nlosLoss = [8.0, 12.0, 18.0, 20.0, 26.0];

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
gPeak = 2.0;
gMin = -10.0;
postureExp = 1.7;

fspl = 32.44 + 20.0 .* log10(distanceKm) + 20.0 .* log10(freqMHz);
noise = -228.6 + 10.0 .* log10(290.0) + 10.0 .* log10(bwHz) + nfDb + 30.0;

voicePath = fullfile(outDir, 'voice_availability_matlab.csv');
fid = fopen(voicePath, 'w');
fprintf(fid, 'scenario_key,scenario_model_key,label,voice_rate_bps,threshold_ebn0_db,samples,p_los,sigma_db,theta_mean_deg,theta_std_deg,nlos_loss_db,availability,p10_ebn0_db,median_ebn0_db,mean_ebn0_db,std_ebn0_db\n');

mainAvail = zeros(1, 5);
mainP10 = zeros(1, 5);
mainMedian = zeros(1, 5);

for i = 1:5
    for j = 1:3
        rng(seed + 1009 * i + round(rateBps(j)), 'twister');
        theta = thetaMean(i) + thetaStd(i) .* randn(nMcVoice, 1);
        theta = min(max(theta, 0.0), 80.0);
        thetaClip = min(abs(theta), 85.0);
        gainDrop = 10.0 .* postureExp .* log10(max(cosd(thetaClip), 1e-3));
        gt = max(gMin, gPeak + gainDrop);
        snrDet = ptDbm + gt + satGrDbi - fspl - polLossDb - extraLossDb - noise;
        los = rand(nMcVoice, 1) < pLos(i);
        shadow = sigmaDb(i) .* randn(nMcVoice, 1);
        snr = snrDet - shadow - double(~los) .* nlosLoss(i);
        ebn0 = snr + 10.0 * log10(bwHz / rateBps(j));
        availability = mean(ebn0 >= thresholdDb(j));
        sortedEb = sort(ebn0(:));
        p10 = sortedEb(max(1, ceil(0.10 * numel(sortedEb))));
        med = sortedEb(max(1, ceil(0.50 * numel(sortedEb))));
        mu = mean(ebn0);
        sd = std(ebn0);
        fprintf(fid, '%s,%s,%s,%.1f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.10f,%.10f,%.10f,%.10f,%.10f\n', ...
            scenarioKey{i}, scenarioModelKey{i}, label{i}, rateBps(j), thresholdDb(j), nMcVoice, ...
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
    sortedCap = sort(cap(:));
    cMc = sortedCap(max(1, ceil(eps0 * numel(sortedCap))));
    fprintf(fid, '%.1f,%.8g,%.12f,%d,%.12f,%.12f,%.12f,%.12f,%.12f,%.12f,%.12f\n', ...
        sigDb, eps0, gamma0Db, nMcCap, cMc, cExact, cLb, cUb, cMc - cExact, cExact - cLb, cUb - cExact);
    outExact(k) = cExact;
    outMc(k) = cMc;
    outLb(k) = cLb;
    outUb(k) = cUb;
end
fclose(fid);
fprintf('Wrote %s\n', outagePath);

validationPath = fullfile(outDir, 'matlab_python_validation.csv');
fid = fopen(validationPath, 'w');
fprintf(fid, 'metric,case_name,matlab_value,python_value,signed_error,absolute_error,unit\n');
pyVoice = [1.0, 0.99949, 0.91431, 0.798785, 0.46734];
for i = 1:5
    err = mainAvail(i) - pyVoice(i);
    fprintf(fid, 'voice_availability,%s,%.12f,%.12f,%.12f,%.12f,probability\n', ...
        scenarioKey{i}, mainAvail(i), pyVoice(i), err, abs(err));
end
pyExact = [2.6027733503284556, 1.9891509115645676, 1.45328414361706, 1.0124970475899504, 0.6739777505770901, 0.43137209727629944, 0.26781126642821723, 0.1627072952880448, 0.09744135955937293, 0.05782620565258833, 0.034125278235743614];
for k = 1:numel(sigmaScan)
    err = outExact(k) - pyExact(k);
    fprintf(fid, 'outage_capacity_exact,sigma_%.1f_db,%.12f,%.12f,%.12f,%.12f,bit/s/Hz\n', ...
        sigmaScan(k), outExact(k), pyExact(k), err, abs(err));
end
fclose(fid);
fprintf('Wrote %s\n', validationPath);

summaryPath = fullfile(outDir, 'matlab_voice_link_validation_summary.md');
fid = fopen(summaryPath, 'w');
fprintf(fid, '# voice-link MATLAB Core Validation Summary\n\n');
fprintf(fid, '- MATLAB mode: R2026a `-nojvm -batch`, flat script\n');
fprintf(fid, '- Voice Monte Carlo samples: %d\n', nMcVoice);
fprintf(fid, '- Outage-capacity Monte Carlo samples: %d\n', nMcCap);
fprintf(fid, '- Simulink status: not executed in this run because R2026a JVM-backed services crash on this workstation.\n\n');
fprintf(fid, '## 2.4 kbps Voice Availability\n\n');
fprintf(fid, '| Scenario | Availability | P10 Eb/N0 (dB) | Median Eb/N0 (dB) |\n');
fprintf(fid, '|---|---:|---:|---:|\n');
for i = 1:5
    fprintf(fid, '| %s | %.5f | %.3f | %.3f |\n', label{i}, mainAvail(i), mainP10(i), mainMedian(i));
end
idx6 = find(abs(sigmaScan - 6.0) < 1e-9, 1);
fprintf(fid, '\n## Reference Outage Capacity\n\n');
fprintf(fid, 'At gamma0 = %.4f dB, sigma = 6 dB, epsilon = %.1e:\n\n', gamma0Db, eps0);
fprintf(fid, '- MATLAB MC: %.6f bit/s/Hz\n', outMc(idx6));
fprintf(fid, '- Exact lognormal: %.6f bit/s/Hz\n', outExact(idx6));
fprintf(fid, '- Chernoff lower bound: %.6f bit/s/Hz\n', outLb(idx6));
fclose(fid);
fprintf('Wrote %s\n', summaryPath);
fprintf('FLAT_NOJVM_DONE\n');
