#!/usr/bin/env python
# coding: utf-8

'''
###############################################################################################################################################################
GEN2 RFID LISTENER v.2 and BUETTNER's READER
This script gives you the opportunity to run the GEN2 RFID Listener v.2 and the Buettner's reader (see Gen 2 RFID on CGRAN) on the same USRP v.1. You need 2 RFX900 daughterboard and 3 RFID antennas (2 for the Reader and 1 for the Listener). We strongly suggest to use this combination as to obtain best result. Infact, in this way you can perfectly configure Gen2 protocol parameters as for the listener as for the reader. We further modified the Buettner's code as to improve the receive chain. Morever, we added the possibility to modify the TX power by setting the desired amplitude value into the FPGA registers.  
###############################################################################################################################################################
EXECUTION INFOs
sudo PYTHONPATH=/usr/local/lib/python2.6/dist-packages/ GR_SCHEDULER=TPB nice -n -20 ./Gen2_RFID_Reader_Listener.py -f freq -m miller
- /usr/local/lib/python2.6/dist-packages/ --> substitute with your python installation directory
- nice -n -20                             --> high priority for the process
- GR_SCHEDULER=TPB                        --> GNUradio default Thread-Per-Block scheduler
###############################################################################################################################################################
'''

from gnuradio import gr, gru, window,  modulation_utils, listener, rfid
from gnuradio import usrp
from gnuradio import eng_notation
from gnuradio.gr import firdes
from gnuradio.blks2impl import psk
from gnuradio.eng_option import eng_option
from string import split
from string import strip
from string import atoi
from optparse import OptionParser
import time
import os
import sys
import math

'''
SETTINGS IMPORTANT PARAMETERS
In order to detect the preamble and correctly decode the messages transmitted by the tag some preliminary considerations must be taken into account. According to the Gen2 standard the reader chooses the up-link parameters and communicates them to the tags using the opening symbols of each packet (reader’s commands preamble). For this reason, decoding reader commands is required to access the up-link parameters and best tune-up in real-time both the "matched filter" and the “Tag Decoder” block (ref. Figure 7 of the Mobicom 2010 paper). Run this code together with the Buettner's reader you find on CGRAN. This permits best tuning of all parameters. 
''' 
up_link_freq      = 41.667  	# BLF your reader communicates to tags --> this is the value used by Buettner's reader
rtcal		  = 72          # Reader-To-Tag calibration (in microsec) of your reader --> this is the value used by Buettner's reader
dec_rate          = 32    	# decimation factor at USRP
sw_dec            = 4		# software decimation
samples_per_pulse = 6		# samples per pulse of the tag signal. It's calculated according as (1/(2*up_link_freq*1000))/((dec_rate*sw_dec)/64e6)
interp		  = 512         # USRP interpolation factor on the the Reader TX side
'''
With the previous defined decimation you can capture 2 MHz of band centered around the tuning frequency of the USRP. So if you choose 866.5 MHz as center frequency you can capture the entire UHF RFID band in Europe. If you are in US, since RFID occupies about 25 MHz of band, with such configuration you'll capture tags when the reader hops to a frequency that falls in the 2 MHz band you have set.
'''

# Buettner's reader ENUM
LOG_PWR_UP, LOG_QUERY, LOG_QREP, LOG_ACK, LOG_NAK, LOG_RN16, LOG_EPC, LOG_EMPTY, LOG_COLLISION, LOG_TIME_MISS, LOG_BAD_RN_MISS, LOG_ERROR, LOG_OKAY = range(13)

