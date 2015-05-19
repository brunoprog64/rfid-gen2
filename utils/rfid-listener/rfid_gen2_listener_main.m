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

addpath('fastica-25');

%user edits
multiple_antennas = 1; %if set to 1, will assume 2 RX files exist
file_mask_name = 'f_rxout'; %will add "_ch1.out / _ch2.out

%load(filename);
%OR: rfid_signal = read_complex_binary(filaname)

tic(); %start internal counter

if (multiple_antennas == 1)
    
    fil1 = strcat('../', file_mask_name, '_ch1.out');
    fil2 = strcat('../', file_mask_name, '_ch2.out');
    
    fprintf('Multiple RX mode activared...\n');
    fprintf(' * Loading file for RX1: %s...\n', fil1);
    fprintf(' * Loading file for RX2: %s...\n', fil2);
    
    rfid_signal = read_complex_binary(fil1);
    rfid_signal_ica = read_complex_binary(fil2);
    
    rfid_signal = rfid_signal(930e3:980e3);
    rfid_signal_ica = rfid_signal_ica(930e3:980e3);
else
    rfid_signal = read_complex_binary('../f_rxout_ch1.out');
    rfid_signal = rfid_signal(930e3:980e3);
end

more off;
figure
plot(abs(rfid_signal));
drawnow();

Fs = 8e5; %800 KS.
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
tag_block_ica = []; %store the data for the tag decoder (RX2)
rn16_deco_bits = []; %store the bits of the decodal
rn16_tag_num = 0; %store the number
q_value = 0;

rfid_stats = zeros(1,6); %no querys, no tags decoded, no tags undecodable, no ACKS, no bad ACKS, no collisions

