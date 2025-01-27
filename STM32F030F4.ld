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
        LONG(main | 1); /* The reset handler */
        . += 4; /* NMI handler */
        . += 4; /* HardFault handler */
        . += 4; /* MemoryManagement handler */
        . += 4; /* BusFault handler */
        . += 4; /* UsageFault handler */
        . += 4; /* Reserved */
        . += 4; /* Reserved */
        . += 4; /* Reserved */
        . += 4; /* Reserved */
        . += 4; /* SVCall handler */
        . += 4; /* DebugMonitor handler */
        . += 4; /* Reserved */
        . += 4; /* PendSV handler */
        LONG(systickHandler | 1); /* SysTick handler */

        /* External interrupt handlers */
        . += 4 * 112;

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