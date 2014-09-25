GR_SWIG_BLOCK_MAGIC(rfid, command_gate_cc);

rfid_command_gate_cc_sptr
rfid_make_command_gate_cc(int pw, int T1, int sample_rate);

class rfid_command_gate_cc: public gr::block{
  rfid_command_gate_cc(int pw, int T1, int sample_rate);

public:
  ~rfid_command_gate_cc();
  void set_ctrl_out(gr::msg_queue::sptr msgq) const;
};