# Block connections      				                                                                       
class my_top_block(gr.top_block):
    def __init__(self, tx, zc, reader, rx, matched_filter, reader_monitor_cmd_gate, cr, tag_monitor, amplitude):
        gr.top_block.__init__(self)
               
        # ASK/PSK demodulators
     	to_mag_L = gr.complex_to_mag()
	to_mag_R = gr.complex_to_mag()
        
	# Others blocks for Buettner's reader
	samp_freq = (64 / dec_rate) * 1e6
	num_taps = int(64000 / (dec_rate * up_link_freq * 4))  
	taps = [complex(1,1)] * num_taps 
	filt = gr.fir_filter_ccc(sw_dec, taps) # Matched filter 
	amp = gr.multiply_const_cc(amplitude)
	c_gate = rfid.cmd_gate(dec_rate * sw_dec, reader.STATE_PTR)
	
 	# Null sink for terminating the Listener graph
	null_sink = gr.null_sink(gr.sizeof_float*1)

	# Deinterleaver to separate FPGA channels
        di = gr.deinterleave(gr.sizeof_gr_complex)

	# Enable real-time scheduling	
        r = gr.enable_realtime_scheduling()
    	if r != gr.RT_OK:
            print "Warning: failed to enable realtime scheduling"

	# Create flow-graph
	self.connect(rx, di)
	self.connect((di,0), filt, to_mag_R, c_gate, zc, reader, amp, tx)
	self.connect((di,1), matched_filter, to_mag_L, reader_monitor_cmd_gate, cr, tag_monitor, null_sink)	



