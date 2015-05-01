function [deco_bits, last_redg] = rfid_gen2_pie_parser(rx_signal, reader_config)

thres = reader_config(1);
rtcal =  reader_config(3);
trcal = reader_config(4);
pivot = reader_config(5); 
Fs = reader_config(6);

rise_edge = [];
deco_bits = [];
l_bit = 1;

for i = 1:length(rx_signal)-1
    if (rx_signal(i) < thres && rx_signal(i+1) > thres)
        rise_edge = [rise_edge i];
        
        %any parameter more than 4*RTCal is invalid.
        
        if (i - l_bit > 4.2*rtcal)
            fprintf('[rfid_listener]: Invalid PIE symbol... skipping...\n');
            continue;
        end
        
        if (i - l_bit > pivot)
            deco_bits = [deco_bits 1];
        else
            deco_bits = [deco_bits 0];
        end
        l_bit = i;
    end
end

last_redg = 0;

%check the output
if (length(deco_bits) > 1)
    deco_bits = deco_bits(2:end);
    last_redg = rise_edge(end) + 1; %last rising edge
else
    deco_bits = 9; %non decodable.
end



