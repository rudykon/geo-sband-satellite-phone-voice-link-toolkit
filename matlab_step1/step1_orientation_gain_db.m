function g = step1_orientation_gain_db(thetaDeg, cfg)
%STEP1_ORIENTATION_GAIN_DB Clipped-cosine posture-dependent antenna proxy.
theta = min(abs(thetaDeg), 85.0);
drop = 10.0 .* cfg.link.postureExponent .* log10(max(cosd(theta), 1e-3));
g = max(cfg.link.gMinDbi, cfg.link.gPeakDbi + drop);
end
