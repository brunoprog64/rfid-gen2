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


#ifndef INCLUDED_listener_clock_recovery_H
#define INCLUDED_listener_clock_recovery_H

#include <gnuradio/block.h>
#include "listener_vars.h"

class listener_clock_recovery;
typedef boost::shared_ptr<listener_clock_recovery> listener_clock_recovery_sptr;

listener_clock_recovery_sptr
listener_make_clock_recovery(int samples_per_pulse, float us_per_sample, state * reader_state, float blf);

class listener_clock_recovery : public gr::block 
{  

  friend listener_clock_recovery_sptr
  listener_make_clock_recovery(int samples_per_pulse, float us_per_sample, state * reader_state, float blf);

  public:
  ~listener_clock_recovery();
  int general_work(int noutput_items,
		   gr_vector_int &ninput_items,
		   gr_vector_const_void_star &input_items,
		   gr_vector_void_star &output_items);
protected:

  listener_clock_recovery(int samples_per_pulse, float us_per_sample, state * reader_state, float blf);
  

private:
  int d_samples_per_pulse;
  float * d_buffer;
  int d_last_zc_count;
  float d_pwr;
  int d_avg_window_size;
  bool d_last_was_pos;
  state * d_reader_state;
  float d_us_per_sample;
  float d_blf;
  float * d_avg_vec;
  int d_avg_vec_index;

  void forecast (int noutput_items, gr_vector_int &ninput_items_required);

};

#endif 
