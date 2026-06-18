function rows = step1_voice_availability_matlab(cfg, thresholdRows)
%STEP1_VOICE_AVAILABILITY_MATLAB Reproduce Step 1 voice availability.

if nargin < 2
    thresholdRows = table();
end

fprintf("Running MATLAB voice-availability Monte Carlo...\n");

rows = table();
for i = 1:height(cfg.scenarios)
    for j = 1:numel(cfg.voice.rateBps)
        rateBps = cfg.voice.rateBps(j);
        thresholdDb = step1_lookup_voice_threshold(cfg, thresholdRows, rateBps, j);
        metrics = step1_scenario_voice_metrics(cfg, i, rateBps, thresholdDb, cfg.nMcVoice, cfg.seed);
        rows = [rows; struct2table(metrics, 'AsArray', true)]; %#ok<AGROW>
    end
end

outCsv = fullfile(cfg.outputDir, "voice_availability_matlab.csv");
writetable(rows, outCsv);

skipFigures = strcmp(getenv('STEP1_SKIP_FIGURES'), '1');
if ~skipFigures
    mainRows = rows(rows.voice_rate_bps == cfg.voice.mainRateBps, :);
    fig = figure("Visible", "off", "Color", "w");
    bar(categorical(mainRows.label), mainRows.availability);
    ylim([0, 1.05]);
    ylabel("Voice availability");
    title("MATLAB GEO S-band 2.4 kbps voice availability");
    grid on;
    exportgraphics(fig, fullfile(cfg.figureDir, "voice_availability_matlab.pdf"));
    exportgraphics(fig, fullfile(cfg.figureDir, "voice_availability_matlab.png"), "Resolution", 220);
    close(fig);
end

fprintf("Wrote %s\n", outCsv);
end

function thresholdDb = step1_lookup_voice_threshold(cfg, thresholdRows, rateBps, rateIndex)
thresholdDb = cfg.voice.thresholdEbN0Db(rateIndex);
if isempty(thresholdRows)
    return;
end
if any(strcmp(thresholdRows.Properties.VariableNames, 'phy_threshold_ebn0_db'))
    valueName = 'phy_threshold_ebn0_db';
elseif any(strcmp(thresholdRows.Properties.VariableNames, 'threshold_ebn0_db'))
    valueName = 'threshold_ebn0_db';
else
    return;
end
idx = abs(thresholdRows.voice_rate_bps - rateBps) < 1e-9;
if any(idx)
    thresholdDb = thresholdRows.(valueName)(find(idx, 1));
end
end
