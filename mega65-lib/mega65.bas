' General utilities and defitions for the MEGA65 computer
'
shared const true = 1
shared const false = 0

shared const VIC2      = $d000
shared const VIC2CTRL  = $d016
shared const BORDERCOL = $d020
shared const SCREENCOL = $d021
shared const VIC4CTRL  = $d054
shared const VIC3CTRL  = $d031
shared const VIC3KEY   = $d02f
shared const HOTREG    = $d05d
shared const SCNPTR    = $d060
shared const COLPTR    = $d064
shared const CHARPTR   = $d068
shared const CHRCOUNT  = $d05e
shared const DISPROWS  = $d07b
shared const LINESTEP_LO = $d058
shared const LINESTEP_HI = $d059

shared const BLACK  = 0
shared const WHITE  = 1
shared const RED    = 2
shared const CYAN   = 3
shared const PURPLE = 4
shared const GREEN  = 5
shared const BLUE   = 6
shared const YELLOW = 7
shared const ORANGE = 8
shared const BROWN  = 9
shared const LRED   = 10
shared const DGREY  = 11
shared const GREY   = 12
shared const LGREEN = 13
shared const LBLUE  = 14
shared const LGREY  = 15

sub enable_40mhz() shared static
    ' run the mega 65 at 40 MHz
    poke $0, $41
end sub

sub enable_io() shared static
    ' make sure that extended I/O mode is enabled
    poke VIC3KEY, $47
    poke VIC3KEY, $53
end sub

function BYTE0 as byte (address as long) shared static
    BYTE0 = peek(@address)
end function

function BYTE1 as byte (address as long) shared static
    BYTE1 = peek(@address + 1)
end function

function BYTE2 as byte (address as long) shared static
    BYTE2 = peek(@address + 2)
end function

