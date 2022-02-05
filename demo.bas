include "mega65-lib/mega65.bas"
include "mega65-lib/memory.bas"
include "mega65-lib/fullcolor.bas"


main:
    dim tiles as byte

    call enable_40mhz()
    call fc_init(1, 1, 60)

    call fc_plotPetsciiChar(0, 10, $35, WHITE, 0)
    call fc_plotPetsciiChar(2, 15, $30, RED, 0)

    'call fc_displayFCIFile("tiles.fci",0,0)
    tiles = fc_loadFCI("tiles.fci")
    call fc_loadFCIPalette(tiles)
    call fc_displayFCI(tiles, 0, 0, true)
    call fc_displayTile(tiles, 20, 20, 0, 0, 6, 7, true)

    call fc_center(0, 13, gScreenColumns, "press any key")
    call fc_getkey()

    call fc_clrscr()
    call fc_textcolor(WHITE)
    call fc_puts("hello ")
    call fc_textcolor(RED)
    call fc_flash(true)
    call fc_puts("sailor")
    call fc_flash(false)
    call fc_textcolor(GREEN)

    call fc_hlinexy(20,10,20,$30)

    call fc_center(0, 13, gScreenColumns, "all done")
loop:
    goto loop
