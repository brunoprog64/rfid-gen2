#ifndef TAG_MONITOR_VARS
#define TAG_MONITOR_VARS

const bool LOGGING_TAG = true;
const bool LOGGING_READER = true;
const int MAX_INPUT_ITEMS = 3072 / 2;


static float fm0_preamble[] = {1,1,-1,1,-1,-1,1,-1,-1,-1,1,1};
static float m8_preamble[] = {1,-1,1,-1,1,-1,1,-1,1,-1,1,-1,1,-1,1,-1,
			      1,-1,1,-1,1,-1,1,-1,-1,1,-1,1,-1,1,-1,1,
			      -1,1,-1,1,-1,1,-1,1,-1,1,-1,1,-1,1,-1,1,
			      -1,1,-1,1,-1,1,-1,1,1,-1,1,-1,1,-1,1,-1,
			      1,-1,1,-1,1,-1,1,-1,-1,1,-1,1,-1,1,-1,1,
			      -1,1,-1,1,-1,1,-1,1,1,-1,1,-1,1,-1,1,-1};
static float m4_preamble[] = {1,-1,1,-1,1,-1,1,-1,
			      1,-1,1,-1,-1,1,-1,1,
			      -1,1,-1,1,-1,1,-1,1,
			      -1,1,-1,1,1,-1,1,-1,
			      1,-1,1,-1,-1,1,-1,1,
			      -1,1,-1,1,1,-1,1,-1};
static float m2_preamble[] = {1,-1,1,-1,
			      1,-1,-1,1,
			      -1,1,-1,1,
			      -1,1,1,-1,
			      1,-1,-1,1,
			      -1,1,1,-1};
static float fm0_one_vec[] = {1,1};
static float fm0_one_vec_bis[] = {-1,-1};
static float fm0_zero_vec[] = {1,-1};
static float fm0_zero_vec_bis[] = {-1,1};
static float m2_one_vec[] = {1,-1,-1,1};
static float m2_one_vec_bis[] = {-1,1,1,-1};
static float m2_zero_vec[] = {1,-1,1,-1};
static float m2_zero_vec_bis[] = {-1,1,-1,1};
static float m4_one_vec[] = {1,-1,1,-1,-1,1,-1,1};
static float m4_zero_vec[] = {1,-1,1,-1,1,-1,1,-1};
static float m4_one_vec_bis[] = {-1,1,-1,1,1,-1,1,-1};
static float m4_zero_vec_bis[] = {-1,1,-1,1,-1,1,-1,1};
static float m8_one_vec[] = {1,-1,1,-1,1,-1,1,-1,-1,1,-1,1,-1,1,-1,1};
static float m8_one_vec_bis[] = {-1,1,-1,1,-1,1,-1,1,1,-1,1,-1,1,-1,1,-1};
static float m8_zero_vec[] = {1,-1,1,-1,1,-1,1,-1,1,-1,1,-1,1,-1,1,-1};
static float m8_zero_vec_bis[] = {-1,1,-1,1,-1,1,-1,1,-1,1,-1,1,-1,1,-1,1};

const int len_fm0_preamble = 12;
const int len_fm0_one = 2;
const int len_m2_one = 4;
const int len_m4_one = 8;
const int len_m8_one = 16;
const int len_m2_preamble = 24; 
const int len_m4_preamble = 48; 
const int len_m8_preamble = 96; 
const int max_tag_response_len = 512;
const int num_RN16_bits = 16 ;
const int num_EPC_bits = 128 ;

struct state{
  float blf;
  int zc;  
  int cum_zc_count;
  bool tag;
  double TAG_POWER;
  int tag_one_len;
  int tag_preamble_len;
  float * tag_preamble;
  float * tag_one;
  float * tag_zero;
  float * tag_one_bis;
  float * tag_zero_bis;
  bool found_preamble;
  int num_bits_decoded;
  bool bit_error;
};

#endif
