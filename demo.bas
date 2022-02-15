include "xc-megalib/mega65.bas"
include "xc-megalib/memory.bas"
include "xc-megalib/fullcolor.bas"


main:
    dim key as byte
    dim tiles as byte
    dim name as String*80

    call enable_40mhz()
    call fc_init(true, true, 0, 0)
    'call fc_setMergeTileMode(20, 20, 20, 20, false)
    call fc_setMergeTileMode()

    call fc_plotPetsciiChar(0, 20, $35, WHITE, 0)
    call fc_plotPetsciiChar(2, 17, $30, RED, 0)

    'call fc_displayFCIFile("tiles.fci",0,0)
    tiles = fc_loadFCI("tiles.fci")

    call fc_loadFCIPalette(tiles)
    call fc_displayFCI(tiles, 0, 0, true)
    call fc_mergeTile(tiles, 20, 20, 0, 0, 7, 6)
    call fc_mergeTile(tiles, 25, 23, 0, 0, 7, 6)

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
    key = fc_getkey(true)
    print "all done"
    call fc_fatal("just a test")
