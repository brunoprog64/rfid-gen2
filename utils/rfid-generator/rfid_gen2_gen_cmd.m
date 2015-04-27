function [y] = rfid_gen_cmd(cmd_type, args, rfid_params)

out_cmd = [];

switch cmd_type
    case 'QUERY'
        %args are DR, ModulType, PilotTone, and Q Value
        %(For now, Select, Target and Session are always 0)
        dr = args(1);
        modul = de2bi(args(2), 2, 'left-msb');
        trext = args(3);
        sel = [0 0];
        session = [0 0];
        target = 0;
        q_val = de2bi(args(4), 4, 'left-msb');
        tmp = [1 0 0 0 dr modul trext sel session target q_val];
        %generate the CRC
        crc = rfid_gen2_crc(tmp);
        qry_bits = [tmp crc];
        out_cmd = rfid_gen2_pie_encode(qry_bits, rfid_params);
    case 'ACK'
        rn16_no = args(1); %the arg is the decoded RN16
        tmp = de2bi(rn16_no,16, 'left-msb');
        ack_bits = [0 1 tmp];
        out_cmd = rfid_gen2_pie_encode(ack_bits, rfid_params);
    case 'NAK'
        nak_bits = [1 1 0 0 0 0 0 0];
        out_cmd = rfid_gen2_pie_encode(nak_bits, rfid_params);
    case 'QUERYREP'
        tmp = de2bi(args(1), 2, 'left-msb'); %the arg is the session (0 to 3)
        qrep_bits = [0 0 tmp];
        out_cmd = rfid_gen2_pie_encode(qrep_bits, rfid_params);
    case 'QUERY-ADJUST' 
        %the args are the session (0 to 3) and the UpDn (0,3,6)
        session_bits = de2bi(args(1),2, 'left-msb');
        updn_bits = de2bi(args(2),3, 'left-msb');
        qadj_bits = [1 0 0 1 session_bits updn_bits];
        out_cmd = rfid_gen2_pie_encode(qadj_bits, rfid_params);
    otherwise
        error('Invalid RFID command.');        
end

y = out_cmd;