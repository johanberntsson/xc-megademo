' Implements functions to set up and use the full color mode
' on the MEGA65 computer.
'
' Globals subroutines:
' - fc_init
' - fc_textcolor
' - fc_plotPetsciiChar
' 
' Global variables
' - gConfig
' - gScreenRows
' - gScreenColumns
' - gTopBorder
' - gBottomBorder

const true = 1
const false = 0

const TOPBORDER_PAL = $58
const BOTTOMBORDER_PAL = $1e8
const TOPBORDER_NTSC = $27
const BOTTOMBORDER_NTSC = $1b7
const CURSOR_CHARACTER = $5f

type Config
    screenbase as long
    reservedbitmapbase as long
    reservedpalettebase as long
    dynamicpalettebase as long
    dynamicbitmapbase as long
    colorbase as long
end type

' TextInfo: 8 bytes
type TextWindow 
    x0 as byte
    y0 as byte
    width as byte
    height as byte
    xc as byte
    yc as byte
    attributes as byte
    textcolor as byte
end type

' fciInfo: 12 bytes
type fciInfo
    baseAdr as long
    paletteAdr as long
    paletteSize as byte
    reservedSysPalette as byte
    columns as byte
    rows as byte
    size as word
end type

dim gConfig as Config shared
dim gCurrentWindow as byte shared
dim gScreenSize as word shared
dim gScreenRows as byte shared
dim gScreenColumns as byte shared
dim gTopBorder as word shared
dim gBottomBorder as word shared

const MAX_WINDOWS =  8
const MAX_FCI_BLOCKS = 16

dim windows(MAX_WINDOWS) as TextWindow @$700
dim infoBlocks(MAX_FCI_BLOCKS) as fciInfo @600

dim autocr as byte
dim csrflag as byte

sub fc_resetwin() shared static
    ' reset text window to the whole screen
    gCurrentWindow = 1
    windows(gCurrentWindow).x0 = 0
    windows(gCurrentWindow).y0 = 0
    windows(gCurrentWindow).width = gScreenColumns
    windows(gCurrentWindow).height = gScreenRows
    windows(gCurrentWindow).xc = 0
    windows(gCurrentWindow).yc = 0
    windows(gCurrentWindow).attributes = 0
    windows(gCurrentWindow).textcolor = 5
end sub

sub fc_go8bit() shared static
    call enable_io()
    poke VIC3CTRL, 96 ' quit bitplane mode if set
    poke 53297, 96    ' quit bitplane mode
    poke SCNPTR, $00  ' screen back to 0x800
    poke SCNPTR + 1, $08
    poke SCNPTR + 2, $00
    poke SCNPTR + 3, $00
    poke VIC4CTRL, peek(VIC4CTRL) and $fa ' clear fchi and 16bit chars
    poke CHRCOUNT, 40
    poke LINESTEP_LO, 40
    poke LINESTEP_HI, 0
    poke HOTREG, peek(HOTREG) or $80      ' enable hotreg
    poke VIC3CTRL, peek(VIC3CTRL) and $7f ' disable H640
    poke VIC3CTRL, peek(VIC3CTRL) and $7f ' disable H640
    'fc_setPalette(0, 0, 0, 0);
    'fc_setPalette(1, 255, 255, 255);
    'fc_setPalette(2, 255, 0, 0);
end sub

sub fc_fatal(message as String * 80) shared static
    call fc_go8bit()
    print "{clear}fatal error"
    print message
end sub

sub fc_setwin(win as byte) shared static
    if win > MAX_WINDOWS or win < 1 then
        call fc_fatal("fc_setwin: bad window number")
    else 
        gCurrentWindow = win
    end if
end sub

sub fc_textcolor(color as byte) shared static
    windows(gCurrentWindow).textcolor = color
end sub

function fc_kbhit as byte () static
    return peek($d610)
end function

function fc_cgetc as byte () static
    dim k as byte
    do
        k = peek($d610)
        poke $d610, 0
    loop until k <> 0
    return k
