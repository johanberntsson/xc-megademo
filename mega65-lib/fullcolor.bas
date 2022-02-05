' Implements functions to set up and use the full color mode
' on the MEGA65 computer.

const TOPBORDER_PAL = $58
const BOTTOMBORDER_PAL = $1e8
const TOPBORDER_NTSC = $27
const BOTTOMBORDER_NTSC = $1b7
const CURSOR_CHARACTER = 100

type Config
    screenbase as long   ' location of 16 bit screen
    palettebase as long  ' loaded palettes base
    bitmapbase as long   ' loaded bitmaps base
    colorbase as long    ' attribute/color ram
end type

type TextWindow ' size = 9 bytes
    x0 as byte         ' current cursor X position
    y0 as byte         ' current cursor Y position
    width as byte      ' X origin
    height as byte     ' Y origin
    xc as byte         ' window width
    yc as byte         ' window height
    textcolor as byte  ' current window text color
    attributes as byte ' current window extended text attributes
end type

type fciInfo ' size = 13 bytes
    baseAdr as long     ' bitmap base address
    paletteAdr as long  ' palette data base addres
    paletteSize as byte ' size of palette (in palette entries)
    reservedSysPalette as byte ' if true, don't use colors 0-15
    columns as byte     ' number of character columns for image
    rows as byte        ' number of character rows
    size as word        ' size of bitmap
end type

dim gConfig as Config shared
dim gCurrentWindow as byte shared ' current window (1 - MAX_WINDOWS)
dim gScreenSize as word shared
dim gScreenRows as byte shared    ' number of screen rows (in characters)
dim gScreenColumns as byte shared ' number of screen columns (in characters)
dim gTopBorder as byte shared
dim gBottomBorder as word shared

dim windowCount as byte
dim infoBlockCount as byte
dim firstFreeGraphMem as long ' first free graphics block
dim firstFreePalMem as long   ' first free palette memory block
dim nextFreeGraphMem as long  ' location of next free graphics block
dim nextFreePalMem as long    ' location of next free palette memory block

const MAX_WINDOWS =  8
const MAX_FCI_BLOCKS = 16

dim windows(MAX_WINDOWS) as TextWindow @$700
dim infoBlocks(MAX_FCI_BLOCKS) as fciInfo @600

dim autocr as byte
dim csrflag as byte

function nyblswap as byte (swp as byte) static
    return ((swp and $0f) * 16) or ((swp and $f0) / 16)
end function

sub fc_zeroPalette(reservedSysPalette as byte) static
    dim start as byte

    call enable_io()
    if reservedSysPalette then start = 16 else start = 0
    for i as byte = start to 255
        poke $d100 + i, 0
        poke $d200 + i, 0
        poke $d300 + i, 0
    next
end sub

sub fc_loadPalette(adr as long, size as byte, reservedSysPalette as byte) static
    dim colAdr as word
    dim start as byte

    if reservedSysPalette then start = 16 else start = 0

    for i as byte = start to size
        colAdr = cword(i) * 3
        poke $d100 + i, nyblswap(peek(cword(adr) + colAdr))
        poke $d200 + i, nyblswap(peek(cword(adr) + colAdr + 1))
        poke $d300 + i, nyblswap(peek(cword(adr) + colAdr + 2))
    next
end sub

sub fc_fadePalette(adr as long, size as byte, reservedSysPalette as byte, steps as byte, fadeOut as byte) static
    'TODO
end sub

sub fc_setPalette(num as byte, red as byte, green as byte, blue as byte) static
    poke $d100 + num, nyblswap(red)
    poke $d200 + num, nyblswap(green)
    poke $d300 + num, nyblswap(blue)
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
    call fc_setPalette(0, 0, 0, 0)
    call fc_setPalette(1, 255, 255, 255)
    call fc_setPalette(2, 255, 0, 0)
end sub

sub fc_fatal(message as String * 80) shared static
    ' you can add messages before calling fc_fatal with print,
    ' and they will appear on the screen afterwards
    call fc_go8bit()
    print "fatal error:", message
    do while true
    loop
end sub

sub fc_fatal() shared static overload
    call fc_fatal("")
end sub

