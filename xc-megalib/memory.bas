' Implements DMA operations for quick data transfer and access to
' higher memory (bank 1 - 5 and attic RAM)

type Dmalist
    option_0b as byte
    option_80 as byte
    source_mb as byte
    option_81 as byte
    dest_mb as byte
    option_85 as byte
    dest_skip as byte
    end_of_options as byte
    command as byte
    count as word
    source_addr as word
    source_bank as byte
    dest_addr as word
    dest_bank as byte
    sub_cmd as byte
    modulo as word
end type

type Dmalist_transparent
    option_07 as byte ' enable transparancy
    option_0b as byte
    option_80 as byte
    source_mb as byte
    option_81 as byte
    dest_mb as byte
    option_82 as byte
    source_skip_bit as byte
    option_83 as byte
    source_skip as byte
    option_84 as byte
    dest_skip_bit as byte
    option_85 as byte
    dest_skip as byte
    option_86 as byte
    transparent as byte
    end_of_options as byte
    command as byte
    count as word
    source_addr as word
    source_bank as byte
    dest_addr as word
    dest_bank as byte
    sub_cmd as byte
    modulo as word
end type

dim dmalist as Dmalist
dim dmalist_transparent as Dmalist_transparent

sub do_dma(list as word) static
    call enable_io()
    poke $d702, 0
    poke $d704, 0
    poke $d701, BYTE1(list)
    poke $d705, BYTE0(list)
end sub 

sub dma_copy_transparent(source_highaddress as byte, source_address as long, destination_highaddress as byte, destination_address as long, count as word, transparent as byte, source_skip as byte, source_skip_bit as byte, dest_skip as byte, dest_skip_bit as byte, overwrite as byte) shared static
    if overwrite then
        dmalist_transparent.option_07 = $0b ' just a dummy
    else
        dmalist_transparent.option_07 = $07
    end if 
    dmalist_transparent.option_0b = $0b
    dmalist_transparent.option_80 = $80
    dmalist_transparent.source_mb = source_highaddress
    dmalist_transparent.option_81 = $81
    dmalist_transparent.dest_mb = destination_highaddress
    dmalist_transparent.option_82 = $82
    dmalist_transparent.source_skip_bit = source_skip_bit
    dmalist_transparent.option_83 = $83
    dmalist_transparent.source_skip = source_skip
    dmalist_transparent.option_84 = $84
    dmalist_transparent.dest_skip_bit = dest_skip_bit
    dmalist_transparent.option_85 = $85
    dmalist_transparent.dest_skip = dest_skip
    dmalist_transparent.option_86 = $86
    dmalist_transparent.transparent = transparent
    dmalist_transparent.end_of_options = 0
    dmalist_transparent.command = 0
    dmalist_transparent.sub_cmd = 0
    dmalist_transparent.count = count
    dmalist_transparent.source_addr = cword(source_address)
    dmalist_transparent.source_bank = BYTE2(source_address) and $0f
    dmalist_transparent.dest_addr = cword(destination_address)
    dmalist_transparent.dest_bank = BYTE2(destination_address) and $0f
    call do_dma(@dmalist_transparent)
end sub

sub dma_copy(source_highaddress as byte, source_address as long, destination_highaddress as byte, destination_address as long, count as word) shared static
    dmalist.option_0b = $0b
    dmalist.option_80 = $80
    dmalist.source_mb = source_highaddress
    dmalist.option_81 = $81
    dmalist.dest_mb = destination_highaddress
    dmalist.option_85 = $85
    dmalist.dest_skip = 1
    dmalist.end_of_options = 0
    dmalist.command = 0
    dmalist.sub_cmd = 0
    dmalist.count = count
    dmalist.source_addr = cword(source_address)
    dmalist.source_bank = BYTE2(source_address) and $0f
    dmalist.dest_addr = cword(destination_address)
    dmalist.dest_bank = BYTE2(destination_address) and $0f
    call do_dma(@dmalist)
end sub

sub dma_copy(source_address as long, destination_address as long, count as word) shared static overload
    call dma_copy(0, source_address, 0, destination_address, count)
end sub

sub dma_fill(highaddress as byte, address as long, value as byte, count as word) shared static
    dmalist.option_0b = $0b
    dmalist.option_80 = $80
    dmalist.source_mb = 0
    dmalist.option_81 = $81
    dmalist.dest_mb = highaddress
    dmalist.option_85 = $85
    dmalist.dest_skip = 1
    dmalist.end_of_options = 0
    dmalist.command = 3
    dmalist.sub_cmd = 0
    dmalist.count = count
    dmalist.source_addr = value
    dmalist.dest_addr = cword(address)
    dmalist.dest_bank = BYTE2(address) and $0f
    call do_dma(@dmalist)
end sub

sub dma_fill(address as long, value as byte, count as word) shared static overload
    call dma_fill(0, address, value, count)
end sub

sub dma_fill_skip(highaddress as byte, address as long, value as byte, count as word, skip as byte) shared static
    dmalist.option_0b = $0b
    dmalist.option_80 = $80
    dmalist.source_mb = 0
    dmalist.option_81 = $81
    dmalist.dest_mb = highaddress
    dmalist.option_85 = $85
    dmalist.dest_skip = skip
    dmalist.end_of_options = 0
    dmalist.command = 3
    dmalist.sub_cmd = 0
    dmalist.count = count
    dmalist.source_addr = cword(value)
    dmalist.source_bank = 0
    dmalist.dest_addr = cword(address)
    dmalist.dest_bank = BYTE2(address) and $0f
    call do_dma(@dmalist)
end sub

sub dma_fill_skip(address as long, value as byte, count as word, skip as byte) shared static overload
    call dma_fill_skip(0, address, value, count, skip)
end sub

sub dma_poke(highaddress as byte, address as long, value as byte) shared static
    dmalist.option_0b = $0b
    dmalist.option_80 = $80
    dmalist.source_mb = 0
    dmalist.option_81 = $81
    dmalist.dest_mb = highaddress
    dmalist.option_85 = $85
    dmalist.dest_skip = 1
    dmalist.end_of_options = 0
    dmalist.command = 3
    dmalist.sub_cmd = 0
    dmalist.count = 1
    dmalist.source_addr = value
    dmalist.source_bank = 0
    dmalist.dest_addr = cword(address)
    dmalist.dest_bank = BYTE2(address) and $0f
    call do_dma(@dmalist)
end sub

function dma_peek as byte (highaddress as byte, address as long) shared static
    dim dmabyte as byte
    dmalist.option_0b = $0b
    dmalist.option_80 = $80
    dmalist.source_mb = highaddress
    dmalist.option_81 = $81
    dmalist.dest_mb = 0
    dmalist.option_85 = $85
    dmalist.dest_skip = 1
    dmalist.end_of_options = 0
    dmalist.command = 0
    dmalist.sub_cmd = 0
    dmalist.count = 1
    dmalist.source_addr = cword(address)
    dmalist.source_bank = BYTE2(address) and $0f
    dmalist.dest_addr = @dmabyte
    dmalist.dest_bank = 0
    call do_dma(@dmalist)
    return dmabyte
end function

function dma_peek as byte (address as long) shared static overload
    return dma_peek(0, address)
end function

sub dma_poke(address as long, value as byte) shared static overload
    call dma_poke(0, address, value)
end sub
