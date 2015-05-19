function [y] = rfid_gen2_check_collision(rx_tag, modul_type, samp_rate, threshold, wnd_peaks)

%This function will look for peaks that follow the sampling rate and will return 0 if
%most of the peaks comply and 1 if otherwise

%Low SNR will cause this function to fail as well as collision. In both cases, the
%FastICA will be used.

if (nargin < 4)
  threshold = 0.7; %threshold for peaks
  wnd_peaks = 3; %window for looking for peaks
end

diff_tag = abs(diff(rx_tag)); %get the peaks of the square wave
rfid_thres = max(diff_tag)*threshold - (mean(diff_tag) + std(diff_tag)); %define a threshold

rf_peaks = [];

%find peaks
for i=wnd_peaks+1:wnd_peaks:length(diff_tag)-wnd_peaks %window because of the slow decay of the square wave
   if (diff_tag(i) > diff_tag(i-wnd_peaks) && diff_tag(i) > diff_tag(i+wnd_peaks))
     if (diff_tag(i) > rfid_thres) 
       rf_peaks = [rf_peaks i];
     end
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
