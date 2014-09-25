GR_SWIG_BLOCK_MAGIC(rfid, reader_decoder);

rfid_reader_decoder_sptr 
rfid_make_reader_decoder (float us_per_sample, float tari);


class rfid_reader_decoder: public gr::sync_block{
 
  rfid_reader_decoder (float us_per_sample, float tari);

public: 
  ~rfid_reader_decoder();
  gr::msg_queue::sptr get_log() const;

  
};
