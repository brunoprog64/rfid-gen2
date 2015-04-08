function [tari, rtcal, trcal, pivot, pos, success] = rfid_gen2_get_reader_config( rx_signal, thres, samp_rate )
    
    rise_edge = [];
    for i=1:length(rx_signal)-1
        if (rx_signal(i) < thres && rx_signal(i+1) > thres)
            rise_edge = [rise_edge i];
        end
        
        if (length(rise_edge) == 4) %we are only interested on the config
            break;
        end
    end
    
    tari = 0;
    rtcal = 0;
    trcal = 0;
    pivot = 0;
    pos = 0;
    success = 1;
    
    if length(rise_edge) < 4
        success = -1;
        return; %nothing to do
    end
    
    tari = rise_edge(2) - rise_edge(1);
    rtcal = rise_edge(3) - rise_edge(2);
    trcal = rise_edge(4) - rise_edge(3);
    pivot = round(rtcal / 2);
    
    %compute the pivot
    pos = rise_edge(end);        
    
    if (tari == 0)
        success = -1;
    end
    
    %check the constraints
    
    %Tari must be 6.25 to 25 us.
    t_l = samp_rate * 5.20*1e-6;
    t_u = samp_rate * 26*1e-6;
    
    if (tari > t_u || tari < t_l)
        fprintf('[rfid_listener]: Tari value is invalid!!!\n');
        success = -1; %invalid status
    end
    
    %RTCAL must be between 2.5 and 3Tari
    if ((rtcal > 3.5*tari) || (rtcal < 2.1*tari))
        fprintf('[rfid_listener]: RTCAL value is invalid!!!\n');
        success = -1; %invalid status
    end
    
    %TRCAL must be between 1.1 and 3 RTCAL
    if ((trcal > 3.5*rtcal) || (trcal < 0.7*rtcal))
        fprintf('[rfid_listener]: TRCAL value is invalid!!!\n');
        success = -1; %invalid status
    end

end

