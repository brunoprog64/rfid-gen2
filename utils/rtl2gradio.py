#!/usr/bin/env python
# rtl2gradio.py: rtl_sdr dump files to gnuradio format converter 
 
# Original code by Salvatore Sanfilippo (https://www.ruby-forum.com/topic/4409202)
# Ported by Bruno Espinoza (bruno.espinozaamaya@uqconnect.edu.au)

#This program takes I/Q files sampled at 8 bits [int] and convert them to 32 bits [float] I/Q.

import sys
import struct

def main():
    arg_len = len(sys.argv)
    
    if (arg_len < 3):
        show_usage()
        return
    try:
        fin = open(sys.argv[1], 'rb')
        fout = open(sys.argv[2], 'w')
    
    except:
        print "File I/O error. Aborting"
        sys.exit(1)
    
    #File is just a big block of 8 bits integers that are I/Q values.
    #We convert that to blocks of 32 bits floats I/Q.
    
    print "Converting file", sys.argv[1], "to GNU Radio format..."
    
    count = 0
    r_byte = fin.read(2)
    while r_byte != "":
        in_byte = struct.unpack('BB', r_byte)
        
        i_val = (in_byte[0] - 127) *(1.0/128)
        q_val = (in_byte[1] - 127) *(1.0/128)
        
        fout.write(struct.pack('ff', i_val, q_val))
        count = count + 1
        r_byte = fin.read(2)
    
    fin.close()
    fout.close()
    print str(count), "I/Q samples converted. Done."
    
def show_usage():
    print "rtl2gradio.py: A RTL-SDR to GNU Radio file converter"
    print "Original code by Salvatore Sanfilippo (https://www.ruby-forum.com/topic/4409202)"
    print "Ported by Bruno Espinoza (bruno.espinozaamaya@uqconnect.edu.au)";
    print "\nUsage: rtl_to_gradio <rtl_file.dmp> <gradio_file.dmp>\n";
    sys.exit(0)

if __name__ == "__main__":
    main()
