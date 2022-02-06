include "mega65-lib/mega65.bas"
include "mega65-lib/memory.bas"
include "mega65-lib/fullcolor.bas"


main:
    dim tiles as byte
    dim name as String*80

    call enable_40mhz()
    call fc_init(1, 1, 0, 0)

    call fc_plotPetsciiChar(0, 20, $35, WHITE, 0)
    call fc_plotPetsciiChar(2, 17, $30, RED, 0)

    'call fc_displayFCIFile("tiles.fci",0,0)
    tiles = fc_loadFCI("tiles.fci")
    call fc_loadFCIPalette(tiles)
    call fc_displayFCI(tiles, 0, 0, true)
    call fc_displayTile(tiles, 20, 20, 0, 0, 7, 6, true)
    call fc_displayTile(tiles, 25, 23, 0, 0, 7, 6, true)

    call fc_gotoxy(0,14)
    call fc_puts("What is your name? ")
    call fc_textcolor(ORANGE)
    name = fc_input()

    call fc_clrscr()
    call fc_textcolor(WHITE)
    call fc_puts("hello ")
    call fc_textcolor(RED)
    call fc_revers(true)
    call fc_puts(name)
    call fc_revers(false)
    call fc_textcolor(GREEN)

    call fc_hlinexy(20,10,20,$30)

    call fc_center(0, 13, gScreenColumns, "press any key")
    call fc_getkey()
    print "all done"
    call fc_fatal("just a test")
