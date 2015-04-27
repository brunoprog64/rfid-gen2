%RFID Decoding --- Main Entry Point for the RFID Signal Decoder

%This is the entry point for a RFID signal decoder that will work decoding
%RFID packets and outputing parameters. 

%This listener works by packets, so it grabs a n-amount of samples, defined
%in wnd_hist_size and send them to other handlers. Depending on the
%sampling rate and other factors, you may want to change wnd_hist_size
%accordingly.

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

clear;
close all;

%load(filename);
%OR: rfid_signal = read_complex_binary(filaname)


rfid_signal = read_complex_binary('../rfid-generator/rx_gen_signal.out');
%rfid_signal = rfid_signal(1.4e5:1.70e5);
%rfid_signal = rfid_signal(1.5255e5+20:1.61e5);

% load('rx_gen_signal.mat');
% rfid_signal = out_signal;

%figure
%plot(abs(rfid_signal));

Fs = 800e3; %800 KS.
wnd_hist_size = 1500; %1500 uS ~ samples processed per block. (Change accordingly)
wnd_hist_block = zeros(1,wnd_hist_size);

%some global variables
th_val = 0; %threshold value 
is_signal_end = 0; %signal end?
curr_pos = 1; %curr position
status = 0; %FSM state
reader_config = zeros(1,6); %threshold, tari, rtcal, trcal, pivot, samp_rate
tag_config = zeros(1,4); %samp_tag, modul_type, preamble, slots

pie_block = [];
tag_block = []; %store the data so can feed the tag decoder
rn16_deco_bits = []; %store the bits of the decodal
rn16_tag_num = 0; %store the number
q_value = 0;