sub fc_addGraphicsRect(x0 as byte, y0 as byte, width as byte, height as byte, bitmapData as long) static
    dim adr as long
    dim currentCharIdx as word

    currentCharIdx = cword(bitmapData / 64)

    for y as byte = y0 to y0 + height - 1
        for x as byte = x0 to x0 + width - 1
            adr = gConfig.screenbase + (x * 2) + (y * cword(gScreenColumns) * 2)
            ' set highbyte first to avoid blinking
            ' while setting up the screeen
            call dma_poke(adr + 1, BYTE1(currentCharIdx))
            call dma_poke(adr, BYTE0(currentCharIdx))
            currentCharIdx = currentCharIdx + 1
        next
    next
end sub 

sub fc_freeGraphAreas() static
    windowCount = 1
    infoBlockCount = 1
    nextFreeGraphMem = firstFreeGraphMem
    nextFreePalMem = firstFreePalMem
end sub

function fc_allocGraphMem as long (size as word) static
    ' very simple graphics memory allocation scheme:
    ' try to find space in 128K beginning at GRAPHBASE, without
    ' crossing bank boundaries. If everything's full, bail out.
    dim adr as long
    adr = nextFreeGraphMem
    if nextFreeGraphMem + size < gConfig.bitmapbase + $10000 then
        nextFreeGraphMem = nextFreeGraphMem + size
        return adr
    end if 
    if nextFreeGraphMem < gConfig.bitmapbase + $10000 then
        nextFreeGraphMem = gConfig.bitmapbase + $10000
        adr = nextFreeGraphMem
    end if 
    if nextFreeGraphMem + size < gConfig.bitmapbase + $20000 then
        nextFreeGraphMem = nextFreeGraphMem + size
        return adr
    end if 
    return 0
end function

function fc_allocPalMem as long (size as word) static
    dim adr as long
    adr = nextFreePalMem
    if nextFreePalMem < $1e000 then ' TODO: don't hardcode boundaries
        nextFreePalMem = nextFreePalMem + size
        return adr
    end if
    return 0
end function

function fc_nextInfoBlock as byte () static
    dim info as byte
    ' find a free block
    if infoBlockCount = MAX_FCI_BLOCKS then call fc_fatal("Out of blocks")
    info = infoBlockCount
    infoBlockCount = infoBlockCount + 1
    return infoBlockCount
end function

function fc_loadFCI as byte (info as byte, filename as String * 20) shared static
    dim options as byte
    dim paletteMemSize as long
    dim bitmapSourceAddress as long
    dim base as word

    ' TODO: this should be rewritten as
    ' open 2,8,2,"tiles"
    ' read #2, header
    ' read #2, ...
    ' close 2
    ' but currently there is a bug stopping it in xc-basic 3
    base = $6000


    load "tiles.fci", 8, base+2 ' compensate for two missing bytes
    infoBlocks(info).rows = peek(base + 5)
    infoBlocks(info).columns = peek(base + 6)
    options = peek(base + 7)
    infoBlocks(info).paletteSize  = peek(base + 8)
    infoBlocks(info).paletteAdr = base + 9

    infoBlocks(info).reservedSysPalette = (options and 2)
    infoBlocks(info).size  = cword(64) * infoBlocks(info).rows * infoBlocks(info).columns
    paletteMemSize = (clong(1) + infoBlocks(info).paletteSize) * 3
    bitmapSourceAddress = base + 9 + paletteMemSize + 3 ' 3 is for IMG
    infoBlocks(info).baseAdr = fc_allocGraphMem(infoBlocks(info).size)

    call dma_copy(bitmapSourceAddress, infoBlocks(info).baseAdr, infoBlocks(info).size)
    return info
end function

function fc_loadFCI as byte (filename as String * 20) shared static overload
    return fc_loadFCI(fc_nextInfoBlock(), filename)
end function

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

sub fc_plotPetsciiChar(x as byte, y as byte, c as byte, color as byte, attribute as byte) shared static
    dim offset as word
    offset = 2 * (x + y * cword(gScreenColumns))
    call dma_poke(gConfig.screenbase + offset, c)
    call dma_poke($ff, gConfig.colorbase  + offset + 1, color or attribute)
