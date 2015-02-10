% PIE Decoding for UHF RFID Gen2
% 2015 by Bruno Espinoza

close all;
clear;

Fs = 800e3; %800 KS/sec according to the USRP.
load('rfid_complete.mat');
rfid_read = abs(rfid_complete);
rfid_read = rfid_read(1:2.5e4);

ms_dur = length(rfid_read) / Fs * 1000;
fprintf('Block has length of %f ms...\n', ms_dur);

%Thresholding
rf_amplitude = max(rfid_read) - min(rfid_read); %we calculate the amplitude of the signal
%now filter by 1 or 0 by using a 60% of threshold, so PIE signal is clean
%of ripples. This also will clean up the Backscatter.

rfid_pie_filtered = rfid_read > (rf_amplitude * 0.6);
plot(rfid_pie_filtered);
%For decoding, we need to know the Rising Edge of all the signal.

rs_edge = [];
fl_edge = [];

for i=2:length(rfid_pie_filtered)    
    if (rfid_pie_filtered(i) == 1 && rfid_pie_filtered(i-1) == 0) %rising edge
        rs_edge = [rs_edge i];
    end   
    
     if (rfid_pie_filtered(i) == 0 && rfid_pie_filtered(i-1) == 1) %falling edge
        fl_edge = [fl_edge i];
    end   
    
end

%Basic assumptions:
% - We asume the first rising Edge is the begining of the signal.
% - Max Tari value is 25uS, and invalid values are 4RTCal, so if we excede
% 4/5 Tari values, we will declare the PIE section finished and look again
% for PIE (ACK) or the next preamble.

%we start a simple parser

if (length(rs_edge) < 2)
    fprintf('This does not seems to be a valid UHF RFID signal...\n');
    return
end

fprintf('Initializing Parser...\n');

status = 0; %no signal detected
pos = 2; %always count from the second edge
pw_samples = 0; %PW samples
tari_samples = 0; %Tari samples
pivot = 0;
trcal = 0;

deco_bits = [9];
%parser to decode PIE bits
while (pos <= length(rs_edge))
    tim_edge = rs_edge(pos) - rs_edge(pos-1);
    
    if (status == 0) %no signal detected, attemp to find the setting time
        if (tim_edge > (0.7e-3 * Fs) && (tim_edge < 2e-3 * Fs))
            fprintf(' -> Checking Setting time < 1.5 - 2.0 ms... OK!!\n');
            status = 1; %check for the 0 symbol
            pos = pos + 1;
            continue
        end
    end
    
    if (status == 1) %possible signal detected, try to find the zero symbol
        %Zero symbol means that the distance from R.E to F.E and F.E to R.E
        %must be the same
        k = fl_edge(pos-1) - rs_edge(pos-1);
        l = rs_edge(pos) - fl_edge(pos-1);
        
        g = abs(k - l);
        if (g / tim_edge < 0.25) %tolerance of 25% percent just be sure
            fprintf(' -> Checking Zero Symbol... OK!!\n');
            pw_samples = round(tim_edge/2);
            tari_samples = tim_edge;
            fprintf('* PW Value for the PIE Signal is %d samples...\n', pw_samples);
            fprintf('* Using Tari value for the PIE Signal of %d samples...\n', tari_samples);
            status = 2; %next stage of recognizing
            pos = pos + 1; %move
            continue;
        else
            status = 0; %back to begining
        end
        
    end
    
    if (status == 2) %RFID signal found, now define RTCAL and TRCAL
        pivot = tim_edge / 2; %any value exceding this will be considered invalid.
        % just check that PW is similar and that the RTCAL does not exceed
        % 3 Tari. If not, signal invalid.
        t_pw = rs_edge(pos) - fl_edge(pos-1);
        
        if (tim_edge <= 3.25*tari_samples) && (t_pw <= 1.25*pw_samples) %give some tolerance just to be sure
            fprintf(' -> Checking RT-Cal Symbol... OK!!\n');
            pivot = round(tim_edge / 2);
            fprintf('* Pivot for detecting PIE values is of %d samples..\n', pivot);
            fprintf('* RTCAL value of of %d samples..\n', tim_edge);
            pos = pos + 1;
            
            %just record the value of TRCAL
            trcal = rs_edge(pos) - rs_edge(pos-1);
            fprintf('* TRCAL value of of %d samples.. and %1.1e seconds\n', trcal, trcal/Fs);
            pos = pos + 1; %ready to decode
            status = 3; %bit decoding status
            fprintf(' -> Now trying to decode PIE bits... \n');
            continue
        end
    end
    
    if (status == 3) %bit decoding status
        if (tim_edge <= pivot*1.25) %just to be sure
            deco_bits = [deco_bits 0];
            pos = pos + 1;
            continue;
        end
        
        if (tim_edge > 8.25*pivot)
            %invalid duration, go to special stage
            status = 9; %special status to check possible scenarios
            continue;
        else
            deco_bits = [deco_bits 1]; 
            pos = pos + 1;
        end
        
    end
    
    if (status == 9)
        %if we found a very large PIE symbol, the following can happen:
        
        %End of the QUERY, then a new Setting Time + Preamble
        %End of the QUERY, then just a Preamble
        %ACK signal after backscatter (This only if next rising edge < 3 ms)
        
        if (tim_edge > (2.91e-3 * Fs)) %time for the tag to reply exhausted.
            %check next bit
            pos = pos + 1;
            tim_edge2 = rs_edge(pos) - rs_edge(pos-1);
            
            fprintf('PIE symbol exceeded... looking again for preamble...\n');
            deco_bits = [deco_bits 9];
            
            if (tim_edge2 <= pivot*1.25) %its a zero of preamble
                status = 1;
                %disp('A');
            else
                status = 0;
                %disp('B');
            end
        else
            pos = pos + 1;
            status = 3; %ACK??
            %need to decode the tag here and compare
            deco_bits = [deco_bits 5];
            fprintf('PIE symbol exceeded... ACK detected...\n');
        end
        
    end
