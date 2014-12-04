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

#include <listener_tag_monitor.h>
#include <gnuradio/io_signature.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "listener_vars.h"
#include <sys/time.h>
#include <float.h>
#include <string.h>


/////////////////////////////////////////////////////////////////
// INITIAL SETUP
////////////////////////////////////////////////////////////////
listener_tag_monitor_sptr
listener_make_tag_monitor(bool real_time, int miller, float blf)
{
  return listener_tag_monitor_sptr(new listener_tag_monitor(real_time, miller, blf));
}
listener_tag_monitor::listener_tag_monitor(bool real_time, int miller, float blf):  gr::block(("listener_tag_monitor",  gr::io_signature::make (1, 1, sizeof(float)),  gr::io_signature::make (1,1,sizeof(float))),
	d_real_time(real_time) , d_miller(miller), d_blf(blf))
{
//;
 	// Initialize state
	STATE.tag=false;			
	STATE.blf = d_blf;
	STATE.zc=0;
        STATE.cum_zc_count=0;
 
	log_tag = gr_make_msg_queue(300000); // message queue --> decoded in Python
  	d_sample_buffer = (float *)malloc(MAX_INPUT_ITEMS * 4 * sizeof(float)); // store input samples
	d_tag_bit_vector = (char *)malloc(max_tag_response_len * sizeof(char)); // store tag bits

	// Encoding parameters definition
	if (d_miller == 0) { // FM0 encoding	
		STATE.tag_preamble = fm0_preamble;
    		STATE.tag_preamble_len = len_fm0_preamble;
		STATE.tag_one          = fm0_one_vec;			// ideal bit '1' 
		STATE.tag_zero	   = fm0_zero_vec;			// ideal bit '0'
		STATE.tag_one_bis      = fm0_one_vec_bis;		// ideal bit '1' 
		STATE.tag_zero_bis     = fm0_zero_vec_bis;		// ideal bit '0'
		STATE.tag_one_len = len_fm0_one;
	}
	if (d_miller == 2) { // Miller-2 encoding	
		STATE.tag_preamble = m2_preamble;
		STATE.tag_preamble_len = len_m2_preamble;
		STATE.tag_one          = m2_one_vec;			// ideal bit '1' 
		STATE.tag_zero	   = m2_zero_vec;			// ideal bit '0'
		STATE.tag_one_bis      = m2_one_vec_bis;		// ideal bit '1' 
		STATE.tag_zero_bis     = m2_zero_vec_bis;		// ideal bit '0'
		STATE.tag_one_len = len_m2_one;
	}
	if (d_miller == 4) { // Miller-4 encoding	
		STATE.tag_preamble = m4_preamble;
		STATE.tag_preamble_len = len_m4_preamble;
		STATE.tag_one          = m4_one_vec;			// ideal bit '1' 
		STATE.tag_zero         = m4_zero_vec;			// ideal bit '0'
		STATE.tag_one_bis      = m4_one_vec_bis;		// ideal bit '1' 
		STATE.tag_zero_bis     = m4_zero_vec_bis;		// ideal bit '0'
		STATE.tag_one_len = len_m4_one;
	}
	if (d_miller == 8) { // Miller-8 encoding	
		STATE.tag_preamble = m8_preamble;
		STATE.tag_preamble_len = len_m8_preamble;
		STATE.tag_one          = m8_one_vec;			// ideal bit '1' 
		STATE.tag_zero         = m8_zero_vec;			// ideal bit '0'
		STATE.tag_one_bis      = m8_one_vec_bis;		// ideal bit '1' 
		STATE.tag_zero_bis     = m8_zero_vec_bis;		// ideal bit '0'
		STATE.tag_one_len = len_m8_one;
	}
	
        DEFAULT_NUM_INPUT_ITEMS = STATE.tag_preamble_len; 	
	d_items_copied = 0;
	d_reads = 0;

	//Set STATE pointer
	STATE_PTR = &STATE;
  	
	reset_receive_state();	// reset receiver to initial state

}
// END SETUP INIZIALE
//////////////////////////////////////////////////////////////////////////////////////////////////



listener_tag_monitor::~listener_tag_monitor()
{
}



