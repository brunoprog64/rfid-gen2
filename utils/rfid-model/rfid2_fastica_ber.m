%FastICA Tag Error Rate Graph generator

%IMPORTANT: This is just a model to test the capabilities of ICA when decoding RFID Tags.
%It tries to consider amplitude changes and phase changes. Also noise is modelled, as AWGN.

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

close all;
clear;

addpath('fastica-25');

%options for the test
no_tags_emul = 2;
no_antennas = 2;
pream_ex = 1; %extended preamble
modul_type = 0; %Miller M=2
s_rate_cycle = 40;
t1_value_sampl = 400;
number_loops = 1e6;

s_rate = (power(2,modul_type)*2)*s_rate_cycle;
no_samples_tag = 60*s_rate;

awgn_level = 30;
ber_level = zeros(4,awgn_level);

for modul_type=0:3 %Iterate all over the possible modulations
    
    if (modul_type == 0)
        modul_str = 'FM0';
    else
        modul_str = sprintf('Miller M=%d', 2^modul_type);
    end
    fprintf('Now testing %s with %d levels of AWGN...\n', modul_str, awgn_level);
    
    for lnoise=0:awgn_level

        fprintf('* Testing %d loops for %d tags with %d antennas at SNR of %d...\n', number_loops, no_tags_emul, no_antennas, lnoise);
        tag_pass = 0;

        for nl=1:number_loops
            t1_value_delays = randi(200, 1, no_tags_emul) + t1_value_sampl;
            rn16_values = randi(power(2,16)-1, 1, no_tags_emul); %tags generate random number of 16 bits.

            modul_vectors = ones(no_tags_emul, no_samples_tag) * -1;
            rx_mixed = zeros(no_antennas, no_samples_tag);

            %generate everything
            for i=1:no_tags_emul
                rn16_bits = de2bi(rn16_values(i),16, 'left-msb');
                enc_rn16 =  rfid_gen2_tag_encode(rn16_bits, pream_ex, modul_type, s_rate) - 1;

                t_bg = t1_value_delays(i);
                t_ed = t_bg + length(enc_rn16) - 1;

                modul_vectors(i,t_bg:t_ed) = enc_rn16;
            end

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
                tmp_value = awgn(tmp_value, lnoise);
                rx_mixed(i,:) = tmp_value;
            end

            y_ica = fastica(abs(rx_mixed),'approach', 'symm', 'verbose', 'off');

            reco_fica = zeros(1, no_tags_emul);
            reco_fica_idx = 1;

            for i=1:size(y_ica,1)
                rx_ica = y_ica(i,:);
                rx_ica = rx_ica / mean(rx_ica) - 1;
                %decode
                rn16 = rfid_gen2_tag_decode(rx_ica, modul_type, s_rate);

                %fprintf('Recovering signal %d:...\n', i);

                rn16_no = bi2de(rn16(1:end-1), 'left-msb');

                if (rn16_no == 0)
                    %fprintf(' -> Unrecoverable signal from ICA... skipping...\n');
                    continue;
                %else
                    %fprintf(' -> Recovered signal from ICA is %d...\n', rn16_no);
                end
                for k=1:no_tags_emul
                    if (rn16_no == rn16_values(k))
                        %fprintf(' -> ICA recovered value %d matched with RN16 original at position %d...\n', rn16_no, k);
                        reco_fica(reco_fica_idx) = rn16_no;
                        reco_fica_idx = reco_fica_idx + 1;
                        break;
                    end
                    %if (k == no_tags_emul)
                        %fprintf(' -> ICA recovered value %d DO NOT match with RN16 originals...\n', rn16_no);
                    %end
                end

                %if (rn16(end) ~= 1)
                    %fprintf(' -> [rfid-decoder]: Invalid RFID signal. Unexpected end!!\n');
                %end
            end
            %if (length(find(reco_fica ~= 0)) > 0) % == length(reco_fica))
            if (isempty(find(reco_fica ~= 0,1)) == 0)
                tag_pass = tag_pass + 1;
                fprintf('*');
            else
                fprintf('.');    
            end

        end
        fprintf('\n');
        ber_level(modul_type+1, lnoise+1) = tag_pass / number_loops;
    end

    if (modul_type == 0)
        modul_str = 'FM0';
    else
        modul_str = sprintf('Miller M=%d', power(2,modul_type));
    end
end    

figure
hold on;
plot(1 - ber_level(1,:), 'b-o');
plot(1 - ber_level(2,:), 'r-+');
plot(1 - ber_level(3,:), 'g-*');
plot(1 - ber_level(4,:), 'k-x');
legend('FM0', 'Miller M=2', 'Miller M=4', 'Miller M=8');
ylabel('Tag Error Rate');
xlabel('AWGN / SNR');