end sub


sub fc_cursor(onoff as byte) shared static
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

sub fc_line(x as byte, y as byte, width as byte, character as byte, col as byte) shared static
    dim w as word
    dim bas as long

    w = cword(width)
    bas = 2 * (x + windows(gCurrentWindow).x0 + clong(gScreenColumns) * (windows(gCurrentWindow).y0 + y))

    ' use DMAgic to fill FCM screens with skip byte... PGS, I love you!
    call dma_fill_skip(gConfig.screenBase + bas, character, w, 2)
    call dma_fill_skip(gConfig.screenBase + bas + 1, 0, w, 2)
    call dma_fill_skip(gConfig.colorBase + bas, 0, w, 2)
    call dma_fill_skip(gConfig.colorBase + bas + 1, col, w, 2)
end sub

sub fc_block(x0 as byte, y0 as byte, width as byte, height as byte, character as byte, col as byte) shared static
    for y as byte = 0 to  height - 1
        call fc_line(x0, y0 + y, width, character, col)
    next
end sub

sub fc_scrollUp() shared static
    dim bas0 as long
    dim bas1 as long
    dim w as word
    w = cword(windows(gCurrentWindow).width) * 2

    for y as byte = windows(gCurrentWindow).y0 to windows(gCurrentWindow).y0 + windows(gCurrentWindow).height - 2
        bas0 = gConfig.screenBase + (clong(windows(gCurrentWindow).x0) * 2 + (y * gScreenColumns * 2))
        bas1 = gConfig.screenBase + (clong(windows(gCurrentWindow).x0) * 2 + ((y + 1) * gScreenColumns * 2))
        call dma_copy(bas1, bas0, w)
        bas0 = gConfig.colorBase + (clong(windows(gCurrentWindow).x0) * 2 + (y * gScreenColumns * 2))
        bas1 = gConfig.colorBase + (clong(windows(gCurrentWindow).x0) * 2 + ((y + 1) * gScreenColumns * 2))
        call dma_copy(bas1, bas0, w)
    next
    call fc_line(0, windows(gCurrentWindow).height - 1, windows(gCurrentWindow).width, 32, windows(gCurrentWindow).textcolor)
end sub

sub fc_scrollDown() shared static
    dim bas0 as long
    dim bas1 as long
    dim w as word
    w = cword(windows(gCurrentWindow).width) * 2

    for y as int = windows(gCurrentWindow).y0 + windows(gCurrentWindow).height - 2 to windows(gCurrentWindow).y0 step -1
        bas0 = gConfig.screenBase + (clong(windows(gCurrentWindow).x0) * 2 + (y * gScreenColumns * 2))
        bas1 = gConfig.screenBase + (clong(windows(gCurrentWindow).x0) * 2 + ((y + 1) * gScreenColumns * 2))
        call dma_copy(bas0, bas1, w)
        bas0 = gConfig.colorBase + (clong(windows(gCurrentWindow).x0) * 2 + (y * gScreenColumns * 2))
        bas1 = gConfig.colorBase + (clong(windows(gCurrentWindow).x0) * 2 + ((y + 1) * gScreenColumns * 2))
        call dma_copy(bas0, bas1, w)
    next

    call fc_line(0, 0, windows(gCurrentWindow).width, 32, windows(gCurrentWindow).textcolor)
end sub


sub cr() static 
    windows(gCurrentWindow).xc = 0
    windows(gCurrentWindow).yc = windows(gCurrentWindow).yc + 1
    if windows(gCurrentWindow).yc > windows(gCurrentWindow).height - 1 then
        call fc_scrollUp()
        windows(gCurrentWindow).yc = windows(gCurrentWindow).height - 1
    end if 
end sub

function asciiToPetscii as byte (c as byte) static
    ' could be made much faster with translation table
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
                call fc_scrollUp()
                windows(gCurrentWindow).yc = windows(gCurrentWindow).height - 1
            end if
        end if 
    end if

    if csrflag then
        call fc_plotPetsciiChar(windows(gCurrentWindow).xc + windows(gCurrentWindow).x0, windows(gCurrentWindow).yc + windows(gCurrentWindow).y0, CURSOR_CHARACTER, windows(gCurrentWindow).textcolor, 16)
    end if
