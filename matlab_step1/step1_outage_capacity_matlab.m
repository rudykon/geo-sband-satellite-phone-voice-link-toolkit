function rows = step1_outage_capacity_matlab(cfg)
%STEP1_OUTAGE_CAPACITY_MATLAB Exact and Monte Carlo outage-capacity check.

fprintf("Running MATLAB outage-capacity validation...\n");

eps0 = cfg.outage.epsilon;
gamma0 = 10.0 .^ (cfg.outage.gamma0Db / 10.0);
sigmaScan = cfg.outage.sigmaScanDb;
nMc = cfg.nMcCapacity;

rows = table();
rng(cfg.seed + 77, "twister");
for k = 1:numel(sigmaScan)
    sigmaDb = sigmaScan(k);
    sigmaNat = log(10.0) / 10.0 * sigmaDb;
    zEps = step1_norminv(eps0);

    cExact = log2(1.0 + gamma0 * exp(sigmaNat * zEps));
    cLb = log2(1.0 + gamma0 * exp(-sigmaNat * sqrt(2.0 * log(1.0 / eps0))));
    cUb = log2(1.0 + gamma0);

    xDb = sigmaDb .* randn(nMc, 1);
    gamma = gamma0 .* 10.0 .^ (-xDb / 10.0);
    cap = log2(1.0 + gamma);
    cMc = step1_empirical_quantile(cap, eps0);

    row = table( ...
        sigmaDb, eps0, cfg.outage.gamma0Db, nMc, cMc, cExact, cLb, cUb, ...
        cMc - cExact, cExact - cLb, cUb - cExact, ...
        'VariableNames', {'sigma_db', 'epsilon', 'gamma0_db', 'samples', ...
        'c_mc', 'c_exact', 'c_chernoff_lb', 'c_no_shadow_ub', ...
        'mc_minus_exact', 'exact_minus_chernoff_lb', 'ub_minus_exact'});
    rows = [rows; row]; %#ok<AGROW>
end

outCsv = fullfile(cfg.outputDir, "outage_capacity_matlab.csv");
writetable(rows, outCsv);

skipFigures = strcmp(getenv('STEP1_SKIP_FIGURES'), '1');
if ~skipFigures
    fig = figure("Visible", "off", "Color", "w");
    plot(rows.sigma_db, rows.c_mc, "o", "LineWidth", 1.2); hold on;
    plot(rows.sigma_db, rows.c_exact, "-", "LineWidth", 1.5);
    plot(rows.sigma_db, rows.c_chernoff_lb, "--", "LineWidth", 1.5);
    plot(rows.sigma_db, rows.c_no_shadow_ub, "-.", "LineWidth", 1.2);
    xlabel("Shadowing standard deviation \sigma_{dB} (dB)");
    ylabel("Outage capacity (bit/s/Hz)");
    title("MATLAB outage-capacity validation");
    legend("Monte Carlo", "Exact lognormal", "Chernoff LB", "No-shadow UB", "Location", "northeast");
    grid on;
    exportgraphics(fig, fullfile(cfg.figureDir, "outage_capacity_matlab.pdf"));
    exportgraphics(fig, fullfile(cfg.figureDir, "outage_capacity_matlab.png"), "Resolution", 220);
    close(fig);
end

fprintf("Wrote %s\n", outCsv);
end
