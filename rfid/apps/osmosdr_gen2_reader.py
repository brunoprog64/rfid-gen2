#!/usr/bin/env python
#Developed by: Michael Buettner (buettner@cs.washington.edu)
#Modified by: Bruno Espinoza (bruno.espinozaamaya@uqconnect.edu.au)

from gnuradio import gr, gru
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
import osmosdr


#parser for frequency and other options
parser = optparse.OptionParser();
parser.add_option('--f', action="store", dest="center_freq", default="910e6", help="Center Frequency", type="float");
parser.add_option('--g', action="store", dest="rx_gain", default="20", help="RX Gain", type="float");
parser.add_option('--l', action="store", dest="log_file", default="log_out.log", help="Log file name");
parser.add_option('--d', action="store", dest="dump_file", default="none", help="[none|matched|full]");
parser.add_option('--s', action="store", dest="device", default="uhd", help="[uhd|bladerf]");
parser.add_option('--q', action="store", dest="q_value", default="0", help="Q value from 0 to 8");
parser.add_option('--m', action="store", dest="modul_type", default="1", help="Modulation Type from 0 to 3 -> 0: FM Encoding, 1: Miller M=2, 2: Miller M=4, 3: Miller M=8");
parser.add_option('--c', action="store", dest="cycles_num", default="5", help="Number of Reader Cycles (def. 5)");
parser.add_option('--r', action="store", dest="round_num", default="10", help="Number of Rounds per Cycle (def. 10)");


options, args = parser.parse_args()

log_file = open(options.log_file, "a")
dump_type = options.dump_file
mtype = int(options.modul_type)
qval = int(options.q_value)
n_cycle = int(options.cycles_num)
n_round = int(options.round_num)

if dump_type == "none":
    print "* Alert: Skipping dumping of the rx block..."
elif dump_type == "full":
    print "** Using a full dump of the RX block!!"
elif dump_type == "matched":
    print "** Using dump of the match_filter block!!"
else:
    print "Unknown dump_type flag!! Set to 'none'"
    dump_type = 'none'
    
if options.device == "uhd":
    print "Using USRP devices..."
else:
    print "Using bladeRF device..."

modul_msg = ["FM0", "Miller M=2", "Miller M=4", "Miller M=8"];

if mtype > 3 or mtype < 0:
    mtype = 1;

if (qval > 8 or qval < 0):
    qval = 0

slots = pow(2,qval);

print "* Using", modul_msg[mtype], "modulation for tags..."
print "* Q Value of", str(qval), "so", str(slots), "slots assigned for tags..."
print "* Reader using", str(n_cycle), "cycles with", str(n_round), "rounds per cycle..."


class my_top_block(gr.top_block):
    def __init__(self):
        gr.top_block.__init__(self)

        amplitude = 5000
        sw_dec = 5 #For reduce the sample rate after the filtering. (4MS / 5 = 800 KS/s)
        samp_rate = 4e6 # corresponds to dec_rate 16. (64M/16)

        #Filter mathced to 1/4 of 40 KHz tag cycle.
        #40 KHz = 100 samples, so 1/4 is 25 samples.
        #num_taps = int(64000 / ( (dec_rate * 4) * 40 )) #Filter matched to 1/4 of the 40 kHz tag cycle
        num_taps = 25
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
        
        #clock recovery
        mm = digital.clock_recovery_mm_ff(omega, gain_omega, mu, gain_mu, omega_relative_limit)
        
        mtype = int(options.modul_type)
        qval = int(options.q_value)
        
        if (mtype > 3 or mtype < 0):
            mtype = 1 #Miller M=2 by default
        
        #qval = int(options.q_value)
        if qval > 8 or qval < 0:
            qval = 0;
        
        n_cycle = int(options.cycles_num)
        n_round = int(options.round_num)
        
        self.reader = rfid.reader_f(int(500e3), mtype, qval, n_cycle, n_round)
        tag_decoder = rfid.tag_decoder_f()
        
        #The parameters for command_gate_cc are:
        # - PW: 12 us. (Negative part of the PIE pulses)
        # - T1: 250 us (Maximium timeout for the tag to reply).
        # - Sample Rate. (800 KS/s after the matched filter)
        command_gate = rfid.command_gate_cc(12,250, int(800e3)) #800 KS/s.

        to_complex = blocks.float_to_complex()
        amp = blocks.multiply_const_ff(amplitude)
#TX
        freq = options.center_freq #915e6
        rx_gain = options.rx_gain #20
        
        if (options.device == "uhd"):
            tx = osmosdr.sink("uhd,type=usrp1")
            tx.set_gain(0, 'DAC-pga') #range -20 to 0.
            tx.set_antenna('TX/RX')            
        else:
            #bladeRF
            tx = osmosdr.sink("bladerf=0") 
            tx.set_gain(-4, 'VGA1')
            tx.set_gain(24, 'VGA2')
        
        #Settings for Backscatter = VGA1 = -4 / VGA2 = 20 
        
        tx.set_sample_rate(500e3)
        tx.set_center_freq(freq)
        
        if not tx:
            print "Couldn't set tx freq"
            
            
#End TX

#RX
        if (options.device == "uhd"):
            rx = osmosdr.source("uhd,type=usrp1")
            rx.set_gain(20, 'PGA0')
            rx.set_gain(15, 'ADC-pga')
            rx.set_antenna('RX2')
        else:
            #bladeRF
            rx = osmosdr.source("bladerf=0")
            rx.set_gain(0, 'LNA')
            rx.set_gain(5, 'VGA1')
            rx.set_gain(5, 'VGA2')
        
        rx.set_sample_rate(samp_rate)
        rx.set_center_freq(freq)
        #rx.set_iq_balance_mode(0, 0)
        #rx.set_dc_offset_mode(0, 0)        
        
        if not rx:
            print "Couldn't set rx freq"

#End RX
        command_gate.set_ctrl_out(self.reader.ctrl_q())
        tag_decoder.set_ctrl_out(self.reader.ctrl_q())
        
#########Build Graph
        self.connect(rx, matched_filt)
        self.connect(matched_filt, command_gate)
        self.connect(command_gate, agc)
        self.connect(agc, to_mag)
        self.connect(to_mag, center, mm, tag_decoder)
        self.connect(tag_decoder, self.reader, amp, to_complex, tx);
#################

		#Output dumps for debug
        
        #self.connect(to_complex, f_txout);
        if dump_type == "matched": 
            f_rxout = blocks.file_sink(gr.sizeof_gr_complex, 'f_rxout.out');
            self.connect(matched_filt, f_rxout)
            #f_rxout = blocks.file_sink(gr.sizeof_float, 'f_rxout.out');
            #self.connect(mm, f_rxout)
        
        if dump_type == "full":
            f_rxout = blocks.file_sink(gr.sizeof_gr_complex, 'f_rxout.out');
            self.connect(rx, f_rxout)
            
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
