function [pr_pos, thres_val] = rfid_gen2_find_threshold(rx_signal, thres)

if (nargin < 2)
    thres = 0.75;
end
pr_pos = 0;

%we have a big change, look for it. (Generally is the mean of the data)
thres_val = mean(rx_signal) * thres;

for i=1:length(rx_signal)-1
    if (rx_signal(i) < thres_val && rx_signal(i+1) > thres_val) %change
        pr_pos = i+1;
        break;
    end
end