///////////////////////////////////////////////////////////////////////////////////////////////////
// GENEARAL WORK
//////////////////////////////////////////////////////////////////////////////////////////////////
int listener_tag_monitor::general_work(int noutput_items,
			  gr_vector_int &ninput_items,
			  gr_vector_const_void_star &input_items,
			  gr_vector_void_star &output_items)
{

const float * in = (const float *)input_items[0];
float * out = (float * )output_items[0];
int nout = 0;
int consumed = d_num_input_items;  	
int num_samples = 0;    		
int i = 0;

num_samples = d_items_copied + d_num_input_items;
memcpy(&d_sample_buffer[d_items_copied], in, ninput_items[0] * sizeof(float));  

while(i < int(num_samples - history())){  

	// Correlate for preamble
  	if(STATE.found_preamble==false) {
  		double sum = 0.;
		double total_pwr = 0.;
		float score = 0.;
		for(int j = 0; j < STATE.tag_preamble_len; j++) {
  			total_pwr += fabs(d_sample_buffer[i + j]);
  			sum += STATE.tag_preamble[j] * (d_sample_buffer[i + j]);
		}
        	score = fabs(sum) / total_pwr;
		if(d_last_score != 0 && score < d_last_score){ // Max correlation --> found preamble
			set_history(STATE.tag_one_len);
			STATE.found_preamble = true;
			STATE.blf = d_blf;
			STATE.zc=0;
        		STATE.cum_zc_count=0;
			//printf("FOUND PREAMBLE \n");
			d_skip_cnt = STATE.tag_preamble_len - 1;
			STATE.TAG_POWER = (total_pwr / STATE.tag_preamble_len);
		}
		else{
		  	if(score > .9){  // Store last score
		    		double max, min, avg;
		    		max_min(&d_sample_buffer[i], STATE.tag_preamble_len, &max, &min, &avg);
		   		if(fabs(max + min) < max){  // max min should be centered
		   			d_last_score = score;
		   		}
	 		}
		}

		//Preamble not detected 
		if(d_find_preamble_count++ > STATE.tag_preamble_len * 10){
			STATE.tag=false;			
			reset_receive_state();
			STATE.blf = d_blf;
			STATE.zc=0;
        		STATE.cum_zc_count=0;
		}

        } // End correlating preamble
	else{ // PREAMBLE FOUND --> decode bits
		// Correlate for bits
		// Early/late gate correlation decoding
		int adjust = 0;
		int best_pos_0 = 0;
		int best_pos_1 = 0;
	  	float best_score_0 = 0;
		float best_score_1 = 0;
		float best_score_0_int = 0;
		float best_score_1_int = 0;
	  		
		double sum_0 = 0;
		double sum_1 = 0;
		double sum_0_bis = 0;
		double sum_1_bis = 0;
		double total_pwr = 0;
		double avg_pwr = 0;
		float score_0 = 0;
		float score_1 = 0;
		float score_0_bis = 0;
		float score_1_bis = 0;

		// Center the signal
		for(int j = 0; j < STATE.tag_one_len; j++){
			avg_pwr += d_sample_buffer[i + j];
		}
		avg_pwr = avg_pwr / (float)STATE.tag_one_len;

		for(int j = 0; j < STATE.tag_one_len; j++){
			total_pwr += fabs(avg_pwr - d_sample_buffer[i + j]);
			sum_0 += STATE.tag_zero[j] * (avg_pwr - d_sample_buffer[i + j]);
	      		sum_1 += STATE.tag_one[j]  * (avg_pwr - d_sample_buffer[i + j]);
			sum_0_bis += STATE.tag_zero_bis[j] * (avg_pwr - d_sample_buffer[i + j]);
	      		sum_1_bis += STATE.tag_one_bis[j]  * (avg_pwr - d_sample_buffer[i + j]);
		}
	
		score_0 = fabs(sum_0) / total_pwr;
		score_1 = fabs(sum_1) / total_pwr;
		score_0_bis = fabs(sum_0_bis) / total_pwr;
		score_1_bis = fabs(sum_1_bis) / total_pwr;
		
		best_score_0 = std::max(score_0,score_0_bis);
		best_score_1 = std::max(score_1,score_1_bis);
	
		avg_symbol_pwr = avg_symbol_pwr + (total_pwr / STATE.tag_one_len);
	
		// Maximum deviation of early/late correlator
		int max_dev=1; 	
		if (d_miller==0 || d_miller==2) max_dev=0;
		else max_dev=1;
		// Early/late gate correlator for Miller
		for(int k = -max_dev; k <= max_dev && k!=0; k++){	
			sum_0 = sum_1 = sum_0_bis = sum_1_bis = 0;
	    		total_pwr = avg_pwr = 0;
	    		score_0 = score_1 = score_0_bis = score_1_bis = 0;
	       		for(int j = 0; j < STATE.tag_one_len; j++){
				if ((i+j+k)>=0 && (i+j+k)<(MAX_INPUT_ITEMS*4)) {
	      				avg_pwr += d_sample_buffer[i + j + k];
				}
	    		}
	    		avg_pwr = avg_pwr / (float)STATE.tag_one_len;
	       		for(int j = 0; j < STATE.tag_one_len; j++){
				if ((i+j+k)>=0 && (i+j+k)<(MAX_INPUT_ITEMS*6)) {
		      			total_pwr += fabs(avg_pwr - d_sample_buffer[i + j + k]);
					sum_0 += STATE.tag_zero[j] * (avg_pwr - d_sample_buffer[i + j + k]);
		      			sum_1 += STATE.tag_one[j]  * (avg_pwr - d_sample_buffer[i + j + k]);
					sum_0_bis += STATE.tag_zero_bis[j] * (avg_pwr - d_sample_buffer[i + j + k]);
		      			sum_1_bis += STATE.tag_one_bis[j]  * (avg_pwr - d_sample_buffer[i + j + k]);
				}
	    		}

			score_0 = fabs(sum_0) / total_pwr;
	    		score_1 = fabs(sum_1) / total_pwr;
			score_0_bis = fabs(sum_0_bis) / total_pwr;
	    		score_1_bis = fabs(sum_1_bis) / total_pwr;

			score_0 = std::max(score_0,score_0_bis);
			score_1 = std::max(score_1,score_1_bis);
	    		
			// Calculate best position
			if(score_0 > best_score_0_int && score_0 > best_score_0){
				best_score_0_int = score_0;
	      			best_pos_0 = k;
	    		}
	    		if(score_1 > best_score_1_int && score_1 > best_score_1){
				best_score_1_int = score_1;
	      			best_pos_1 = k;
	    		}   

	
		}//End early/late gate correlator
  
		if (best_score_1 > best_score_0) {
			adjust = best_pos_1;
			d_tag_bit_vector[STATE.num_bits_decoded++] = '1';
		}
		else {
			adjust = best_pos_0;
			d_tag_bit_vector[STATE.num_bits_decoded++] = '0';		
		}
			
		// Adjust position of the next samples
		d_skip_cnt = STATE.tag_one_len+adjust;

		// Optimized request size
		d_num_input_items = STATE.tag_one_len * (num_EPC_bits - STATE.num_bits_decoded);
			
		// EPC MESSAGE 
		if(STATE.num_bits_decoded == num_EPC_bits ) { 
			STATE.tag=false;  // Close gate 
			STATE.blf = d_blf;
			STATE.zc=0;
        		STATE.cum_zc_count=0;
			float tag_RSSI = avg_symbol_pwr / num_EPC_bits;
			int pass = check_crc(d_tag_bit_vector, STATE.num_bits_decoded);
			if(pass == 1) {
				// Printf bits				
				//for(int i = 0; i < STATE.num_bits_decoded;i++){
 	      			//	printf("%c", d_tag_bit_vector[i]);
 	    			//}
	        		//printf("\n");
				d_reads++;
				printf("Tag reads = %d \n",d_reads);
				// Real time printf of EPC message
				if (d_real_time == true) {
					printf("CORRECT TAG FOUND !!  RSSI = %.2f \n",tag_RSSI);
					int HEADER = 0;
					int EPC_MANAGER = 0;
					int OBJECT_CLASS = 0;
					int SERIAL_NUMBER = 0;
					for(int i = 16; i < 112;i++){
						if ((i-16)>=0 && (i-16)<8) { // HEADER FIELD
							HEADER = HEADER * 2 + d_tag_bit_vector[i] -'0';
						}
						if ((i-16)>=8 && (i-16)<36) { // EPC MANAGER FIELD
							EPC_MANAGER = EPC_MANAGER * 2 + d_tag_bit_vector[i] -'0'; 
						}
						if ((i-16)>=36 && (i-16)<60) { // OBJECT CLASS FIELD
							OBJECT_CLASS = OBJECT_CLASS * 2 + d_tag_bit_vector[i] -'0'; 
						}	
	 	      				if ((i-16)>=60 && (i-16)<96) { // SERIAL NUMBER FIELD
							SERIAL_NUMBER = SERIAL_NUMBER * 2 + d_tag_bit_vector[i] -'0';
						}
	 	    			}
					printf("EPC:\t%X %07X %X %X\n",HEADER,EPC_MANAGER,OBJECT_CLASS,SERIAL_NUMBER);
					printf("\n");
				}
				
				// Create log message
				d_tag_bit_vector[STATE.num_bits_decoded] = '\0';
			      	char tmp[500];
			      	char tmp2[500];
			      	strcpy(tmp, d_tag_bit_vector);
			      	sprintf(tmp2, ",%f\n", tag_RSSI);
			      	strcat(tmp, tmp2);
				log_msg(LOG_EPC, tmp, LOG_OKAY);
			}
			else{ // Failed CRC
				if (d_real_time == true) {
					printf("!! ERROR: UNCORRECT CRC !! \n");
				}
				float tag_RSSI = avg_symbol_pwr / num_EPC_bits;
				d_tag_bit_vector[STATE.num_bits_decoded] = '\0';
				char tmp[500];
				char tmp2[500];
				strcpy(tmp, d_tag_bit_vector);
				sprintf(tmp2, ",%f\n", tag_RSSI);
				strcat(tmp, tmp2);
				log_msg(LOG_EPC, tmp, LOG_ERROR);
			}
        		reset_receive_state();
       			break;
		}
	 	/* TODO
		// RN16 MESSAGE
		if(STATE.num_bits_decoded == num_RN16_bits && d_rn16==true){ 
			float tag_RSSI = avg_symbol_pwr / num_RN16_bits;
			// Possible bad RN16 
		    	if(STATE.bit_error) {
				// Printf RN16 Error
				//printf("RN16 MESSAGE ERROR !!  RSSI = %.2f \n",tag_RSSI);
				//for(int i = 0; i < STATE.num_bits_decoded;i++){
	    			//	printf("%c", d_tag_bit_vector[i]);
	    			//}
	    			//printf("\n");
		      		d_tag_bit_vector[STATE.num_bits_decoded] = '\0';
				char tmp[500];
	      			char tmp2[500];
	      			strcpy(tmp, d_tag_bit_vector);
	      			sprintf(tmp2, ",%f\n", tag_RSSI);
	      			strcat(tmp, tmp2);
	      			log_msg(LOG_RN16, tmp, LOG_ERROR);
	    		}
			// Correct RN16 
	    		else {
				// Printf RN16 message
				//printf("RN16 MESSAGE !!  RSSI = %.2f \n",tag_RSSI);
				//for(int i = 0; i < STATE.num_bits_decoded;i++){
	    			//	printf("%c", d_tag_bit_vector[i]);
	    			//}
	    			//printf("\n");
	        		d_tag_bit_vector[STATE.num_bits_decoded] = '\0';
				char tmp[500];
	      			char tmp2[500];
	      			strcpy(tmp, d_tag_bit_vector);
	      			sprintf(tmp2, ",%f\n", tag_RSSI);
	      			strcat(tmp, tmp2);
		        	log_msg(LOG_RN16, tmp, LOG_OKAY);
			}
			reset_receive_state();
			break;
		}
		*/
	} // END BIT DECODING

	if(d_skip_cnt > 0){
		i = i + d_skip_cnt;
  	}
  	else{
  		i++;
  	}

} // END WHILE

d_items_copied = num_samples - i;
memcpy(d_sample_buffer, &d_sample_buffer[num_samples - d_items_copied], d_items_copied * sizeof(float));

consume_each(consumed);
return consumed;
   
}
// END GENERAL WORK
////////////////////////////////////////////////////////////////////////////////////////// 



