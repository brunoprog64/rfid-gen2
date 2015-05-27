function [pr_pos, thres_val] = rfid_gen2_find_threshold(rx_signal, thres)

%rfid_gen2_find_threshold() --- Function to find the initial threshold

%This function will take the derivative of the signal looking for big
%changes, and then it will check it the threshold exists for a long time
%(To avoid detecting short noise sparks)

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au

  if (nargin < 2)
      thres = 0.75;
  end
  
  pr_pos = 0;
  thres_val = 0;

  %we have a big change, look for it (Using diff())
  rfid_diff = diff(rx_signal);
  
  peak_thres = max(rfid_diff) * thres;
  
  if (peak_thres < thres)
    return;
  end
    
  %delim_samples = round(1.2e-3 * samp_rate);
  idx = find(rfid_diff > peak_thres);
  
  for i=1:length(idx)
      %check that the block has the 1.5 ms of setting
      values = rx_signal(idx(i):end);
      t_thres = rx_signal(idx(i));
      up_samples = length(find(values > t_thres));
      
      if (up_samples > length(values)*0.7) %if is a new block, it must be almost all the window
          pr_pos = idx(i);
          thres_val = max(values) * 0.7;
          break;
      end
  end
  
  
  