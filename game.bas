include "mega65-lib/mega65.bas"
include "mega65-lib/memory.bas"
include "mega65-lib/fullcolor.bas"

const GAME_WIDTH = 7
const GAME_HEIGHT = 15

type Hexagon
    color as byte
    isbrick as byte
    redraw as byte
end type

dim tiles as byte
dim map(GAME_WIDTH, GAME_HEIGHT) as Hexagon

sub init_hexagons() static
    for x as byte = 0 to GAME_WIDTH - 1
        for y as byte = 0 to GAME_HEIGHT - 1
            map(x,y).isbrick = true
            map(x,y).redraw = true
            map(x,y).color = rndb() mod 4
        next
    next
end sub

function draw_hexagons as byte () static
    dim numTiles as byte: numTiles = 0
    dim tileOffsetX as byte
    dim tileOffsetY as byte

    for y as byte = 0 to GAME_HEIGHT - 1
        for x as byte = 0 to GAME_WIDTH - 1
            if map(x,y).redraw then
                map(x,y).redraw = false
                if map(x,y).isbrick then
                    numTiles = numTiles + 1
                    tileOffsetX = 7 * map(x,y).color
                    tileOffsetY = 0
                else
                    tileOffsetX = 7
                    tileOffsetY = 6
                end if 
                call fc_displayTile(tiles, 4 + x*10 + 5 * (y mod 2), y*3, tileOffsetX, tileOffsetY, 7, 6, true)
            end if
        next
    next
    return numTiles
end sub

main:
    randomize ti()
    call enable_40mhz()
    call fc_init(true, true, 0, 0)
    ' Where we will allow merging of tiles 
    ' (the whole screen takes too much memory)
    call fc_setUniqueTileMode(2, 3, 72, 45)
    tiles = fc_loadFCI("tiles.fci") 
    call fc_loadFCIPalette(tiles)
    call init_hexagons()

    ' draw bottom wall
    call fc_displayTile(tiles, 0, 44, 0, 6, 28, 6, false)
    call fc_displayTile(tiles, 28, 44, 0, 6, 28, 6, false)
    call fc_displayTile(tiles, 56, 44, 0, 6, 24, 6, false)
    ' draw hexagons
    call draw_hexagons()
loop:
    goto loop