//////////////////////////////////////////////////////////////////////////////////////////
// FORECAST
//////////////////////////////////////////////////////////////////////////////////////////
void listener_tag_monitor::forecast (int noutput_items, gr_vector_int &ninput_items_required)
{
	unsigned ninputs = ninput_items_required.size ();
	for (unsigned i = 0; i < ninputs; i++){
		ninput_items_required[i] = d_num_input_items; 
	}   
}
// END FORECAST
////////////////////////////////////////////////////////////////////////////////////////// 



//////////////////////////////////////////////////////////////////////////////////////////
// CALCULATE MAX AND MIN
//////////////////////////////////////////////////////////////////////////////////////////
void listener_tag_monitor::max_min(const float * buffer, int len, double * max, double * min, double * avg )
{

	*max = DBL_MIN;
	*min = DBL_MAX;
	double tmp = 0;

	for (int i = 0; i < len; i++){
		tmp += buffer[i];
		if(buffer[i] > * max){
			*max = buffer[i];
		}
		if(buffer[i] < * min){
			*min = buffer[i];
		}
	}
  
	*avg = tmp / len;

}
// END MAX_MIN
////////////////////////////////////////////////////////////////////////////////////////// 



/////////////////////////////////////////////////////////////////////////////////////////
// RESET RECEIVE STATE
////////////////////////////////////////////////////////////////////////////////////////
void listener_tag_monitor::reset_receive_state()
{
	set_history(STATE.tag_preamble_len);
	d_num_input_items = DEFAULT_NUM_INPUT_ITEMS;
	d_rn16=true;
	STATE.found_preamble = false;
	STATE.bit_error = false;
	STATE.num_bits_decoded = 0;
	d_skip_cnt = 0;
	d_last_score = 0.;
	avg_symbol_pwr = 0.;
	d_find_preamble_count = 0;

}
// END RESET RECEIVE STATE
////////////////////////////////////////////////////////////////////////////////////////// 



