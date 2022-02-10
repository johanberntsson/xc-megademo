include "mega65-lib/mega65.bas"
include "mega65-lib/memory.bas"
include "mega65-lib/fullcolor.bas"

const GAME_WIDTH = 15
const GAME_HEIGHT = 7
const GAME_SIZE = 105 ' GAME_WIDTH * GAME_HEIGHT

const SPRPTRADR = $d06c
const SPRPTRBNK = $d06e
const JOYSTICK1 = $dc00
const JOYSTICK2 = $dc01

const STATE_DONE = 0
const STATE_REPAINT = 1
const STATE_HIGHLIGHT = 2
const STATE_EXPLOSION = 4

' don't change these. They are updated by the interrupt
dim irqtimer as long @$fb
dim irqcounter as byte @$fe

type Hexagon
    color as byte
    isbrick as byte
    state as byte
    state_cnt as byte
    hascursor as byte
    isqueuing as byte
end type
dim map(GAME_WIDTH, GAME_HEIGHT) as Hexagon

dim logo as byte
dim tiles as byte

type HexCoordinate
    hex_x as byte
    hex_y as byte
end type
dim queue_len as byte
dim queue(GAME_SIZE) as HexCoordinate

' We will use doubled coordinates for the hexagons
' https://www.redblobgames.com/grids/hexagons/

function x_hex2array as byte (x as byte, y as byte) shared static
    return x
end function

function y_hex2array as byte (x as byte, y as byte) shared static
    return y / 2
end function

function x_array2hex as byte (x as byte, y as byte) shared static
    return x
end function

function y_array2hex as byte (x as byte, y as byte) shared static
    return y * 2 + (x mod 2)
end function

x_adjacenthexagons:
data as int -1, -1, 0, 1, 1, 0
y_adjacenthexagons:
data as int -1, 1, 2, 1, -1, -2
dim dx(6) as int @x_adjacenthexagons
dim dy(6) as int @y_adjacenthexagons

amigacursorsprite:
data as byte $ff,$f0,$00,$ea,$ac,$00,$ea,$ac
data as byte $00,$d5,$6c,$00,$d5,$6c,$00,$d5
data as byte $b0,$00,$d5,$b0,$00,$d5,$6c,$00
data as byte $d5,$6c,$00,$d7,$5b,$00,$d7,$5b
data as byte $00,$3c,$d6,$c0,$3c,$d6,$c0,$00
data as byte $35,$b0,$00,$35,$b0,$00,$0d,$6c
data as byte $00,$0d,$6c,$00,$03,$70,$00,$03
data as byte $70,$00,$00,$c0,$00,$00,$c0,$81
dim spritedata(64) as byte @amigacursorsprite

function x_array2screen as byte (x as byte, y as byte) static
    return x * 5 
end function

function y_array2screen as byte (x as byte, y as byte) static
    return 2 + 6 * y + 3 * (x mod 2)
end function

sub start_irq () static
    ' 60 Hz is too much, so only increase the irqtimer
    ' every 6th time (making it 10 Hz)
    irqtimer = 0
    irqcounter = 6
    asm
        jmp startirq
irqcallback:
        ; update irqtimer
        ; first step down from 60 to 10 Hz
        dec $fe
        bne done
        lda #6
        sta $fe
        ; increase irqtimer (long at $fb)
        inc $fb
        bne done
        inc $fc
        bne done
        inc $fd
        lda $fd
        and #$7f ; don't allow negative numbers
        sta $fd
done:
        ; play music
        ;jsr $a04e
        ;jsr $a0fa

        ; end irq
        lda #$ff
        sta $d019
        jmp $ea31
startirq:
        ; init music
        ;jsr $a000
        ;jsr $a046

        ; Suspend interrupts during init
        sei
        ;  Disable CIA
        lda #$7f
        sta $dc0d
        ; Enable raster interrupts
        lda $d01a
        ora #$01
        sta $d01a
        ; High bit of raster line cleared, we're
        ; only working within single byte ranges
        lda $d011
        and #$7f
        sta $d011
        ; We want an interrupt at the top line
        lda #140
        sta $d012
        ; Push low and high byte of our routine into IRQ vector addresses
        lda #<irqcallback
        sta $0314
        lda #>irqcallback
        sta $0315
        ; Enable interrupts again
        cli
    end asm
end sub

function is_valid_hex as byte (hex_x as byte, hex_y as byte) static
    ' negative x and y are 254 or 255, so will be caught below
    'if hex_x >= 254 then return false
    'if hex_y >= 254 then return false
    if hex_x >= GAME_WIDTH then return false
    if hex_y >= 2 * GAME_HEIGHT then return false
    return true
end function

