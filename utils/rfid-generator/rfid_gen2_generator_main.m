%RFID Generator --- Main Entry Point for the RFID Signal Geberatir

%This is the entry point for a RFID signal generator that will work 
%creating RFID packets according to some parameters. 

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

clear;
close all;

%main config
main_snr = 25;
main_amp = 5;
tag_amp = 0.06; %range (0.01 -> 0.1 only)
tari_nominal = 0; %if 0, the values for RTCAL and TRCAL are given in %us, if set in 1 values are set referent to Tari and RTCAL.

if (tari_nominal == 1)
    fprintf('[rfid-generator]: Nominal mode is ON. RTCAL and TRCAL will be calculated from Tari...\n');
end
    
%tag config
q_val = 0; %Q value (No. slots is 2^q)
max_rounds = 5; %max of query in the casse of Q > 0. (Overrides the Q)
no_tags = 1; %number of tags
modul_type = 1; %Type of Modulation (FM0, Miller 2, 4, 8)
tr_ext = 1; %use or not the extended preamble
dr_f = 0; %DR factor (0 = 8 or 1 = 64/3)

%rfid reader config
Fs = (8e5); %sampling rate (in Hz)
pwr_off_per = 1200; %in us (Power Down)
tari_value = 24; %in us (Tari goes from 6.25us to 25 us)
one_symbol_val = 2; %in Taris (Length of 1-PIE bit) (From 1.5 to 2 Tari)
rtcal_value = 72; %in us (Must be 2.5 to 3 Tari)
trcal_value = 200; %in us (Must be 1.1 to 3 RTCal)
t1_value = 200; %in us (T1 value for tags)
epc_null = 2000; %in us (white space for the EPC)

%rtcal_check_val =  0;
%trcal_check_val = 0;

if (tari_nominal == 0) 
    %us values
    rtcal_check_val = rtcal_value;
    trcal_check_val = trcal_value;
else
    %calculate the values
    rtcal_check_val = rtcal_value*tari_value;
    trcal_check_val = rtcal_check_val*trcal_value;
end

%check if the Tari, RTCAL and TRCAL are valid
if (tari_value < 6.25 || tari_value > 25)
    fprintf('[rfid-generator]: Invalid Tari value!!! Must be between 6.25 - 25 uS!!!\n');
    return;
end

if ((rtcal_check_val < (1.5*tari_value)) || (rtcal_check_val > 3*tari_value))
    fprintf('[rfid-generator]: Invalid RTCAL value!!! Must be between %.2f - %.2f uS!!!\n', (1.5*tari_value), (2*tari_value));
    return;
end

if ((trcal_check_val < (1.1*rtcal_check_val)) || (trcal_check_val > 3*rtcal_check_val))
    fprintf('[rfid-generator]: Invalid TRCAL value!!! Must be between %.2f - %.2f uS!!!\n', (1.1*rtcal_check_val), (3*rtcal_check_val));
    return;
end

%generate first the config
pwr_off_samp = round(pwr_off_per*1e-6*Fs);
pwr_up_samp = round(1500*1e-6*Fs);
delim_samp = round(12.5*1e-6*Fs);
tari_samp = round(tari_value*1e-6*Fs);
pw_samp = round(tari_samp/2);

rtcal_samp = round(rtcal_check_val*1e-6*Fs) - pw_samp; %positive block of RT
trcal_samp = round(trcal_check_val*1e-6*Fs) - pw_samp; %positive block of TR

t1_sampl = round(t1_value*1e-6*Fs);

fprintf('[rfid-generator]: Tari samples: %d / PW samples: %d \n * RTCAL samples: %d / TRCAL Samples: %d \n * T1 samples: %d...\n', tari_samp, pw_samp, rtcal_samp, trcal_samp, t1_sampl);
fprintf('[rfid-generator]: Tari uS: %.2f / PW uS: %.2f \n * RTCAL uS: %.2f / TRCAL uS: %.2f \n * T1 uS: %.2f...\n', tari_value, tari_value/2, rtcal_value, trcal_value, t1_value);

config_signal = [zeros(1,pwr_off_samp) ones(1,pwr_up_samp) zeros(1,delim_samp)];
config_signal = [config_signal ones(1,pw_samp) zeros(1,pw_samp) ones(1,rtcal_samp)];
config_signal = [config_signal zeros(1,pw_samp) ones(1,trcal_samp) zeros(1,pw_samp)];

%phase offset components
pmin = -2*pi;
pmax = 2*pi;

%now generate the QUERY
one_samp = round(tari_samp*one_symbol_val) - pw_samp;
rfid_config = [one_samp pw_samp];

qry_args = [dr_f,modul_type,tr_ext,q_val]; %DR, Modul-Type, TR-Ext, Q Value

