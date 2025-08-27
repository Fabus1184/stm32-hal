const std = @import("std");

pub const cortex = @import("../core/cortex.zig");
pub usingnamespace cortex;

pub const ICSR: *volatile packed struct(u32) {
    /// Contains the active exception number
    /// - 0: Thread mode
    /// - Non-zero: exception number
    vectactive: u6,
    _: u6,
    /// indicates the exception number of the highest priority pending enabled exception
    /// - 0: no pending exception
    /// - Non-zero: exception number
    vectpending: u6,
    __: u4,
    /// interrupt pending flag, excluding NMI and Faults
    /// - 0: interrupt not pending
    /// - 1: interrupt pending
    isrpending: bool,
    ___: u2,
    /// SysTick exception clear-pending bit
    ///
    /// Write:
    /// - 0: no effect
    /// - 1: clear SysTick exception pending bit
    ///
    /// This bit is write-only, on a register read its value is unknown
    pendstclr: bool,
    /// SysTick exception set-pending bit
    ///
    /// Write:
    /// - 0: no effect
    /// - 1: changes SysTick exception state to pending
    ///
    /// Read:
    /// - 0: SysTick exception is not pending
    /// - 1: SysTick exception is pending
    pendstset: bool,
    /// PendSV clear-pending bit
    ///
    /// Write:
    /// - 0: no effect
    /// - 1: removes the pending state from the PendSV exception
    pendsvclr: bool,
    /// PendSV set-pending bit
    ///
    /// Write:
    /// - 0: no effect
    /// - 1: changes the PendSV exception state to pending
    ///
    /// Read:
    /// - 0: PendSV exception is not pending
    /// - 1: PendSV exception is pending
    /// Writing 1 to this bit is the only way to set the PendSV exception state to pending
    pendsvset: bool,
    ____: u2,
    /// NMI set-pending bit
    ///
    /// Write:
    /// - 0: no effect
    /// - 1: changes the NMI exception state to pending
    ///
    /// Read:
    /// - 0: NMI exception is not pending
    /// - 1: NMI exception is pending
    nmipendset: bool,
} = @ptrFromInt(0xE000_ED04);

export fn exceptionHandler() callconv(.Naked) noreturn {
    asm volatile (
    // R0-R3, R12, LR, PC, xPSR are automatically pushed onto the stack
    // Push R4-R7 (callee-saved registers)
        \\push {r4-r7}
        // Save LR to R0 and push it onto the stack
        \\mov r0, lr
        \\push {r0}
        // load PC from the stack into R0
        \\ldr r0, [sp, #44]
        // Call the real handler with the PC in R0
        \\bl %[handler]
        // Restore LR
        \\pop {r0}
        \\mov lr, r0
        // Pop R4-R7 (callee-saved registers)
        \\pop {r4-r7}
        // Return from the interrupt
        \\bx lr
        :
        : [handler] "i" (exceptionHandlerReal),
        : "r0", "r1", "r2", "r3", "r12", "lr", "memory"
    );
}

const Exception = enum(@TypeOf(ICSR.vectactive)) {
    Reset = 1,
    NMI = 2,
    HardFault = 3,
    MemoryManagement = 4,
    BusFault = 5,
    UsageFault = 6,
    SVCall = 11,
    DebugMonitor = 12,
    PendSV = 14,
    SysTick = 15,
    IRQ0 = 16,
    IRQ1 = 17,
    IRQ2 = 18,
    IRQ3 = 19,
    IRQ4 = 20,
    IRQ5 = 21,
    IRQ6 = 22,
    IRQ7 = 23,
    IRQ8 = 24,
    IRQ9 = 25,
    IRQ10 = 26,
    IRQ11 = 27,
    IRQ12 = 28,
    IRQ13 = 29,
    IRQ14 = 30,
    IRQ15 = 31,
    IRQ16 = 32,
    IRQ17 = 33,
    IRQ18 = 34,
    IRQ19 = 35,
    IRQ20 = 36,
    IRQ21 = 37,
    IRQ22 = 38,
    IRQ23 = 39,
    IRQ24 = 40,
    IRQ25 = 41,
    IRQ26 = 42,
    IRQ27 = 43,
    IRQ28 = 44,
    IRQ29 = 45,
    IRQ30 = 46,
    IRQ31 = 47,
};

pub var SoftExceptionHandler = std.EnumMap(Exception, *const fn () void){};

export fn exceptionHandlerReal(pc: u32) callconv(.C) void {
    const e: Exception = @enumFromInt(ICSR.vectactive);

    if (SoftExceptionHandler.get(e)) |handler| {
        handler();
    } else {
        std.log.err("unhandled exception: {s}, pc: {x}", .{ @tagName(e), pc });
        @panic("unhandled exception");
    }
}
