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
#include "config.h"
#endif
#include <listener_clock_recovery.h>
#include <gr_io_signature.h>
#include <stdexcept>
#include <float.h>
#include <string.h>
#include <stdio.h>
#include "listener_vars.h"



// EXECUTED OPERATIONS
// 1. Center the signal at 0 amplitude
// 2. Find the zero crossings
// 3. Sample at the appropriate distance from the zero crossing
// 4. Adapt clock taking into account BLF tolerance and tag signal jitter



/////////////////////////////////////////////////////////////////
// INITIAL SETUP
////////////////////////////////////////////////////////////////
listener_clock_recovery_sptr
listener_make_clock_recovery(int samples_per_pulse, float us_per_sample, state * reader_state, float blf)
{
  return listener_clock_recovery_sptr(new listener_clock_recovery(samples_per_pulse, us_per_sample, reader_state, blf));
}
listener_clock_recovery::listener_clock_recovery(int samples_per_pulse, float us_per_sample, state * reader_state, float blf)
  : gr_block("listener_clock_recovery", 
		      gr_make_io_signature(1,1,sizeof(float)),
		      gr_make_io_signature(1,1,sizeof(float))),
    d_samples_per_pulse(samples_per_pulse), d_us_per_sample(us_per_sample), d_blf(blf)
{

	// Initialize state
	d_reader_state = reader_state;
  	d_reader_state->blf = d_blf;

	set_history(8);

	// Buffer for storing input signal
	d_buffer = (float * )malloc(8196 * sizeof(float));  //buffer for storing signal
	for(int i = 0; i < 8196; i++) d_buffer[i] = 0;  
	
	d_last_zc_count = 0; 
	d_pwr = 0;

	// Number of pulses for average
	int num_pulses = 64;  

	d_avg_window_size = d_samples_per_pulse * num_pulses; 
	d_last_was_pos = true;  

	// Average vector
	d_avg_vec_index = 0;
	d_avg_vec = (float*)malloc(d_avg_window_size * sizeof(float));
	for(int i = 0; i < d_avg_window_size; i++) d_avg_vec[i] = 0;  

}
// END INITIAL SETUP
//////////////////////////////////////////////////////////////////////////////////////////////////



//////////////////////////////////////////////////////////////////////////////////////////
// FORECAST
//////////////////////////////////////////////////////////////////////////////////////////
void listener_clock_recovery::forecast(int noutput_items, gr_vector_int &ninput_items_required){
	unsigned ninputs = ninput_items_required.size ();
	for (unsigned i = 0; i < ninputs; i++){
		ninput_items_required[i] = noutput_items + history();
	}   
}
// END FORECAST
////////////////////////////////////////////////////////////////////////////////////////// 



listener_clock_recovery::~listener_clock_recovery()
{
}



static inline bool
is_positive(float x){
  return x < 0 ? false : true;
}



///////////////////////////////////////////////////////////////////////////////////////////////////
// GENERAL WORK
//////////////////////////////////////////////////////////////////////////////////////////////////
int listener_clock_recovery::general_work(int noutput_items,
					gr_vector_int &ninput_items,
					gr_vector_const_void_star &input_items,
					gr_vector_void_star &output_items)
{

	const float *in = (const float *) input_items[0];
	float* out = (float *) output_items[0];
	int nout = 0;
	int num_past_samples = d_samples_per_pulse;  	
  	int num_samples = 0;

	for(int i = 0; i < noutput_items; i++) {  
		//Calculate average
		d_pwr -= d_avg_vec[d_avg_vec_index];
		d_pwr += in[i];
		d_avg_vec[d_avg_vec_index++] = in[i];

		if(d_avg_vec_index == d_avg_window_size) {
			d_avg_vec_index = 0;
		}

		d_buffer[i + num_past_samples] = in[i];
		num_samples++;
	}

	// Find zero crossings, reduce sample rate, adapt clock
	for(int i = num_past_samples; i < num_samples + num_past_samples; i++) {
		
                // Center the signal
		d_buffer[i] = d_buffer[i] - (d_pwr / (float)(d_avg_window_size));
		
                // Find zero-crossing
		if((d_last_was_pos && ! is_positive(d_buffer[i])) || (!d_last_was_pos && is_positive(d_buffer[i]))) {
	      		if((d_last_zc_count*d_us_per_sample) > (1/(2*(d_reader_state->blf)*0.001)) * 1.45) {
				out[nout++] = d_buffer[i - (2*d_last_zc_count / 3)];
				out[nout++] = d_buffer[i - (d_last_zc_count / 3)];
			} else {
				if (d_last_zc_count > 0) {
					d_reader_state->zc++;
					d_reader_state->cum_zc_count = d_reader_state->cum_zc_count+d_last_zc_count;
					// Adapt clock
					if (d_reader_state->zc == 32) { // Calculate average clock every 32 short pulses
						d_reader_state->zc=0;
						float local_blf = d_reader_state->cum_zc_count/32;
						local_blf = (1/(local_blf*d_us_per_sample*2))*1000;
						if (std::abs(local_blf-d_blf) <= 10) { // Correct a maximum jitter of 10 KHz 
							d_reader_state->blf = local_blf;
						} else {
							d_reader_state->blf = d_blf;
						}
						d_reader_state->cum_zc_count = 0;  
					}
				}
				if (d_last_zc_count==1) d_last_zc_count=2; // This is because if d_last_zc_count=1 then d_last_zc_count/2=0
									   // but we want to look back
				out[nout++] = d_buffer[i - (d_last_zc_count / 2)];
	      		}
			d_last_zc_count = 0;
  		} else{
	      		d_last_zc_count++;
	    	}

	    	d_last_was_pos = is_positive(d_buffer[i]);

	}//end for

	//Copy num_past_samples to head of buffer 
	memcpy(d_buffer, &d_buffer[num_samples], num_past_samples * sizeof(float));

	consume_each(noutput_items);

	return nout;

}
// END GENERAL WORK
//////////////////////////////////////////////////////////////////////////////////////////       
