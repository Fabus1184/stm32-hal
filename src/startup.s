// Generate code optimized for cortex-m0 and handle floating point 
// calculations in software (fplib) since there is no FPU available.
.syntax unified
.cpu cortex-m0
.fpu softvfp
.thumb

// Global memory locations (usable in other files)
.global vtable
.global reset_handler
.global mymain

// Vector Table
.type vtable, %object
vtable:
    .word _estack
    .word reset_handler
.size vtable, .-vtable

// Application code
.type reset_handler, %function
reset_handler:
    // Set the stack pointer to the end of the stack
    LDR  r0, =_estack
    MOV  sp, r0

    // call the main function
    BL   mymain

    // Infinite loop for good measure
    B    .

.size reset_handler, .-reset_handler