%RFID Generator --- Main Entry Point for the RFID Signal Geberatir

%This is the entry point for a RFID signal generator that will work 
%creating RFID packets according to some parameters. 

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

clear;
close all;

%main config
main_snr = 40;
main_amp = 5;
tag_amp = 0.06; %range (0.01 -> 0.1 only)


%tag config
q_val = 2; %Q value (No. slots is 2^q)
max_rounds = 5; %max of query in the casse of Q > 0. (Overrides the Q)
no_tags = 12; %number of tags
modul_type = 1; %Type of Modulation (FM0, Miller 2, 4, 8)
tr_ext = 1; %use or not the extended preamble
dr_f = 0; %DR factor (0 = 8 or 1 = 64/3)

%rfid reader config
Fs = 800e3; %sampling rate (in Hz)
pwr_off_per = 1200; %in us (Power Down)
tari_value = 20; %in us (Tari) ~this is also PW.
one_symbol_val = 2; %in Taris (Length of 1-PIE bit)
rtcal_value = 3; %in Taris. (RTCAL)
trcal_value = 2.4; %in rtcal_values (TRCAL)
t1_value = 200; %in us (T1 value for tags)

%generate first the config
pwr_off_samp = round(pwr_off_per*1e-6*Fs);
pwr_up_samp = round(1200*1e-6*Fs);
delim_samp = round(12.5*1e-6*Fs);
tari_samp = round(tari_value*1e-6*Fs);
rtcal_samp = round((rtcal_value*tari_value)*1e-6*Fs);
trcal_samp = round((trcal_value*rtcal_value*tari_value)*1e-6*Fs);

t1_sampl = round(t1_value*1e-6*Fs);

config_signal = [zeros(1,pwr_off_samp) ones(1,pwr_up_samp) zeros(1,delim_samp)];
config_signal = [config_signal ones(1,tari_samp) zeros(1,tari_samp) ones(1,rtcal_samp)];
config_signal = [config_signal zeros(1,tari_samp) ones(1,trcal_samp) zeros(1,tari_samp)];

%now generate the QUERY
one_samp = round(tari_samp*one_symbol_val);
rfid_config = [one_samp tari_samp];

qry_args = [dr_f,modul_type,tr_ext,q_val]; %DR, Modul-Type, TR-Ext, Q Value

if (qry_args(2) == 1)
    tag_bfreq = (64/3) / (trcal_value*1e-6);
else
    tag_bfreq = 8 / (trcal_value*1e-6);
end

qry_cmd = rfid_gen2_gen_cmd('QUERY', qry_args, rfid_config);


%build the tag parameters
tag_slot = randi(power(2,q_val+1), 1, no_tags);
tag_rn16 = randi(power(2,16), 1, no_tags);

%if we use a Q > 0 do the multi_tag response
tag_config = [tag_bfreq modul_type tr_ext t1_sampl Fs tag_amp]; %base_freq modul_type, preamble, t1_value, samp_rate tag_amplitude
tag_rx = [];

pie_preamble = [zeros(1,delim_samp) ones(1,tari_samp) zeros(1,tari_samp) ones(1,rtcal_samp) zeros(1,tari_samp)] - 1;

q_slots = power(2,q_val);

fprintf('[rfid-generator]: Simulating RFID envirionment with %d slots and %d tags...\n', q_slots, no_tags);

if (no_tags > q_slots)
    fprintf('[rfid-generator]: Q slots is less than total number of tags. Collision will happen!!!\n');
end


if (q_val > 0)
    for i=1:q_slots
        max_rounds = max_rounds - 1;
        tag_slot = tag_slot - 1;
        %simulate tags
        [tmp, rn16, coll] = rfid_gen2_tag_model(no_tags, tag_slot, tag_rn16, tag_config);
        
        str_t = sprintf('%d ', tag_slot);
        fprintf('[rfid-generator]: Tag internal slot counter view - Round %d...\n', i);
        fprintf(' -> [%s\b]\n', str_t);
        
        if (coll == 1)
            fprintf('[rfid-generator]: Collision created!!!\n');
        end
        
        if (rn16 > 0 && coll == 0)
            tmp2 = rfid_gen2_gen_cmd('ACK', rn16, rfid_config) - 1;
            tmp2 = [pie_preamble tmp2];
            tag_rx = [tag_rx tmp tmp2 zeros(1,t1_sampl)]; %just the tag
            tag_rx = [tag_rx zeros(1,t1_value*10)]; %dummy for now ~ should be EPC
            tmp2 = rfid_gen2_gen_cmd('QUERYREP', 0, rfid_config) - 1;
            tmp2 = [pie_preamble tmp2];
            tag_rx = [tag_rx tmp2 zeros(1,t1_sampl)]; %just the tag
        else
            %append a QUERY-REQ
            tmp2 = rfid_gen2_gen_cmd('QUERYREP', 0, rfid_config) - 1;
            tmp2 = [pie_preamble tmp2];
            tag_rx = [tag_rx tmp tmp2 zeros(1,t1_sampl)];
        end
        
        %tag_rx = [tag_rx tmp];
        
        
        if (max_rounds == 0)
            break;
        end
    end
else
    tag_slot = tag_slot - 1;
    disp(tag_slot)
    %simulate_tags
    tag_rx = tag_rx + rfid_gen2_tag_model(no_tags, tag_slot, tag_rn16, tag_config);
end

tag_rx = tag_rx + 1;

out_signal = [config_signal qry_cmd tag_rx zeros(1,pwr_off_samp/2)] * main_amp;
out_signal = awgn(out_signal, main_snr);
plot(out_signal);

