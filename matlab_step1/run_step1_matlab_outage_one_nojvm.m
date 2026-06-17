%RUN_STEP1_MATLAB_OUTAGE_ONE_NOJVM Append one outage-capacity row.
%
% Set environment variable SIGMA_DB before calling this script.

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
outDir = fullfile(rootDir, 'outputs', 'matlab_step1');
if ~exist(outDir, 'dir'), mkdir(outDir); end

sigmaDb = str2double(getenv('SIGMA_DB'));
if isnan(sigmaDb)
    error('SIGMA_DB environment variable is required.');
end

nMcCap = 1000000;
seed = 20260608;
eps0 = 1e-2;
gamma0Db = 11.706656016154298;
gamma0 = 10.0 .^ (gamma0Db ./ 10.0);

outagePath = fullfile(outDir, 'outage_capacity_matlab.csv');
if ~exist(outagePath, 'file') || str2double(getenv('OUTAGE_RESET')) == 1
    fid = fopen(outagePath, 'w');
    fprintf(fid, 'sigma_db,epsilon,gamma0_db,samples,c_mc,c_exact,c_chernoff_lb,c_no_shadow_ub,mc_minus_exact,exact_minus_chernoff_lb,ub_minus_exact\n');
    fclose(fid);
end

rng(seed + 77 + round(1000 * sigmaDb), 'twister');
sigNat = log(10.0) / 10.0 * sigmaDb;
zEps = sqrt(2.0) * erfinv(2.0 * eps0 - 1.0);
cExact = log2(1.0 + gamma0 * exp(sigNat * zEps));
cLb = log2(1.0 + gamma0 * exp(-sigNat * sqrt(2.0 * log(1.0 / eps0))));
cUb = log2(1.0 + gamma0);
xDb = sigmaDb .* randn(nMcCap, 1);
gamma = gamma0 .* 10.0 .^ (-xDb ./ 10.0);
cap = log2(1.0 + gamma);
sortedCap = sort(cap(:));
cMc = sortedCap(max(1, ceil(eps0 * numel(sortedCap))));

fid = fopen(outagePath, 'a');
fprintf(fid, '%.1f,%.8g,%.12f,%d,%.12f,%.12f,%.12f,%.12f,%.12f,%.12f,%.12f\n', ...
    sigmaDb, eps0, gamma0Db, nMcCap, cMc, cExact, cLb, cUb, cMc - cExact, cExact - cLb, cUb - cExact);
fclose(fid);

fprintf('OUTAGE_ONE_DONE sigma=%.1f c_exact=%.12f c_mc=%.12f\n', sigmaDb, cExact, cMc);
