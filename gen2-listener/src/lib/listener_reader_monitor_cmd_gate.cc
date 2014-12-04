/* -*- c++ -*- */
/*
 * Copyright 2004,2006 Free Software Foundation, Inc.
 * 
 * This file is part of GNU Radio
 * 
 * GNU Radio is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 * 
 * GNU Radio is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with GNU Radio; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */


#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <listener_reader_monitor_cmd_gate.h>
#include <gnuradio/io_signature.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <float.h>
#include <math.h>
#include "listener_vars.h"



// Calculate maximum
inline float max(float a, float b)
{
   return a >= b ? a : b;
}



/////////////////////////////////////////////////////////////////
// INITIAL SETUP
////////////////////////////////////////////////////////////////
listener_reader_monitor_cmd_gate_sptr
listener_make_reader_monitor_cmd_gate (bool real_time, float us_per_sample, state * reader_state, float blf, float rtcal)
{
  return listener_reader_monitor_cmd_gate_sptr (new listener_reader_monitor_cmd_gate (real_time, us_per_sample, reader_state, blf, rtcal));
}

listener_reader_monitor_cmd_gate::listener_reader_monitor_cmd_gate(bool real_time, float us_per_sample, state * reader_state, float blf, float rtcal)
  : gr::block("listener_reader_monitor_cmd_gate",
		   gr::io_signature::make (1,1,sizeof(float)),
		       gr::io_signature::make (1,1,sizeof(float))),
    d_real_time(real_time), d_us_per_sample(us_per_sample), d_blf(blf), d_rtcal(rtcal)
{
      
	// Initialize state
	d_reader_state = reader_state;
  	d_reader_state->blf = d_blf;
  	d_reader_state->zc=0;
  	d_reader_state->cum_zc_count=0;

	pwrd_dwn = false;
	d_thresh=6000;
	
	// According to gen2 standard determine when tag responds after a reader command
        Tpri = (1/d_blf)*1000;
	T1 = max(d_rtcal,10*Tpri); //dallo standard gen2
	
	// Gen2 defines at least 1ms of power-down period --> 0.8 ms is a good choice to ensure power-down detection 
	pwrd_down_time = 800; //in microsec.

	log_reader = gr::msg_queue::make(300000); // message queue --> decoded in Python
	
}
// END INITIAL SETUP
//////////////////////////////////////////////////////////////////////////////////////////////////


   
listener_reader_monitor_cmd_gate::~listener_reader_monitor_cmd_gate()
{
}



///////////////////////////////////////////////////////////////////////////////////////////////////
// GENERAL WORK
//////////////////////////////////////////////////////////////////////////////////////////////////
int listener_reader_monitor_cmd_gate::general_work(int noutput_items,
			   			gr_vector_int &ninput_items,
			   			gr_vector_const_void_star &input_items,
			   			gr_vector_void_star &output_items)
{

	const float * in = (const float *)input_items[0];
	float * out = (float * )output_items[0];

	double avg, max, min;
	double max_RSSI, avg_RSSI;
	static long high_cnt=0;
	static long low_cnt=0;
  
	int n_out = 0;
  
	//First possibility to determine threshold (don't permit SNR calculation)
	/*
	if (d_reader_state->tag==false) {
		max_min(in, noutput_items, &max, &min, &avg);
		max_RSSI = max;
		avg_RSSI = avg;
		d_thresh = max * .7;
	}	 
	*/

	static int num_pulses = 0;  
	for(int i = 0; i < noutput_items; i++) {

		// Detect the last command transmitted by the reader and ungate after that
    		if(d_reader_state->tag==false) {
      			static bool edge_fell = false;
         		if(!edge_fell){
				if(in[i] < d_thresh){
	  				edge_fell = true;
	  			}
			} else {
				if(in[i] > d_thresh && d_thresh > 5000) { 
	    				num_pulses++;
					edge_fell = false;
	    			}
      			}

			if(in[i] < d_thresh) {
				low_cnt++;
				if(low_cnt * d_us_per_sample > pwrd_down_time) { // Detected reader power-down period
					pwrd_dwn=true;
					num_pulses=-1;
				}
			}
			if(in[i] > d_thresh && d_thresh > 5000) {
				if (low_cnt>0) {
					low_cnt=0;
					high_cnt=0;
				}
				high_cnt++;
				if (pwrd_dwn==true) {
					// Second possibility for threshold calculation (use this for future implementation of SNR calculation)
					max_min(in, noutput_items, &max, &min, &avg);
					max_RSSI = max;
					avg_RSSI = avg;
					d_thresh = max * .7;
					pwrd_dwn=false;
					if (d_real_time==true) printf("READER SIGNAL: Powered-Up after detected power-down period\n");
					log_msg(LOG_PWR_UP, NULL, LOG_OKAY);
				}
			}

			if (num_pulses==26 && high_cnt*d_us_per_sample > T1) { 
				if (d_real_time==true) printf("READER SIGNAL: QUERY\n");
				log_msg(LOG_QUERY, NULL, LOG_OKAY);
				num_pulses=0;
			}

			if (num_pulses==7 && high_cnt*d_us_per_sample > T1) { 
				if (d_real_time==true) printf("READER SIGNAL: QREP\n");
				log_msg(LOG_QREP, NULL, LOG_OKAY);
				num_pulses=0;
			}

			if (num_pulses==21 && high_cnt*d_us_per_sample > T1) { 
				if (d_real_time==true) {
					printf("READER SIGNAL: ACK\n");
					printf("EXPECTED EPC message from Tag\n");			
				}
				log_msg(LOG_ACK, NULL, LOG_OKAY);	
				num_pulses=0;
				// Open gate --> expected EPC message from Tag
				d_reader_state->tag=true;
				d_reader_state->blf = d_blf;
				d_reader_state->zc=0;
        			d_reader_state->cum_zc_count=0;
			}
	
			if (num_pulses==11 && high_cnt*d_us_per_sample > T1) { 
				if (d_real_time==true) printf("READER SIGNAL: NAK\n");
				log_msg(LOG_NAK, NULL, LOG_OKAY);
				num_pulses=0;
			}

			if (num_pulses>0 && high_cnt*d_us_per_sample > T1) { 
				num_pulses=0;
			}
		
		}

		// Send out expected tag signal
		if (d_reader_state->tag==true ) {
			out[n_out++] = in[i]; 
		}
		
	}

	consume_each(noutput_items);
	return n_out;

}
// END GENERAL WORK
////////////////////////////////////////////////////////////////////////////////////////// 



