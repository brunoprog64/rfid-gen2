function v = read_complex_byte(filename, count)
%% usage: read_complex_byte (filename, [count])
%%
%% open filename and return the contents as a column vector,
%% reading 8bit unsigned, and treating them as doubles (and normalizing
%% to (+/- 1)
%%
% if ((m = nargchk (1,2,nargin)))
% usage (m);
% endif;
if (nargin < 2)
count = Inf;
end;
f = fopen (filename, 'rb');
if (f < 0)
v = 0;
else
t = fread (f, [2, count], 'uint8=>double');
fclose (f);
v = t(1,:)-127 + (t(2,:)-127)*1i;
v = v / 128;
[r, c] = size (v);
v = reshape (v, c, r);
end;
