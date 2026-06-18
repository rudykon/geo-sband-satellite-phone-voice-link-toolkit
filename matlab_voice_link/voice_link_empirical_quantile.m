function q = voice_link_empirical_quantile(x, p)
%VOICE_LINK_EMPIRICAL_QUANTILE Deterministic empirical quantile helper.
x = sort(x(:));
n = numel(x);
idx = min(max(ceil(p .* n), 1), n);
q = x(idx);
end
