function [ y ] = rfid_gen2_crc( input_bits , crc_poly)
 
    if (nargin < 2)
        crc_poly = [1 0 1 0 0 1];
    end
    
    data_poly = [input_bits zeros(1,length(crc_poly))];
    pol_len = length(data_poly);
    
    while (pol_len >= length(crc_poly))
        %do the XOR
        crc_xor = [crc_poly zeros(1,(pol_len - length(crc_poly)))];
        xor_res = bitxor(data_poly, crc_xor);
        
        %pad 0s
        for i=1:length(xor_res)
            if (xor_res(i) ~= 0)
                break;
            end
        end
        data_poly = xor_res(i:end);
        pol_len = length(data_poly);
    end
    y = data_poly;
end