# Main program       
def main():

    # Parsing command line parameter
    parser = OptionParser (option_class=eng_option)	
    parser.add_option("-f", "--freq", type="eng_float", dest="freq", default=866.5, help="set USRP center frequency (provide frequency in MHz)")
    parser.add_option("-m", "--miller", type="int", dest="miller", default=2, help="set number of Miller subcarriers (2,4 or 8)")
    (options, args) = parser.parse_args()	
    
    which_usrp = 0		
    fpga = "gen2_reader_2ch_mod_pwr.rbf" # Modified firmware --> you can set TX amplitude directly from Python (see below)
    freq = options.freq # Default value = 866.5 --> center frequency of 2 MHz European RFID Band
    freq = freq*1e6	
    miller = options.miller
    deviation_corr = 1 # Maximum deviation for Early/Late gate correlator in Buettner's reader	
    amplitude = 30000 # Amplitude of READER TX signal. 30000 is the maximum allowed. 	
    rx_gain = 20   									      									          
    us_per_sample = float (1 / (64.0 / (dec_rate*sw_dec)))		
    samp_freq = (64 / dec_rate) * 1e6						
    
    # BUETTNER'S READER HARDWARE SUB-SYSTEM for TX SIDE	
    tx = usrp.sink_c(which_usrp,fusb_block_size = 1024, fusb_nblocks=4, fpga_filename=fpga)
    tx.set_interp_rate(interp)
    tx_subdev = (0,0) # TX/RX port of RFX900 daugtherboard on SIDE A 
    tx.set_mux(usrp.determine_tx_mux_value(tx, tx_subdev))
    subdev = usrp.selected_subdev(tx, tx_subdev)
    subdev.set_enable(True)
    subdev.set_gain(subdev.gain_range()[2])
        
    t = tx.tune(subdev.which(), subdev, freq) # Tuning TX Daughterboard @ Center Frequency
    if not t:
        print "Couldn't set READER TX frequency"

    tx._write_fpga_reg(usrp.FR_USER_1, int(amplitude)) # SET FPGA register value with the desired tx amplitude		
    # END BUETTNER'S READER HARDWARE SUB-SYSTEM for TX SIDE

    # BUETTNER'S READER HARDWARE SUB-SYSTEM for RX SIDE		
    rx = usrp.source_c(which_usrp, dec_rate, nchan=2, fusb_block_size = 512, fusb_nblocks = 16, fpga_filename=fpga) # USRP source: 2 channels (reader + listener) 
    rx.set_mux(rx.determine_rx_mux_value((0,0), (1,0))) # 2 channel mux --> rx from (0,0) to reader - rx from (1,0) to listener
    rx_reader_subdev_spec = (0,0) # Reader RFX900 daugtherboard on SIDE A 
    rx_reader_subdev = rx.selected_subdev(rx_reader_subdev_spec)  
    rx_reader_subdev.set_gain(rx_gain)
    rx_reader_subdev.set_auto_tr(False)
    rx_reader_subdev.set_enable(True)
    rx_reader_subdev.select_rx_antenna('RX2') # RX2 port of RFX900 on side A --> RX antenna of Buettner's reader
    
    r = usrp.tune(rx, 0, rx_reader_subdev, freq) # Tuning READER RX Daughterboard @ Center Frequency
    if not r:
        print "Couldn't set READER RX frequency"
    # END BUETTNER'S READER HARDWARE SUB-SYSTEM for TX SIDE	

    # LISTENER HARDWARE SUB-SYSTEM
    rx_listener_subdev_spec = (1,0) # Listener DB RFX900 on side B				
    rx_listener_subdev = rx.selected_subdev(rx_listener_subdev_spec)	
    rx_listener_subdev.set_gain(rx_gain)						 
    rx_listener_subdev.set_auto_tr(False)
    rx_listener_subdev.set_enable(True)					
    rx_listener_subdev.select_rx_antenna('RX2') # RX Antenna on RX2 Connector of side B RFX900 (comment this line if you want TX/RX connector)
 
    r = usrp.tune(rx, 1, rx_listener_subdev, freq) # Tuning Listener Daughterboard @ Center Frequency
    if not r:
        print "Couldn't set LISTENER RX frequency"
    # END LISTENER HARDWARE SUB-SYSTEM     
    
          
    print ""
    print "********************************************************"
    print "************ Gen2 RFID Monitoring Platform *************" 
    print "********* Reader and Listener on the same USRP *********"
    print "********************************************************\n"

    print "USRP center frequency: %s MHz" % str(freq/1e6)
    print "Sampling Frequency: "+ str(samp_freq/1e6) + " MHz" + " --- microsec. per Sample: " + str(us_per_sample)
        
   
    # BUETTNER's READER SOFTWARE SUB-SYSTEM (GNU-Radio flow-graph)	
    gen2_reader = rfid.gen2_reader(dec_rate*sw_dec*samples_per_pulse, interp, int(miller), True, int(deviation_corr))	
    zc = rfid.clock_recovery_zc_ff(samples_per_pulse, 1, float(us_per_sample), float(up_link_freq), True)
    # END BUETTNER's READER SOFTWARE SUB-SYSTEM (GNU-Radio flow-graph)    

    # LISTENER SOFTWARE SUB-SYSTEM (GNU-Radio flow-graph)	
    # MATCHED FILTER
    num_taps = int(64000 / (dec_rate * up_link_freq * 4))  #Matched filter for 1/4 cycle
    taps = [complex(1,1)] * num_taps
    matched_filter = gr.fir_filter_ccc(sw_dec, taps)
    # Tag Decoding Block --> the boolean value in input indicate if real-time output of EPC is enabled or not 
    tag_monitor = listener.tag_monitor(True, int(miller), float(up_link_freq))	
    # Clock recovery
    cr = listener.clock_recovery(samples_per_pulse, us_per_sample, tag_monitor.STATE_PTR, float(up_link_freq))
    # Reader Decoding Block and Command gate--> the boolean value indicate if real-time output of reader commands is enabled or not 
    reader_monitor_cmd_gate = listener.reader_monitor_cmd_gate(False, us_per_sample, tag_monitor.STATE_PTR, float(up_link_freq), float(rtcal))
    # END LISTENER SOFTWARE SUB-SYSTEM (GNU-Radio flow-graph)

    # Create GNU-Radio flow-graph
    tb = my_top_block(tx, zc, gen2_reader, rx, matched_filter, reader_monitor_cmd_gate, cr, tag_monitor, amplitude)


    # Start application
    tb.start()
    
    # GETTING LOGs from BUETTNER's READER
    video_output = False # Set as True if you want real time video output of Buettner's reader logs
    log_reader_buettner_file = open("log_reader_buettner.log", "w")		
    finish=0;
    succ_reads=0;
    epc_errors=0;

    while 1:
	log_reader_buettner = gen2_reader.get_log()
	i = log_reader_buettner.count()
        for k in range(0, i):
                msg = log_reader_buettner.delete_head_nowait()
                print_msg(msg, log_reader_buettner_file, video_output) 
                if msg.type() == 99: # All cycles are terminated
			finish=1             	
		if msg.type() == LOG_EPC: # EPC
			if msg.arg2() == LOG_ERROR:
				epc_errors=epc_errors+1; # CRC Error on EPC  
			else: 
				succ_reads=succ_reads+1; # Successful EPc
	if finish:
	    break
    
    # Stop application
    tb.stop()
    log_reader_buettner_file.close()
    rec_frames = succ_reads+epc_errors	
    print "\nReader --> Total Received Frames: "+str(rec_frames)
    print "Reader --> Successful reads: "+str(succ_reads)
    print "Reader --> CRC error frames: "+str(epc_errors)	
    print ""

    # GETTING LOGs from LISTENER
    log_READER = reader_monitor_cmd_gate.get_reader_log()
    log_TAG    = tag_monitor.get_tag_log()
    print "Listener collected %s Entries for READER LOG" % str(log_READER.count())
    print "Listener collected %s Entries for TAG LOG" % str(log_TAG.count())
  
    c = raw_input("PRESS 'f' to write LOG files, 'q' to QUIT\n")
    if c == "q":
		print "\n Shutting Down...\n"
		return
    if c == "f":
		print "\n Writing READER LOG on file...\n\n"
		reader_file = open("reader_log.out","w")
    		reader_file.close()
		reader_file = open("reader_log.out","a")
		i = log_READER.count()    		
		for k in range(0, i):
    			decode_reader_log_msg(log_READER.delete_head_nowait(),reader_file)
        		k = k + 1
		reader_file.close()
   		
		print "\n Writing TAG LOG on file...\n"
		tag_file = open("tag_log.out","w")
    		tag_file.close()
		tag_file = open("tag_log.out","a")
		i = log_TAG.count();    		
		for k in range(0, i):
    			decode_tag_log_msg(log_TAG.delete_head_nowait(),tag_file)
        		k = k + 1
    		tag_file.close()