if (qry_args(1) == 1)
    tag_bfreq = (64/3) / (trcal_value*1e-6);
else
    tag_bfreq = 8 / (trcal_value*1e-6);
end


if (int64(tag_bfreq) > 640000 || int64(tag_bfreq) < 40000)
    fprintf('[rfid-generator]: Invalid Tag Backscatter frequency: %.2f Khz. Must be between 40 - 640 KHz!!!\n', (tag_bfreq/1000));
    return;
end

if modul_type == 0
    str_modul = 'FM0';
else
    str_modul = sprintf('Miller M=%d', 2^modul_type);
end

if (modul_type > 3 || modul_type < 0)
    fprintf('[rfid-generator]: Invalid modulation type requested!!!');
    return
end

fprintf('[rfid-generator]: Base Frequency for Tags will be of %.2f Khz and use %s modulation...\n', (tag_bfreq/1000), str_modul);
fprintf('[rfid-generator]: Samples per Tag cycle: %d samples...\n', round((1/tag_bfreq)*Fs) *  power(2,modul_type));

qry_cmd = rfid_gen2_gen_cmd('QUERY', qry_args, rfid_config);

%build the tag parameters
tag_slot = randi(power(2,q_val), 1, no_tags);
tag_rn16 = randi(power(2,16), 1, no_tags);

%if we use a Q > 0 do the multi_tag response
tag_config = [tag_bfreq modul_type tr_ext t1_sampl Fs tag_amp]; %base_freq modul_type, preamble, t1_value, samp_rate tag_amplitude
tag_rx = zeros(1,t1_sampl);

pie_preamble = [zeros(1,delim_samp) ones(1,pw_samp) zeros(1,pw_samp) ones(1,rtcal_samp) zeros(1,pw_samp)] - 1;

q_slots = power(2,q_val);

fprintf('[rfid-generator]: Simulating RFID envirionment with %d slots and %d tags...\n', q_slots, no_tags);

if (no_tags > q_slots)
    fprintf('[rfid-generator]: Q slots is less than total number of tags. Collision will happen!!!\n');
end

for i=1:q_slots
    
    %simulate the tags
    max_rounds = max_rounds - 1;
    tag_slot = tag_slot - 1;
    %simulate tags
    
    %simulate amplitude
    tag_amp  = (100 - 50) .*rand(1,1) + 50;
    tag_config(6) = tag_amp / 1000;
    
    [modul_tag, rn16, coll] = rfid_gen2_tag_model(no_tags, tag_slot, tag_rn16, tag_config);
    
    phaoff = (pmax-pmin).*rand(1,1) + pmin;
    modul_tag = modul_tag .* exp(1i*phaoff);
    
    if (coll == 1)
        fprintf('[rfid-generator]: Collision created!!!\n');
    end
    
    %check responses
    if (rn16 > 0 && coll == 0) %there is a valid RN16
        ack_msg = rfid_gen2_gen_cmd('ACK', rn16, rfid_config) - 1;
        ack_rx = [pie_preamble ack_msg];
        
        tag_rx = [tag_rx modul_tag ack_rx];
        tag_rx = [tag_rx zeros(1,epc_null*1e-6*Fs)]; %dummy for now ~ should be EPC
        
        if (q_slots > 1)
            qrep_msg = rfid_gen2_gen_cmd('QUERYREP', 0, rfid_config) - 1;
            qrep_rx = [pie_preamble qrep_msg];
            tag_rx = [tag_rx qrep_rx zeros(1,t1_sampl)]; %just the tag
        end
    else
        tag_rx = [tag_rx modul_tag];
        
        if (q_slots > 1)
            %append a QUERY-REQ
            qrep_msg = rfid_gen2_gen_cmd('QUERYREP', 0, rfid_config) - 1;
            qrep_msg = [pie_preamble qrep_msg];
            tag_rx = [tag_rx qrep_msg zeros(1,round(t1_sampl))];
        end
    end
        
    if (max_rounds == 0)
        break;
    end
    
end

tag_rx = tag_rx + 1;

out_signal = [config_signal qry_cmd tag_rx zeros(1,pwr_off_samp/2)] * main_amp;



phaoff = (pmax-pmin).*rand(1,1) + pmin;
out_signal = out_signal .* exp(-1i*phaoff);
out_signal = awgn(out_signal, main_snr);
out_signal = out_signal / max(out_signal);
out_signal = out_signal * 0.75;

plot(abs(out_signal));

write_complex_binary(out_signal, 'rx_gen_signal.out');
fprintf('Written the file as: rx_gen_signal.out!!!\n');

fprintf('RN16 values created are:')
disp(tag_rn16)
