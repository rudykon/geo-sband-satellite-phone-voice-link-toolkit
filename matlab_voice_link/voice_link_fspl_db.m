function y = voice_link_fspl_db(distanceKm, freqMHz)
%VOICE_LINK_FSPL_DB Free-space path loss in dB.
y = 32.44 + 20.0 .* log10(distanceKm) + 20.0 .* log10(freqMHz);
end