end sub

sub fc_gotoxy(x as byte, y as byte) shared static 
    windows(gCurrentWindow).xc = x
    windows(gCurrentWindow).yc = y
end sub


function fc_input as String * 80 () shared static
    dim ct as byte
    dim len as byte
    dim maxlen as byte
    dim current as byte
    dim fcbuf as word
    dim ret as String * 80

    len = 0
    ret = ""
    maxlen = 80
    fcbuf = 1 + @ret

    ct = csrflag
    call fc_cursor(true)
    do
        current = fc_cgetc()
        if current = 20 and len > 0 then
            ' del pressed
            call fc_cursor(0)
            call fc_gotoxy(windows(gCurrentWindow).xc - 1, windows(gCurrentWindow).yc)
            call fc_putc(32)
            call fc_gotoxy(windows(gCurrentWindow).xc - 1, windows(gCurrentWindow).yc)
            call fc_cursor(1)
            len = len - 1
            poke fcbuf + len, 0
        end if
        if current >= 32 and len < maxlen then
            ' fix upper/lowercase
            if current >= 97 then
                current = current - 32
            else
                if current >= 65 then
                    current = current + 32
                end if
            end if
            poke fcbuf + len, current
            call fc_putc(current)
            len = len + 1
        end if
    loop while current <> 13
    call fc_cursor(ct)
    poke fcbuf - 1, len
    return ret
end function

sub adjustBorders(extrarows as byte, extracolumns as byte) static
    dim extraTopRows as byte
    dim extraBottomRows as byte
    dim newBottomBorder as int

    extraTopRows = 0
    extraBottomRows = 0

    extraColumns = extraColumns + 1 ' TODO: support for extra columns
    extraBottomRows = extraRows / 2
    extraTopRows = extraRows - extraBottomRows

    poke 53320, gTopBorder - (extraTopRows * 8) ' top border position
    poke 53326, gTopBorder - (extraTopRows * 8) ' top text position

    newBottomBorder = gBottomBorder + (extraBottomRows * 8)

    poke 53322, BYTE0(newBottomBorder)
    poke 53323, BYTE1(newBottomBorder)

    poke 53371, gScreenRows
end sub

sub fc_loadFCIPalette(info as byte) shared static
    call fc_loadPalette(infoBlocks(info).paletteAdr, infoBlocks(info).paletteSize, infoBlocks(info).reservedSysPalette)
end sub

sub fc_fadeFCI(info as byte, x0 as byte, y0 as byte, steps as byte) static
    call fc_zeroPalette(infoBlocks(info).reservedSysPalette)
    call fc_addGraphicsRect(x0, y0, infoBlocks(info).columns, infoBlocks(info).rows, infoBlocks(info).baseAdr)
    call fc_fadePalette(infoBlocks(info).paletteAdr, infoBlocks(info).paletteSize, infoBlocks(info).reservedSysPalette, steps, false)
end sub


sub fc_displayFCI(info as byte, x0 as byte, y0 as byte, setPalette as byte) shared static
    call fc_addGraphicsRect(x0, y0, infoBlocks(info).columns, infoBlocks(info).rows, infoBlocks(info).baseAdr)
    if setPalette then call fc_loadFCIPalette(info)
end sub

function fc_displayFCIFile as byte (filename as String * 20, x0 as byte, y0 as byte) shared static
    dim info as byte
    info = fc_loadFCI(filename)
    call fc_displayFCI(info, x0, y0, true)
    return info
end function

sub fc_displayTile(info as byte, x0 as byte, y0 as byte, t_x as byte, t_y as byte, t_w as byte, t_h as byte, mergeTiles as byte) shared static
    dim x as byte
    dim y as byte
    dim screenAddr as long
    dim charIndex as word

    for y = t_y to t_y + t_h -1
        screenAddr = gConfig.screenbase + 2 *(x0 + (y0 + y - t_y) * cword(gScreenColumns))
        charIndex = cword(infoBlocks(info).baseAdr / 64) + t_x + (y * infoBlocks(info).columns)
        for x = t_x to t_x + t_w - 1
            'print x, y
            ' set highbyte first to avoid blinking
            ' while setting up the screeen
            call dma_poke(screenAddr + 1, BYTE1(charIndex))
            call dma_poke(screenAddr, BYTE0(charIndex))
            screenAddr = screenAddr + 2
            charIndex = charIndex + 1
        next
    next
