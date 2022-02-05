# xc-megademo
A demonstration of using XC=BASIC 3 to program the MEGA65 in full color graphics mode.

Read more about XC=BASIC in the [manual](https://xc-basic.net/doku.php?id=v3:start).

The full color mode is adapted from FCIO in the mega65 C library. There is a good [tutorial](https://steph72.github.io/fcio-tutorial/) that will give a nice overview.

# Getting Started

Download and install [xc-basic 3](https://github.com/neilsf/xc-basic3)
and the [DASM assembler](https://github.com/dasm-assembler/dasm).

Make sure that you have a MEGA65 emulator installed, for example xemu-xmega65.

Put the correct paths to these programs in the Makefile.

Type "make" to run the example program.

# FC changes

unify reserved\* / dynamic\* to and use index 0 for reserved, 1.. for things that can be cleared and reused

remove Ext-version of printout functions (no longer needed since font can be specified)


# TODO

add fc_setfont (similar to fc_setwin) which can be either the standard font, or use one of the bitmaps. Change all fc_put\* and similar to use this info



