SHELL := /bin/sh
TARGET = hello

SOURCES = hello.c
OBJECTS = $(SOURCES:%.c=%.o)

CC = gcc
LD = gcc
GDB = gdb
UPX = $(realpath ../../upx/src/upx.out)

LDFLAGS += -static

# GCC verbose option
#CFLAGS += -v
#LDFLAGS += -v

# GCC debugging options
#CFLAGS += -g3 -ggdb3

# Disable stack protector 
#CFLAGS += -fno-stack-protector

# Disable fortify source 
#CFLAGS += -D_FORTIFY_SOURCE=0

# Disable PIE
#LDFLAGS += -no-pie

# Disable NX
#LDFLAGS += -z execstack

# Disable RELRO
#LDFLAGS += -z norelro


# Common common definitions
#ENV_DIR = $(realpath ../glibc/env)
#GLIBC_VER = 2.27

# Interpreter
#INTERPRETER = $(ENV_DIR)/glibc-$(GLIBC_VER)/sysroot/lib/ld.so)
#LDFLAGS += -Wl,--dynamic-linker=$(INTERPRETER)

# GDB
#GLIBC_DIR = $(ENV_DIR)/build/glibc-$(GLIBC_VER)
#GDBOPT_DIRECTORY = --directory="$(GLIBC_DIR):$\
#$(GLIBC_DIR)/csu:$\
#$(GLIBC_DIR)/elf:$\
#$(GLIBC_DIR)/stdlib"

#GDBOPTS = -q $(GDBOPT_DIRECTORY)


all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) $^ -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

gdb: $(TARGET)
	$(GDB) $(GDBOPTS) $(TARGET)

pack:
	@if [ ! -x $(TARGET) ]; then \
        echo 'Run make fisrt'; \
		exit 1; \
	fi	
	$(UPX) -k $(TARGET)

unpack:
	@if [ ! -x $(TARGET).~ ]; then \
        echo 'Run make fisrt'; \
		exit 1; \
	fi	
	$(UPX) -d $(TARGET)

.PHONY: distclean clean

clean:
	$(RM) *.o $(TARGET).~ $(TARGET)

distclean: clean
	$(RM) .gdb_history peda-session-*.txt 