end sub

sub fc_puts(s as word) shared static 
    for i as byte = 1 to peek(s)
        call fc_putc(peek(s + i))
    next 
end sub

sub fc_puts(s as String * 80) shared static overload
    call fc_puts(@s)
end sub

sub fc_putsxy(x as byte, y as byte, s as string*80) shared static
    call fc_gotoxy(x, y)
    call fc_puts(@s)
end sub

sub fc_putcxy(x as byte, y as byte, c as byte) shared static
    call fc_gotoxy(x, y)
    call fc_putc(c)
end sub

function fc_wherex as byte () shared static
    return windows(gCurrentWindow).xc
end function

function fc_wherey as byte () shared static
    return windows(gCurrentWindow).yc
end function

sub fc_setAutoCR(a as byte) shared static
    autocr = a
end sub

sub fc_center(x as byte, y as byte, width as byte, text as String * 80) shared static
    dim l as byte
    l = len(text)
    if l >= width - 2 then
        call fc_gotoxy(x, y)
        call fc_puts(@text)
    else
        call fc_gotoxy(x - 1 + width / 2 - l / 2, y)
        call fc_puts(@text)
    end if
end sub

sub fc_clrscr() shared static
    call fc_block(0, 0, windows(gCurrentWindow).width, windows(gCurrentWindow).height, 32, windows(gCurrentWindow).textcolor)
    call fc_gotoxy(0, 0)
end sub

sub fc_textcolor(color as byte) shared static
    windows(gCurrentWindow).textcolor = color
end sub


function fc_getkeyP as byte (x as byte, y as byte, prompt as String * 80) shared static
    call fc_emptyBuffer()
    call fc_gotoxy(x, y)
    call fc_textcolor(WHITE)
    call fc_puts(@prompt)
    return fc_cgetc()
end sub

sub fc_hlinexy(x as byte, y as byte, width as byte, lineChar as byte) shared static
    for cgi as byte = x to x + width - 1
        call fc_putcxy(windows(gCurrentWindow).x0 + x + cgi, windows(gCurrentWindow).y0 + y, lineChar)
    next
end sub

sub fc_vlinexy(x as byte, y as byte, height as byte, lineChar as byte) shared static
    for cgi as byte = y to y + height - 1
        call fc_putcxy(windows(gCurrentWindow).x0 + x, windows(gCurrentWindow).y0 + y + cgi, lineChar)
    next
end sub

sub fc_setwin(win as byte) shared static
    if win >= MAX_WINDOWS then call fc_fatal("bad window number")
    gCurrentWindow = win
end sub

function fc_makeWin as byte (x0 as byte, y0 as byte, width as byte, height as byte) static
    dim w as byte
    if windowCount = MAX_WINDOWS then call fc_fatal("too many windows")
    w = windowCount
    windowCount = windowCount + 1
    windows(w).x0 = x0
    windows(w).y0 = y0
    windows(w).width = width
    windows(w).height = height
    windows(w).xc = 0
    windows(w).yc = 0
    windows(w).attributes = 0
    windows(w).textcolor = 5
    return w
end function

sub fc_resetwin() shared static
    ' reset text window to the whole screen
    gCurrentWindow = 0
    windows(gCurrentWindow).x0 = 0
    windows(gCurrentWindow).y0 = 0
    windows(gCurrentWindow).width = gScreenColumns
    windows(gCurrentWindow).height = gScreenRows
    windows(gCurrentWindow).xc = 0
    windows(gCurrentWindow).yc = 0
    windows(gCurrentWindow).attributes = 0
    windows(gCurrentWindow).textcolor = 5
end sub


