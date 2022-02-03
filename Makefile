# define the paths to suppprting programs
C1541 := c1541
XEMU := xemu-xmega65
DASM := ../../dasm/dasm
XCBASIC3 := ../bin/Linux/xcbasic3
# generated binaries
PRG := bin/demo.prg
DISCNAME := xc-megademo.d81
# all basic source files
MAINSOURCE := demo.bas
BASICSOURCE :=  $(MAINSOURCE) $(wildcard **/*.bas)
# png files to convert and add to the floppy
PNGS := $(wildcard img-src/*.png)
FCIS := $(subst img-src, res, $(PNGS:%.png=%.fci))

# phony target is simply a target that is always out-of-date
.PHONY: mega65, mega65-prg, all, clean

all: mega65

# convert png to fci (MEGA65 full color mode graphics)
res/%.fci: img-src/%.png
	python3 tools/png2fci.py -v0r $< $@

$(PRG): $(BASICSOURCE)
	mkdir -p bin res
	$(XCBASIC3) $(MAINSOURCE) $(PRG) -d $(DASM)

$(DISCNAME): $(PRG) $(FCIS)
	cat c65bin/c65toc64wrapper.prg $(PRG) > bin/autoboot.c65
	$(C1541) -format xc-megademo,sk d81 $(DISCNAME)
	$(C1541) $(DISCNAME) -write bin/autoboot.c65
	for filename in res/*; do \
	    $(C1541) $(DISCNAME) -write $$filename; \
	done

mega65: $(DISCNAME)
	$(XEMU) -8 $(DISCNAME)

mega65-prg: $(PRG)
	$(XEMU) -prg $(PRG)

clean:
	rm -rf bin res $(DISCNAME)

