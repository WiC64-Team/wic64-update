ASM = acme
ASMFLAGS = -f cbm -l main.sym -v3 --color -Wno-label-indent
INCLUDES = -I../wic64-library
SOURCES = *.asm ../wic64-library/wic64.asm ../wic64-library/wic64.h
EMU ?= x64sc
EMUFLAGS ?=

.PHONY: all clean

all: update.prg

%.prg: %.asm $(SOURCES)
	$(ASM) $(ASMFLAGS) $(INCLUDES) -l $*.sym -o $*.prg  $*.asm

test: update.prg
	$(EMU) $(EMUFLAGS) update.prg

clean:
	rm -f *.{prg,sym}