end function

sub fc_emptyBuffer() static
    dim dummy as byte
    do while fc_kbhit()
        dummy = fc_cgetc()
    loop
end sub

function fc_getkey as byte () shared static
    call fc_emptyBuffer()
    return fc_cgetc()
end function

sub fc_clrscr() shared static
    ' TODO
end sub

sub adjustborders(extrarows as byte, extracolumns as byte) static
    ' TODO
end sub

sub fc_screenmode(h640 as byte, v400 as byte, rows as byte) static
    ' starts full color mode in 640 * 400
    dim extrarows as byte

    call enable_io()
    if rows = 0 then
        if v400 then gScreenRows = 50 else gScreenRows = 25
    else
        gScreenRows = rows
    end if

    poke HOTREG, peek(HOTREG) or $80    ' enable HOTREG if previously disabled
    poke VIC4CTRL, peek(VIC4CTRL) or $5 ' FC & 16 bit chars

    if h640 then
        poke VIC3CTRL, peek(VIC3CTRL) or $80 ' enable H640
        poke VIC2CTRL, peek(VIC2CTRL) or $1  ' shift one pixel right (VIC3 bug)
        gScreenColumns = 80
    else
        poke VIC3CTRL, peek(VIC3CTRL) and $7f ' disable H640
        gScreenColumns = 40
    end if

    if v400 then
        poke VIC3CTRL, peek(VIC3CTRL) or $08 ' enable V400
        extrarows = gScreenRows - 50
    else
        poke VIC3CTRL, peek(VIC3CTRL) and $f7 ' enable V400
        extrarows = 2*(gScreenRows - 25)
    end if

    gScreenSize = cword(gScreenRows) * gScreenColumns
    call dma_fill_skip(gConfig.screenbase, 32, gScreenSize, 2)
    call dma_fill($ff, gConfig.colorbase, 0, 2 * gScreenSize)

    poke HOTREG, peek(HOTREG) and $7f ' disable HOTREG

    if extrarows > 0 then call adjustborders(extrarows, 0)

    ' move color RAM because of stupid CBDOS himem usage
    poke COLPTR, BYTE0(gConfig.colorbase)
    poke COLPTR + 1, BYTE1(gConfig.colorbase)

    ' set CHARCOUNT to the number of columns on screen
    poke CHRCOUNT, gScreenColumns
    ' *2 to have 2 screen bytes == 1 character
    poke LINESTEP_LO, gScreenColumns * 2
    poke LINESTEP_HI, 0

    poke DISPROWS, gScreenRows

    poke SCNPTR, BYTE0(gConfig.screenbase)
    poke SCNPTR + 1, BYTE1(gConfig.screenbase)
    poke SCNPTR + 2, BYTE2(gConfig.screenbase)
    poke SCNPTR + 3, 0 ' can't put the screen in attic ram

    call fc_resetwin()
    call fc_clrscr()
end sub

sub fc_real_init(h640 as byte, v400 as byte, rows as byte) static
    call enable_io()

    if peek($d06f) and 128 then
        gTopBorder = TOPBORDER_NTSC
        gBottomBorder = BOTTOMBORDER_NTSC
    else
        gTopBorder = TOPBORDER_PAL
        gBottomBorder = BOTTOMBORDER_PAL
    end if

    poke BORDERCOL, BLACK
    poke SCREENCOL, BLACK

    autoCR = TRUE

    call fc_screenmode(h640, v400, rows)
    call fc_textcolor(GREEN)
end sub

sub fc_gotoxy(x as byte, y as byte) shared static 
    windows(gCurrentWindow).xc = x
    windows(gCurrentWindow).yc = y
end sub

sub fc_displayFCIFile(filename as String * 20, x0 as byte, y0 as byte) shared static
    'fciInfo *info;
    'info = fc_loadFCI(filename, 0, 0);
    'fc_displayFCI(info, x0, y0, true);
    'TOOD return info;
end sub

sub fc_scrollup() shared static
    ' TODO