while (~is_signal_end)
    %check if we go outside limits    
    if (curr_pos + wnd_hist_size > length(rfid_signal))
        wnd_hist_block = abs(rfid_signal(curr_pos:end));
        wnd_hist_block = [wnd_hist_block]; %; zeros(wnd_hist_size-length(rfid_signal(curr_pos:end)))];
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
                reader_config(2:end) = [tari, rt, tr, pv, Fs];
                curr_pos = (curr_pos - wnd_hist_size) + pos - rt;
                wnd_hist_size = 32*pv; %QUERY has 22 symbols.
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
            [deco_bits, lre] = rfid_gen2_pie_parser(wnd_hist_block, reader_config);
            
            if (deco_bits(1) == 9)
                fprintf('[rfid_listener]: Invalid bits...\n');
                %unexpected state
                status = 100;
            else
                curr_pos = (curr_pos - wnd_hist_size) + lre;
                %decode the session
                [cmd_type, cmd_args] = rfid_gen2_pie_bdeco(deco_bits, reader_config(4), reader_config(6));
                                
                %decide what to do based on the output
                if (strcmp(cmd_type,'QRY') == 1) %we found a query, so next is the tags.                    
                    tag_srate = (1 / cmd_args(1)) * Fs;
                    tag_config = [tag_srate cmd_args(2:end)];
                    q_value = cmd_args(4);
                    
                    rfid_stats(1) = rfid_stats(1) + 1; %add one query to count
                    
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
                    
                    div = power(2, cmd_args(3))*2; %to round the sampling rate to a valid value
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
                    wnd_hist_size = tag_srate * 75;
                    
                    tag_block = [];
                    
                    if (multiple_antennas > 0)
                        tag_block_ica = [];
                    end
                    
                    status = 3;
                end
                
                if (strcmp(cmd_type,'ACK') == 1)
                    ack_num = cmd_args(1);
                    if (ack_num == rn16_tag_num)
                        fprintf('[rfid_listener]: ACK validation successful. Now decoding EPC-Code...\n');
                        rfid_stats(3) = rfid_stats(4) + 1;
                    else
                        fprintf('[rfid_listener]: Unexpected ACK! Listener Decodal do not match with the Reader...\n');
                        rfid_stats(3) = rfid_stats(5) + 1;
                    end
                    status = 5;
                    wnd_hist_size = 4*1e-3*Fs; %big window for the EPC.
                end
                
                
                if (strcmp(cmd_type, 'QREP') == 1)
                    %go to the next tag decodal
                    tag_block = [];
                    
                    if (multiple_antennas > 0)
                        tag_block_ica = [];
                    end
                    status = 3;
                end
                
                if (strcmp(cmd_type, 'NAK') == 1)
                    status = 5;
                end
                
                if (strcmp(cmd_type, 'QADJ') == 1);
                    %we expect tags.
                    tag_block = [];
                    
                    if (multiple_antennas > 0)
                        tag_block_ica = [];
                    end
                    
                    status = 3;
                end
                
            end
        case 3 %store all the samples in a slot to feed the tag_decoder
            
            %multiple_antennas
            if (multiple_antennas > 0)
                wnd_ica_block = rfid_signal_ica(curr_pos-wnd_hist_size+1:curr_pos);
                wnd_ica_block = abs(wnd_ica_block);
            end
                
            for i=1:length(wnd_hist_block)
                if (wnd_hist_block(i) > reader_config(1))
                    tag_block = [tag_block wnd_hist_block(i)];
                    
                    if (multiple_antennas > 0)
                        tag_block_ica = [tag_block_ica wnd_ica_block(i)];
                    end
                else
                    break;
                end
            end
            
            if (length(tag_block) < 52)
                fprintf('[rfid_listener]: Unexpected end of cycle!!!\n');
                status = 100; %we do not know what to do, crash.
                continue;
            end
                
            tag_block = tag_block(1:end-50);
            %normalize the tag
            tag_block = tag_block / mean(tag_block) - 1;
            
            if (multiple_antennas > 0)
                tag_block_ica = tag_block_ica(1:end-50);
                tag_block_ica = tag_block_ica / mean(tag_block_ica) - 1;
            end
            
            status = 4; %go to tag decodal
            curr_pos = curr_pos - (wnd_hist_size); %go back to the falling edge
            wnd_hist_size = 0; %stop processing blocks
            is_signal_end = 0; %guarantee the decodal of the tag
                        
        case 4 %tag decodal
            wnd_hist_size = 1500; %enable the sample processing
            %detect if a collision exists
            coll_exist = rfid_gen2_check_collision(tag_block, tag_config(3), tag_config(1));
            
            if (coll_exist == 1)
                fprintf('[rfid_listener]: Collisison detected!!!\n\n');
                rfid_stats(6) = rfid_stats(6) + 1;
            end
            
            %if a collision exists, then apply the FastICA
            
            if (multiple_antennas > 0 && coll_exist == 1)
                %demux and decode the signal
                [tag_deco_clean, is_deco_data] = rfid_gen2_fastica_tags(tag_block, tag_block_ica, tag_config(3), tag_config(1));
                
                if (is_deco_data == 1)
                    nv = 100; %the edge appears to, so we get rid of it
                    figure
                    subplot(2,1,1);
                    plot(tag_block(nv:end));
                    subplot(2,1,2);
                    plot(tag_block_ica(nv:end));
                end
                
                [rn16_deco_bits, ~, sym_pos] = rfid_gen2_tag_decode(tag_deco_clean, tag_config(3), tag_config(1));
            else
                %decode the tag
                [rn16_deco_bits, ~, sym_pos] = rfid_gen2_tag_decode(tag_block, tag_config(3), tag_config(1));
            end
            
            if (isempty(sym_pos) ~= 1)
                curr_pos = curr_pos + sym_pos(end); %skip
            else
                rfid_stats(3) = rfid_stats(3) + 1;
            end
            
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
                rn16_tag_num = bi2de(rn16_deco_bits, 'right-msb');
                fprintf('[rfid_listener]: Tag Backscatter decoded. RN16 is %d...\n', rn16_tag_num);
                status = 5; %go to decode pie
                rfid_stats(2) = rfid_stats(2) + 1;
                %continue;
            end
            
        case 5 %pie decodal after an QUERY
            r_edge = [];
            lpos = 0;
            zero_samples = 0;
            delim_samples = (12.5*Fs*1e-6) - 1;
            end_cycle_pie = 0;
            
            %calculate rising edges
            for i=1:length(wnd_hist_block)-1
                
                if (wnd_hist_block(i) < reader_config(1))
                    zero_samples = zero_samples + 1;
                end
            
                if (wnd_hist_block(i) < reader_config(1) && wnd_hist_block(i+1) > reader_config(1))
                
                    if (zero_samples > reader_config(3)) %more than RTCAL
                        end_cycle_pie = 1;
                        break;
                    end
                
                    if (zero_samples >= delim_samples) %ignore temporal power offs
                        r_edge = [r_edge i-lpos];
                        lpos = i;
                        zero_samples = 0;
                    end
                end                
            end
            
            if (end_cycle_pie == 1)
                if (q_value == 0)
                    fprintf('[rfid_listener: No PIE Commands. Ending cycle...\n\n\n');
                else
                    fprintf('[rfid_listener: Unexpected end of cycle...\n\n\n');
                end
                
                status = 0;
                curr_pos = curr_pos - length(wnd_hist_block);
                wnd_hist_block = 1500;
            end
        
            
            if (isempty(r_edge) == 1)
                fprintf('[rfid-listener]: Unexpected silence of the reader!!!\n');
                continue; %skip and keep looking for PIE symbols
            end
            
            offset_pie = r_edge(1);
            
            if (length(r_edge) < 4)
                curr_pos = curr_pos - length(wnd_hist_block) + offset_pie;
                wnd_hist_block = 1500;
                continue;
            end
            
            r_edge = r_edge(2:end);
            
            %here we can look for PIE symbols ~ we should get 0 - RTCAL - [TRCAL | 0 | 1]
            %those values could be from new query or another command so double check
            
            ntari = r_edge(1);
            nrtcal = r_edge(2);
            nusymbol = r_edge(3);
            
            fprintf('Detected values: Tari: %d / RTCAL: %d / 3rd Symbol: %d\n', ntari, nrtcal, nusymbol)
            
            if (nrtcal < ntari*3.5 && nrtcal > ntari*2.2)
                %check for TRCAL
                if (nusymbol > nrtcal)
                    fprintf('[rfid_listener]: Unexpected start of another PIE Preamble...!!!\n\n\n');
                    status = 1;
                    curr_pos = curr_pos - wnd_hist_size;
                    wnd_hist_size = 1500;
                    is_signal_end = 0;      
                    continue;
                else
                    fprintf('[rfid_listener]: PIE Frame-Sync detected...!!\n');
                    status = 2;
                    
                    %fprintf('Debug: CuP: %f, WNDS: %f, OPI: %f\n\n', curr_pos, wnd_hist_size, offset_pie);
                    %disp(r_edge)
                    
                    %curr_pos = (curr_pos - wnd_hist_size) + offset_pie + r_edge(2) - (round(r_edge(1)/2));
                    curr_pos = (curr_pos - wnd_hist_size) + offset_pie + r_edge(2) - round(r_edge(1) / 2);
                    wnd_hist_size = 26*pv; %ACK has 16 symbols.
                    is_signal_end = 0; %force decodal
                    continue;
                end
            end
        otherwise
            error('Invalid FSM state!!!');
            break;
    end 
end

tot_runtime = toc(); %recover internal timer

fprintf('Finished parsing the file!!!\n')
fprintf('\n****** RFID Listener Statitics *********\n\n');
fprintf(' - No. of Decoded QUERY: %d\n - No. of Decoded Tags: %d\n - No. of Undecodable Tags: %d\n - No. of ACK: %d\n - No. of Bad ACKs: %d\n', rfid_stats(1), 
rfid_stats(2), rfid_stats(3),rfid_stats(4),rfid_stats(5));
fprintf(' - No. of Collisions detected: %d\n\n', rfid_stats(6));

fprintf('Total Runtime: %f seconds...\n', tot_runtime)