end
%decode the commands with a simpler parser. By now only NACK, ACK and QUERY
fprintf('-> Nothing more to parse... finishing\n');
fprintf('-> Now decoding RFID protocol...\n');

%we know that when found a 9, its the begining of the protocol.
%we know when found a 5 that some backscatter or ACK / NACK is found.

pos = 1;
status = 0;

while (pos < length(deco_bits))
    
    if (deco_bits(pos) == 9)
        status = 1; %QUERY or QUERY-REP
        pos = pos + 1;
        continue;
    end
    
    if (deco_bits(pos) == 5)
        fprintf('-> ACK command found...\n');
        status = 5; %ACK
        pos = pos + 2; %skip preamble
        continue;
    end
    
    if (status == 1)
        tmp = bi2de(deco_bits(pos:pos+1), 'left-msb');
        if (tmp ~= 2 && tmp ~= 0)
            pos = pos + 2;
            continue; %not QUERY or QUERY-Rep, quietly ignore
        end
        
        if (tmp == 0)
            fprintf('-> QUERY-REP command found...\n');
            status = 4; %decode QUERY-REP
        else       
            tmp = bi2de(deco_bits(pos:pos+3), 'left-msb');

            if (tmp == 8)
                fprintf('-> QUERY command found...\n');
                status = 2; %decode QUERY
            end

            if (tmp == 9) % decode QUERY-ADJUST
                fprintf('-> QUERY-ADJUST command found...\n');
                status = 3;
            end
        end 
    end
    
    if (status == 2) %decode QUERY
        cmd_bits = deco_bits(pos+4:pos+21);
        crc_check = [1 0 0 0 cmd_bits(1:end-5)];
        
        drval = bi2de(cmd_bits(1), 'left-msb'); 
        mval = bi2de(cmd_bits(2:3), 'left-msb');
        trext = bi2de(cmd_bits(4), 'left-msb');
        q_val = bi2de(cmd_bits(9:13), 'left-msb');
        crc_val = bi2de(cmd_bits(14:end), 'left-msb');
        
        if (drval == 0)
            fq = 8 / (trcal / Fs);
            fprintf(' * DR value of 8, so the frequency of the tag is %f KHz...\n', fq / 1000);
        else
            fq = (64/3) / (trcal / Fs);
            fprintf(' * DR value of 64/3, so the frequency of the tag is %f KHz...\n', fq / 1000);
        end
        
        if (trext == 0)
            fprintf(' * Not using pilot tone for the incomming tag...\n');
        else
            fprintf(' * Using pilot tone for the incomming tag...\n');
        end
        
        switch mval
            case 0
                fprintf(' * Using FM0 decoder for the incomming tag...\n');
            case 1
                fprintf(' * Using Miller M=2 decoder for the incomming tag...\n');
            case 2
                fprintf(' * Using Miller M=4 decoder for the incomming tag...\n');
            case 3
                fprintf(' * Using Miller M=8 decoder for the incomming tag...\n');
        end
        
        fprintf(' * Q Value is %d, so number of slots for tags is %d...\n', q_val, (2^q_val));
        fprintf(' * CRC value is 0x%X... \n', crc_val);
       
        pos = pos + 22;
        status = 0; %back to parser
    end
    
    %status 3 and 4 TODO, we need readings
    
    if (status == 5) %ACK
        %disp(deco_bits(pos+3:pos+18))
        ack_rn16 = bi2de(deco_bits(pos+3:pos+18), 'left-msb'); %MSB according to specs
        fprintf(' * RN16 value being ACKed is %d...\n', ack_rn16);
        pos = pos + 18;
        %possible results could be another QUERY or NAK
        %status = 6;
        continue;
    end
end

fprintf('-> Nothing more to parse... finishing\n');

return
