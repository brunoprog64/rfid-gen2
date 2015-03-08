function [y,tfq] = pie_decoding(bits, tr_val, Fs)
    %try to find which command has been used.
    %Look only for QUERY, QREP, ACK, NAK.
    %return Modul Type and Tag Frequency.
    
    y = 9; %no encoding
    tfq = 0; %no tag.
    if (length(bits) < 2)
        fprintf('Invalid PIE command...\n');
        return
    end
    i = 1;
    fprintf('*****PIE Decoder*****\n');
    while (i <= length(bits))
        
        %always check that we can read 2 bits
        if (i + 1 > length(bits))
            fprintf('Unexpected end...\n');
            break;
        end
        
        cmd_head = bi2de(bits(i:i+1), 'left-msb');
    
        switch (cmd_head)
            case 0 %QREP
                qrep_ses = bi2de(bits(i+2:i+3));
                fprintf('QREP Command detected at session %d...\n', qrep_ses);
                i = i + 3;
            case 1 %ACK
                ack_rn16 = bi2de(bits(i+2:i+17), 'left-msb');
                fprintf('ACK Command with RN16 %d...\n', ack_rn16);
                i = i + 17;
            case 2 %QUERY
                i = i + 4;
                
                if (bits(i) == 0)
                    q_dr = 8;
                else
                    q_dr = 64/3;
                end
                q_m = bi2de(bits(i+1:i+2), 'left-msb');
                y = q_m;
                
                q_trext = bits(i+3);
                q_qval = bi2de(bits(i+4:i+7), 'left-msb');
                
                
                fprintf('QUERY Command detected...\n');
                
                q_blf = q_dr / (tr_val / Fs);
                tfq = q_blf;
                fprintf(' -> Tag frequency at %f KHz...\n', (q_blf / 1000));
                
                if (q_trext == 0)
                    fprintf(' -> Extended Preamble active...\n');
                else
                    fprintf(' -> Short Preamble active...\n');
                end
                fprintf(' -> Modulation ');
                if (q_m == 0)
                    fprintf('FM0');
                elseif (q_m == 1)
                    fprintf('Miller M=2');
                elseif (q_m == 2)
                    fprintf('Miller M=4');
                else
                    fprintf('Miller M=8');
                end
                fprintf(' used for tags...\n');
                fprintf(' -> Q Value of %d, so %d slots for tags...\n', q_qval, power(2,q_qval));
                i = i + 17;
                
            case 3 %NAK
                fprintf('NAK command detected...\n');
                i = i + 7;
        end
        
        i = i + 1;
    end

end