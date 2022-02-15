include "xc-megalib/mega65.bas"
include "xc-megalib/memory.bas"
include "xc-megalib/fullcolor.bas"

main:
    dim key as byte
    dim tiles as byte
    dim name as String*80

    call enable_40mhz()
    call fc_init(true, false, 0, 0)

    call fc_setMergeTileMode(10,1, 60, 23, true)

    tiles = fc_loadFCI("civ.fci")
    call fc_loadFCIPalette(tiles)
    'call fc_displayFCI(tiles, 0, 0)

    call fc_putsxy(9, 1, "X")
    call fc_putsxy(70, 1, "X")
    call fc_putsxy(10, 24, "X")

    call fc_mergeTile(tiles, 10, 0, 0, 0, 4, 4)
    call fc_mergeTile(tiles, 14, 0, 8, 0, 4, 4)
    call fc_mergeTile(tiles, 18, 0, 8, 0, 4, 4)
    call fc_mergeTile(tiles, 22, 0, 16, 0, 4, 4)
    call fc_mergeTile(tiles, 26, 0, 12, 0, 4, 4)
    call fc_mergeTile(tiles, 30, 0, 12, 0, 4, 4)
    call fc_mergeTile(tiles, 34, 0, 12, 0, 4, 4)
    call fc_mergeTile(tiles, 38, 0, 12, 0, 4, 4)
    call fc_mergeTile(tiles, 42, 0, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 46, 0, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 50, 0, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 54, 0, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 58, 0, 12, 0, 4, 4)

    call fc_mergeTile(tiles, 8, 3, 4, 0, 4, 4)
    call fc_mergeTile(tiles, 12, 3, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 16, 3, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 20, 3, 16, 0, 4, 4)
    'call fc_mergeTile(tiles, 24, 3, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 28, 3, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 32, 3, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 36, 3, 12, 0, 4, 4)

    call fc_mergeTile(tiles, 10, 6, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 14, 6, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 18, 6, 16, 0, 4, 4)
    'call fc_mergeTile(tiles, 22, 6, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 26, 6, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 30, 6, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 34, 6, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 38, 6, 12, 0, 4, 4)

    call fc_mergeTile(tiles, 8, 9, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 12, 9, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 16, 9, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 20, 9, 16, 0, 4, 4)
    'call fc_mergeTile(tiles, 24, 9, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 28, 9, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 32, 9, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 36, 9, 12, 0, 4, 4)

    call fc_mergeTile(tiles, 10, 12, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 14, 12, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 18, 12, 16, 0, 4, 4)
    'call fc_mergeTile(tiles, 22, 12, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 26, 12, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 30, 12, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 34, 12, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 38, 12, 12, 0, 4, 4)

    call fc_mergeTile(tiles, 8, 15, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 12, 15, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 16, 15, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 20, 15, 16, 0, 4, 4)
    'call fc_mergeTile(tiles, 24, 15, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 28, 15, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 32, 15, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 36, 15, 12, 0, 4, 4)

    call fc_mergeTile(tiles, 10, 18, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 14, 18, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 18, 18, 16, 0, 4, 4)
    'call fc_mergeTile(tiles, 22, 18, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 26, 18, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 30, 18, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 34, 18, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 38, 18, 12, 0, 4, 4)

    call fc_mergeTile(tiles, 8, 21, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 12, 21, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 16, 21, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 20, 21, 16, 0, 4, 4)
    'call fc_mergeTile(tiles, 24, 21, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 28, 21, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 32, 21, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 36, 21, 12, 0, 4, 4)

    call fc_mergeTile(tiles, 10, 24, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 14, 24, 4, 0, 4, 4)
    'call fc_mergeTile(tiles, 18, 24, 16, 0, 4, 4)
    'call fc_mergeTile(tiles, 22, 24, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 26, 24, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 30, 24, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 34, 24, 12, 0, 4, 4)
    'call fc_mergeTile(tiles, 38, 24, 12, 0, 4, 4)

    call fc_putsxy(0, 0, "Game Orders Advisors World Civilopedia")
    call fc_putsxy(0, 7, "30,000")
    call fc_putsxy(0, 8, "3300 BC")
    call fc_putsxy(0, 10, "Spartan")
    call fc_putsxy(0, 11, "Militia")
    call fc_putsxy(0, 12, "Moves: 1")

    call fc_center(0, 24, gScreenColumns, "press any key")
    key = fc_getkey(true)
    'print "all done"
    call fc_fatal("all done")
