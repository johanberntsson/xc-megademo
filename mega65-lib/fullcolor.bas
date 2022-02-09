' Implements functions to set up and use the full color mode
' on the MEGA65 computer.
'
' Control:
' - fc_init
' - fc_fatal
' - fc_go8bit
'
' Bitmaps:
' - fc_loadFCI
' - fc_loadFCIPalette
' - fc_displayFCI
' - fc_displayFCIFile
' - fc_displayTile
' - fc_resetPalette
' - fc_loadReservedBitmap
' - fc_setUniqueTileMode
'
' Text input:
' - fc_cursor
' - fc_getkey
' - fc_input
' - fc_getkeyP
'
' Screen Layout
' - fc_setwin
' - fc_clrscr
' - fc_resetwin
' - fc_scrollUp
' - fc_scrollDown
' - fc_wherex
' - fc_wherey
' - fc_gotoxy

' Text output:
' - fc_setfont
' - fc_setAutoCR
' - fc_textcolor
' - fc_flash
' - fc_revers
' - fc_bold
' - fc_underline
' TODO: all text output routines below should use gCurrentFont
' - fc_plotPetsciiChar
' - fc_line
' - fc_block
' - fc_puts
' - fc_puts
' - fc_putsxy
' - fc_putcxy
' - fc_center
' - fc_hlinexy
' - fc_vlinexy

const TOPBORDER_PAL = $58
const BOTTOMBORDER_PAL = $1e8
const TOPBORDER_NTSC = $27
const BOTTOMBORDER_NTSC = $1b7
const CURSOR_CHARACTER = 100

type Config
    screenbase as long    ' location of 16 bit screen
    palettebase as long   ' loaded palettes base
    bitmap_mirror as long ' bitmap base in uniqueMode (fast ram)
    bitmapbase as long    ' loaded bitmaps base
    colorbase as long     ' attribute/color ram
    bitmapbase_high as byte 
    ' bitmapbase_high is usually $00, but could be $80
    ' if uniqueMode stores bitmaps in attic RAM
end type

type TextWindow
    x0 as byte           ' current cursor X position
    y0 as byte           ' current cursor Y position
    width as byte        ' X origin
    height as byte       ' Y origin
    xc as byte           ' window width
    yc as byte           ' window height
    textcolor as byte    ' current window text color
    attributes as byte   ' current window extended text attributes
end type

type fciInfo
    baseAdr as long      ' bitmap base address
    paletteAdr as long   ' palette data base addres
    paletteSize as byte  ' size of palette (in palette entries)
    reservedSysPalette as byte ' if true, don't use colors 0-15
    columns as byte      ' number of character columns for image
    rows as byte         ' number of character rows
    size as word         ' size of bitmap
end type

dim gConfig as Config shared
dim gCurrentFont as int           ' -1 if text, else use gCurrentFont fci
dim gCurrentWindow as byte shared ' current window (1 - MAX_WINDOWS)
dim gScreenSize as word shared
dim gScreenRows as byte shared    ' number of screen rows (in characters)
dim gScreenColumns as byte shared ' number of screen columns (in characters)
dim gTopBorder as byte shared
dim gBottomBorder as word shared

dim windowCount as byte
dim fciCount as byte
dim firstFreeGraphMem as long ' first free graphics block
dim firstFreePalMem as long   ' first free palette memory block
dim nextFreeGraphMem as long  ' location of next free graphics block
dim nextFreePalMem as long    ' location of next free palette memory block

' if set, uses bitmap_mirror - $5ffff for tiles
' that can be modified independently
dim uniqueTile_X0 as byte
dim uniqueTile_Y0 as byte
dim uniqueTile_Width as byte
dim uniqueTile_Height as byte
dim uniqueTileMode as byte    

const MAX_WINDOWS =  8
const MAX_FCI = 16

dim windows(MAX_WINDOWS) as TextWindow
dim fci(MAX_FCI) as fciInfo

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
    dim colAdr as long
    dim start as byte

    if reservedSysPalette then start = 16 else start = 0

    for i as byte = start to size
        colAdr = clong(i) * 3
        poke $d100 + i, nyblswap(dma_peek(adr + colAdr))
        poke $d200 + i, nyblswap(dma_peek(adr + colAdr + 1))
        poke $d300 + i, nyblswap(dma_peek(adr + colAdr + 2))
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
    fciCount = 1
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
    return 0 ' should never happen
end function

function fc_nextInfoBlock as byte () static
    dim info as byte
    ' find a free block
    if fciCount = MAX_FCI then call fc_fatal("Out of blocks")
    info = fciCount
    fciCount = fciCount + 1
    return fciCount
end function

