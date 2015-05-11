function [best_tag, is_deco_data] = rfid_gen2_fastica_tags(tag_rx1, tag_rx2, modul_type, samp_rate)

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
    
    %debug
    %figure
    %subplot(2,1,1);
    %plot(tags_ica(1,:));
    %subplot(2,1,2);
    %plot(tags_ica(2,:));
    
    %Choose the best signal
    
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
    
    best_tag = tags_ica(bpos,:);
    
end
