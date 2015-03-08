%%% MATLAB / Octave UHF RFID Gen2 Model

%IMPORTANT: Notice that this model is made to ease the understanding on how the gen2-reader works.
%At this moment, it is unable to decode tags or to handle some specific stuff on the RFID model, but is partially ready
%to be used as a basic listener.

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

clear;
close all;
Fs = 800e3;
wnd_size = 10; %change accordingly to sampling rate.  Assumes 800 KS/s.
status = 0;

%status list
%0 = looking for initial threshold
%1 = threshold found - looking for PIE configuration details
%2 = look for backscatter

load('rfid_signal.mat'); %a capture
rfid_data = rfid_signal; %rfid_read;
wnd_block = zeros(1,wnd_size);
wnd_idx = 1;

mean_blocks = zeros(1,3);
mean_idx = 1;

%for detecting PIE, we do as follows:
%We take average of blocks. When find a large discontinuity, we mark this
%as the beginning of the PIE signal and establish a threshold. All other
%decoding is just by comparing  with the threshold.

%this loop is for finding the initial threshold.
pie_threshold = 0;
last_average = 0;
last_sample = 1;
last_i = 0;
i = 1;
lre_pos = 0; %last rising edge
lfe_pos = 0; %last falling edge

rtcal_ready = 0;
st2_val = 0;

%RFID parameters
rfid_params = zeros(1,3); %TARI, RTCAL, TRCAL
rtcal_samples = 0;
trcal_samples = 0;
pie_pivot = 0;
t1_samples = 0; %max time for the tag to reply. (For eassiness, 5RTCAL)

pie_bits = [];
tag_samples = [];

while (i <= length(rfid_data))
    
    
    %In this state search for the rising edge and define the threshold.
    if (status == 0) %looking for 1st Rising Edge
       if (wnd_idx > wnd_size)
          m = mean(wnd_block);
          %fprintf('Mean for this block is %f and difference with former %f...\n', m, abs(last_average - m));
          %check if the difference between averages is significant
          if (abs(last_average - m) > 0.9) %we found our threshold
              pie_threshold = max(wnd_block);
              fprintf('PIE Threshold set to %f...\n', pie_threshold);
              status = 1; %found threshold
              lre_pos = i;
              
              while (abs(rfid_data(i)) > pie_threshold) %skip samples to the next falling edge
                  i = i + 1;
              end
          end
          wnd_idx = 1;
          last_average = m;
          
      end
      wnd_block(wnd_idx) = abs(rfid_data(i));
      wnd_idx = wnd_idx + 1;
    end
    
    %In this stage, find the 0-Symbol, RTCAL, TRCAL.
    if (status == 1) %detected the PIE Threshold
        csam = abs(rfid_data(i)) > pie_threshold;
        ty_edge = last_sample - csam; %-1 Rising Edge / 1 = Falling Edge / 0 = nothing.
        
        if (st2_val == 0) 
            if (ty_edge == -1)
                lre_pos = i;
                fprintf('Finding 0-Symbol...\n');
                st2_val = 1;
                ty_edge = 0;
            end
        elseif (st2_val < 4)
           if (ty_edge == -1)
               m = i - lre_pos;
               rfid_params(st2_val) = m;
               ty_edge = 0;
               st2_val = st2_val + 1;
               lre_pos = i;
           end
        end
        
       if (st2_val == 4)
           
           %check the constraints about Tari, RTCAL and TRCAL
           
           if ~(rfid_params(2) <= 3.25*rfid_params(1))
               fprintf('RTCAL do not meet constraints (2.5 - 3 Tari)... this is a invalid RFID signal!!!\n');
               return;
           else
               fprintf('Checking TARI... OK (%d samples)!!!\n', rfid_params(1));
               fprintf('Checking RTCAL... OK (%d samples)!!!\n', rfid_params(2));
               pie_pivot = round(rfid_params(2) / 2);
               fprintf('PIE pivot value set to %d...\n', pie_pivot);
           end
           
           if ~(rfid_params(3) <= rfid_params(2)*3.25)
               fprintf('TRCAL do not meet constraints (1.1 - 3 RTCAL)... this is a invalid RFID signal!!!\n');
               return
           else
               fprintf('Checking TRCAL... OK (%d samples)!!!\n', rfid_params(3));
               t1_samples = rfid_params(2) * 5;
               st2_val = 5;
           end
       end 
       
       if (st2_val == 5) %decode of bits
           
           if (rfid_data(i) > pie_threshold)
            tag_samples = [tag_samples abs(rfid_data(i))];
           end
           
           if (ty_edge == -1)
               m = i - lre_pos;
               lre_pos = i;           
               
               if (m < pie_pivot)
                   pie_bits = [pie_bits 0];
                   tag_samples = [];
               elseif (m < t1_samples)
                   pie_bits = [pie_bits 1];
                   tag_samples = [];
               else %invalid PIE symbol here.
                   %send the bits and the TRCAL values for decoding.
                   [mtype,tfreq] = pie_decoding(pie_bits, rfid_params(3), Fs);
                   %calculate the parameters
                   srate_tag = (1/tfreq)*Fs;
                   fprintf('Expected Tag Samples per Symbol %d...\n', srate_tag);
                   %send the data for Tag Decoding
                   
                   tag_bits = rfid_gen2_tag_decode(tag_samples,mtype,srate_tag);
                   tag_rn16 = bi2de(tag_bits);
                   
                   fprintf('Possible RN16 decoded from tag: %d...\n', tag_rn16);
                   
                   tag_samples = []; %clean
                   while (abs(rfid_data(i)) > pie_threshold) %skip samples to the next falling edge
                     i = i + 1;
                   end
                   status = 1;
                   st2_val = 0;
               end
           end
       end
       
       
       last_sample = csam;    
    end
    
    i = i + 1;
    
end


plot(abs(rfid_data))
