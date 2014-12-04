

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
	$(GNURADIO_RUNTIME_INCLUDEDIR)/gnuradio/swig/gnuradio.i

LOCAL_IFILES = 				\
	listener.i

# These files are built by SWIG.  The first is the C++ glue.
# The second is the python wrapper that loads the _listener shared library
# and knows how to call our extensions.

BUILT_SOURCES = 			\
	listener.cc			\
	listener.py				

# This gets listener.py installed in the right place
ourpython_PYTHON =			\
	listener.py

ourlib_LTLIBRARIES = _listener.la

# These are the source files that go into the shared library
_listener_la_SOURCES = 				\
	listener.cc				\
	listener_reader_monitor_cmd_gate.cc	\
	listener_clock_recovery.cc		\
	listener_tag_monitor.cc			
	

# magic flags
_listener_la_LDFLAGS = -module -avoid-version

# link the library against some comon swig runtime code and the 
# c++ standard library
_listener_la_LIBADD = 				\
	-lstdc++			
	-lgrswigrunpy

listener.cc listener.py: listener.i $(ALL_IFILES)
	$(SWIG) $(SWIGCPPPYTHONARGS) -module listener -o listener.cc $<

#listener.cc listener.py:  $(LOCAL_IFILES) $(ALL_IFILES)
#	$(SWIG) $(SWIGPYTHONARGS) -module listener -o listener.cc $(LOCAL_IFILES)

# These headers get installed in ${prefix}/include/gnuradio
grinclude_HEADERS =                     	\
	listener_clock_recovery.h		\
	listener_reader_monitor_cmd_gate.h	\
	listener_tag_monitor.h				


# These swig headers get installed in ${prefix}/include/gnuradio/swig
swiginclude_HEADERS = 			\
	$(LOCAL_IFILES)			

# Don't distribute output of swig
#dist-hook:
#	@for file in $(BUILT_SOURCES); do echo $(RM) $(distdir)/$$file; done
#	@for file in $(BUILT_SOURCES); do $(RM) $(distdir)/$$file; done

#MOSTLYCLEANFILES = $(BUILT_SOURCES) *.pyc
