GR_SWIG_BLOCK_MAGIC(rfid, tag_decoder_f);

rfid_tag_decoder_f_sptr
rfid_make_tag_decoder_f();

class rfid_tag_decoder_f: public gr::block{
  rfid_tag_decoder_f();

public:
  ~rfid_tag_decoder_f();
  void set_ctrl_out(gr::msg_queue::sptr msgq) const;
};
