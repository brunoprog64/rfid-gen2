%RFID Encoding --- Script to encode binary data.
%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

function [y] = rfid_gen2_tag_encode(in_bits, tr_ext, modul_type, samp_rate)

pream_bits_fm0 = [1 1 -1 1 -1 -1 1 -1 -1 -1 1 1];
pream_bits_m2 = [1 -1 1 -1 1 -1 -1 1 -1 1 -1 1 -1 1 1 -1 1 -1 -1 1 -1 1 1 -1];
pream_bits_m2 = [repmat([1 -1 1 -1],1,4) pream_bits_m2]; %pad the 4 0s

pream_bits_m4 = [1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 -1 1 -1 1 1 -1 1 -1 1 -1 1 -1 -1 1 -1 1 1 -1 1 -1 1 -1 1 -1 -1 1 -1 1 -1 1 -1 1 1 -1 1 -1];
pream_bits_m4 = [repmat([1 -1 1 -1 1 -1 1 -1],1,4) pream_bits_m4]; %pad the 4 0s

pream_bits_m8 = [1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 1 -1 1 -1 1 -1 1 -1];
pream_bits_m8 = [repmat([1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1],1,4) pream_bits_m8]; %pad the 4 0s

if (tr_ext == 1)
    pream_fm0_ext = repmat([1 -1],1,12);
    pream_m2_ext = repmat([1 -1 1 -1],1,16);
    pream_m4_ext = repmat([1 -1 1 -1 1 -1 1 -1],1,16);
    pream_m8_ext = repmat([1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1],1,16);
    
    pream_bits_fm0 = [pream_fm0_ext pream_bits_fm0];
    pream_bits_m2 = [pream_m2_ext pream_bits_m2];
    pream_bits_m4 = [pream_m4_ext pream_bits_m4];
    pream_bits_m8 =  [pream_m8_ext pream_bits_m8];
end

if (isempty(in_bits) == 1)
  error('Need bits to encode!!!');
end

fm0_one_bits = [1 1];
fm0_zero_bits = [1 -1];

preamble_mask = [];
preamble_tag = [];
one_fm0 = [];
zero_fm0 = [];

fm0_samp_rate = samp_rate;

%generate 0 and 1 for FM0
for i=1:length(fm0_one_bits)
  one_fm0 = [one_fm0 ones(1,fm0_samp_rate/2)*fm0_one_bits(i)];
  zero_fm0 = [zero_fm0 ones(1,fm0_samp_rate/2)*fm0_zero_bits(i)];
end

div_val = 2;
%generate preambles
if (modul_type == 0)
  div_val = 2;
  preamble_mask = pream_bits_fm0;
elseif (modul_type == 1)
  div_val = 4;
  preamble_mask = pream_bits_m2;
elseif (modul_type == 2)
    div_val = 8;
    preamble_mask = pream_bits_m4;
elseif (modul_type == 3)
    div_val = 16;
    preamble_mask = pream_bits_m8;
end

for i=1:length(preamble_mask)
  preamble_tag = [preamble_tag ones(1,fm0_samp_rate/div_val)*preamble_mask(i)];
end

fm0_bits_mask = zeros(2, fm0_samp_rate);
fm0_bits_mask(1,:) = zero_fm0;
fm0_bits_mask(2,:) = one_fm0;

%first modulate in FM0, and then multiply by carrier if we are using Miller
fm0_output = [];
l_symbol = 1;
last_phase = 1;

fm_mill_bits = ~in_bits;
fm0_miller_out = [];

for i=1:length(in_bits)
  if (l_symbol == 1)
    last_phase = last_phase * -1;
  end
  
  fm0_output = [fm0_output (fm0_bits_mask(in_bits(i)+1,:) * last_phase)];
  fm0_miller_out = [fm0_miller_out (fm0_bits_mask(fm_mill_bits(i)+1,:) * last_phase)];
  l_symbol = in_bits(i);
end

if (modul_type == 0) %if we ask for FM=0, return FM=0.
  y = [preamble_tag fm0_output]; %preamble + RN16
  return
end

%Now handle Miller Encoding - We must generate a carrier and then multiply fm0_output with that.

m2_mask = [1 -1 1 -1];
m4_mask = [1 -1 1 -1 1 -1 1 -1];
m8_mask = [1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1];

miller_mask = [];

miller_carrier = [];
%generate the carrier first
if (modul_type == 1)
  div_val = 4;
  miller_mask = m2_mask;
elseif (modul_type == 2)
  miller_mask = m4_mask;
  div_val = 8;
elseif (modul_type == 3)
  miller_mask = m8_mask;
  div_val = 16;
end

for j=1:length(miller_mask)
  miller_carrier = [miller_carrier miller_mask(j) * ones(1,samp_rate/div_val)];
end

miller_out = [];

for i=1:samp_rate:length(fm0_output)
  fm0_d = fm0_miller_out(i:i+samp_rate-1) * -1;
  miller_out = [miller_out (miller_carrier .* fm0_d)];
end

y = [preamble_tag miller_out];