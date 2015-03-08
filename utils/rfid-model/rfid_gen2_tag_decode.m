%RFID Decoding --- Script to decode binary data.

%IMPORTANT: Please notice that this requires a precise symbol rate. In raw captures this is not possible.
%The Buettner Encoder apply a clock recovery scheme that outputs 2 samples per symbol and then uses the same method used here.
%Currently I cannot replicate that Miller and Mueller method in Matlab / Octave.

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

function [y] = rfid_gen2_tag_decode(rx_signal, modul_type, samp_rate)

%the approach is to decode by correlation
fm0_preamble_bits = [1 1 -1 1 -1 -1 1 -1 -1 -1 1 1];
pream_bits_m2 = [1 -1 1 -1 1 -1 -1 1 -1 1 -1 1 -1 1 1 -1 1 -1 -1 1 -1 1 1 -1];

fm0_bit_mask_bits = [1 -1];
m2_bit_mask_bits = [1 -1 -1 1];

if (length(rx_signal) == 0)
  error('Need data to decode!!!');
end

%TODO: M=2 and M=4
if (modul_type > 1)
  error('Miller M=4 and M=8 not implemented yet!!');
end


preamble_bits = [];
one_bits = [];
div_value = 1;

if (modul_type == 0) %FM0
  preamble_bits = fm0_preamble_bits;
  one_bits = fm0_bit_mask_bits;
  div_value = 2;
elseif (modul_type == 1) %M=2
  preamble_bits = pream_bits_m2;
  one_bits = m2_bit_mask_bits;
  div_value = 4;
end

%generate the preamble bit mask
tag_preamble_mask = [];

for i=1:length(preamble_bits)
  tag_preamble_mask = [tag_preamble_mask ones(1,samp_rate/div_value) * preamble_bits(i)];
end

%generate the one bit mask
tag_one_bits = [];
for i=1:length(one_bits)
  tag_one_bits = [tag_one_bits ones(1,samp_rate/div_value) * one_bits(i)];
end

deco_pos = 0;
lscore = 0;
score = 0;

%1st Correlation is Preamble
for i=1:length(rx_signal)-length(tag_preamble_mask)
  fsync_rx = rx_signal(i:i+length(tag_preamble_mask)-1);
  tmp = sum(fsync_rx .* tag_preamble_mask);
  total_pwr=sum(abs(fsync_rx));
  score= abs(tmp) /total_pwr;
  
  if (score > lscore && score > 0.8)
    deco_pos = (i-1) + length(tag_preamble_mask);
    break
  end
  
  lscore = score;
end

if (deco_pos) == 0
  %no preamble found, no valid signal
  fprintf("[rfid_decoder]: Could not find preamble. (Score: %f) Invalid signal!!\n", score);
  y = [zeros(1,16)];
  return
end

%2nd Correlation is bits decoding
deco_bits = [];

for i=deco_pos:samp_rate:length(rx_signal)

  if (i + samp_rate-1) > length(rx_signal) %-1 because of the 1-index thing.
   break
  end

  rx_deco = rx_signal(i:i+samp_rate-1);
  total_pwr = sum(abs(rx_deco));
  tmp = sum(rx_deco.*tag_one_bits);
  
  score = abs(tmp) / total_pwr;
  
  if (score > 0.6)
    deco_bits = [deco_bits 1];
  else
    deco_bits = [deco_bits 0];
  end
end

y = deco_bits;

end
