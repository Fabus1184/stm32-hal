MEMORY
{
    RAM (xrw)     : ORIGIN = 0x20000000, LENGTH = 128K
    CCMRAM (xrw)  : ORIGIN = 0x10000000, LENGTH = 64K
    FLASH (rx)    : ORIGIN = 0x8000000, LENGTH = 512K
}

ENTRY(main);
__reset_stack_pointer = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS {
    .text : {
        LONG(__reset_stack_pointer); /* Initial stack pointer value */
        LONG(main | 1); /* The reset handler */
        LONG(exceptionHandler | 1); /* NMI handler */
        LONG(exceptionHandler | 1); /* HardFault handler */
        LONG(exceptionHandler | 1); /* MemoryManagement handler */
        LONG(exceptionHandler | 1); /* BusFault handler */
        LONG(exceptionHandler | 1); /* UsageFault handler */
        LONG(exceptionHandler | 1); /* Reserved */
        LONG(exceptionHandler | 1); /* Reserved */
        LONG(exceptionHandler | 1); /* Reserved */
        LONG(exceptionHandler | 1); /* Reserved */
        LONG(exceptionHandler | 1); /* SVCall handler */
        LONG(exceptionHandler | 1); /* DebugMonitor handler */
        LONG(exceptionHandler | 1); /* Reserved */
        LONG(exceptionHandler | 1); /* PendSV handler */
        LONG(exceptionHandler | 1); /* SysTick handler

        /* External interrupt handlers */
        . += 4 * 112;

        /* And here comes the rest of the code, ie. all symbols starting with .text */
        *(.text*)
        *(.rodata*)

        . = ALIGN(4);
    } > FLASH  /* Put this in the flash memory region */

    .data : {
        _start_data = .;
        *(.data)
        . = ALIGN(4);
        _end_data = .;
    } > RAM AT > FLASH

    .bss : {
        _start_bss = .;
        *(.bss)
        *(COMMON)
        . = ALIGN(4);
        _end_bss = .;
    } > RAM
    
    .ARM.exidx : {
        *(.ARM.exidx*)
        . = ALIGN(4);
    } > FLASH
}

_start_data_load = LOADADDR(.data);