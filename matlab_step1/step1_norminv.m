function z = step1_norminv(p)
%STEP1_NORMINV Standard-normal inverse CDF without Statistics Toolbox.
z = sqrt(2.0) .* erfinv(2.0 .* p - 1.0);
end
