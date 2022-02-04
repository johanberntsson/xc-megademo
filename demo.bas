include "mega65-lib/mega65.bas"
include "mega65-lib/memory.bas"
include "mega65-lib/fullcolor.bas"


main:
    dim tiles as byte

    call enable_40mhz()
    call fc_init(1, 1, 60)
    call fc_plotPetsciiChar(0, 10, $35, WHITE, 0)
    'call fc_displayFCIFile("tiles.fci",0,0)
    tiles = fc_loadFCI("tiles.fci")
    call fc_loadFCIPalette(tiles)
    call fc_displayFCI(tiles, 0, 0, true)
    call fc_displayTile(tiles, 20, 20, 0, 0, 6, 7, true)
    call fc_plotPetsciiChar(2, 15, $30, RED, 0)
    call fc_putsxy(3, 13, "press any key")
    'call fc_getkey()
loop:
    goto loop