function fc_loadFCI as byte (info as byte, filename as String * 20) shared static
    dim b as byte
    dim n as byte
    dim size as word
    dim adrTo as long
    dim adrFrom as long
    dim options as byte
    dim compressed as byte

    open 2,8,2, filename
    ' skip fciP
    read #2, b
    read #2, b
    read #2, b
    read #2, b
    ' skip version
    read #2, b
    read #2, b: fci(info).rows = b
    read #2, b: fci(info).columns = b
    read #2, b: options = b
    read #2, b: fci(info).paletteSize = b

    compressed = (options and 1)
    fci(info).reservedSysPalette = (options and 2)

    ' read palette
    size = fci(info).paletteSize
    adrTo = fc_allocPalMem(3 * size)
    fci(info).paletteAdr = adrTo
    adrFrom = $400
    for i as byte = 0 to 2
        for j as word = 0 to size
            read #2, b
            poke cword(adrFrom + j), b
        next
        call dma_copy(adrFrom, adrTo, size + 1)
        adrTo = adrTo + size + 1
    next

    ' skip IMG
    read #2, b
    read #2, b
    read #2, b

    ' read bitmap info
    size = cword(64) * fci(info).rows * fci(info).columns
    fci(info).size  = size
    adrTo = fc_allocGraphMem(size)
    fci(info).baseAdr = adrTo
    adrFrom = $400

    dim lastb as word
    dim totRead as word
    dim count as byte

    n = 0
    count = 0
    totRead = 0


    ' if compressed = true, then the data is RLE encoded
    ' with repeated numbers being the compression marker
    ' <num> <num> <count> means that the output contains
    ' <count> number of <num>
    do while cint(totRead) < cint(size) ' TODO: why cast?
        if count > 0 then
            count = count - 1
        else 
            read #2, b
            if compressed = true and b = lastb then
                ' double entry found, should be followed by
                ' a count (but skip if nothing read yet)
                if totRead > 0 then 
                    read #2, count
                    count = count - 2
                end if
            end if
            lastb = b
        end if
        poke cword(adrFrom + n), b
        totRead = totRead + 1
        if n = $ff then
            ' buffer is full, copy to destination
            call dma_copy(0, adrFrom, gConfig.bitmapbase_high, adrTo, cword(n + 1))
            adrTo = adrTo + n + 1
            n = 0
        else
            n = n + 1
        end if
    loop
    close 2
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
    call dma_fill_skip($ff, gConfig.colorBase + bas, 0, w, 2)
    call dma_fill_skip($ff, gConfig.colorBase + bas + 1, col, w, 2)
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
        call dma_copy($ff, bas1, $ff, bas0, w)
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
        call dma_copy($ff, bas0, $ff, bas1, w)
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

sub fc_setfont(font as int) shared static
    gCurrentFont = font
end sub

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

sub fc_clearUniqueTiles() static
    call dma_fill($18000, 0, cword($7800)) ' $18000 - $1f800
    ' skip over DOS ($1f800 - $24000)
    call dma_fill($24000, 0, cword($8000)) ' $24000 - $2c000
    ' skip over C64 kernal ($2c000 - $30000)
    call dma_fill($30000, 0, $8000)
    call dma_fill($38000, 0, $8000)
    call dma_fill($40000, 0, $8000)
    call dma_fill($48000, 0, $8000)
    call dma_fill($50000, 0, $8000)
    call dma_fill($58000, 0, $8000)
end sub

sub fc_setUniqueTileMode(x0 as byte, y0 as byte, width as byte, height as byte) shared static
    dim b as byte
    dim a as long: a = $30000
    if uniqueTileMode = false then
        ' Bank out the C64/C65 ROM, freeing $18000 - $3xxxx.
        ' But, assuming that the program is started from C64
        ' mode, we still need the kernal and DOS, so avoid
        ' writing on $1f800 - $24000 and $2c000 - $30000
        b =  dma_peek(a)
        asm
            ; Since dasm doesn't allow 4510 opcodes I have
            ; written the assembler in acme, made a hexdump and
            ; stored it here
            ;byte $a9, $00       ; lda #$00
            ;byte $aa            ; tax
            ;byte $a8            ; tay
            ;byte $4b            ; taz
            ;byte $5c            ; map
            ;byte $a9, $36       ; lda #$36 (no basic)
            ;byte $85, $01       ; sta $01
            ;byte $a9, $47       ; lda #$47
            ;byte $8d, $2f, $d0  ; sta $d02f
            ;byte $a9, $53       ; lda #$53
            ;byte $8d, $2f, $d0  ; sta $d02f
            ;byte $ea            ; eom
            ; call MEGA65 hypervisor to remove write protection
            byte $a9, $70       ; lda #$70
            byte $8d, $40, $d6  ; sta $d640
            byte $ea            ; nop
        end asm
        ' check if we can write to the new RAM (banking worked)
        call dma_poke(a, b + 1)
        if dma_peek(a) <> b + 1 then call fc_fatal("Banking failed")
        call fc_clearUniqueTiles()

        uniqueTileMode = true
        uniqueTile_X0 = x0
        uniqueTile_Y0 = y0
        uniqueTile_Width = width
        uniqueTile_Height = height

        if fciCount > 1 then call fc_fatal("Unique will destroy bitmaps")
        gConfig.bitmapbase = clong(0)
        gConfig.bitmapbase_high = $80
        call fc_freeGraphAreas()

    end if 
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
    call fc_loadPalette(fci(info).paletteAdr, fci(info).paletteSize, fci(info).reservedSysPalette)
