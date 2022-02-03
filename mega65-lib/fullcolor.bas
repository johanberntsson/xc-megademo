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

Const true = 1
Const false = 0

Const TOPBORDER_PAL = $58
Const BOTTOMBORDER_PAL = $1e8
Const TOPBORDER_NTSC = $27
Const BOTTOMBORDER_NTSC = $1b7
Const CURSOR_CHARACTER = $5f

type Config
    screenbase as long
    colorbase as long
end type

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

dim gConfig as Config shared
dim gCurrentWindow as TextWindow shared
dim gScreenSize as word shared
dim gScreenRows as byte shared
dim gScreenColumns as byte shared
dim gTopBorder as word shared
dim gBottomBorder as word shared

dim defaultWindow as TextWindow @$0700

dim autocr as byte
dim csrflag as byte

sub fc_resetwin() shared static
    ' reset text window to the whole screen
    gCurrentWindow = defaultWindow
    gCurrentWindow.x0 = 0
    gCurrentWindow.y0 = 0
    gCurrentWindow.width = gScreenColumns
    gCurrentWindow.height = gScreenRows
    gCurrentWindow.xc = 0
    gCurrentWindow.yc = 0
    gCurrentWindow.attributes = 0
    gCurrentWindow.textcolor = 5
end sub

sub fc_textcolor(color as byte) shared static
    gCurrentWindow.textcolor = color
end sub

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

    poke HOTREG, peek(HOTREG) or $80: ' enable HOTREG if previously disabled
    poke VIC4CTRL, peek(VIC4CTRL) or $5: ' FC & 16 bit chars

    if h640 then
        poke VIC3CTRL, peek(VIC3CTRL) or $80: ' enable H640
        poke VIC2CTRL, peek(VIC2CTRL) or $1: ' shift one pixel right (VIC3 bug)
        gScreenColumns = 80
    else
        poke VIC3CTRL, peek(VIC3CTRL) and $7f: ' disable H640
        gScreenColumns = 40
    end if

    if v400 then
        poke VIC3CTRL, peek(VIC3CTRL) or $08: ' enable V400
        extrarows = gScreenRows - 50
    else
        poke VIC3CTRL, peek(VIC3CTRL) and $f7: ' enable V400
        extrarows = 2*(gScreenRows - 25)
    end if

    gScreenSize = cword(gScreenRows) * gScreenColumns
    call dma_fill_skip(gConfig.screenbase, 32, gScreenSize, 2)
    call dma256_fill($ff, gConfig.colorbase, 0, 2 * gScreenSize)

    poke HOTREG, peek(HOTREG) and $7f: ' disable HOTREG

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
    poke SCNPTR + 3, 0: ' can't put the screen in attic ram

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
    gCurrentWindow.xc = x
    gCurrentWindow.yc = y
end sub

sub fc_scrollup() shared static
    ' TODO
end sub

sub cr() static 
    gCurrentWindow.xc = 0
    gCurrentWindow.yc = gCurrentWindow.yc + 1
    if gCurrentWindow.yc > gCurrentWindow.height - 1 then
        call fc_scrollup()
        gCurrentWindow.yc = gCurrentWindow.height - 1
    end if 
end sub

sub fc_plotPetsciiChar(x as byte, y as byte, c as byte, color as byte, attribute as byte) shared static
    dim offset as word
    offset = 2 * (x + y * cword(gScreenColumns))
    call dma_poke(gConfig.screenbase + offset, c)
    call dma256_poke($ff, gConfig.colorbase  + offset + 1, color or attribute)
end sub

function asciiToPetscii as byte (c as byte) static
    ' TODO: could be made much faster with translation table
    if c = '_' then return 100
    if c >= 64 and c <= 95 then return c - 64
    if c >= 96 and c < 192 then return c - 32
    if c >= 192 then return c - 128
    return c
end function

sub fc_putc(c as byte) static
    dim out as byte
    if c = 13 then call cr(): return
    if gCurrentWindow.xc >= gCurrentWindow.width then return
    out = asciiToPetscii(c)
    call fc_plotPetsciiChar(gCurrentWindow.xc + gCurrentWindow.x0, gCurrentWindow.yc + gCurrentWindow.y0, out, gCurrentWindow.textcolor, gCurrentWindow.attributes)
    gCurrentWindow.xc = gCurrentWindow.xc + 1

    if autocr then
        if gCurrentWindow.xc >= gCurrentWindow.width then
            gCurrentWindow.xc = 0
            gCurrentWindow.yc = gCurrentWindow.yc + 1
            if gCurrentWindow.yc >= gCurrentWindow.height then
                call fc_scrollup()
                gCurrentWindow.yc = gCurrentWindow.height - 1
            end if
        end if 
    end if

    if csrflag then
        call fc_plotPetsciiChar(gCurrentWindow.xc + gCurrentWindow.x0, gCurrentWindow.yc + gCurrentWindow.y0, CURSOR_CHARACTER, gCurrentWindow.textcolor, 16)
    end if
end sub

sub fc_puts(s as long) shared static 
    for i as byte = 1 to peek(s)
        call fc_putc(peek(s + i))
    next 
end sub

sub fc_putsxy(x as byte, y as byte, s as string*80) shared static
    call fc_gotoxy(x, y)
    call fc_puts(@s)
end sub

sub fc_cursor(onoff as byte)
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
    call fc_plotPetsciiChar(gCurrentWindow.xc + gCurrentWindow.x0, gCurrentWindow.yc + gCurrentWindow.y0, cursor, gCurrentWindow.textcolor, attribute)
end sub

sub fc_init(h640 as byte, v400 as byte, rows as byte) shared static
    ' standard config
    gConfig.screenbase = $12000
    gConfig.colorbase = $81000: ' $0ff ...
    call fc_real_init(h640, v400, rows)
end sub

sub fc_init(h640 as byte, v400 as byte, rows as byte, screenbase as long, colorbase as long) overload shared static
    ' use users supplied config parameters
    gConfig.screenbase = screenbase
    gConfig.colorbase = colorbase
    call fc_real_init(h640, v400, rows)
end sub