//////////////////////////////////////////////////////////////////////////////////////////
// CALCULATE MAX AND MIN OF THE SIGNAL
//////////////////////////////////////////////////////////////////////////////////////////
int listener_reader_monitor_cmd_gate::max_min(const float * buffer, int len, double * max, double * min, double * avg )
{

	double tmp_avg = 0;
	double tmp_std_dev = 0;

	for (int i = 0; i < len; i++) {
    		tmp_avg += buffer[i];
    		if(buffer[i] > * max) {
      			*max = buffer[i];
    		}
    		if(buffer[i] < * min) {
      			*min = buffer[i];
    		}
  	}
  	tmp_avg = tmp_avg / len;
  	*avg = tmp_avg;
  
  	return 1;

}
// END CALCULATE MAX AND MIN OF THE SIGNAL
//////////////////////////////////////////////////////////////////////////////////////////



/////////////////////////////////////////////////////////////////////////////////////////
// CREATE LOG MSG
////////////////////////////////////////////////////////////////////////////////////////
void
listener_reader_monitor_cmd_gate::log_msg(int message, char * text, int error){

	if(LOGGING_READER){
		char msg[1000];
		timeval time;
		gettimeofday(&time, NULL);
		tm * t_info = gmtime(&time.tv_sec);
		int len = 0;
		if(text != NULL){
			len = sprintf(msg, "%s Time: %d.%03ld\n", text, (t_info->tm_hour*3600)+(t_info->tm_min*60)+t_info->tm_sec, time.tv_usec/1000);
		}
		else{
			len = sprintf(msg,"Time: %d.%03ld\n", (t_info->tm_hour*3600)+ (t_info->tm_min*60)+t_info->tm_sec, time.tv_usec/1000 );
		}

		gr::message::sptr log_msg = gr::message::make(message, 0, error, len);
		memcpy(log_msg->msg(), msg, len);

		log_reader->insert_tail(log_msg);
	}

}
// END LOG MSG
//////////////////////////////////////////////////////////////////////////////////////////



//////////////////////////////////////////////////////////////////////////////////////////
// FORECAST
//////////////////////////////////////////////////////////////////////////////////////////
void listener_reader_monitor_cmd_gate::forecast (int noutput_items, gr_vector_int &ninput_items_required)
{
	unsigned ninputs = ninput_items_required.size ();
	for (unsigned i = 0; i < ninputs; i++){
		ninput_items_required[i] = noutput_items;
	}   
}
// END FORECAST
//////////////////////////////////////////////////////////////////////////////////////////
