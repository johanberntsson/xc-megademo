# define the paths to suppprting programs
C1541 := c1541
XEMU := xemu-xmega65
DASM := ../../dasm/bin/dasm
XCBASIC3 := ../bin/Linux/xcbasic3

# basic library source files
LIBSOURCE :=  $(wildcard **/*.bas)

# png files to convert and add to the floppy
PNGS := $(wildcard img-src/*.png)
FCIS := $(subst img-src, res, $(PNGS:%.png=%.fci))

# phony target is simply a target that is always out-of-date
.PHONY: demo, game, all, clean

all: demo

demo: demo.d81
	$(XEMU) -8 demo.d81

game: game.d81
	$(XEMU) -8 game.d81


# convert png to fci (MEGA65 full color mode graphics)
res/%.fci: img-src/%.png
	python3 tools/png2fci.py -v0r $< $@

bin/%.prg: %.bas $(LIBSOURCE)
	mkdir -p bin res
	$(XCBASIC3) $< $@ -d $(DASM)

%.d81: bin/%.prg $(FCIS)
	rm -f $@
	cat c65bin/c65toc64wrapper.prg bin/$*.prg > bin/autoboot.c65
	$(C1541) -format xc-megademo,sk d81 $@
	$(C1541) $@ -write bin/autoboot.c65
	for filename in res/*; do \
	    $(C1541) $@ -write $$filename; \
	done

clean:
	rm -rf bin res *.d81

