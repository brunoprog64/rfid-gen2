function [y] = rfid_gen2_check_collision(rx_tag, modul_type, samp_rate, threshold, wnd_peaks)
%rfid_gen2_check_collision() --- Function to check is there is a collision

%This function will look for peaks that follow the sampling rate and will return 0 if
%most of the peaks comply and 1 if otherwise

%Low SNR will cause this function to fail as well as collision. In both cases, the
%FastICA will be used.

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au)

if (nargin < 4)
  threshold = 0.75; %threshold for peaks
  wnd_peaks = 3; %window for looking for peaks
end

rx_tag = medfilt1(rx_tag, 10);

diff_tag = abs(diff(rx_tag)); %get the peaks of the square wave
rfid_thres = max(diff_tag)*threshold;

rf_peaks = [];

%find peaks
for i=wnd_peaks+1:length(diff_tag) - wnd_peaks
  if (diff_tag(i) < rfid_thres)
    continue;
  end
  
  cpeak_val = diff_tag(i);
  l_wnd_side = diff_tag(i - wnd_peaks);
  r_wnd_side = diff_tag(i + wnd_peaks);

  if (cpeak_val > l_wnd_side && cpeak_val > r_wnd_side)
    rf_peaks = [rf_peaks i];
    i = i + wnd_peaks;
  end
end

rf_spaces = [];
%find spaces
for i=1:length(rf_peaks)-1
  rf_spaces = [rf_spaces (rf_peaks(i+1) - rf_peaks(i))];
end

if (modul_type == 0)
  samp_divs = [samp_rate*0.5 samp_rate*1];
else
  samp_divs = [samp_rate/(2^modul_type) samp_rate/(2^(modul_type+1))];
end

r_pts = 0;
f_pts = 0;

%find the number of points
r1 = find(rf_spaces <= samp_divs(1)*1.25 & rf_spaces >= samp_divs(1)*0.85);
r2 = find(rf_spaces <= samp_divs(2)*1.25 & rf_spaces >= samp_divs(2)*0.85);

r_pts = length(r1) + length(r2);
f_pts = length(rf_spaces) - r_pts;


if (r_pts > f_pts)
  y = 0;
else
  y = 1;
end