# Decode Buettner's Reader Messages
def print_msg(msg, log_file, video_output):
	LOG_PWR_UP, LOG_QUERY, LOG_QREP, LOG_ACK, LOG_NAK, LOG_RN16, LOG_EPC, LOG_EMPTY, LOG_COLLISION, LOG_TIME_MISS, LOG_BAD_RN_MISS, LOG_ERROR, LOG_OKAY = range(13)

	fRed = chr(27) + '[31m'
	fBlue = chr(27) + '[34m'
	fReset = chr(27) + '[0m'

	if msg.type() == LOG_PWR_UP:
        	fields = split(strip(msg.to_string()), " ")
       		if video_output == True:
			print "%s\t Power Up" %(fields[-1]) 
        	log_file.write(fields[-1] + ",PWR_UP,0,0,0\n");

    	if msg.type() == LOG_QUERY:
        	fields = split(strip(msg.to_string()), " ")
		if video_output == True:        
			print "%s\t Query" %(fields[-1]) 
        	log_file.write(fields[-1] + ",QUERY,0,0,0\n");

    	if msg.type() == LOG_QREP:
        	fields = split(strip(msg.to_string()), " ")
		if video_output == True:        
			print "%s\t QRep" %(fields[-1]) 
        	log_file.write(fields[-1] + ",QREP,0,0,0\n");

    	if msg.type() == LOG_ACK:
        	fields = split(strip(msg.to_string()), " ")
        	rn16 = fields[0].split(",")[0]
        	snr = strip(fields[0].split(",")[1])
        	tmp = atoi(rn16,2)
        	if msg.arg2() == LOG_ERROR:
			if video_output == True:            	
				print "%s\t%s ACKED w/ Error: %04X%s" %(fields[-1], fRed, tmp, fReset)
            		log_file.write(fields[-1] +",ACK,1," + str(hex(tmp))[2:] +"," + snr  +"\n")
        	else:
			if video_output == True:
            			print "%s\t ACKED: %04X%s" %(fields[-1], tmp, fReset)
            		log_file.write(fields[-1] +",ACK,0," + str(hex(tmp))[2:] + "," + snr +"\n");

    		if msg.type() == LOG_NAK:
        		fields = split(strip(msg.to_string()), " ")
			if video_output == True:        
				print "%s\t NAK" %(fields[-1])
        		log_file.write(fields[-1] + ",NAK,0,0,0\n");
    
	if msg.type() == LOG_RN16:
		if video_output == True:        
			print "LOG_RN16"
        
    	if msg.type() == LOG_EPC:
        	fields = split(strip(msg.to_string()), " ")
		if video_output == True:	        
			print fields[0]
        	epc = fields[0].split(",")[0]
        	snr = strip(fields[0].split(",")[1])
        	epc = epc[16:112]
        	tmp = atoi(epc,2)
        	if msg.arg2() == LOG_ERROR:
			if video_output == True:            
				print "%s\t    %s EPC w/ Error: %024X%s" %(fields[-1],fRed, tmp, fReset)
            		log_file.write(fields[-1] + ",EPC,1," + str(hex(tmp))[2:-1] + ","+snr + "\n");
        	else:
			if video_output == True:
            			print "%s\t    %s EPC: %024X%s" %(fields[-1],fBlue, tmp, fReset)
            		log_file.write(fields[-1] +",EPC,0," + str(hex(tmp))[2:-1] + "," +snr + "\n");

    	if msg.type() == LOG_EMPTY:
        	fields = split(strip(msg.to_string()), " ")
		if video_output == True:        
			print "%s\t    - Empty Slot - " %(fields[-1]) 
        	log_file.write(fields[-1] + ",EMPTY,0,0,0\n");

    	if msg.type() == LOG_COLLISION:
        	fields = split(strip(msg.to_string()), " ")
		if video_output == True:        
			print "%s\t    - Collision - " %(fields[-1]) 
        	log_file.write(fields[-1] + ",COLLISION,0,0,0\n");

    	if msg.type() == LOG_TIME_MISS:
        	fields = split(strip(msg.to_string()), " ")
		if video_output == True:        
			print "%s\t    %s Timing Miss%s" %(fields[-1],fRed, fReset)
        	log_file.write(fields[-1] + ",TIME_MISS,0,0,0\n");
    
    	if msg.type() == LOG_BAD_RN_MISS:
		fields = split(strip(msg.to_string()), " ")
		if video_output == True:        
			print "%s\t    %s Bad RN16 Miss%s" %(fields[-1],fRed, fReset)
        	log_file.write(fields[-1] + ",BAD_RN_MISS,0,0,0\n");

	

