rfid-gen2
=========

Gen2 Reader originally by Michael Buettner. (https://www.cgran.org/wiki/Gen2)
Gen2-Listener originally by Eric Blossom. (https://www.cgran.org/wiki/gen2-listener)

* Update: Now that CGRAN is dead, you can access to the original code in the 'master' branch, with the modified code ported to GNU Radio 3.7.x in the 'gr3.7' branch.

This repository is for source modifications for a COMP7802 Thesis project.
All the code remains in GPL3, accordingly to the original licensors.

This code was modified to run on:

- GNU Radio 3.7.3
- Ubuntu 12.04
- USRP1 with RFX900 Daugtherboard and bladeRF.
- Generic UHF RFID tags.

COMP7802 - Computer Research Project: 
---------------------------------------
Collision Avoidance for ISO 1800-6C using SDR.

Bruno Espinoza Amaya (bruno.espinozaamaya@uqconnect.edu.au)
Computer Science Master Student in the University of Queensland.

Instructions:
-------------
- Just to the classical ./configure --prefix=/usr/ && make && sudo make install
- You may change the --prefix accordingly to your GNU Radio installation. (Like /usr/local)
- Tested with GNU Radio 3.7.3 (The 'gr3.7' branch) and with GNU Radio 3.2.2 (The 'master' branch). 
- bladeRF support in only available on 'gr3.7' branch, as osmosdr is the requirement.
- Original Python scripts do not work with GNU Radio 3.6.x, due to the removal of 'usrp' driver, now superseed by 'uhd'. Switch to 'gr3.7' where UHD or osmosdr are used.
- If make complains about gruel_common.i in GNU Radio 3.6.x just copy the file from /usr/include/gruel/swig/gruel_common.i to /usr/include/gnuradio/swig. It also can be added to Makefile.common but it will broke the compilation on older GNU Radio systems.
- The file to run is rfid/apps/gen2_reader.py or rfid/apps/osmosdr_gen2_reader.py. It has the following parameters:
  * --f <freq_center>: Center Frequency in Hz. By default is 915e6 (915 MHz)
  * --g <rx_gain>: Can set the RX gain. (DEPRECATED)
  * --s [uhd | bladerf]: (osmosdr_gen2_reader.py only). Chooses the device.
  * --m [0-3]: (osmosdr_gen2_reader.py only). Specify one of 4 accepted modulation schemes for the tag. (FM, Miller M=2, Miller M=4 and Miller M=8)
  * --d [none | full | matched]: Provides a 'f_rxout.out' file with a capture of the raw data after or before the matched_filter.
