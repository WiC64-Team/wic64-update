ASM = acme
ASMFLAGS = -f cbm -l main.sym -v3 --color -Wno-label-indent

INCLUDES = -I../wic64-library
SOURCES = *.asm ../wic64-library/wic64.asm ../wic64-library/wic64.h

EMU ?= x64sc
EMUFLAGS ?=

TARGET_DEFAULT = wic64-update
TARGET_PORTAL = wic64-update-portal

.PHONY: all clean

all: $(TARGET_DEFAULT).prg $(TARGET_PORTAL).prg

$(TARGET_DEFAULT).prg: $(SOURCES)
	$(ASM) $(ASMFLAGS) $(INCLUDES) -l $(TARGET_DEFAULT).sym -o $(TARGET_DEFAULT).prg  update.asm

$(TARGET_PORTAL).prg: $(SOURCES)
	$(ASM) $(ASMFLAGS) $(INCLUDES) -DPORTAL_VERSION=1 -l $(TARGET_PORTAL).sym -o $(TARGET_PORTAL).prg  update.asm

test: $(TARGET_DEFAULT).prg
	$(EMU) $(EMUFLAGS) $(TARGET_DEFAULT).prg

test-portal: $(TARGET_PORTAL).prg
	$(EMU) $(EMUFLAGS) $(TARGET_PORTAL).prg

clean:
	rm -f *.{prg,sym}