# Decode Reader Messages
def decode_reader_log_msg(msg,reader_file):
	LOG_QUERY, LOG_QREP, LOG_ACK, LOG_NAK, LOG_PWR_UP, LOG_ERROR, LOG_OKAY = range(7)

	if msg.type() == LOG_QUERY:
		fields = split(strip(msg.to_string()), " ")
        	reader_file.write(fields[-1] + "\tQUERY\n");

	if msg.type() == LOG_QREP:
		fields = split(strip(msg.to_string()), " ")
        	reader_file.write(fields[-1] + "\tQREP\n");

	if msg.type() == LOG_ACK:
		fields = split(strip(msg.to_string()), " ")
        	reader_file.write(fields[-1] + "\tACK\n");

	if msg.type() == LOG_NAK:
		fields = split(strip(msg.to_string()), " ")
        	reader_file.write(fields[-1] + "\tNAK\n");

	if msg.type() == LOG_PWR_UP:
		fields = split(strip(msg.to_string()), " ")
        	reader_file.write(fields[-1] + "\tPOWER UP\n");
	


# Decode Tag Messages
def decode_tag_log_msg(msg,tag_file):
	LOG_RN16, LOG_EPC, LOG_ERROR, LOG_OKAY = range(4)

	if msg.type() == LOG_EPC:
        	fields = split(strip(msg.to_string()), " ")
        	epc = fields[0].split(",")[0]
        	rssi = strip(fields[0].split(",")[1])
        	epc = epc[16:112]
        	tmp = atoi(epc,2)
        	if msg.arg2() == LOG_ERROR:
			tag_file.write("%s\tCRC_ERR\t\tEPC: %024X\tRSSI: %s\n" % (fields[-1],tmp,rssi));
            	else:
            		tag_file.write("%s\tCRC_OK\t\tEPC: %024X\tRSSI: %s\n" % (fields[-1],tmp,rssi));




# Gen2 RFID Listener v.2 + Listener (DUAL CHANNEL APPLICATION)
if __name__ == '__main__':
    main ()
