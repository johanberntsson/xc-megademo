include "mega65-lib/mega65.bas"
include "mega65-lib/memory.bas"
include "mega65-lib/fullcolor.bas"

call enable_40mhz()
call fc_init(1, 1, 60)
call fc_putsxy(3, 3, "hello world")
call fc_plotPetsciiChar(0, 0, $35, WHITE, 0)
call fc_plotPetsciiChar(2, 5, $30, RED, 0)

