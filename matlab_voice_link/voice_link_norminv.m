function z = voice_link_norminv(p)
%VOICE_LINK_NORMINV Standard-normal inverse CDF without Statistics Toolbox.
z = sqrt(2.0) .* erfinv(2.0 .* p - 1.0);
end
