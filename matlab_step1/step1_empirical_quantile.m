function q = step1_empirical_quantile(x, p)
%STEP1_EMPIRICAL_QUANTILE Deterministic empirical quantile helper.
x = sort(x(:));
n = numel(x);
idx = min(max(ceil(p .* n), 1), n);
q = x(idx);
end