sub fc_screenmode(h640 as byte, v400 as byte, rows as byte, columns as byte) static
    ' starts full color mode in 640 * 400
    dim extrarows as byte
    dim extracols as byte

    call enable_io()

    if rows = 0 then
        if v400 then gScreenRows = 50 else gScreenRows = 25
    else
        gScreenRows = rows
    end if

    if columns = 0 then
        if h640 then gScreenColumns = 80 else gScreenColumns = 40
    else
        gScreenColumns = columns
    end if

    poke HOTREG, peek(HOTREG) or $80    ' enable HOTREG if previously disabled
    poke VIC4CTRL, peek(VIC4CTRL) or $5 ' FC & 16 bit chars

    if h640 then
        poke VIC3CTRL, peek(VIC3CTRL) or $80 ' enable H640
        poke VIC2CTRL, peek(VIC2CTRL) or $1  ' shift one pixel right (VIC3 bug)
        gScreenColumns = 80
        extracols = gScreenColumns - 80
    else
        poke VIC3CTRL, peek(VIC3CTRL) and $7f ' disable H640
        gScreenColumns = 40
        extracols = gScreenColumns - 40
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

    if extrarows > 0 then call adjustBorders(extrarows, 0)

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
    'call fc_clrscr()
end sub

sub fc_flash(f as byte) shared static
    if f then
        windows(gCurrentWindow).attributes = windows(gCurrentWindow).attributes or $10
    else
        windows(gCurrentWindow).attributes = windows(gCurrentWindow).attributes and $ef
    end if
end sub

sub fc_revers(f as byte) shared static
    if f then
        windows(gCurrentWindow).attributes = windows(gCurrentWindow).attributes or $20
    else
        windows(gCurrentWindow).attributes = windows(gCurrentWindow).attributes and $df
    end if
end sub

sub fc_bold(f as byte) shared static
    if f then
        windows(gCurrentWindow).attributes = windows(gCurrentWindow).attributes or $40
    else
        windows(gCurrentWindow).attributes = windows(gCurrentWindow).attributes and $bf
    end if
end sub

sub fc_underline(f as byte) shared static
    if f then
        windows(gCurrentWindow).attributes = windows(gCurrentWindow).attributes or $80
    else
        windows(gCurrentWindow).attributes = windows(gCurrentWindow).attributes and $7f
    end if
end sub

sub fc_resetPalette() shared static
    call enable_io()
    call fc_loadPalette(gConfig.palettebase, 255, false)
end sub

sub fc_loadReservedBitmap(name as String * 80) shared static
    if firstFreeGraphMem <> gConfig.bitmapbase then call fc_fatal("Reserved memory must be allocated first")
    call fc_loadFCI(0, name)
    call fc_resetPalette()
end sub

sub fc_real_init(h640 as byte, v400 as byte, rows as byte, columns as byte) static
    call enable_io()
    poke 53272,23 ' make lowercase

    if peek($d06f) and 128 then
        gTopBorder = TOPBORDER_NTSC
        gBottomBorder = BOTTOMBORDER_NTSC
    else
        gTopBorder = TOPBORDER_PAL
        gBottomBorder = BOTTOMBORDER_PAL
    end if

    firstFreePalMem = gConfig.palettebase
    firstFreeGraphMem = gConfig.bitmapbase
    call fc_freeGraphAreas()

    poke BORDERCOL, BLACK
    poke SCREENCOL, BLACK

    autoCR = TRUE

    call fc_screenmode(h640, v400, rows, columns)
    call fc_textcolor(GREEN)
end sub

sub fc_init(h640 as byte, v400 as byte, rows as byte, columns as byte) shared static
    ' standard config
    gConfig.screenbase = $12000
    gConfig.palettebase = $14000
    gConfig.bitmapbase = gConfig.palettebase + MAX_FCI_BLOCKS * 256 * 3
    gConfig.colorbase = $81000 ' $0ff ...
    call fc_real_init(h640, v400, rows, columns)
end sub

sub fc_init(h640 as byte, v400 as byte, rows as byte, columns as byte, screenbase as long, palettebase as long, bitmapbase as long, colorbase as long) overload shared static
    ' use users supplied config parameters
    gConfig.screenbase = screenbase
    gConfig.palettebase = palettebase
    gConfig.bitmapbase = bitmapbase
    gConfig.colorbase = colorbase
    call fc_real_init(h640, v400, rows, columns)
end sub

