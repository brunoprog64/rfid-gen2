%RFID Decoding --- Script to decode binary data.

%IMPORTANT: Please notice that this requires a precise symbol rate. In raw captures this is not possible.
%The Buettner Encoder apply a clock recovery scheme that outputs 2 samples per symbol and then uses the same method used here.
%Currently I cannot replicate that Miller and Mueller method in Matlab / Octave.

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

function [y, pream_pos, sym_pos] = rfid_gen2_tag_decode(rx_signal, modul_type, samp_rate, no_bits_deco)

if (nargin < 4)
    no_bits_deco = 17;
end

%the approach is to decode by correlation
fm0_preamble_bits = [1 1 -1 1 -1 -1 1 -1 -1 -1 1 1];
pream_bits_m2 = [1 -1 1 -1 1 -1 -1 1 -1 1 -1 1 -1 1 1 -1 1 -1 -1 1 -1 1 1 -1];

fm0_zero_mask_bits = [1 1];
m2_zero_mask_bits = [1 -1 1 -1];

fm0_bit_mask_bits = [1 -1];
m2_bit_mask_bits = [1 -1 -1 1];

if (length(rx_signal) == 0)
  error('Need data to decode!!!');
end

%TODO: M=2 and M=4
if (modul_type > 1)
  error('Miller M=4 and M=8 not implemented yet!!');
end

%check if the signal is valid
if ~(min(rx_signal) < 0 && max(rx_signal) > 0)
    error('Data do not seem to be valid. BPSK type data is expected.');
end

preamble_bits = [];
one_bits = [];
zero_bits = [];
div_value = 1;

if (modul_type == 0) %FM0
  preamble_bits = fm0_preamble_bits;
  one_bits = fm0_bit_mask_bits;
  zero_bits = fm0_zero_mask_bits;
  div_value = 2;
elseif (modul_type == 1) %M=2
  preamble_bits = pream_bits_m2;
  one_bits = m2_bit_mask_bits;
  zero_bits = m2_zero_mask_bits;
  div_value = 4;
end

%generate the preamble bit mask
tag_preamble_mask = [];

for i=1:length(preamble_bits)
  tag_preamble_mask = [tag_preamble_mask ones(1,samp_rate/div_value) * preamble_bits(i)];
end

%generate the one bit mask
tag_one_bits = [];
tag_zero_bits = [];

for i=1:length(one_bits)
  tag_one_bits = [tag_one_bits ones(1,samp_rate/div_value) * one_bits(i)];
  tag_zero_bits = [tag_zero_bits ones(1,samp_rate/div_value) * zero_bits(i)];
end

deco_pos = 0;
lscore = 0;
score = 0;
pream_pos = 0;
sym_pos = [];

%1st Correlation is Preamble
for i=1:length(rx_signal)-length(tag_preamble_mask)
  fsync_rx = rx_signal(i:i+length(tag_preamble_mask)-1);
  tmp = sum(fsync_rx .* tag_preamble_mask);
  total_pwr=sum(abs(fsync_rx));
  score= abs(tmp) /total_pwr;
  
  if (score > 0.8)
    deco_pos = (i-1) + length(tag_preamble_mask);
    pream_pos = i;
    fprintf('[rfid_listener]: Tag preamble detected at %d with score %f...\n', i, score);
    break
  end
  
  lscore = score;
end

if (deco_pos) == 0
  %no preamble found, no valid signal
  fprintf('[rfid_decoder]: Could not find preamble. (Score: %f) Invalid signal!!\n', score);
  y = zeros(1,16);
  return
end

%2nd Correlation is bits decoding
deco_bits = [];

for i=deco_pos:samp_rate:length(rx_signal)

  if (i + samp_rate-1) > length(rx_signal) %-1 because of the 1-index thing.
   break
  end
  
  sym_pos = [sym_pos i];
  
  rx_deco = rx_signal(i:i+samp_rate-1);
  total_pwr = sum(abs(rx_deco));
  
  %correlate zero bit
  tmp_zero = sum(rx_deco.*tag_zero_bits);
  score_zero = abs(tmp_zero) / total_pwr;
  %correlate one bit
  tmp_one = sum(rx_deco.*tag_one_bits);
  score_one = abs(tmp_one) / total_pwr;
  
  
  if (score_one > score_zero)
    deco_bits = [deco_bits 1];
  else
    deco_bits = [deco_bits 0];
  end
  
  %fprintf('[rfid_decoder]: Score for 1: %f / Score for 0: %f...\n', score_one, score_zero);
  
  no_bits_deco = no_bits_deco - 1;
  
  if (no_bits_deco == 0)
      sym_pos = [sym_pos i+samp_rate];
      break;
  end
  
end

if (deco_bits(end) ~= 1)
    fprintf('[rfid_decoder]: Unexpected end of the Tag signal!!!\n');
end

y = deco_bits;
