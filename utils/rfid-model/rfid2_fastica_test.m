%FastICA test

%IMPORTANT: This is just a model to test the capabilities of ICA when decoding RFID Tags.
%It tries to consider amplitude changes and phase changes. Also noise is modelled, as AWGN.

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

close all;
clear;

no_tags_emul = 2;
rn16_values = zeros(1,no_tags_emul);
modul_type = 1; %Miller M=2
s_rate = 20;
awgn_level = 17;

tmp = rfid_gen2_tag_encode(ones(1,16),modul_type,s_rate);
m_len = length(tmp);

modul_vectors = zeros(length(rn16_values), m_len + 100);

rn16_values = randi(power(2,16)-1, 1, no_tags_emul); %tags generate random number of 16 bits.
%genereate everything
for i=1:length(rn16_values)
  bin_vec = de2bi(rn16_values(i),16); #MSB first.
  tmp = rfid_gen2_tag_encode(bin_vec, modul_type, s_rate);
  tmp = [zeros(1,50) tmp zeros(1,50)];
  tmp = awgn(tmp, awgn_level);
  modul_vectors(i,:) = tmp;
end

%For this case, the multipath and reflection will probably will cause 3 things: 
% -> Phase inversion
% -> Amplitude Shift
% -> Delay or ISI.

%Model a simple delay.
for i=1:no_tags_emul
    tmp = modul_vectors(i,:).';
    tmp = circshift(tmp, randi(50)).';
    modul_vectors(i,:) = tmp;
end

%So define a Mixing Matrix where we specify both the phase and the amplitude shift. For now, we will try random values.
mix_matrix = randn(length(no_tags_emul));
rx_antenna = mix_matrix * modul_vectors;

y_ica = fastica(rx_antenna); %compute the ICA.

%plot everything
v = length(rn16_values);

%figure #the original ones
%for i=1:v
%  subplot(v,1,i);
%  plot(modul_vectors(i,:));
%  title(sprintf('Original RN16: %d', rn16_values(i)));
%end

figure %the mixed ones
for i=1:v
  subplot(v,1,i);
  plot(rx_antenna(i,:));
  title(sprintf('Mixed RN16: No. %d', i));
end

figure %the ICA ones
for i=1:v
  subplot(v,1,i);
  plot(y_ica(i,:));
  title(sprintf('ICA Recovered RN16: No. %d', i));
end

%FastICA does not return the signals in the same order as input.
%%% For validate this model, we decode both the original and the ICA

fprintf('Validating model...\n');

for i=1:no_tags_emul
  fprintf("Tag No. %d\n",i);
  tmp = modul_vectors(i,:);
  tmp_bits = rfid_gen2_tag_decode(tmp, modul_type, s_rate);
  tmp_dec = bi2de(tmp_bits, 'left-msb');
  
  fprintf(' -> Original RN16: %d\n', tmp_dec);
  
  tmp = y_ica(i,:);
  tmp_bits = rfid_gen2_tag_decode(tmp, modul_type, s_rate);
  tmp_dec = bi2de(tmp_bits,'left-msb');
  fprintf(' -> ICA RN16: %d\n', tmp_dec);
  
  fprintf("\n");
end
