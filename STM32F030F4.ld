ENTRY(reset_handler)

/* define the end of the stack memory (start of SRAM + size of SRAM) */
_estack = 0x20001000;

/* define memory regions */
MEMORY
{
    FLASH ( rx )      : ORIGIN = 0x08000000, LENGTH = 16K
    RAM ( rxw )       : ORIGIN = 0x20000000, LENGTH = 4K
}