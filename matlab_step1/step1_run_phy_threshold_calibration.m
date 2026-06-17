function rows = step1_run_phy_threshold_calibration(cfg)
%STEP1_RUN_PHY_THRESHOLD_CALIBRATION Calibrate voice Eb/N0 thresholds.
%
% This simulation uses Communications Toolbox System objects when available:
% convolutional encoder, QPSK modulator/demodulator, AWGN channel, and Viterbi
% decoder. It estimates BER/FER versus Eb/N0 and interpolates the Eb/N0 needed
% to meet a target frame-error-rate.

if nargin < 1 || isempty(cfg)
    cfg = step1_params();
end

if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end

requiredFunctions = {'convenc', 'vitdec', 'pskmod', 'pskdemod'};
for i = 1:numel(requiredFunctions)
    if exist(requiredFunctions{i}, 'file') ~= 2
        error('Required Communications Toolbox function is not available: %s', requiredFunctions{i});
    end
end
if exist('comm.AWGNChannel', 'class') ~= 8
    error('Required Communications Toolbox object is not available: comm.AWGNChannel');
end

fprintf('Running PHY threshold calibration with Communications Toolbox...\n');

rng(cfg.seed + 3100, 'twister');

rates = cfg.voice.rateBps(:);
legacyThresholds = cfg.voice.thresholdEbN0Db(:);
ebn0AxisDb = (-6.0:0.5:10.0).';
targetFer = 1e-2;
frameDurationMs = 40.0;
maxFrames = 2000;
minFrameErrors = 40;
trellis = poly2trellis(7, [171 133]);
tracebackDepth = 35;
modOrder = 4;
bitsPerSymbol = log2(modOrder);
codingRate = 1 / 2;
tailBits = log2(trellis.numStates);

berFerRows = table();
thresholdRows = table();

for r = 1:numel(rates)
    rateBps = rates(r);
    infoBitsPerFrame = max(64, round(rateBps * frameDurationMs / 1000.0));
    infoBitsPerFrame = infoBitsPerFrame + mod(infoBitsPerFrame, bitsPerSymbol);

    for e = 1:numel(ebn0AxisDb)
        ebn0Db = ebn0AxisDb(e);
        snrDb = ebn0Db + 10.0 * log10(bitsPerSymbol * codingRate);

        chan = comm.AWGNChannel( ...
            'NoiseMethod', 'Signal to noise ratio (SNR)', ...
            'SNR', snrDb);

        totalBits = 0;
        bitErrors = 0;
        frameErrors = 0;
        frames = 0;

        while frames < maxFrames && (frameErrors < minFrameErrors || frames < 200)
            txBits = randi([0 1], infoBitsPerFrame, 1);
            txTerminated = [txBits; zeros(tailBits, 1)];
            codedBits = convenc(txTerminated, trellis);
            txSymbols = pskmod(codedBits, modOrder, pi / 4, InputType='bit');
            rxSymbols = chan(txSymbols);
            rxCodedBits = pskdemod(rxSymbols, modOrder, pi / 4, OutputType='bit');
            rxBitsRaw = vitdec(rxCodedBits, trellis, tracebackDepth, 'term', 'hard');
            rxBits = rxBitsRaw(1:infoBitsPerFrame);

            err = sum(rxBits ~= txBits);
            bitErrors = bitErrors + err;
            frameErrors = frameErrors + double(err > 0);
            totalBits = totalBits + infoBitsPerFrame;
            frames = frames + 1;
        end

        ber = bitErrors / totalBits;
        fer = frameErrors / frames;
        berFerRows = [berFerRows; table( ...
            rateBps, infoBitsPerFrame, frameDurationMs, ebn0Db, snrDb, ...
            frames, bitErrors, frameErrors, ber, fer, targetFer, ...
            'VariableNames', {'voice_rate_bps', 'info_bits_per_frame', 'frame_duration_ms', ...
            'ebn0_db', 'snr_db', 'frames', 'bit_errors', 'frame_errors', ...
            'ber', 'fer', 'target_fer'})]; %#ok<AGROW>
    end

    idx = abs(berFerRows.voice_rate_bps - rateBps) < 1e-9;
    thresholdDb = step1_interpolate_fer_threshold(berFerRows.ebn0_db(idx), berFerRows.fer(idx), targetFer);
    thresholdRows = [thresholdRows; table( ...
        rateBps, targetFer, thresholdDb, legacyThresholds(r), thresholdDb - legacyThresholds(r), ...
        infoBitsPerFrame, frameDurationMs, maxFrames, ...
        'VariableNames', {'voice_rate_bps', 'target_fer', 'phy_threshold_ebn0_db', ...
        'legacy_threshold_ebn0_db', 'phy_minus_legacy_db', ...
        'info_bits_per_frame', 'frame_duration_ms', 'max_frames_per_point'})]; %#ok<AGROW>
end

writetable(berFerRows, fullfile(cfg.outputDir, 'ber_fer_vs_ebn0.csv'));
writetable(thresholdRows, fullfile(cfg.outputDir, 'voice_threshold_from_phy.csv'));

rows = thresholdRows;
fprintf('Wrote %s\n', fullfile(cfg.outputDir, 'ber_fer_vs_ebn0.csv'));
fprintf('Wrote %s\n', fullfile(cfg.outputDir, 'voice_threshold_from_phy.csv'));
end

function thresholdDb = step1_interpolate_fer_threshold(ebn0Db, fer, targetFer)
ebn0Db = double(ebn0Db(:));
fer = double(fer(:));
[ebn0Db, order] = sort(ebn0Db);
fer = fer(order);

ferMono = cummin(fer);

if all(ferMono > targetFer)
    thresholdDb = max(ebn0Db);
    return;
end
if all(ferMono <= targetFer)
    thresholdDb = min(ebn0Db);
    return;
end

crossIdx = find(ferMono <= targetFer, 1, 'first');
if isempty(crossIdx) || crossIdx == 1
    thresholdDb = ebn0Db(max(1, crossIdx));
    return;
end

x0 = ebn0Db(crossIdx - 1);
x1 = ebn0Db(crossIdx);
y0 = log10(max(ferMono(crossIdx - 1), 1e-8));
y1 = log10(max(ferMono(crossIdx), 1e-8));
yt = log10(targetFer);
if abs(y1 - y0) < 1e-12
    thresholdDb = x1;
else
    thresholdDb = x0 + (yt - y0) * (x1 - x0) / (y1 - y0);
end
end
