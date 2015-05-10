#!/usr/bin/env python
#Developed by: Michael Buettner (buettner@cs.washington.edu)
#Modified by: Bruno Espinoza (bruno.espinozaamaya@uqconnect.edu.au)

from gnuradio import gr, gru
from gnuradio import blocks
from gnuradio import eng_notation
from gnuradio import analog,blocks,digital,filter
from gnuradio.eng_option import eng_option
from string import split
from string import strip
from string import atoi
import time
import os
import math
import rfid
import optparse



#parser for frequency and other options
parser = optparse.OptionParser();
parser.add_option('--f', action="store", dest="file_in", default="rx.out", help="File Name with Capture");
parser.add_option('--l', action="store", dest="log_file", default="log_out.log", help="Log file name");
parser.add_option('--q', action="store", dest="q_value", default="0", help="Q value from 0 to 8");
parser.add_option('--m', action="store", dest="modul_type", default="1", help="Modulation Type from 0 to 3 -> 0: FM Encoding, 1: Miller M=2, 2: Miller M=4, 3: Miller M=8");

options, args = parser.parse_args();

log_file = open(options.log_file, "a")
mtype = int(options.modul_type)
qval = int(options.q_value)
f_in = options.file_in

modul_msg = ["FM0", "Miller M=2", "Miller M=4", "Miller M=8"];

if mtype > 3 or mtype < 0:
    mtype = 1;

if (qval > 8 or qval < 0):
    qval = 0

slots = pow(2,qval);

print "* Using", modul_msg[mtype], "modulation for tags..."
print "* Q Value of", str(qval), "so", str(slots), "slots assigned for tags..."


class my_top_block(gr.top_block):
    def __init__(self):
        gr.top_block.__init__(self)

        amplitude = 5000
        sw_dec = 5
        num_taps = 25
        samp_rate = 8e5
        
        taps = [complex(1,1)] * num_taps
        matched_filt = filter.fir_filter_ccc(sw_dec, taps); 
        

        agc = analog.agc2_cc(0.3, 1e-3, 1, 1)
        agc.set_max_gain(100)

        to_mag = blocks.complex_to_mag()

        center = rfid.center_ff(10)

        omega = 5
        mu = 0.25
        gain_mu = 0.25
        gain_omega = .25 * gain_mu * gain_mu
        omega_relative_limit = .05

        mm = digital.clock_recovery_mm_ff(omega, gain_omega, mu, gain_mu, omega_relative_limit)
        
        mtype = int(options.modul_type)
        qval = int(options.q_value)
        
        if (mtype > 3 or mtype < 0):
            mtype = 1 #Miller M=2 by default
        
        if qval > 8 or qval < 0:
            qval = 0;
        
        
        self.reader = rfid.reader_f(int(500e3), mtype, qval, 5, 10)

        tag_decoder = rfid.tag_decoder_f()
        command_gate = rfid.command_gate_cc(12, 250, int(800e3))

        to_complex = blocks.float_to_complex()
        amp = blocks.multiply_const_ff(amplitude)
        
        tx = blocks.null_sink(gr.sizeof_gr_complex*1)
        rx = blocks.file_source(gr.sizeof_gr_complex*1,f_in, False) #no repeat

        rx_throtle = blocks.throttle(gr.sizeof_gr_complex*1, samp_rate,True)

        command_gate.set_ctrl_out(self.reader.ctrl_q())
        tag_decoder.set_ctrl_out(self.reader.ctrl_q())

#########Build Graph
        #self.connect(rx, rx_throtle, matched_filt)
        #self.connect(matched_filt, command_gate)
        self.connect(rx, rx_throtle,command_gate)
        self.connect(command_gate, agc)
        self.connect(agc, to_mag)
        self.connect(to_mag, center, mm, tag_decoder)
        self.connect(tag_decoder, self.reader, amp, to_complex, tx);
#################
        f_rxout = blocks.file_sink(gr.sizeof_gr_complex, 'file.out');
        self.connect(command_gate, f_rxout)
    
