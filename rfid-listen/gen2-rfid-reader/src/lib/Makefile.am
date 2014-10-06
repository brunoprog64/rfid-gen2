

include $(top_srcdir)/Makefile.common

ourpythondir = $(grpythondir)
ourlibdir    = $(grpyexecdir)

INCLUDES = $(STD_DEFINES_AND_INCLUDES) $(PYTHON_CPPFLAGS)
#$(CPPUNIT_INCLUDES)

SWIGCPPPYTHONARGS = -noruntime -c++ -fvirtual -python -modern $(PYTHON_CPPFLAGS) \
$(STD_DEFINES_AND_INCLUDES) -I$(swigincludedir) -I$(grincludedir)

#SWIGPYTHONARGS = $(SWIGPYTHONFLAGS) $(SWIGGRFLAGS)

ALL_IFILES = 				\
	$(LOCAL_IFILES)			\
	$(NON_LOCAL_IFILES)		

NON_LOCAL_IFILES =			\
	$(GNURADIO_CORE_INCLUDEDIR)/swig/gnuradio.i

LOCAL_IFILES = 				\
	rfid.i				

# These files are built by SWIG.  The first is the C++ glue.
# The second is the python wrapper that loads the _rfid shared library
# and knows how to call our extensions.

BUILT_SOURCES = 			\
	rfid.cc			\
	rfid.py				

# This gets listener.py installed in the right place
ourpython_PYTHON =			\
	rfid.py

ourlib_LTLIBRARIES = _rfid.la

# These are the source files that go into the shared library
_rfid_la_SOURCES = 			\
	rfid.cc				\
	rfid_clock_recovery_zc_ff.cc	\
	rfid_cmd_gate.cc		\
	rfid_gen2_reader.cc		\
	rfid_reader_decoder.cc		
	


# magic flags
_rfid_la_LDFLAGS = -module -avoid-version

# link the library against some comon swig runtime code and the 
# c++ standard library
_rfid_la_LIBADD = 				\
	-lstdc++			
	-lgrswigrunpy		

rfid.cc rfid.py: rfid.i $(ALL_IFILES)
	$(SWIG) $(SWIGCPPPYTHONARGS) -module rfid -o rfid.cc $<

#rfid.cc rfid.py:  $(LOCAL_IFILES) $(ALL_IFILES)
#	$(SWIG) $(SWIGPYTHONARGS) -module rfid -o rfid.cc $(LOCAL_IFILES)

# These headers get installed in ${prefix}/include/gnuradio
grinclude_HEADERS =                     \
	rfid_clock_recovery_zc_ff.h	\
	rfid_cmd_gate.h			\
	rfid_gen2_reader.h		\
	rfid_reader_decoder.h		
	
# These swig headers get installed in ${prefix}/include/gnuradio/swig
swiginclude_HEADERS = 			\
	$(LOCAL_IFILES)			

# Don't distribute output of swig
#dist-hook:
#	@for file in $(BUILT_SOURCES); do echo $(RM) $(distdir)/$$file; done
#	@for file in $(BUILT_SOURCES); do $(RM) $(distdir)/$$file; done

#MOSTLYCLEANFILES = $(BUILT_SOURCES) *.pyc

