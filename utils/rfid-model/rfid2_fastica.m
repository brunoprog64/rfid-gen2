%FastICA test

%IMPORTANT: This is just a model to test the capabilities of ICA when decoding RFID Tags.
%It tries to consider amplitude changes and phase changes. Also noise is modelled, as AWGN.

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

close all;
clear;

addpath('fastica-25');

%some options
no_tags_emul = 2;
no_antennas = 2;
pream_ex = 1;
modul_type = 0; %Miller M=2
s_rate_cycle = 20;
awgn_level = 12;
t1_value_sampl = 400;

s_rate = (power(2,modul_type)*2)*s_rate_cycle;
t1_value_delays = randi(200, 1, no_tags_emul) + t1_value_sampl;

rn16_values = randi(power(2,16)-1, 1, no_tags_emul); %tags generate random number of 16 bits.
no_samples_tag = 60*s_rate;

modul_vectors = ones(no_tags_emul, no_samples_tag) * -1;
rx_mixed = zeros(no_antennas, no_samples_tag);

fprintf('Delays:\n');
disp(t1_value_delays);

%generate everything
for i=1:no_tags_emul
    rn16_bits = de2bi(rn16_values(i),16, 'left-msb');
    enc_rn16 =  rfid_gen2_tag_encode(rn16_bits, pream_ex, modul_type, s_rate) - 1;
    
    t_bg = t1_value_delays(i);
    t_ed = t_bg + length(enc_rn16) - 1;
    
    modul_vectors(i,t_bg:t_ed) = enc_rn16;
end

%proceed to use the other array for the mixing
for i=1:no_antennas    
    %for a given antenna, generate the amplitude change and phase change
    amp_phase_chg = randi([-1000 1000], 1, no_tags_emul);
    amp_phase_chg = amp_phase_chg / 1000;

    %phase shift
    pha_shift = randi([-2*1000 2*1000], 1, no_tags_emul);
    pha_shift = (pha_shift / 1000) * pi;
    
    tmp_value = zeros(1,no_samples_tag);
    for j=1:no_tags_emul
        rx_tag = (modul_vectors(j,:)*amp_phase_chg(j));
        rx_tag = rx_tag .* exp(1i*pha_shift(j));
        tmp_value = tmp_value + rx_tag;
    end
    tmp_value = awgn(tmp_value, awgn_level);
    rx_mixed(i,:) = tmp_value;
end

y_ica = fastica(abs(rx_mixed),'approach', 'symm');

reco_fica = zeros(1, no_tags_emul);
reco_fica_idx = 1;

for i=1:size(y_ica,1)
    rx_ica = y_ica(i,:);
    rx_ica = rx_ica / mean(rx_ica) - 1;
    %decode
    rn16 = rfid_gen2_tag_decode(rx_ica, modul_type, s_rate);
    
    fprintf('Recovering signal %d:...\n', i);
    
    rn16_no = bi2de(rn16(1:end-1), 'left-msb');
    
    if (rn16_no == 0)
        fprintf(' -> Unrecoverable signal from ICA... skipping...\n');
        continue;
    else
        fprintf(' -> Recovered signal from ICA is %d...\n', rn16_no);
    end
    for k=1:no_tags_emul
        if (rn16_no == rn16_values(k))
            fprintf(' -> ICA recovered value %d matched with RN16 original at position %d...\n', rn16_no, k);
            reco_fica(reco_fica_idx) = rn16_no;
            reco_fica_idx = reco_fica_idx + 1;
            break;
        end
    end
    
    if (k == no_tags_emul)
        fprintf(' -> ICA recovered value %d DO NOT match with RN16 originals...\n', rn16_no);
    end
    
    if (rn16(end) ~= 1)
        fprintf(' -> [rfid-decoder]: Invalid RFID signal. Unexpected end!!\n');
    end
    
end

fprintf('\nOriginal RN16 numbers:\n');
disp(rn16_values);

fprintf('\nRecovered FastICA symbols:\n');
disp(reco_fica);