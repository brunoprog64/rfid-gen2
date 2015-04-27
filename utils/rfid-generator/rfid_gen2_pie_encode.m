function [y] = rfid_gen_pie_encode(in_bits, rfid_config)

one_samp = rfid_config(1);
pw_samp = rfid_config(2);

pie_one = [ones(1,one_samp) zeros(1,pw_samp)];
pie_zero = [ones(1,pw_samp) zeros(1,pw_samp)];

pie_enc = [];

for i=1:length(in_bits)
    if (in_bits(i) > 0)
        pie_enc = [pie_enc pie_one];
    else
        pie_enc = [pie_enc pie_zero];
    end
end



y = pie_enc;