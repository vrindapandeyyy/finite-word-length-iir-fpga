% sweep_wordlength.m
% Direct form vs cascade of biquads, with the INTEGER bits accounted for.
%   direct form : Q3.(B-3)  (coefficients reach 2.37, so 3 bits incl. sign are needed)
%   cascade     : Q2.(B-2)  (section coefficients stay below 2)
% SQNR is averaged over 20 noise realisations. Coefficient quantization only.
clear; clc;
order = 4;  fs = 10000;  fc = 1000;  T = 1/fs;
omega_a = (2/T) * tan(2*pi*fc*T/2);
k = 0:(order-1);
s_poles = omega_a * exp(1j*(pi*(2*k+1)/(2*order) + pi/2));
z_poles = (1 + s_poles*(T/2)) ./ (1 - s_poles*(T/2));
a_ideal = real(poly(z_poles));
b_poly  = real(poly(-ones(order,1)));
k_gain  = sum(a_ideal) / sum(b_poly);
b_ideal = b_poly * k_gain;

p = sort(z_poles(imag(z_poles) > 0), 'descend');
g = sqrt(k_gain);
sec_b = [g, 2*g, g];
sec_a = [[1, -2*real(p(1)), abs(p(1))^2]; [1, -2*real(p(2)), abs(p(2))^2]];

t = 0:1/fs:0.05;
q = @(v, f) round(v * 2^f) / 2^f;
bits = [4 5 6 7 8 10 12 14 16];
nrun = 20;

fprintf('Bits | Direct: max|p|   SQNR(dB) | Cascade: max|p|   SQNR(dB)\n');
for ib = 1:numel(bits)
    B  = bits(ib);
    bd = q(b_ideal, B-3);   ad = q(a_ideal, B-3);
    pd = max(abs(roots(ad)));

    bc  = q(sec_b, B-2);
    ac1 = q(sec_a(1,:), B-2);   ac2 = q(sec_a(2,:), B-2);
    pc  = max([max(abs(roots(ac1))), max(abs(roots(ac2)))]);

    sd = zeros(1, nrun);  sc = zeros(1, nrun);
    for r = 1:nrun
        rng(r);
        x  = sin(2*pi*400*t) + 0.5*sin(2*pi*3000*t) + 0.2*randn(size(t));
        yi = filter(b_ideal, a_ideal, x);
        yd = filter(bd, ad, x);
        yc = filter(bc, ac2, filter(bc, ac1, x));
        sd(r) = 10*log10(sum(yi.^2) / sum((yi - yd).^2));
        sc(r) = 10*log10(sum(yi.^2) / sum((yi - yc).^2));
    end

    if pd >= 1, sd_txt = 'unstable'; else, sd_txt = sprintf('%.2f', mean(sd)); end
    if pc >= 1, sc_txt = 'unstable'; else, sc_txt = sprintf('%.2f', mean(sc)); end
    fprintf('%4d |   %.4f   %9s |   %.4f   %9s\n', B, pd, sd_txt, pc, sc_txt);
end