/////////////////////////////////////////////////////////////////////////////////////////
// CHECK CRC 16 bit
////////////////////////////////////////////////////////////////////////////////////////
int listener_tag_monitor::check_crc(char * bits, int num_bits){

	register unsigned short i, j;
	register unsigned short crc_16, rcvd_crc;
	unsigned char * data;
	int num_bytes = num_bits / 8;
	data = (unsigned char* )malloc(num_bytes );
	int mask;

	for(i = 0; i < num_bytes; i++){
		mask = 0x80;
		data[i] = 0;
		for(j = 0; j < 8; j++){
			if (bits[(i * 8) + j] == '1'){
				data[i] = data[i] | mask;
			}
			mask = mask >> 1;
		}
   	}

	rcvd_crc = (data[num_bytes - 2] << 8) + data[num_bytes -1];

	crc_16 = 0xFFFF; 
	for (i=0; i < num_bytes - 2; i++) {
		crc_16^=data[i] << 8;
		for (j=0;j<8;j++) {
			if (crc_16&0x8000) {
				crc_16 <<= 1;
				crc_16 ^= 0x1021; // (CCITT) x16 + x12 + x5 + 1
			}
			else {
				crc_16 <<= 1;
			}
		}
	}
	crc_16 = ~crc_16;

	if(rcvd_crc != crc_16){
		//printf("Failed CRC\n");
		return -1;
	}
	else{
		return 1;
  	}
    
}
// END CHECK CRC16
//////////////////////////////////////////////////////////////////////////////////////////



/////////////////////////////////////////////////////////////////////////////////////////
// CREATE LOG MSG
////////////////////////////////////////////////////////////////////////////////////////
void
listener_tag_monitor::log_msg(int message, char * text, int error){

	if(LOGGING_TAG){
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

		gr::message::sptr log_msg = gr:message::make((message, 0, error, len);
		//gr_message_sptr log_msg = gr_make_message(message, 0, error, len);
		memcpy(log_msg->msg(), msg, len);

		log_tag->insert_tail(log_msg);
	}

}
// END LOG MSG
//////////////////////////////////////////////////////////////////////////////////////////