end sub

sub cr() static 
    windows(gCurrentWindow).xc = 0
    windows(gCurrentWindow).yc = windows(gCurrentWindow).yc + 1
    if windows(gCurrentWindow).yc > windows(gCurrentWindow).height - 1 then
        call fc_scrollup()
        windows(gCurrentWindow).yc = windows(gCurrentWindow).height - 1
    end if 
end sub

sub fc_plotPetsciiChar(x as byte, y as byte, c as byte, color as byte, attribute as byte) shared static
    dim offset as word
    offset = 2 * (x + y * cword(gScreenColumns))
    call dma_poke(gConfig.screenbase + offset, c)
    call dma_poke($ff, gConfig.colorbase  + offset + 1, color or attribute)
end sub

function asciiToPetscii as byte (c as byte) static
    ' TODO: could be made much faster with translation table
    ' if c = '_' then return 100
    if c >= 64 and c <= 95 then return c - 64
    if c >= 96 and c < 192 then return c - 32
    if c >= 192 then return c - 128
    return c
end function

sub fc_putc(c as byte) static
    dim out as byte
    if c = 13 then call cr(): return
    if windows(gCurrentWindow).xc >= windows(gCurrentWindow).width then return
    out = asciiToPetscii(c)
    call fc_plotPetsciiChar(windows(gCurrentWindow).xc + windows(gCurrentWindow).x0, windows(gCurrentWindow).yc + windows(gCurrentWindow).y0, out, windows(gCurrentWindow).textcolor, windows(gCurrentWindow).attributes)
    windows(gCurrentWindow).xc = windows(gCurrentWindow).xc + 1

    if autocr then
        if windows(gCurrentWindow).xc >= windows(gCurrentWindow).width then
            windows(gCurrentWindow).xc = 0
            windows(gCurrentWindow).yc = windows(gCurrentWindow).yc + 1
            if windows(gCurrentWindow).yc >= windows(gCurrentWindow).height then
                call fc_scrollup()
                windows(gCurrentWindow).yc = windows(gCurrentWindow).height - 1
            end if
        end if 
    end if

    if csrflag then
        call fc_plotPetsciiChar(windows(gCurrentWindow).xc + windows(gCurrentWindow).x0, windows(gCurrentWindow).yc + windows(gCurrentWindow).y0, CURSOR_CHARACTER, windows(gCurrentWindow).textcolor, 16)
    end if
end sub

sub fc_puts(s as word) shared static 
    for i as byte = 1 to peek(s)
        call fc_putc(peek(s + i))
    next 
end sub

sub fc_putsxy(x as byte, y as byte, s as string*80) shared static
    call fc_gotoxy(x, y)
    call fc_puts(@s)
end sub

sub fc_cursor(onoff as byte) static
    dim cursor as byte
    dim attribute as byte

    csrflag = onoff
    if csrflag then 
        cursor = CURSOR_CHARACTER
        attribute = 16
    else
        cursor = 32
        attribute = 0
    end if
    call fc_plotPetsciiChar(windows(gCurrentWindow).xc + windows(gCurrentWindow).x0, windows(gCurrentWindow).yc + windows(gCurrentWindow).y0, cursor, windows(gCurrentWindow).textcolor, attribute)
end sub

sub fc_init(h640 as byte, v400 as byte, rows as byte) shared static
    ' standard config
    gConfig.screenbase = $12000
    gConfig.reservedbitmapbase = $14000
    gConfig.reservedpalettebase = $15000
    gConfig.dynamicpalettebase = $15300
    gConfig.dynamicbitmapbase = $40000
    gConfig.colorbase = $81000 ' $0ff ...
    call fc_real_init(h640, v400, rows)
end sub

sub fc_init(h640 as byte, v400 as byte, rows as byte, screenbase as long, colorbase as long) overload shared static
    ' use users supplied config parameters
    gConfig.screenbase = screenbase
    gConfig.colorbase = colorbase
    call fc_real_init(h640, v400, rows)
end sub

