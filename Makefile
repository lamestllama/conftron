## Conftron makefile.  
## -Wunused-parameter.
UNAME := $(shell uname)

SRC = lcm_interface.c 
SRC += $(shell ls *_telemetry.c)

LCM_TYPES = $(shell cat classes.dat | perl -pe "s/(\w+) /\1.lcm /gi;" 2>/dev/null)
SRC += $(shell ./types.sh $(LCM_TYPES))

OBJ_DIR = obj
OBJ = $(SRC:%.c=$(OBJ_DIR)/%.o)

INCLUDES += -I.
LDFLAGS += -llcm

XML = types.xml telemetry.xml settings.xml
XML_PATH = conf/

AP_PROJECT_ROOT ?= ..

WARNINGFLAGS = -Wall -Wextra -Werror -std=gnu99
AUTOFLAGS = -Wno-unused-parameter
DEBUGFLAGS = -g -DDT=0.01
OPTFLAGS = 

LIB_DIR = lib
LIBSRC = $(shell ls stubs/*stub.c)
LIBOBJ = $(LIBSRC:%.c=%.o)
LIBNAME = libautostubs
LIBFLAGS = -fpic 
MKLIBFLAGS = -shared -Wl,-soname,$(LIBNAME).so

ifeq ($(UNAME),Darwin)
	LDFLAGS += -L/usr/local/lib
	INCLUDES += -isystem /usr/local/include
else
OPTFLAGS += -march=native -O3 
endif

CFLAGS ?= $(WARNINGFLAGS) $(DEBUGFLAGS) $(INCLUDES) $(OPTFLAGS) -DAIRFRAME_CONSTANTS=\<airframes/$(aircraft).h\>

Q ?= @

.PHONY: all clean tidy megaclean

## The author apologizes for the `all' make target, also known as
## LAMBDA: THE ULTIMATE MONAD (with apologies to Steele, Peyton-Jones
## and many others).  His make skills are not strong.  
all: 
	$(Q)$(MAKE) -C . clean
	$(Q)$(MAKE) -C . gen
	$(Q)$(MAKE) -C . compile -j

engage: all

lcm:
	$(Q)lcm-gen -c $(LCM_TYPES) --c-cpath auto/ --c-hpath auto/
	$(Q)lcm-gen -p $(LCM_TYPES) --ppath python/

gen: 
	@echo
	@echo ----- Generating LCM types and custom C interface. -----
	@echo
	$(Q)python lcmgen.py $(AP_PROJECT_ROOT)/$(XML_PATH)/airframes/$(AIRCRAFT).xml 
	$(Q)$(MAKE) -C . lcm
	@echo
	@echo ----- Done generating code.  -----
	@echo

# This builds a shared library. 
# $(Q)$(CC) $(CFLAGS) $(MKLIBFLAGS) $< -o $(LIB_DIR)/$(LIBNAME).so
# @echo LIBCC $(LIBNAME).so

lib: $(LIBOBJ)
	@echo AR $(LIBNAME).a
	$(Q)$(AR) rcs $(LIB_DIR)/$(LIBNAME).a $(LIBOBJ)
	$(Q)rm *stub.o &>/dev/null || echo

compile: lib $(OBJ) 

stubs/%stub.o : stubs/%stub.c
	@echo LIBCC $@
	$(Q)$(CC) -c $(CFLAGS) $(LIBFLAGS) $< -o $@

$(OBJ_DIR)/%.o : auto/%.c 
	@echo CC $@
	$(Q)$(CC) -c $(CFLAGS) $(AUTOFLAGS) $< -o $@

$(OBJ_DIR)/%.o : %.c
	@echo CC $@
	$(Q)$(CC) -c $(CFLAGS) $< -o $@

$(OBJ_DIR)/%.o : telemetry/%.c 
	@echo CC $@
	$(Q)$(CC) -c $(CFLAGS) $< -o $@

$(OBJ_DIR)/%.o : settings/%.c
	@echo CC $@
	$(Q)$(CC) -c $(CFLAGS) $< -o $@

upstream: 
	$(Q)cd upstream; \
	./configure; \
	$(MAKE); \
	sudo $(MAKE) install; \
	sudo ldconfig || echo "no ldconfig found; hope you're on a mac"; 

clean: 
	$(Q)./clean.sh &>/dev/null

megaclean:
	$(MAKE) -C upstream clean
