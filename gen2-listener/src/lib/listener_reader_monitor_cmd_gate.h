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

#ifndef INCLUDED_LISTENER_READER_MONITOR_CMD_GATE_H
#define INCLUDED_LISTENER_READER_MONITOR_CMD_GATE_H

#include <gnuradio/block.h>
#include <gnuradio/message.h>
#include <gnuradio/msg_queue.h>

#include "listener_vars.h"

class listener_reader_monitor_cmd_gate;
typedef boost::shared_ptr<listener_reader_monitor_cmd_gate> listener_reader_monitor_cmd_gate_sptr;

listener_reader_monitor_cmd_gate_sptr 
listener_make_reader_monitor_cmd_gate (bool real_time, float us_per_sample, state * reader_state, float blf, float rtcal);

class listener_reader_monitor_cmd_gate : public gr::block 
{
 
 private:
  friend listener_reader_monitor_cmd_gate_sptr
  listener_make_reader_monitor_cmd_gate (bool real_time, float us_per_sample, state * reader_state, float blf, float rtcal);
  
  double d_us_per_sample;
  double d_thresh;
  bool pwrd_dwn;
  bool d_real_time;
  float d_blf;
  float d_rtcal;
  float Tpri;
  float T1;
  float pwrd_down_time;
  state * d_reader_state;

  gr::msg_queue::sptr  log_reader;
  enum {LOG_QUERY, LOG_QREP, LOG_ACK, LOG_NAK, LOG_PWR_UP, LOG_ERROR, LOG_OKAY};  
  
  listener_reader_monitor_cmd_gate(bool real_time, float us_per_sample, state * reader_state, float blf, float rtcal);
  void forecast (int noutput_items, gr_vector_int &ninput_items_required); 
  int max_min(const float * buffer, int len, double * max, double * min, double* avg );
  void log_msg(int message, char * text, int error);
    

 public:
  ~listener_reader_monitor_cmd_gate();
 
  int general_work(int noutput_items, 
		   gr_vector_int &ninput_items,
		   gr_vector_const_void_star &input_items,
		   gr_vector_void_star &output_items);

  gr::msg_queue::sptr  get_reader_log() const {return log_reader;}

  
};

#endif

