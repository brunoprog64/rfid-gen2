GR_SWIG_BLOCK_MAGIC(rfid, reader_f);

rfid_reader_f_sptr
rfid_make_reader_f(int sample_rate, int modul_type, int q_val, int ncycles, int nrounds);

class rfid_reader_f: public gr::block{
  rfid_reader_f(int sample_rate, int sample_rate, int modul_type, int q_val, int ncycles, int nrounds);

public:
  ~rfid_reader_f();
  gr::msg_queue::sptr ctrl_q();
  gr::msg_queue::sptr get_log();
};
