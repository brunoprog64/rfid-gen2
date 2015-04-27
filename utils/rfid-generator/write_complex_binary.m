%
% Copyright 2001 Free Software Foundation, Inc.
% 
% This file is part of GNU Radio
% 
% GNU Radio is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2, or (at your option)
% any later version.
% 
% GNU Radio is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with GNU Radio; see the file COPYING.  If not, write to
% the Free Software Foundation, Inc., 51 Franklin Street,
% Boston, MA 02110-1301, USA.
% -------------------------------------------------------------------------
% write_complex_binary(): Writes complex samples to a file that can then be
% used by a GNU Radio file source.
%
% Inputs:
% 
% - data: An array of complex samples.
% - filename: Name of the file that will be written.
%
% Example:
%
% write_complex_binary(complex_data, 'test_tone.dat');
% -------------------------------------------------------------------------
function v = write_complex_binary (data, filename)


    m = nargchk (2, 2, nargin);
    if m
        usage (m);
    end

    f = fopen (filename, 'wb');
    if (f < 0)
        v = 0;
    else
        
        data_real = real(data);
        data_imag = imag(data);

        interleaved = zeros(1, 2*length(data_real));
        interleaved(1:2:end) = data_real;
        interleaved(2:2:end) = data_imag;
        v = fwrite (f, interleaved, 'float');
        fclose (f);
    end
end

