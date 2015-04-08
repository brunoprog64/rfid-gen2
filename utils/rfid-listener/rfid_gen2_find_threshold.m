function [pr_pos, thres_val] = rfid_gen2_find_threshold(rx_signal)

%do some quick sanity checks
if (mean(rx_signal) < 1) %no threshold changes in this block, skip
    pr_pos = 0;
    thres_val = 0;
    return;
end
    
%we have a big change, look for it. (Generally is the mean of the data)
thres_val = mean(rx_signal);

for i=1:length(rx_signal)-1
    if (rx_signal(i) >= thres_val)
        %find the aprox. begining
        if (rx_signal(i) > rx_signal(i+1)) %when the slope stops growing
            pr_pos = i;
            thres_val = rx_signal(i) * 0.75; %threshold
            break;
        end
    end
end



