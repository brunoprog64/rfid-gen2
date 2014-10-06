#!/usr/bin/env python
# coding: utf-8

'''
###############################################################################################################################################################
GEN2 RFID LISTENER v.2
This is an improvement version of the RFID Listener previously released. The main modifications we introduced concern matched filtering, clock recovery and Tag ID decoding. 
###############################################################################################################################################################
EXECUTION INFOs
sudo PYTHONPATH=/usr/local/lib/python2.6/dist-packages/ GR_SCHEDULER=TPB nice -n -20 ./Gen2_RFID_Listener_v2.py -f freq
- /usr/local/lib/python2.6/dist-packages/ --> substitute with your python installation directory
- nice -n -20                             --> high priority for the process
- GR_SCHEDULER=TPB                        --> GNUradio default Thread-Per-Block scheduler
###############################################################################################################################################################
'''

from gnuradio import gr, gru, window,  modulation_utils, listener
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
In order to detect the preamble and correctly decode the messages transmitted by the tag some preliminary considerations must be taken into account. According to the Gen2 standard the reader chooses the up-link parameters and communicates them to the tags using the opening symbols of each packet (reader’s commands preamble). For this reason, decoding reader commands is required to access the up-link parameters and best tune-up in real-time both the "matched filter" and the “Tag Decoder” block (ref. Figure 7 of the Mobicom 2010 paper). Since this new Listener is optimized for Tag deconding instead of Reader deconding, we suggest to run first the previous version as to obtain the BLF and the number of Miller subcarrier your reader use. Then you can set accordingly the parameters listed below.
We suggest to try this code together with the Buettner's reader you find on CGRAN. This permits best tuning of all parameters. Use the following code if you run the listener and the Buettner's reader on two separate USRP. Otherwise, if you want listener and reader on the same USRP/PC run the "Gen2_RFID_Reader_Listener.py" code you find in this project folder.
''' 
up_link_freq      = 41.667  	# BLF your reader communicates to tags --> this is the value used by Buettner's reader
miller            = 8           # Number of Miller sub-carriers your reader communicates to tags
rtcal		  = 72          # Reader-To-Tag calibration (in microsec) of your reader --> this is the value used by Buettner's reader
dec_rate          = 32    	# decimation factor at USRP
sw_dec            = 4		# software decimation
samples_per_pulse = 6		# samples per pulse of the tag signal. It's calculated according as (1/(2*up_link_freq*1000))/((dec_rate*sw_dec)/64e6)
'''
With the previous defined decimation you can capture 2 MHz of band centered around the tuning frequency of the USRP. So if you choose 866.5 MHz as center frequency you can capture the entire UHF RFID band in Europe. If you are in US, since RFID occupies about 25 MHz of band, with such configuration you'll capture tags when the reader hops to a frequency that falls in the 2 MHz band you have set.
'''


# Block connections      				                                                                       
class my_top_block(gr.top_block):
    def __init__(self, rx, matched_filter, reader_monitor_cmd_gate, cr, tag_monitor):
        gr.top_block.__init__(self)
               
        # ASK/PSK demodulator
     	to_mag = gr.complex_to_mag()
        
	# Null sink for terminating the graph
	null_sink = gr.null_sink(gr.sizeof_float*1)

	# Enable real-time scheduling	
        r = gr.enable_realtime_scheduling()
    	if r != gr.RT_OK:
            print "Warning: failed to enable realtime scheduling"

	# Create flow-graph
	self.connect(rx, to_mag, matched_filter, reader_monitor_cmd_gate, cr, tag_monitor, null_sink)	
		
        # File sink for monitoring block output	
	#file_sink = gr.file_sink(gr.sizeof_float, "block_x.out") # Change to "gr.sizeof_gr_complex" if "block_x" is "rx" 
	#self.connect(block_x, file_sink)



# Main program       
def main():

    # Parsing command line parameter
    parser = OptionParser (option_class=eng_option)	
    parser.add_option("-f", "--freq", type="eng_float", dest="freq", default=866.5, help="set USRP center frequency (provide frequency in MHz)")
    (options, args) = parser.parse_args()	
    
    which_usrp = 0		
    fpga = "std_2rxhb_2tx.rbf" 
    freq = options.freq # Default value = 866.5 --> center frequency of 2 MHz European RFID Band
    freq = freq*1e6	
    rx_gain = 20   									      									          
    us_per_sample = float (1 / (64.0 / (dec_rate*sw_dec)))		
    samp_freq = (64 / dec_rate) * 1e6						
    
    # LISTENER HARDWARE SUB-SYSTEM (USRP v.1)    
    rx = usrp.source_c(which_usrp, dec_rate, fpga_filename= fpga) # Create USRP source
    rx_subdev_spec = (0,0) # DB RFX900 on side A, change to (1,0) for side B				
    rx.set_mux(usrp.determine_rx_mux_value(rx, rx_subdev_spec))  		
    
    rx_listener_subdev = usrp.selected_subdev(rx, rx_subdev_spec)
    rx_listener_subdev.set_gain(rx_gain)						 
    rx_listener_subdev.set_auto_tr(False)					
    rx_listener_subdev.select_rx_antenna('RX2') # RX Antenna on RX2 Connector of USRP (comment this line if you want TX/RX connector)
 
    r = rx.tune(0, rx_listener_subdev, freq) # Tuning Daughterboard @ Center Frequency
    if not r:
        print "Couldn't set LISTENER RX frequency"
    # END LISTENER HARDWARE SUB-SYSTEM (USRP v.1) 	    
    
    # FILE SOURCE for offline tests (comment previous lines and uncomments this line)
    # u = gr.file_source(gr.sizeof_gr_complex*1, "input_file", False)
        
    print ""
    print "*************************************************************"
    print "****************** Gen2 RFID Listener ***********************"
    print "*************************************************************\n"

    print "USRP center frequency: %s MHz" % str(freq/1e6)
    print "Sampling Frequency: "+ str(samp_freq/1e6) + " MHz" + " --- microsec. per Sample: " + str(us_per_sample)
        
    
    # LISTENER SOFTWARE SUB-SYSTEM (GNU-Radio flow-graph)	
    # MATCHED FILTER
    num_taps = int(64000 / (dec_rate * up_link_freq * 4)) 
    taps = []
    for i in range(0,int(num_taps)):
        taps.append(float(1))
    matched_filter = gr.fir_filter_fff(sw_dec, taps)

    # Tag Decoding Block --> the boolean value in input indicate if real-time output of EPC is enabled or not 
    tag_monitor = listener.tag_monitor(True, int(miller), float(up_link_freq))	

    # Clock recovery
    cr = listener.clock_recovery(samples_per_pulse, us_per_sample, tag_monitor.STATE_PTR, float(up_link_freq))
    
    # Reader Decoding Block and Command gate--> the boolean value indicate if real-time output of reader commands is enabled or not 
    reader_monitor_cmd_gate = listener.reader_monitor_cmd_gate(False, us_per_sample, tag_monitor.STATE_PTR, float(up_link_freq), float(rtcal))
  
    # Create GNU-Radio flow-graph
    tb = my_top_block(rx, matched_filter, reader_monitor_cmd_gate, cr, tag_monitor)
    # END LISTENER SOFTWARE SUB-SYSTEM (GNU-Radio flow-graph)


    # Start application
    tb.start()
    
    while 1:
	c = raw_input("\nPRESS 'q' for STOPPING capture\n")
        if c == "Q" or c == "q":
	 	break

    # Stop application
    tb.stop()

    # GETTING LOGs 
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




# Gen2 RFID Listener v.2  
if __name__ == '__main__':
    main ()