sub refresh_adjacent(hex_x as byte, hex_y as byte) static
    dim x as byte
    dim y as byte
    dim hx as byte
    dim hy as byte
    'print "refresh",hex_x;",";hex_y
    
    for i as byte = 0 to 5
        hx = cbyte(hex_x + dx(i))
        hy = cbyte(hex_y + dy(i))
        if is_valid_hex(hx, hy) then
            x = x_hex2array(hx, hy)
            y = y_hex2array(hx, hy)
            if map(x,y).isbrick then
                map(x,y).state = STATE_REPAINT
                'print "- ",hx;",";hy
            end if
        end if
    next
end sub

sub clear_tile(x as byte, y as byte) static
    ' screen coordinates
    dim xs as byte
    dim ys as byte
    xs = x_array2screen(x, y)
    ys = y_array2screen(x, y)
    'call fc_clearTile(xs, ys, 7, 6)
    call fc_displayTile(tiles, xs, ys, 0, 6, 7, 6, false)
end sub

sub set_sprite(xx as byte, yy as byte) static
    for y as byte = 0 to GAME_HEIGHT - 1
        for x as byte = 0 to GAME_WIDTH - 1
            if map(x,y).hascursor then
                ' delete old cursor
                map(x,y).hascursor = false
                if map(x,y).isbrick then
                    map(x,y).state = STATE_REPAINT
                else
                    call clear_tile(x, y)
                    call refresh_adjacent(x_array2hex(x, y), y_array2hex(x, y))
                end if
            end if
            if x = xx and y = yy then
                ' add new cursor
                map(x,y).hascursor = true
                map(x,y).state = STATE_REPAINT
            end if
        next
    next
end sub

sub show_sprite() static
    dim spriteaddress as long: spriteaddress = $c000
    dim spritepointers as long: spritepointers = 820
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
    poke VIC2 + 23, 0 ' expand y
    poke VIC2 + 28, 1 ' hires/multicolor
    poke VIC2 + 29, 0 ' expand x
    ' RED, BLACK, WHITE is the classic Amiga color
    poke VIC2 + 37, RED 
    poke VIC2 + 38, BLACK
    poke VIC2 + 39, YELLOW
end sub

sub init_hexagons() static
    for y as byte = 0 to GAME_HEIGHT - 1
        for x as byte = 0 to GAME_WIDTH - 1
            map(x,y).isbrick = true
            map(x,y).state = STATE_REPAINT
            map(x,y).color = rndb() mod 4
        next
    next
end sub

function draw_hexagons as byte () static
    dim numTiles as byte: numTiles = 0
    dim xx as byte
    dim yy as byte

    for y as byte = 0 to (GAME_HEIGHT - 1)
        for x as byte = 0 to GAME_WIDTH - 1
            if map(x,y).isbrick then numTiles = numTiles + 1
            if map(x,y).state <> STATE_DONE then
                map(x,y).state = STATE_DONE
                xx = x_array2screen(x, y)
                yy = y_array2screen(x, y)
                if map(x,y).isbrick then
                    call fc_displayTile(tiles, xx, yy, 7 * map(x,y).color, 0, 7, 6, true)
                end if 
                if map(x,y).hascursor then
                    call fc_displayTile(tiles, xx, yy, 7, 6, 7, 6, true)
                end if
            end if
        next
    next
    return numTiles
end sub

sub remove_brick(hex_x as byte, hex_y as byte) static
    dim x as byte: x = x_hex2array(hex_x, hex_y) ' array coordinates
    dim y as byte: y = y_hex2array(hex_x, hex_y)
    map(x, y).isbrick = false
    call clear_tile(x, y)
    call refresh_adjacent(hex_x, hex_y)
    'print "break", hex_x;","; hex_y,x;",";y
end sub

sub add_brick_to_queue(hex_x as byte, hex_y as byte, color as byte) static
    if is_valid_hex(hex_x, hex_y) = false then return

    dim x as byte: x = x_hex2array(hex_x, hex_y)
    dim y as byte: y = y_hex2array(hex_x, hex_y)
    'print "add?", hex_x;",";hex_y,x;",";y,map(x, y).state;",";map(x, y).isbrick;",";map(x, y).color
    if map(x, y).isqueuing = false and map(x, y).isbrick = true and map(x, y).color = color then
        'print "add", hex_x, hex_y
        queue(queue_len).hex_x = hex_x
        queue(queue_len).hex_y = hex_y
        queue_len = queue_len + 1
        map(x, y).isqueuing = true 
    end if
end sub

