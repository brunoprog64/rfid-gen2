clear;
close all;

addpath('fastica-25');

Fs = 2000;
t = 0:1/Fs:1;
t = t(1:end-1);
f = 20;

%generate 3 waves: sinewave, square and sawtooth
y_sw = cos(2*pi*f*t);
y_sq = square(2*pi*f*t);
y_saw = sawtooth(2*pi*f*t);

%m_matrix = [1 2 0.2; 0.5 2 1; 1.5 1 2];
m_matrix = randn(3);

y_rx_sig = [y_sw ; y_sq ; y_saw];
y_rx_sig = awgn(y_rx_sig, 44, 'measured');

y_rx_obs = m_matrix.' * y_rx_sig;
y_rx_ica = fastica(y_rx_obs, 'numOfIC', 3, 'approach', 'symm', 'verbose', 'off');

subplot(3,1,1);
plot(y_rx_ica(1,:));

subplot(3,1,2);
plot(y_rx_ica(2,:));

subplot(3,1,3);
plot(y_rx_ica(3,:));
