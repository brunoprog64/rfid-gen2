function [y] = rfid_gen2_check_tag_exists( rx_signal, modul_type, samp_rate )

%rfid_gen2_check_tag_exists() --- Function to check is there is a reply
%from a tag

%This function will just correlate to the preamble. It is just created to
%avoid overhead of calling the complete decodal one. Outputs a 1 if there
%is preamble and 0 if not.

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au

    %the approach is to decode by correlation
    fm0_preamble_bits = [1 1 -1 1 -1 -1 1 -1 -1 -1 1 1];
    pream_bits_m2 = [1 -1 1 -1 1 -1 -1 1 -1 1 -1 1 -1 1 1 -1 1 -1 -1 1 -1 1 1 -1];
    pream_bits_m4 = [1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 -1 1 -1 1 1 -1 1 -1 1 -1 1 -1 -1 1 -1 1 1 -1 1 -1 1 -1 1 -1 -1 1 -1 1 -1 1 -1 1 1 -1 1 -1];
    pream_bits_m8 = [1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 -1 1 1 -1 1 -1 1 -1 1 -1];


    if (isempty(rx_signal) == 1)
      error('Need data to decode!!!');
    end

    %check if the signal is valid
    if ~(min(rx_signal) < 0 && max(rx_signal) > 0)
        error('Data do not seem to be valid. BPSK type data is expected.');
    end

    preamble_bits = [];
    div_value = 1;

    if (modul_type == 0) %FM0
      preamble_bits = fm0_preamble_bits;
      div_value = 2;
    elseif (modul_type == 1) %M=2
      preamble_bits = pream_bits_m2;
      div_value = 4;
    elseif (modul_type == 2)
      preamble_bits = pream_bits_m4;
      div_value = 8;
    elseif (modul_type == 3)
      preamble_bits = pream_bits_m8;
      div_value = 16;
    end

    %generate the preamble bit mask
    tag_preamble_mask = [];

    for i=1:length(preamble_bits)
      tag_preamble_mask = [tag_preamble_mask ones(1,samp_rate/div_value) * preamble_bits(i)];
    end

    pream_pos = 0;

    %Correlate for Preamble
    for i=1:length(rx_signal)-length(tag_preamble_mask)
      fsync_rx = rx_signal(i:i+length(tag_preamble_mask)-1);
      tmp = sum(fsync_rx .* tag_preamble_mask);
      total_pwr=sum(abs(fsync_rx));
      score= abs(tmp) /total_pwr;

      if (score > 0.9)
        pream_pos = i;
        %fprintf('[rfid_listener]: Tag preamble detected at %d with score %f...\n', i, score);
        break
      end
    end

    if (pream_pos > 0)
        y = 1;
    else
        y = pream_pos;
    end

end