end sub

sub fc_fadeFCI(info as byte, x0 as byte, y0 as byte, steps as byte) static
    call fc_zeroPalette(fci(info).reservedSysPalette)
    call fc_addGraphicsRect(x0, y0, fci(info).columns, fci(info).rows, fci(info).baseAdr)
    call fc_fadePalette(fci(info).paletteAdr, fci(info).paletteSize, fci(info).reservedSysPalette, steps, false)
end sub


sub fc_displayFCI(info as byte, x0 as byte, y0 as byte, setPalette as byte) shared static
    call fc_addGraphicsRect(x0, y0, fci(info).columns, fci(info).rows, fci(info).baseAdr)
    if setPalette then call fc_loadFCIPalette(info)
end sub

function fc_displayFCIFile as byte (filename as String * 20, x0 as byte, y0 as byte) shared static
    dim info as byte
    info = fc_loadFCI(filename)
    call fc_displayFCI(info, x0, y0, true)
    return info
end function

sub fc_displayTile(info as byte, x0 as byte, y0 as byte, t_x as byte, t_y as byte, t_w as byte, t_h as byte, mergeTiles as byte) shared static
    dim screenAddr as long
    dim charIndex as word
    dim toTileAddr as long
    dim fromTileAddr as long
    dim rawToTileAddr as long

    for y as byte = 0 to t_h -1
        screenAddr = gConfig.screenbase + 2 *(x0 + (y0 + y) * cword(gScreenColumns))
        if uniqueTileMode then
            fromTileAddr = fci(info).baseAdr + 64*(t_x + ((y + t_y) * clong(fci(info).columns)))
            ' copy bitmap asset to location in bitmap_mirror - $5xxxx
            rawToTileAddr = gConfig.bitmap_mirror + 64 * (x0 + (clong(gScreenColumns) * (y + y0)))
        else
            charIndex = cword(fci(info).baseAdr / 64) + t_x + (y * fci(info).columns)
        end if
        for x as byte = t_x to t_x + t_w - 1
            if uniqueTileMode then
                toTileAddr = rawToTileAddr
                ' skip over DOS
                if toTileAddr >= $1f800 then toTileAddr = toTileAddr + $4800
                ' skip over C64 kernal
                if toTileAddr >= $2c000 then toTileAddr = toTileAddr + $4000
                if mergeTiles then
                    call dma_copy_transparent(gConfig.bitmapbase_high, fromTileAddr, 0, toTileAddr, 64, 0)
                else
                    call dma_copy(gConfig.bitmapbase_high, fromTileAddr, 0, toTileAddr, 64)
                end if
                charIndex = cword(toTileAddr / 64)
                fromTileAddr = fromTileAddr + 64
                rawToTileAddr = rawToTileAddr + 64
            end if
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
    if uniqueTileMode then call fc_clearUniqueTiles()
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

sub fc_real_init(h640 as byte, v400 as byte, unique as byte, rows as byte, columns as byte) static
    call enable_io()
    poke 53272,23 ' make lowercase
    uniqueTileMode = false

    if peek($d06f) and 128 then
        gTopBorder = TOPBORDER_NTSC
        gBottomBorder = BOTTOMBORDER_NTSC
    else
        gTopBorder = TOPBORDER_PAL
        gBottomBorder = BOTTOMBORDER_PAL
    end if

    ' where the sceen bitmap starts in uniqueMode
    gConfig.bitmap_mirror = $19000 

    firstFreePalMem = gConfig.palettebase
    firstFreeGraphMem = gConfig.bitmapbase
    call fc_freeGraphAreas()

    poke BORDERCOL, BLACK
    poke SCREENCOL, BLACK

    autoCR = TRUE

    call fc_screenmode(h640, v400, rows, columns)
    if unique then call fc_setUniqueTileMode(0, 0, gScreenColumns, gScreenRows)

    call fc_setfont(-1)
    call fc_textcolor(GREEN)
end sub

sub fc_init(h640 as byte, v400 as byte, unique as byte, rows as byte, columns as byte) shared static
    ' standard config
    gConfig.screenbase = $12000
    gConfig.palettebase = $14000
    gConfig.bitmapbase_high = $00
    gConfig.bitmapbase = gConfig.palettebase + MAX_FCI * 256 * 3
    gConfig.colorbase = $81000 ' $0ff ...
    call fc_real_init(h640, v400, unique, rows, columns)
end sub

