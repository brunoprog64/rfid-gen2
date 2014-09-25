rfid-gen2
=========

Gen2 Reader originally by Michael Buettner. (https://www.cgran.org/wiki/Gen2)

This repository is for source modifications for a COMP7802 Thesis project.

All the code remains in GPL3, accordingly to the original licensor.

This code was tested on:

- GNU Radio 3.2.2
- Ubuntu 10.04
- USRP1 with RFX900 Daughterboard
- Generic UHF RFID tags.

COMP7802 - Computer Research Project: 
Collision Avoidance for ISO 1800-6C using SDR.

Bruno Espinoza Amaya (bruno.espinozaamaya@uqconnect.edu.au)
Computer Science Master Student in the University of Queensland.


Instructions:
-------------
- Just to the classical ./configure --prefix=/usr/ && make && sudo make install
- You may change the --prefix accordingly to your GNU Radio installation.
- Tested with GNU Radio 3.2.2 and 3.6.4, but original Python scripts do not work on 3.6.x.
- If make complains about gruel_common.i in GNU Radio 3.6.x just copy the file from /usr/include/gruel/swig/gruel_common.i to /usr/include/gnuradio/swig. It also can be added to Makefile.common but it will broke the compilation on older GNU Radio systems.
- The file to run is rfid/apps/gen2_reader.py. (It accepts 2 parameters --f <freq_center> and --g <rx_gain>, by default they are 915e6 and 20).
