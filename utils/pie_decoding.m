% PIE Decoding for UHF RFID Gen2
% 2015 by Bruno Espinoza

close all;
clear;

Fs = 800e3; %800 KS/sec according to the USRP.
load('rfid_read_block.mat');
rfid_read = abs(rfid_read);

ms_dur = length(rfid_read) / Fs * 1000;
fprintf('Block has length of %f ms...\n', ms_dur);

%Thresholding
rf_amplitude = max(rfid_read) - min(rfid_read); %we calculate the amplitude of the signal
%now filter by 1 or 0 by using a 60% of threshold, so PIE signal is clean
%of ripples. This also will clean up the Backscatter.

rfid_pie_filtered = rfid_read > (rf_amplitude * 0.6);

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

%The Setting time (1st and 2nd Raising Edges must be less than 1500 us)
tmp = rs_edge(2) - rs_edge(1);
tmp = tmp / Fs;

if (tmp < 1.5e-3)
    fprintf(' -> Checking Setting time < 1.5 ms... OK!!\n');
else
    fprintf('This does not seems to be a valid UHF RFID signal...\n');
    return
end

%Check that the 0-Symbol exists. For this, we need to find the PW of the
%signal by computing the difference between Rising and Falling Edges

%We could also just check for the Rising and Falling Edges of the 0, but
%this do not guarantees that the signal is PIE Encoded.

pw_val = [];

for i=1:length(fl_edge) - 1
    tmp = rs_edge(i+1) - fl_edge(i);
    pw_val = [pw_val tmp];
end

pw_samples = round(mean(pw_val));

if (std(pw_samples) > 1.1) %PW must be close to each other
     fprintf('This does not seems to be a valid UHF RFID signal...\n');
     return;
end

tari_samples = pw_samples * 2;

fprintf('* PW Value for the PIE Signal is %d samples...\n', pw_samples);
fprintf('* Using Tari value for the PIE Signal of %d samples...\n', tari_samples);

%now we position into the 2nd Rising Edge and start parsing
tmp = rs_edge(3) - rs_edge(2);
if (tmp < (tari_samples * 1.1))
    fprintf(' -> Checking the Data-0 Delimitator... OK!\n');
else
    fprintf('This does not seems to be a valid UHF RFID signal...\n');
end

%Now we calculate the Pivot of RTCal (Pivot = RTCAL/2) so we can distingish
%between 0s and 1 based on falling edge. We assume values > 4 RTCAL to be
%invalid and if value < pivot is 0 and if value > pivot is 1.

pivot = (rs_edge(4) - rs_edge(3)) / 2;
pivot = floor(pivot);

fprintf('* Pivot for detecting PIE values is of %d samples..\n', pivot);
fprintf('* RTCAL value of of %d samples..\n', pivot*2);

%For the TRCAL, it tell us the frequency of the tag. We can find it by
%doing: DR / TRCAL in uS, and we got a value in KHz.
%DR is a value sent to the tag in the QUERY command.

trcal = rs_edge(5) - rs_edge(4);

fprintf('* TRCAL value of of %d samples.. and %1.1e seconds\n', trcal, trcal/Fs);

%start the decoding
deco_bits = [];

for i=6:length(rs_edge)
    
    val = rs_edge(i) - rs_edge(i-1);
    if (val <= pivot)
        deco_bits = [deco_bits 0];
    end
    
    if (val >= pivot)
        if (val >= 8*pivot) %4 RTCAL or 8 Pivot
            fprintf('Error: Invalid PIE Symbol... skipping...\n');
            deco_bits = [deco_bits 9]; %as a delimitator
            continue
        end 
        deco_bits = [deco_bits 1];
    end
end
%decode the commands with a simpler parser. By now only NACK, ACK and QUERY
pie_begin = 1;
pos = 1;
status = 0;

while 1
    
    %check that we have enough
    if (pos >= length(deco_bits))
        fprintf('-> Nothing more to parse... finishing\n');
        break;
    end
    
    %check if the current pos is 1 or 9
    if (deco_bits(pos) == 9) %skip
        pos = pos + 1;
        continue
    end
    
    tmp = bi2de(deco_bits(pos:pos+1), 'left-msb');
    
    
    if (tmp == 2) %possible commands... QUERY and SELECT
        
        tmp2 = bi2de(deco_bits(pos:pos+3), 'left-msb');
        
        if (tmp2 == 8) % Look for QUERY Command
             fprintf('-> QUERY command found...\n');
             status = 1; %query decode
             pos = pos + 4; %skip to the next QUERY bits
        end
    end
    
    if (tmp == 1) %ACK command
        fprintf('-> ACK command found...\n');
        status = 2;
        pos = pos + 2; %skip to the next 2 bits
    end
    
    if (tmp == 3) %NACK command
        fprintf('-> NACK command found...\n');
        pos = pos + 8; %skip the six zeros.
        continue; %check again
    end
    
    if (status == 2) %decode ACK (16 bits)       
        ack_rn16 = bi2de(deco_bits(pos:pos+15)); %MSB according to specs
        fprintf(' * RN16 value being ACKed is %d...\n', ack_rn16);
        pos = pos + 15;
        status = 0; %back to parser
    end
    
    if (status == 1) %decode QUERY (22 bits)        
        cmd_bits = deco_bits(pos:pos+17);
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
            fq = 8 / (trcal / Fs);
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
       
        pos = pos + 18;
        status = 0; %back to parser
    end
    
    
    
end