while (~is_signal_end)
    %check if we go outside limits    
    if (curr_pos + wnd_hist_size > length(rfid_signal))
        wnd_hist_block = abs(rfid_signal(curr_pos:end));
        wnd_hist_block = [wnd_hist_block ; zeros(wnd_hist_size-length(rfid_signal(curr_pos:end)),1)];
        is_signal_end = 1;
    else
        wnd_hist_block = rfid_signal(curr_pos:curr_pos+wnd_hist_size-1);
        wnd_hist_block = abs(wnd_hist_block);
    end
    
    curr_pos = curr_pos + wnd_hist_size;
    %fprintf('Now Entering State: %d...\n', status);
    
    switch (status)
        case 0 %looking for preamble of Reader
             [pr_pos, th_val] = rfid_gen2_find_threshold(wnd_hist_block);
             
             if (pr_pos > 0)                 
                 status = 1;
                 fprintf('[rfid_listener]: Possible RFID Threshold set at %f at position %d...\n', th_val, (curr_pos-wnd_hist_size)+pr_pos );
                 reader_config(1) = th_val;
                 curr_pos = (curr_pos - wnd_hist_size) + pr_pos;
                 wnd_hist_size = 2e-3 * Fs; %2 ms just in case for looking for the 1.2 ms setting time
             end    
        case 1 %get RFID configuration
            %curr_pos
            [tari, rt, tr, pv, pos, gtari] = rfid_gen2_get_reader_config(wnd_hist_block, reader_config(1), Fs);
            %set the position of the listener for decoding the querys.
            if (gtari > 0)
                reader_config(2:end) = [tari, rt, tr, pv Fs];
                curr_pos = (curr_pos - wnd_hist_size) + pos - rt;
                wnd_hist_size = 22*pv; %QUERY has 22 symbols.
                status = 2;

                fprintf('[rfid_listener]: RFID configuration found!\n');
                fprintf(' -> Tari: %d ; RTCAL: %d; TRCAL: %d ; PIE Pivot: %d\n', tari, rt, tr, pv);
                fprintf('[rfid_listener]: RFID configuration passed! Now decoding...\n');
            else
                fprintf('[rfid_listener]: Invalid RFID configuration parameters... searching again.\n');
                fprintf(' -> Tari: %d ; RTCAL: %d; TRCAL: %d ; PIE Pivot: %d\n', tari, rt, tr, pv);
                status = 0;
            end
        case 2 %parse the pie symbols
            
            deco_bits = rfid_gen2_pie_parser(wnd_hist_block, reader_config);
            
            if (deco_bits(1) == 9)
                fprintf('[rfid_listener]: Invalid bits...\n');
                %return;
            else
                %decode the session
                [cmd_type, cmd_args] = rfid_gen2_pie_bdeco(deco_bits, reader_config(4), reader_config(6));
                
                %decide what to do based on the output
                if (strcmp(cmd_type,'QRY') == 1) %we found a query, so next is the tags.                    
                    tag_srate = (1 / cmd_args(1)) * Fs;
                    tag_config = [tag_srate cmd_args(2:end)];
                    q_value = cmd_args(4);
                    
                    %we only got the sampling rate of one period, but in
                    %Miller encoding this is different
                    
                    modul_str = '';
                    
                    if (cmd_args(3) == 0)
                        tag_srate = tag_srate * 1;
                        modul_str = 'FM0';
                    end
                    
                    if (cmd_args(3) == 1)
                        tag_srate = tag_srate * 2;
                        modul_str = 'Miller M=2';
                    end
                    
                    if (cmd_args(3) == 2)
                        tag_srate = tag_srate * 4;
                        modul_str = 'Miller M=4';
                    end
                    
                    if (cmd_args(3) == 3)
                        tag_srate = tag_srate * 8;
                        modul_str = 'Miller M=8';
                    end
                    
                    div = power(2, modul_type)*2; %to round the sampling rate to a valid value
                    %try to make the numbers divisible
                    tsrate = round(tag_srate);
                    
                    if (mod(tsrate, div) ~= 0)
                        divr = fix(tsrate / div);
                        divm = mod(tsrate , div);
                        
                        tsrate = tsrate - divm;
                        
                        fprintf('[rfid-listener]: Invalid Sampling rate of %d samples... rounding to %d samples...\n', round(tag_srate), tsrate);
                    end
                    
                    tag_config(1) = round(tsrate);
                    
                    fprintf('[rfid_listener]: Tag Encoding detected to be %s encoding...\n', modul_str);
                    fprintf('[rfid_listener]: Tag decodal... sample rate estimated at %d samples...\n', tag_srate);
                    tag_block = [];
                    status = 3;
                end
                
                if (strcmp(cmd_type,'ACK') == 1)
                    ack_num = cmd_args(1);
                    if (ack_num == rn16_tag_num)
                        fprintf('[rfid_listener]: ACK validation successful. Now decoding EPC-Code...\n');
                    else
                        fprintf('[rfid_listener]: Unexpected ACK! Listener Decodal do not match with the Reader...\n');
                    end
                    status = 5;
                    wnd_hist_size = 4*1e-3*Fs; %big window for the EPC.
                end
            end
        case 3 %store all the samples in a slot to feed the tag_decoder
            for i=1:length(wnd_hist_block)
                if (wnd_hist_block(i) > reader_config(1))
                    tag_block = [tag_block wnd_hist_block(i)];
                else
                    tag_block = tag_block(1:end-50);
                    %normalize the tag
                    tag_block = tag_block / mean(tag_block) - 1;
                    status = 4; %go to tag decodal
                    curr_pos = curr_pos - (wnd_hist_size - i); %go back to the falling edge
                    wnd_hist_size = 0; %stop processing blocks
                    is_signal_end = 0; %guarantee the decodal of the tag
                    break;
                end
            end
        case 4 %tag decodal
            wnd_hist_size = 500; %enable the sample processing
            %TODO: detect if a collision exists
            %detect_collision()????
            
            %TODO: if a collision exists, then apply the FastICA???
            
            %decode the tag
            rn16_deco_bits = rfid_gen2_tag_decode(tag_block, tag_config(2), tag_config(1));
            
            if (isempty(rn16_deco_bits) == 0)
                raw_tag_bits = sprintf('%d ', rn16_deco_bits(1:end));
                fprintf('[rfid_listener]: Raw Tag bits: %s\n', raw_tag_bits);
            end
            
            if (isempty(rn16_deco_bits) == 1 && q_value == 0) %no tag answer the query and 0 slots
                status = 0; %nothing to do.
                fprintf('[rfid_listener]: No tags on the range...\n');
                %continue;
            end
            
            if (rn16_deco_bits(end) == 0 && q_value == 0) %invalid RN16
                fprintf('[rfid_listener]: Invalid Tag response. Unexpected end..\n');
                status = 5; %special case
                %continue;
            end
                
            if (rn16_deco_bits(end) == 0 && q_value > 0) %invalid RN16
                fprintf('[rfid_listener]: Invalid Tag response for this slot. Unexpected end..\n');
                status = 5; %go to decodal PIE
                %continue;
            end

            if (rn16_deco_bits(end) == 1)
                rn16_deco_bits = rn16_deco_bits(1:end-1); %drop the EOF sign
                g = sprintf('%d ', rn16_deco_bits);
                fprintf(' -> Decoded bits: [%s\b]...\n', g);
                rn16_tag_num = bi2de(rn16_deco_bits, 'left-msb');
                fprintf('[rfid_listener]: Tag Backscatter decoded. RN16 is %d...\n', rn16_tag_num);
                status = 5; %go to decode pie
                %continue;
            end
            
        case 5 %pie decodal after an QUERY
            
            %here we expect a 0 and a RTCAL (a 1) first.
            
            r_lengths = [];
            last_pos = 0;
            %r_sy_pos = [];
            lpos = 0;
            zero_samples = 0;
            st = 0;
            
            for i=1:length(wnd_hist_block)-1
                
                if (wnd_hist_block(i) < reader_config(1) && st == 0)
                    zero_samples = zero_samples + 1;
                end
                
                if (wnd_hist_block(i) > reader_config(1))
                    st = 1;
                end
                
                if (wnd_hist_block(i) <  reader_config(1) && wnd_hist_block(i+1) >  reader_config(1))
                    r_lengths = [r_lengths  i-lpos];
                    lpos = i;
                    
                    if (length(r_lengths) > 3) %we only care about 0, RT-CAL and the next symbol.
                        last_pos = i;
                        break;
                    end
                end
            end
            
            delim_samples = round(13.5*1e-6*Fs); %12.5 us delimitator
            
            if (zero_samples == 0) %unexpected silence with no commands
                fprintf('[rfid_listener]: Unexpected silence of the tag.\n');
                continue; %do not bother as if there is no zeros, no edges neither
            end
            
            %if we found a more spacing and a q_value = 0, nothing to do
            if (zero_samples > delim_samples)
                if (q_value == 0)
                    fprintf('[rfid_listener]: No PIE Commands. Ending cycle...\n\n\n');
                else
                    fprintf('[rfid_listener]: Unexpected end of the cycle...\n\n\n');
                end
                status = 0;
                curr_pos = round(curr_pos - length(wnd_hist_block));
                wnd_hist_size = 500;
                continue;
            end
            
            %check that the first 2 symbols are > 3 Tari.
            r_lengths = r_lengths(2:end);
            
            if (sum(r_lengths(1:2)) > reader_config(2)*3)
                
                if (r_lengths(3) > reader_config(2)*3)
                    fprintf('[rfid_listener]: Unexpected start of another PIE Preamble...!!!\n\n\n');
                    status = 1;
                    curr_pos = curr_pos - wnd_hist_size;
                    wnd_hist_size = 500;
                    continue;
                end
                
                fprintf('[rfid_listener]: PIE Frame-Sync detected...!!\n');
                status = 2;
                curr_pos = (curr_pos - wnd_hist_size) + sum(r_lengths(1:2));
                wnd_hist_size = 800;
                continue;
            end
        otherwise
            error('Invalid FSM state!!!');
            break;
    end 
end