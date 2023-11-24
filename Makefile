ASM = acme
ASMFLAGS = -f cbm -l main.sym -v3 --color -Wno-label-indent

INCLUDES = -I../wic64-library
SOURCES = *.asm ../wic64-library/wic64.asm ../wic64-library/wic64.h

EMU ?= x64sc
EMUFLAGS ?=

TARGET = wic64-update

.PHONY: all clean

all: $(TARGET).prg

$(TARGET).prg: $(SOURCES)
	$(ASM) $(ASMFLAGS) $(INCLUDES) -l $(TARGET).sym -o $(TARGET).prg  update.asm

test: $(TARGET).prg
	$(EMU) $(EMUFLAGS) $(TARGET).prg

clean:
	rm -f *.{prg,sym}
