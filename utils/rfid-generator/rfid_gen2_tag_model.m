function [y, rn16, coll] = rfid_gen2_tag_model(no_tags, tag_counter, tag_rn16, tag_config)

%fetch configuration [tag_bfreq modul_type tr_ext t1_sampl Fs]
base_freq = tag_config(1);
modul_type = tag_config(2);
tr_pream = tag_config(3);
t1_value = tag_config(4);
Fs = tag_config(5);
tag_amp = tag_config(6);

rn16 = 0;

%check if there is a tag to simulate.
tag_idx = find(tag_counter == 0);

if isempty(tag_idx) == 1
    %nothing to do
    tmp = round(t1_value*1e-6*Fs);
    y = zeros(1,tmp+500);
    coll = 0;
    return
end

if length(tag_idx) > 1
    coll = 1; %collision
    rn16 = randi(power(2,16));
else
    coll = 0;
    rn16 = tag_rn16(tag_idx(1));
end

%there are tags to decode
tag_delay = randi(t1_value, 1, length(tag_idx)); %delay for tags



%calculate the sample rate in samples
srate_or = round((1 / base_freq)*Fs);
srate = srate_or * (power(2,modul_type));


t_len = 50*srate;
tag_out = ones(1,t_len) * -1;
lzeros = 1;

for i=1:length(tag_delay)
    rn16_bits = de2bi(tag_rn16(i),16,'left-msb'); %the bits of the RN16
    rn16_bits = [rn16_bits 1]; %pad the 1 bit for end
    %correct the samp_rate

    tg_res = rfid_gen2_tag_encode(rn16_bits, tr_pream, modul_type, srate);
    
    t_out = [zeros(1, tag_delay(i)) tg_res];
    lzeros = length(t_out);
    
    if (length(t_out) > lzeros)
        lzeros = length(t_out);
    end
    
    t_out = [t_out zeros(1,t_len - length(t_out))];
    tag_out = tag_out + t_out;
end

%count the zeros

tag_out = [tag_out(1:lzeros) ones(1,round(200*1e-6*Fs))*-1];
y = (tag_out + 1) * tag_amp;
