% Course: BAEVD204 - Signal Processing Lab
% Project: Analysis of Finite Word Length Effects on IIR Filter Stability
% Team: Vrinda Pandey (25BVD0126), Ayush Krishna Balabadra (25BVD0112)

clear all;
close all;
clc;

%% Step 1: Baseline 4th-Order Butterworth Filter Design (Bilinear Transform)
order = 4;                 % 4th order filter
fs = 10000;                % sampling frequency = 10 kHz
fc = 1000;                 % cutoff frequency = 1 kHz

% Pre-warp analog cutoff frequency
T = 1 / fs;
omega_c = 2 * pi * fc;
omega_a = (2 / T) * tan(omega_c * T / 2);

% S-plane Butterworth poles
k = 0:(order - 1);
s_poles = omega_a * exp(1j * (pi * (2*k + 1) / (2 * order) + pi/2));

% Bilinear transformation: s -> z
z_poles = (1 + s_poles * (T / 2)) ./ (1 - s_poles * (T / 2));
z_zeros = -ones(order, 1); % 4 zeros at z = -1

% Calculate ideal polynomial coefficients
a_ideal = real(poly(z_poles));
b_poly  = real(poly(z_zeros));
k_gain  = sum(a_ideal) / sum(b_poly); % normalize DC gain to 1 (0 dB)
b_ideal = b_poly * k_gain;
%% Step 2: Fixed-Point Coefficient Quantization (16-bit and 8-bit)
% 16-bit quantization (Q15: 1 sign bit, 15 fractional bits)
scale_16 = 2^15;
b_16 = round(b_ideal * scale_16) / scale_16;
a_16 = round(a_ideal * scale_16) / scale_16;

% 8-bit quantization (Q7: 1 sign bit, 7 fractional bits)
scale_8 = 2^7;
b_8 = round(b_ideal * scale_8) / scale_8;
a_8 = round(a_ideal * scale_8) / scale_8;

%% Step 3: Pole-Zero Distribution and Stability Check
p_ideal = roots(a_ideal);
p_16    = roots(a_16);
p_8     = roots(a_8);

z_ideal = roots(b_ideal);
z_16    = roots(b_16);
z_8     = roots(b_8);

r_ideal = max(abs(p_ideal));
r_16    = max(abs(p_16));
r_8     = max(abs(p_8));

fprintf('STABILITY ANALYSIS \n');
fprintf('Ideal Filter Max Pole Radius : %.4f\n', r_ideal);
fprintf('16-Bit Filter Max Pole Radius: %.4f\n', r_16);
fprintf('8-Bit Filter Max Pole Radius : %.4f\n', r_8);

if r_8 >= 1.0
    fprintf('Warning: 8-bit quantized filter is UNSTABLE (|p| >= 1)!\n\n');
else
    fprintf('8-bit quantized filter is stable.\n\n');
end

% Plotting Pole-Zero plots on Z-plane (Unit Circle)
theta = linspace(0, 2*pi, 300);
uc_x = cos(theta);
uc_y = sin(theta);

