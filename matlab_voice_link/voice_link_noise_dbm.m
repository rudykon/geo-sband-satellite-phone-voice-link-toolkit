function y = voice_link_noise_dbm(bwHz, nfDb)
%VOICE_LINK_NOISE_DBM Thermal noise plus receiver noise figure in dBm.
tempK = 290.0;
y = -228.6 + 10.0 .* log10(tempK) + 10.0 .* log10(bwHz) + nfDb + 30.0;
end
