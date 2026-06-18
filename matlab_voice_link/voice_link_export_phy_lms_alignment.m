function alignRows = voice_link_export_phy_lms_alignment(cfg)
%VOICE_LINK_EXPORT_PHY_LMS_ALIGNMENT Export three-way validation tables.

if nargin < 1 || isempty(cfg)
    cfg = voice_link_params();
end

fprintf('Exporting PHY/LMS/Python-MATLAB-Simulink alignment report...\n');

matVoicePath = fullfile(cfg.outputDir, 'voice_availability_matlab.csv');
simVoicePath = fullfile(cfg.outputDir, 'simulink_voice_availability.csv');
pyVoicePath = fullfile(cfg.rootDir, 'outputs', 'geo_satphone', 'voice_availability.csv');
phyThresholdPath = fullfile(cfg.outputDir, 'voice_threshold_from_phy.csv');
lmsPath = fullfile(cfg.outputDir, 'lms_channel_availability.csv');
lmsSimPath = fullfile(cfg.outputDir, 'lms_simulink_channel_availability.csv');

matVoice = readtable(matVoicePath);
simVoice = readtable(simVoicePath);
pyVoice = readtable(pyVoicePath);
phyRows = readtable(phyThresholdPath);
lmsRows = readtable(lmsPath);
hasLmsSim = exist(lmsSimPath, 'file') == 2;
if hasLmsSim
    lmsSimRows = readtable(lmsSimPath);
else
    lmsSimRows = table();
end

matMain = matVoice(abs(matVoice.voice_rate_bps - cfg.voice.mainRateBps) < 1e-9, :);

alignRows = table();
for i = 1:height(matMain)
    scenarioKey = string(matMain.scenario_key(i));
    scenarioModelKey = string(matMain.scenario_model_key(i));
    pyIdx = strcmp(string(pyVoice.scenario), scenarioModelKey) & abs(pyVoice.voice_rate_bps - cfg.voice.mainRateBps) < 1e-9;
    simIdx = strcmp(string(simVoice.scenario_key), scenarioKey);
    lmsIdx = strcmp(string(lmsRows.scenario_key), scenarioKey);
    lmsSimIdx = false;
    if hasLmsSim
        lmsSimIdx = strcmp(string(lmsSimRows.scenario_key), scenarioKey);
    end

    if any(pyIdx) && any(simIdx) && any(lmsIdx)
        pyAvail = pyVoice.availability(find(pyIdx, 1));
        matAvail = matMain.availability(i);
        simAvail = simVoice.availability(find(simIdx, 1));
        lmsAvail = lmsRows.availability(find(lmsIdx, 1));
        if hasLmsSim && any(lmsSimIdx)
            lmsSimAvail = lmsSimRows.availability(find(lmsSimIdx, 1));
        else
            lmsSimAvail = NaN;
        end
        alignRows = [alignRows; table( ...
            scenarioKey, scenarioModelKey, string(matMain.label(i)), ...
            cfg.voice.mainRateBps, pyAvail, matAvail, simAvail, lmsAvail, lmsSimAvail, ...
            simAvail - matAvail, matAvail - pyAvail, lmsAvail - matAvail, lmsSimAvail - lmsAvail, ...
            'VariableNames', {'scenario_key', 'scenario_model_key', 'label', 'voice_rate_bps', ...
            'python_availability', 'matlab_availability', 'simulink_availability', ...
            'lms_matlab_availability', 'lms_simulink_availability', ...
            'simulink_minus_matlab', 'matlab_minus_python', ...
            'lms_matlab_minus_matlab', 'lms_simulink_minus_lms_matlab'})]; %#ok<AGROW>
    end
end

writetable(alignRows, fullfile(cfg.outputDir, 'three_way_alignment.csv'));

fid = fopen(fullfile(cfg.outputDir, 'phy_lms_alignment_summary.md'), 'w');
fprintf(fid, '# voice-link PHY/LMS MATLAB-Simulink Alignment Summary\n\n');
fprintf(fid, '## PHY Threshold Calibration\n\n');
fprintf(fid, '| Voice rate | Target FER | PHY Eb/N0 threshold | Legacy threshold | Delta |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|\n');
for i = 1:height(phyRows)
    fprintf(fid, '| %.1f bps | %.2g | %.3f dB | %.3f dB | %.3f dB |\n', ...
        phyRows.voice_rate_bps(i), phyRows.target_fer(i), ...
        phyRows.phy_threshold_ebn0_db(i), phyRows.legacy_threshold_ebn0_db(i), ...
        phyRows.phy_minus_legacy_db(i));
end

fprintf(fid, '\n## LMS Time-Series Availability\n\n');
fprintf(fid, '| Scenario | Availability | FER | P10 Eb/N0 | Max outage | P95 burst |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|\n');
for i = 1:height(lmsRows)
    fprintf(fid, '| %s | %.5f | %.5f | %.3f dB | %.1f ms | %.1f ms |\n', ...
        char(string(lmsRows.label(i))), lmsRows.availability(i), lmsRows.frame_error_rate(i), ...
        lmsRows.p10_ebn0_db(i), lmsRows.max_outage_ms(i), lmsRows.p95_burst_ms(i));
end

fprintf(fid, '\n## Python/MATLAB/Simulink Alignment\n\n');
fprintf(fid, '| Scenario | Python | MATLAB | Simulink | LMS MATLAB | LMS Simulink | Sim-MATLAB | MATLAB-Python |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(alignRows)
    fprintf(fid, '| %s | %.5f | %.5f | %.5f | %.5f | %.5f | %.3g | %.3g |\n', ...
        char(string(alignRows.label(i))), alignRows.python_availability(i), alignRows.matlab_availability(i), ...
        alignRows.simulink_availability(i), alignRows.lms_matlab_availability(i), ...
        alignRows.lms_simulink_availability(i), ...
        alignRows.simulink_minus_matlab(i), alignRows.matlab_minus_python(i));
end

fprintf(fid, '\n## Files\n\n');
fprintf(fid, '- `ber_fer_vs_ebn0.csv`\n');
fprintf(fid, '- `voice_threshold_from_phy.csv`\n');
fprintf(fid, '- `lms_channel_availability.csv`\n');
fprintf(fid, '- `lms_simulink_channel_availability.csv`\n');
fprintf(fid, '- `lms_frame_timeseries_sample.csv`\n');
fprintf(fid, '- `three_way_alignment.csv`\n');
fprintf(fid, '- `simulink_voice_availability.csv`\n');
fclose(fid);

fprintf('Wrote %s\n', fullfile(cfg.outputDir, 'three_way_alignment.csv'));
fprintf('Wrote %s\n', fullfile(cfg.outputDir, 'phy_lms_alignment_summary.md'));
end
