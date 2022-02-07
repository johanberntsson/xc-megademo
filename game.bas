include "mega65-lib/mega65.bas"
include "mega65-lib/memory.bas"
include "mega65-lib/fullcolor.bas"

const GAME_WIDTH = 15
const GAME_HEIGHT = 7

const SPRPTRADR = $d06c
const SPRPTRBNK = $d06e
const JOYSTICK1 = $dc00
const JOYSTICK2 = $dc01

type Hexagon
    color as byte
    isbrick as byte
    redraw as byte
end type

dim tiles as byte
dim map(GAME_WIDTH, GAME_HEIGHT) as Hexagon

cursorsprite:
data as byte $00,$00,$00,$aa,$a0,$00,$95,$60
data as byte $00,$95,$60,$00,$95,$80,$00,$95
data as byte $80,$00,$95,$60,$00,$95,$58,$00
data as byte $99,$56,$00,$9a,$55,$80,$a0,$95
data as byte $60,$80,$25,$60,$00,$09,$80,$00
data as byte $02,$00,$00,$00,$00,$00,$00,$00
data as byte $00,$00,$00,$00,$00,$00,$00,$00
data as byte $00,$00,$00,$00,$00,$00,$00,$81
dim spritedata(64) as byte @cursorsprite

sub set_sprite(x as byte, y as byte) static
    x = 200: y = 229
    poke VIC2, x
    poke VIC2 + 1, y
end sub

sub show_sprite() static
    dim spriteaddress as long: spriteaddress = $c000
    dim spritepointers as long: spritepointers = 800
    dim spritelocation as word

    for i as byte = 0 to 63
        poke cword(spriteaddress) + i, spritedata(i)
    next
    poke $c000+62,0

    ' allow sprite data to be placed anywhere in memory,
    ' although still on 64-byte boundaries
    ' Location of the list of pointers
    poke SPRPTRADR, BYTE0(spritepointers)
    poke SPRPTRADR + 1, BYTE1(spritepointers)
    ' two bytes per sprite pointer in bank 0 (SPRPTR16)
    poke SPRPTRBNK, $80 or BYTE2(spritepointers)

    ' put sprite at $c000 (768 * 64 = 0 + 3 * 256 * 64)
    spritelocation = cword(spriteaddress / 64)
    poke cword(spritepointers), BYTE0(spritelocation)
    poke cword(spritepointers + 1), BYTE1(spritelocation)

    poke VIC2, 150
    poke VIC2 + 1, 150 
    poke VIC2 + 21, 1
    poke VIC2 + 23, 1 ' expand y
    poke VIC2 + 28, 1 ' hires/multicolor
    poke VIC2 + 29, 1 ' expand x
    poke VIC2 + 37, DGREY
    poke VIC2 + 38, YELLOW
    poke VIC2 + 39, WHITE
end sub

sub init_hexagons() static
    for y as byte = 0 to GAME_HEIGHT - 1
        for x as byte = 0 to GAME_WIDTH - 1
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
                call fc_displayTile(tiles, 2 + x*5, 3 + y*6 + 3 * (x mod 2), tileOffsetX, tileOffsetY, 7, 6, true)
            end if
        next
    next
    return numTiles
end sub

main:
    dim x as byte
    dim y as byte
    dim key as byte
    randomize ti()
    call enable_40mhz()
    call fc_init(true, true, true, 0, 0)
    ' d054 controls the horizontal resolution and position
    poke $d054,peek($d054) or 16
    ' d076 should control vertical resolution and position
    poke $d076,255
    tiles = fc_loadFCI("tiles.fci") 
    call fc_loadFCIPalette(tiles)
    call init_hexagons()
    call show_sprite()
    call fc_displayTile(tiles, 0, 44, 0, 6, 28, 6, false)
    call fc_displayTile(tiles, 28, 44, 0, 6, 28, 6, false)
    call fc_displayTile(tiles, 56, 44, 0, 6, 24, 6, false)
    call draw_hexagons()
    call set_sprite(0, 3)
    x = 0
    y = 0
loop:
    goto loop
    print key, x, y
    call set_sprite(x, y)
    key = fc_getkey()
    if key = 97 then x = x - 1
    if key = 100 then x = x + 1
    if key = 119 then y = y - 1
    if key = 115 then y = y + 1
    if key = 32 then call fc_fatal()
    if x < 0 then x = 0
    if y < 0 then y = 0
    if x >= GAME_WIDTH then x = GAME_WIDTH -1
    if y >= GAME_HEIGHT then y = GAME_HEIGHT -1
