function compareRows = step1_compare_with_python(cfg, voiceRows, outageRows, simRows)
%STEP1_COMPARE_WITH_PYTHON Compare MATLAB/Simulink outputs with Python CSVs.

compareRows = table();

pyVoicePath = fullfile(cfg.rootDir, "outputs", "geo_satphone", "voice_availability.csv");
if exist(pyVoicePath, "file")
    pyVoice = readtable(pyVoicePath);
    mainMatlab = voiceRows(voiceRows.voice_rate_bps == cfg.voice.mainRateBps, :);
    for i = 1:height(mainMatlab)
        pyIdx = strcmp(string(pyVoice.scenario), string(mainMatlab.step1_key(i))) ...
            & abs(pyVoice.voice_rate_bps - cfg.voice.mainRateBps) < 1e-9;
        if any(pyIdx)
            pyAvail = pyVoice.availability(find(pyIdx, 1));
            row = table( ...
                "voice_availability", mainMatlab.scenario_key(i), ...
                mainMatlab.availability(i), pyAvail, ...
                mainMatlab.availability(i) - pyAvail, ...
                abs(mainMatlab.availability(i) - pyAvail), ...
                "probability", ...
                'VariableNames', {'metric', 'case_name', 'matlab_value', 'python_value', ...
                'signed_error', 'absolute_error', 'unit'});
            compareRows = [compareRows; row]; %#ok<AGROW>
        end
    end
end

pyOutagePath = fullfile(cfg.rootDir, "outputs", "outage_capacity", "sigma_scan.csv");
if exist(pyOutagePath, "file")
    pyOutage = readtable(pyOutagePath);
    for k = 1:height(outageRows)
        pyIdx = abs(pyOutage.sigma_db - outageRows.sigma_db(k)) < 1e-9;
        if any(pyIdx)
            pyExact = pyOutage.c_exact(find(pyIdx, 1));
            row = table( ...
                "outage_capacity_exact", "sigma_" + string(outageRows.sigma_db(k)) + "_db", ...
                outageRows.c_exact(k), pyExact, outageRows.c_exact(k) - pyExact, ...
                abs(outageRows.c_exact(k) - pyExact), "bit/s/Hz", ...
                'VariableNames', {'metric', 'case_name', 'matlab_value', 'python_value', ...
                'signed_error', 'absolute_error', 'unit'});
            compareRows = [compareRows; row]; %#ok<AGROW>
        end
    end
end

if ~isempty(simRows)
    mainMatlab = voiceRows(voiceRows.voice_rate_bps == cfg.voice.mainRateBps, :);
    for i = 1:height(mainMatlab)
        simIdx = strcmp(string(simRows.scenario_key), string(mainMatlab.scenario_key(i)));
        if any(simIdx)
            simAvail = simRows.availability(find(simIdx, 1));
            row = table( ...
                "simulink_vs_matlab_voice", mainMatlab.scenario_key(i), ...
                simAvail, mainMatlab.availability(i), simAvail - mainMatlab.availability(i), ...
                abs(simAvail - mainMatlab.availability(i)), "probability", ...
                'VariableNames', {'metric', 'case_name', 'matlab_value', 'python_value', ...
                'signed_error', 'absolute_error', 'unit'});
            compareRows = [compareRows; row]; %#ok<AGROW>
        end
    end
end

outCsv = fullfile(cfg.outputDir, "matlab_python_validation.csv");
if ~isempty(compareRows)
    writetable(compareRows, outCsv);
    fprintf("Wrote %s\n", outCsv);
else
    fprintf("[warn] No Python outputs were found for comparison.\n");
end
end