figure(1);
subplot(1, 3, 1);
plot(uc_x, uc_y, 'k--'); hold on;
plot(real(p_ideal), imag(p_ideal), 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
plot(real(z_ideal), imag(z_ideal), 'bo', 'MarkerSize', 8, 'LineWidth', 1.5);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('Real Part'); ylabel('Imaginary Part');
title(['Ideal (64-bit), max|p| = ', num2str(round(r_ideal, 4))]);

subplot(1, 3, 2);
plot(uc_x, uc_y, 'k--'); hold on;
plot(real(p_16), imag(p_16), 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
plot(real(z_16), imag(z_16), 'bo', 'MarkerSize', 8, 'LineWidth', 1.5);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('Real Part'); ylabel('Imaginary Part');
title(['16-bit Quantized, max|p| = ', num2str(round(r_16, 4))]);

subplot(1, 3, 3);
plot(uc_x, uc_y, 'k--'); hold on;
plot(real(p_8), imag(p_8), 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
plot(real(z_8), imag(z_8), 'bo', 'MarkerSize', 8, 'LineWidth', 1.5);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('Real Part'); ylabel('Imaginary Part');
title(['8-bit Quantized, max|p| = ', num2str(round(r_8, 4))]);

%% Step 4: Frequency Response Comparison (DTFT Evaluation)
N_pts = 1024;
f = linspace(0, fs/2, N_pts);
w = 2 * pi * f / fs;

H_ideal = zeros(1, N_pts);
H_16    = zeros(1, N_pts);
H_8     = zeros(1, N_pts);

for idx = 1:N_pts
    z_vec = exp(-1j * w(idx) * (0:order));
    H_ideal(idx) = sum(b_ideal .* z_vec) / sum(a_ideal .* z_vec);
    H_16(idx)    = sum(b_16 .* z_vec) / sum(a_16 .* z_vec);
    H_8(idx)     = sum(b_8 .* z_vec) / sum(a_8 .* z_vec);
end

figure(2);
% Magnitude Response
subplot(2, 1, 1);
plot(f, 20*log10(abs(H_ideal)), 'b', 'LineWidth', 1.5); hold on;
plot(f, 20*log10(abs(H_16)), 'g--', 'LineWidth', 1.5);
plot(f, 20*log10(abs(H_8)), 'r:', 'LineWidth', 1.5);
grid on;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Magnitude Response Comparison');
legend('Ideal 64-bit', '16-bit Fixed', '8-bit Fixed', 'Location', 'southwest');
ylim([-80 10]);

% Phase Response
subplot(2, 1, 2);
plot(f, unwrap(angle(H_ideal))*180/pi, 'b', 'LineWidth', 1.5); hold on;
plot(f, unwrap(angle(H_16))*180/pi, 'g--', 'LineWidth', 1.5);
plot(f, unwrap(angle(H_8))*180/pi, 'r:', 'LineWidth', 1.5);
grid on;
xlabel('Frequency (Hz)');
ylabel('Phase (degrees)');
title('Phase Response Comparison');
legend('Ideal 64-bit', '16-bit Fixed', '8-bit Fixed', 'Location', 'southwest');

%% Step 5: Test Signal Simulation & SQNR Calculation
t = 0:1/fs:0.05; % 50 ms test window

% Test signal: 400 Hz passband tone + 3000 Hz stopband tone + noise
x = sin(2*pi*400*t) + 0.5*sin(2*pi*3000*t) + 0.2*randn(size(t));

% Built-in direct form filtering (standard in base MATLAB)
y_ideal = filter(b_ideal, a_ideal, x);
y_16    = filter(b_16, a_16, x);
y_8     = filter(b_8, a_8, x);

% Calculate SQNR in dB
sqnr_16 = 10 * log10(sum(y_ideal.^2) / sum((y_ideal - y_16).^2));
sqnr_8  = 10 * log10(sum(y_ideal.^2) / sum((y_ideal - y_8).^2));

fprintf('------ SQNR RESULTS ------\n');
fprintf('16-Bit Output SQNR: %.2f dB\n', sqnr_16);
fprintf('8-Bit Output SQNR : %.2f dB\n', sqnr_8);

% Time domain plots
figure(3);
subplot(2, 1, 1);
plot(t*1000, x, 'Color', [0.6 0.6 0.6]); hold on;
plot(t*1000, y_ideal, 'b', 'LineWidth', 1.2);
plot(t*1000, y_16, 'g--', 'LineWidth', 1.2);
plot(t*1000, y_8, 'r:', 'LineWidth', 1.2);
grid on;
xlabel('Time (ms)');
ylabel('Amplitude');
title('Filtered Signal Comparison in Time Domain');
legend('Noisy Input', 'Ideal Filtered', '16-bit Output', '8-bit Output');

subplot(2, 1, 2);
plot(t*1000, y_ideal - y_16, 'g', 'LineWidth', 1.2); hold on;
plot(t*1000, y_ideal - y_8, 'r', 'LineWidth', 1.2);
grid on;
xlabel('Time (ms)');
ylabel('Error');
title('Quantization Error (y_{ideal} - y_{quantized})');
legend('16-bit Error', '8-bit Error');

%% Step 6: Save Results to CSV for Report
coeff_names = {'b0'; 'b1'; 'b2'; 'b3'; 'b4'; 'a0'; 'a1'; 'a2'; 'a3'; 'a4'};
ideal_vals  = [b_ideal(:); a_ideal(:)];
quant16_vals = [b_16(:); a_16(:)];
quant8_vals  = [b_8(:); a_8(:)];

T_coeffs = table(coeff_names, ideal_vals, quant16_vals, quant8_vals, ...
    'VariableNames', {'Coeff', 'Ideal_64bit', 'Quant_16bit', 'Quant_8bit'});

disp(' ');
disp(T_coeffs);
writetable(T_coeffs, 'filter_coefficients_lab_data.csv');
