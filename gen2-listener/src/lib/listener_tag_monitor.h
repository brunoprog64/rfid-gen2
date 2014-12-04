/* -*- c++ -*- */
/* 
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


// Acknowledgement: I would like to acknowledge Michael Buettner since this adapted and modified block is inherited from his CGRAN project "Gen2 RFID Reader"

#ifndef INCLUDED_LISTENER_TAG_MONITOR_H
#define INCLUDED_LISTENER_TAG_MONITOR_H

#include <gnuradio/block.h>
#include <gnuradio/message.h>
#include <gnuradio/msg_queue.h>
#include "listener_vars.h"

class listener_tag_monitor;
typedef boost::shared_ptr<listener_tag_monitor> listener_tag_monitor_sptr;

listener_tag_monitor_sptr 
listener_make_tag_monitor (bool real_time, int miller, float blf);

class listener_tag_monitor : public gr::block
{
private:
  friend listener_tag_monitor_sptr listener_make_tag_monitor(bool real_time, int miller, float blf);
  
  listener_tag_monitor(bool real_time, int miller, float blf);

  float d_blf;
  bool d_real_time;
  bool d_rn16;
  char EPC[128];
  int d_miller;
  int d_num_input_items;
  int DEFAULT_NUM_INPUT_ITEMS;
  int d_items_copied;
  float * d_sample_buffer;
  int d_skip_cnt;
  float d_last_score;
  int d_reads;
  int d_find_preamble_count;
  char * d_tag_bit_vector;
  float avg_symbol_pwr;

  gr::msg_queue::sptr log_tag;
  enum {LOG_RN16, LOG_EPC, LOG_ERROR, LOG_OKAY};  

  void forecast (int noutput_items, gr_vector_int &ninput_items_required); 
  void max_min(const float * buffer, int len, double * max, double * min, double* avg );
  int check_crc(char * bits, int num_bits);
  void log_msg(int message, char * text, int error);

public:
  ~listener_tag_monitor(); 
  int general_work(int noutput_items, 
		   gr_vector_int &ninput_items,
		   gr_vector_const_void_star &input_items,
		   gr_vector_void_star &output_items);

  void reset_receive_state();

  state * STATE_PTR;
  state STATE;

  gr::msg_queue::sptr get_tag_log() const {return log_tag;}

};

#endif
