function [tari, rtcal, trcal, pivot, pos, success] = rfid_gen2_get_reader_config( rx_signal, thres, samp_rate )
%rfid_gen2_get_reader_config() --- Function to obtain Tari, RTCAL and TRCAL

%This function will count rising edges and compute the Tari, RTCAL and
%TRCAL values from the signal. If the values are invalid, it will return
%-1, if not, it will return the values

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au

    rise_edge = [];
    l = 0;
    for i=1:length(rx_signal)-1
        if (rx_signal(i) < thres && rx_signal(i+1) > thres)
            rise_edge = [rise_edge i-l];
            l = i;
        end
    end
    
    tari = 0;
    rtcal = 0;
    trcal = 0;
    pivot = 0;
    pos = 0;
    inval_code = 0;
    
    if length(rise_edge) < 4
        success = -1;
        return; %nothing to do
    end
    
    for i=1:length(rise_edge)-2
    
      success = 1;
    
      tari = rise_edge(i);
      rtcal = rise_edge(i+1);
      trcal = rise_edge(i+2);
      pivot = round(rtcal / 2);
      
      pos = sum(rise_edge(1:i+2));
      
      %check the constraints
      
      %Tari must be 6.25 to 25 us.
      t_l = samp_rate * 5.20*1e-6;
      t_u = samp_rate * 26*1e-6;
      
      if (tari > t_u || tari < t_l)
          success = -1; %invalid status ~ Tari
      end
      
      %RTCAL must be between 2.5 and 3Tari
      if ((rtcal > 3.5*tari) || (rtcal < 2.1*tari))
          
          success = -2; %invalid status ~ RTCAL
      end
      
      %TRCAL must be between 1.1 and 3 RTCAL
      if ((trcal > 3.5*rtcal) || (trcal < 0.7*rtcal))
          
          success = -3; %invalid status ~ TRCAL
      end
      
      if (success == 1)
        break;
      end
      
    end
    
    if (success == 1 && i > 2)
      fprintf('[rfid-listener]: Warning!!! Unknown bits detected, but skipped...\n');
    end
    
    if (success == -1)
      fprintf('[rfid_listener]: Tari value is invalid!!!\n');
    end
    
    if (success == -2)
      fprintf('[rfid_listener]: RTCAL value is invalid!!!\n');
    end
    
    if (success == -3)
      fprintf('[rfid_listener]: TRCAL value is invalid!!!\n');
    end
    
end

