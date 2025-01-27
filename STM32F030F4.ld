MEMORY
{
    FLASH ( rx )      : ORIGIN = 0x08000000, LENGTH = 16K
    RAM ( rxw )       : ORIGIN = 0x20000000, LENGTH = 4K
}

ENTRY(main);
__reset_stack_pointer = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS {
    .text : {
        LONG(__reset_stack_pointer);
        LONG(main | 1);
        
        /* The whole interrupt table is 332 bytes long. Advance to that position. */
        FILL(0x00);
        . += 4;
        LONG(systickHandler | 1);
        . += (88 - 7) * 4;

        /* And here comes the rest of the code, ie. all symbols starting with .text */
        *(.text)
        *(.rodata*)

        . = ALIGN(4);
    } > FLASH  /* Put this in the flash memory region */
    
    .ARM.exidx : {
        *(.ARM.exidx*)
        . = ALIGN(4);
    } > FLASH
}