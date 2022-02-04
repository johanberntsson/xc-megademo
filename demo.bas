include "mega65-lib/mega65.bas"
include "mega65-lib/memory.bas"
include "mega65-lib/fullcolor.bas"

main:
    call enable_40mhz()
    call fc_init(1, 1, 60)
    call fc_plotPetsciiChar(0, 10, $35, WHITE, 0)
    call fc_displayFCIFile("tiles.fci",0,0)
    call fc_plotPetsciiChar(2, 15, $30, RED, 0)
    call fc_putsxy(3, 13, "press any key")
    'call fc_getkey()
loop:
    goto loop