function break_bricks as byte (hex_x as byte, hex_y as byte) static
    dim color as byte
    dim first as byte
    dim smashed_bricks as byte
    dim x as byte: x = x_hex2array(hex_x, hex_y)
    dim y as byte: y = y_hex2array(hex_x, hex_y)

    if map(x, y).isbrick = false then return 0

    
    ' first entry
    first = 1
    queue_len = 1
    queue(0).hex_x = hex_x
    queue(0).hex_y = hex_y
    smashed_bricks = 0
    color = map(x, y).color
    for y as byte = 0 to GAME_HEIGHT - 1
        for x as byte = 0 to GAME_WIDTH - 1
            map(x,y).isqueuing = false
        next
    next

    do while queue_len > 0
        queue_len = queue_len - 1
        hex_x = queue(queue_len).hex_x
        hex_y = queue(queue_len).hex_y
        'print "check", hex_x;",";hex_y,x;",";y,color
        call remove_brick(hex_x, hex_y)
        smashed_bricks = smashed_bricks + 1
        ' adjacent hexagons
        for i as byte = 0 to 5
            call add_brick_to_queue(cbyte(hex_x + dx(i)), cbyte(hex_y + dy(i)), color)
        next
        if first = 1 and queue_len = 0 then
            ' not allowed to remove only one brick
            ' put it back
            ' map(x, y).isbrick = true
            ' smashed_bricks = 0
        else
            first = 0
        end if
    loop 
    return smashed_bricks
end sub

sub compact_vertically() static
    ' array coordinates
    dim z as byte
    ' screen coordinates
    dim xs as byte
    dim ys as byte
    ' hex coordinates
    dim hex_z as byte
    dim hex_x as byte
    dim hex_y as byte

    for x as byte = 0 to GAME_WIDTH - 1
        for y as int = GAME_HEIGHT - 1 to 0 step -1
            hex_x = x_array2hex(x, cbyte(y))
            hex_y = y_array2hex(x, cbyte(y))
            if map(x, y).isbrick = false then
                'print "hole", hex_x, hex_y
                hex_z = hex_y - 2
                z = y_hex2array(hex_x, hex_z)
                do while hex_z < 254  and map(x, z).isbrick = false
                    hex_z = hex_z - 2
                    z = y_hex2array(hex_x, hex_z)
                loop
                'print "result", hex_x, hex_z
                if hex_z < 254 then
                    ' move x.z to x.y
                    map(x, y).color = map(x, z).color
                    map(x, y).isbrick = map(x, z).isbrick
                    map(x, y).state = STATE_REPAINT
                    ' clear x.z
                    map(x, z).isbrick = false
                    call clear_tile(x, z)
                    call refresh_adjacent(hex_x, hex_y)
                    call refresh_adjacent(hex_x, hex_z)
                end if
            end if
        next
    next
    'call fc_fatal()
end sub

sub show_intro() static
    dim key as byte
    call fc_textcolor(RED)
    call fc_center(0, 20, 80, "Breaking")
    call fc_textcolor(GREEN)
    call fc_center(0, 22, 80, "HEXAGONS")
    call fc_textcolor(WHITE)
    call fc_center(0, 30, 80, "By Johan Berntsson")
    call fc_textcolor(GREY)
    call fc_center(0, 32, 80, "version 1 - 9 Feb 2022")
    call fc_textcolor(WHITE)
    call fc_center(0, 40, 80, "Loading...")

    'load "ocean.prg", 8
    'load "themodel.prg", 8
    call start_irq()

    logo = fc_loadFCI("logo.fci") 
    call fc_loadFCIPalette(logo)
    call fc_displayTile(logo, 0, 0, 0, 0, 56, 14, false)

    tiles = fc_loadFCI("tiles.fci")


    call fc_center(0, 40, 80, "Press any key")
    'dim key$ as string * 1
    'do
    '    get key$
    'loop until len(key$) > 0
    key = fc_getkey()
end sub

sub show_game() static
    'call show_sprite()
    call fc_clrscr()
    call fc_loadFCIPalette(tiles)
    call fc_displayTile(tiles, 0, 44, 0, 12, 28, 6, false)
    call fc_displayTile(tiles, 28, 44, 0, 12, 28, 6, false)
    call fc_displayTile(tiles, 56, 44, 0, 12, 24, 6, false)
end sub

sub play_game() static
    dim key as byte
    dim hex_x as byte
    dim hex_y as byte
    dim x as byte: x = 0
    dim y as byte: y = 0
loop:
    call set_sprite(x, y)
    call draw_hexagons()
    key = fc_getkey()
    'print key
    if key = 97 or key = 157 and x > 0 then x = x - 1
    if key = 100 or key = 29 and x < GAME_WIDTH - 1 then x = x + 1
    if key = 119 or key = 145 and y > 0 then y = y - 1
    if key = 115 or key = 17 and y < GAME_HEIGHT - 1 then y = y + 1
    if key = 32 then 
        hex_x = x_array2hex(x, y)
        hex_y = y_array2hex(x, y)
        call break_bricks(hex_x, hex_y)
        call compact_vertically()
    end if 
    'if key = 13 then call fc_fatal()
    goto loop
end sub

main:
    call enable_40mhz()
    call fc_init(true, true, true, 0, 0)

    ' d054 controls the horizontal resolution and position
    poke $d054,peek($d054) or 16
    ' d076 should control vertical resolution and position
    poke $d076,255

    call show_intro()

    randomize ti()
    call init_hexagons()

    call show_game()

    call play_game()
