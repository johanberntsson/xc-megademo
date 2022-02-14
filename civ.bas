include "xc-megalib/mega65.bas"
include "xc-megalib/memory.bas"
include "xc-megalib/fullcolor.bas"

main:
    dim key as byte
    dim tiles as byte
    dim name as String*80

    call enable_40mhz()
    call fc_init(true, true, true, 0, 0)

    call fc_plotPetsciiChar(0, 20, $35, WHITE, 0)
    call fc_plotPetsciiChar(2, 17, $30, RED, 0)

    tiles = fc_loadFCI("civ.fci")
    call fc_loadFCIPalette(tiles)
    call fc_displayFCI(tiles, 0, 0, true)

    call fc_displayTile(tiles, 20, 10, 0, 0, 4, 4, true)
    call fc_displayTile(tiles, 24, 10, 8, 0, 4, 4, true)
    call fc_displayTile(tiles, 28, 10, 8, 0, 4, 4, true)
    call fc_displayTile(tiles, 32, 10, 16, 0, 4, 4, true)
    call fc_displayTile(tiles, 36, 10, 12, 0, 4, 4, true)

    call fc_displayTile(tiles, 18, 13, 4, 0, 4, 4, true)
    call fc_displayTile(tiles, 22, 13, 4, 0, 4, 4, true)
    call fc_displayTile(tiles, 26, 13, 4, 0, 4, 4, true)
    call fc_displayTile(tiles, 30, 13, 16, 0, 4, 4, true)
    call fc_displayTile(tiles, 34, 13, 12, 0, 4, 4, true)

    call fc_displayTile(tiles, 20, 16, 4, 0, 4, 4, true)
    call fc_displayTile(tiles, 24, 16, 4, 0, 4, 4, true)
    call fc_displayTile(tiles, 28, 16, 16, 0, 4, 4, true)
    call fc_displayTile(tiles, 32, 16, 12, 0, 4, 4, true)

    call fc_center(0, 3, gScreenColumns, "press any key")
    key = fc_getkey(true)
    print "all done"
    call fc_fatal("just a test")