def main():


    tb = my_top_block()

    tb.start()
    while 1:

        c = raw_input("'Q' to quit. L to get log.\n")
        if c == "q":
            break

        if c == "L" or c == "l":
            log_file.write("T,CMD,ERROR,BITS,SNR\n")
            log = tb.reader.get_log()
            print "Log has %s Entries"% (str(log.count()))
            i = log.count();


            for k in range(0, i):
                msg = log.delete_head_nowait()
                print_log_msg(msg, log_file)

    tb.stop()

def print_log_msg(msg, log_file):
    LOG_START_CYCLE, LOG_QUERY, LOG_ACK, LOG_QREP, LOG_NAK, LOG_REQ_RN, LOG_READ, LOG_RN16, LOG_EPC, LOG_HANDLE, LOG_DATA, LOG_EMPTY, LOG_COLLISION, LOG_OKAY, LOG_ERROR = range(15)


    fRed = chr(27) + '[31m'
    fBlue = chr(27) + '[34m'
    fReset = chr(27) + '[0m'


    if msg.type() == LOG_START_CYCLE:
        fields = split(strip(msg.to_string()), " ")
        print "%s\t Started Cycle" %(fields[-1])
        log_file.write(fields[-1] + ",START_CYCLE,0,0,0\n");

    if msg.type() == LOG_QUERY:
        fields = split(strip(msg.to_string()), " ")
        print "%s\t Query" %(fields[-1])
        log_file.write(fields[-1] + ",QUERY,0,0,0\n");

    if msg.type() == LOG_QREP:
        fields = split(strip(msg.to_string()), " ")
        print "%s\t QRep" %(fields[-1])
        log_file.write(fields[-1] + ",QREP,0,0,0\n");

    if msg.type() == LOG_ACK:
        fields = split(strip(msg.to_string()), " ")
        print "%s\t ACK" %(fields[-1])
        log_file.write(fields[-1] + ",ACK,0,0,0\n");

    if msg.type() == LOG_NAK:
        fields = split(strip(msg.to_string()), " ")
        print "%s\t NAK" %(fields[-1])
        log_file.write(fields[-1] + ",NAK,0,0,0\n");


    if msg.type() == LOG_RN16:
        fields = split(strip(msg.to_string()), " ")
        rn16 = fields[0].split(",")[0]
        snr = strip(fields[0].split(",")[1])
        tmp = int(rn16,2)

        if msg.arg2() == LOG_ERROR:

            print "%s\t    %s RN16 w/ Error: %04X%s" %(fields[-1],fRed, tmp, fReset)
            log_file.write(fields[-1] + ",RN16,1," +"%04X" % tmp  + ","+snr + "\n");
        else:
            print "%s\t    %s RN16: %04X%s" %(fields[-1],fBlue, tmp, fReset)
            log_file.write(fields[-1] +",RN16,0," + "%04X" % tmp + "," +snr + "\n");


    if msg.type() == LOG_EPC:
        fields = split(strip(msg.to_string()), " ")
        epc = fields[0].split(",")[0]
        snr = strip(fields[0].split(",")[1])
        epc = epc[16:112]

        tmp = int(epc,2)
        if msg.arg2() == LOG_ERROR:
            print "%s\t    %s EPC w/ Error: %024X%s" %(fields[-1],fRed, tmp, fReset)
            log_file.write(fields[-1] + ",EPC,1," + "%024X" % tmp + ","+snr + "\n");
        else:
            print "%s\t    %s EPC: %024X%s" %(fields[-1],fBlue, tmp, fReset)
            log_file.write(fields[-1] +",EPC,0," + "%024X" % tmp + "," +snr + "\n");

    if msg.type() == LOG_EMPTY:
        fields = split(strip(msg.to_string()), " ")
        snr = strip(fields[0])
        print "%s\t    - Empty Slot - " %(fields[-1])
        log_file.write(fields[-1] + ",EMPTY,0,0,"+snr+"\n");

    if msg.type() == LOG_COLLISION:
        fields = split(strip(msg.to_string()), " ")
        print "%s\t    - Collision - " %(fields[-1])
        log_file.write(fields[-1] + ",COLLISION,0,0,0\n");


if __name__ == '__main__':
    main()
