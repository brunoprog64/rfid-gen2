function [best_tag, is_deco_data] = rfid_gen2_fastica_tags(tag_rx1, tag_rx2, modul_type, samp_rate)

%rfid_gen2_fastica_tags() --- Function to recover a tag from a collision

%This function will use FastICA functions to try to recover a collision.
%Then it will select the 'best decodable' function, by decoding the tag and
%taking the sumation of the correlation scores per symbol.

%2015 by Bruno Espinoza. (bruno.espinozaamaya@uqconnect.edu.au

    %check if both RX are equal
    tag_length = 0;
    is_deco_data = 0;
    
    if (length(tag_rx1) == length(tag_rx2))
        tag_length = length(tag_rx1);
    else
        if length(tag_rx1) > length(tag_rx2)
            tag_length = length(tag_rx2);
        else
            tag_length = length(tag_rx1);
        end
    end

    tag_mix = zeros(2, tag_length);
    tag_mix(1,:) = tag_rx1(1:tag_length);
    tag_mix(2,:) = tag_rx2(1:tag_length);
    
    %do the F.ICA
    tags_ica = fastica(tag_mix,'approach', 'symm', 'verbose', 'off');
    %tags_ica = fastica(tag_mix,'verbose', 'off');
    
    best_tag = [];
    scores_signal = zeros(1, size(tags_ica,1));
    
    for i=1:size(tags_ica,1)
        [~, pream_pos, ~, scores] = rfid_gen2_tag_decode(tags_ica(i,:), modul_type, samp_rate);
        if (pream_pos > 0)
            scores_signal(i) = mean(scores);
        else
            scores_signal(i) = -999; %unrecoverable signal
        end
    end
    
    fprintf('\n[rfid_listener]: Scores from the ICA recovered Signals...:\n');
    disp(scores_signal)
    fprintf('\n');
    
    [mval, bpos] = max(scores_signal);
    
    if (mval == -999)
        fprintf('[rfid_listener]: Unable to recover any of the signals using ICA...\n');
    else
        fprintf('[rfid_listener]: Best ICA score match for the signal is Ch. %d RX antenna...\n', bpos);
        is_deco_data = 1;
    end
    
    best_tag = tags_ica(bpos,20:end);
end
