function [cmd_type, cmd_args] = rfid_gen2_pie_bdeco(bits_deco, tr_val, Fs)
%For now only: QUERY, QUERYREP, ACK, QUERY_ADJUST, NAK

cmd_type = 'UKW';
cmd_args = [];

if (length(bits_deco) < 5) %min bits for a command are 4 bits.
    return;
end

state = 0;
i = 1;

while (i <= length(bits_deco))
    switch state
        case 0 %grab 2 bits
            head_bits = bi2de(bits_deco(i:i+2-1), 'left-msb');
            i = i + 2;
            state = head_bits + 1;
        case 1 %QUERY-REP
            qrep_session = bits_deco(i:i+2-1);
            fprintf('[rfid_listener]: QUERY-REP command detected...\n');
            fprintf(' -> Session Number for this QUERY-REP is %d\n', bi2de(qrep_session, 'left-msb'));
            fprintf(' -> Decrementing -1 the tags internal counter...\n\n');
            i = i + 2;
            state = 0;
            
            cmd_type = 'QREP';
            cmd_args = bi2de(qrep_session, 'left-msb');
            
        case 2 %ACK
            rn16_bits = bits_deco(i:i+16-1);
            fprintf('[rfid_listener]: ACK command detected...\n');
            fprintf(' -> ACK RN16 value: %d\n', bi2de(rn16_bits));
            g = sprintf('%d', rn16_bits);
            fprintf(' -> ACK RN16 bits value: %s \n\n', g);
            i = i + 16;
            state = 0;
            
            cmd_type = 'ACK';
            cmd_args = bi2de(rn16_bits);
            
        case 3 %QUERY / QUERY ADJUST
            qry_type = bi2de(bits_deco(i:i+2-1), 'left-msb');
            if (qry_type > 0)
                state = 6;
            else
                state = 5;
            end
            i = i + 2;
        case 4 %NAK
            fprintf('[rfid_listener]: NAK command detected...\n\n');
            i = i + 6;
            state = 0;
            
            cmd_type = 'NAK';
            cmd_args = 0;
            
        case 5 %QUERY Decodal
            fprintf('[rfid_listener]: QUERY command detected...\n');
            if (bits_deco(i) == 0)
                q_dr = 8;
            else
                q_dr = 64/3;
            end
            q_m = bi2de(bits_deco(i+1:i+2), 'left-msb');
  
            q_trext = bits_deco(i+3);
            q_qval = bi2de(bits_deco(i+4:i+7), 'left-msb');
            
            q_blf = q_dr / (tr_val / Fs);
            fprintf(' -> Tag frequency at %f KHz...\n', (q_blf / 1000));

            if (q_trext == 1)
                fprintf(' -> Using pilot tone (Extended preamble)...\n');
            else
                fprintf(' -> Not using pilot tone...\n');
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
            i = i + 18;
            state = 0;
            
            cmd_type = 'QRY';
            cmd_args = [q_blf, q_trext, q_m, q_qval, power(2,q_qval)]; %freq, preamble, modulation, q_value, q_slots
        case 6 %QUERY ADJUST decodal
            qry_session = bi2de(bits_deco(i:i+2-1), 'left-msb');
            i = i + 2;
            q_chg = bi2de(bits_deco(i:i+3-1), 'left-msb');
            fprintf('[rfid_listener]: QUERY-ADJUST command detected...\n');
            fprintf(' -> Session Number for this QUERY-ADJUST is %d\n', qry_session);
            fprintf(' -> Q Changed with data... %d\n\n', q_chg);
            i = i + 3;
            state = 0;
            
            cmd_type = 'QADJ';
            cmd_args = [qry_session, q_chg];
    end
end