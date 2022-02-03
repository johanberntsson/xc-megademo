XEMU := xemu-xmega65
DASM := ../../dasm/dasm
XCBASIC3 := ../bin/Linux/xcbasic3

all: mega65

compile:
	$(XCBASIC3) megademo.bas megademo.prg -d $(DASM)

c64: compile
	#x64 test.prg

mega65: compile
	$(XEMU) -prg megademo.prg

clean:
	rm -f megademo.prg

