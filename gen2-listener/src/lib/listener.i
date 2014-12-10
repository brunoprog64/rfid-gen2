/* -*- c++ -*- */
 
%include "exception.i"
%import "gnuradio.i"                           
 
%{
#include <gnuradio/block.h>
#include <gnuradio/sync_block.h>
#include <gnuradio/sync_decimator.h>
#include <gnuradio/sync_interpolator.h>
#include <gnuradio/tagged_stream_block.h>
#include <gnuradio/block_gateway.h>

#include <gnuradio/swig/gnuradio_swig_bug_workaround.h>    
#include "listener_clock_recovery.h"
#include "listener_tag_monitor.h"
#include "listener_reader_monitor_cmd_gate.h"
#include <stdexcept>
%}
  

//-----------------------------------------------------------------
GR_SWIG_BLOCK_MAGIC(listener, clock_recovery);

listener_clock_recovery_sptr 
listener_make_clock_recovery(int samples_per_pulse, float us_per_sample, state * reader_state,  float blf);

class listener_clock_recovery: public gr::block{
  listener_clock_recovery(int samples_per_pulse, float us_per_sample, state * reader_state,  float blf);

public:
  ~listener_clock_recovery();
  
};


//-----------------------------------------------------------------
GR_SWIG_BLOCK_MAGIC(listener, tag_monitor);

listener_tag_monitor_sptr
listener_make_tag_monitor (bool real_time, int miller, float blf);


class listener_tag_monitor: public gr::block{
 
  listener_tag_monitor (bool real_time, int miller, float blf);

public: 
  ~listener_tag_monitor();
  state * STATE_PTR;  
  reset_receive_state();
  gr::msg_queue::sptr get_tag_log() const;

};



//-----------------------------------------------------------------
GR_SWIG_BLOCK_MAGIC(listener, reader_monitor_cmd_gate);

listener_reader_monitor_cmd_gate_sptr 
listener_make_reader_monitor_cmd_gate (bool real_time, float us_per_sample, state * reader_state, float blf, float rtcal);


class listener_reader_monitor_cmd_gate: public gr::block{
 
  listener_reader_monitor_cmd_gate (bool real_time, float us_per_sample, state * reader_state, float blf, float rtcal);

public: 
  ~listener_reader_monitor_cmd_gate();
  gr::msg_queue::sptr get_reader_log() const;
   
};


