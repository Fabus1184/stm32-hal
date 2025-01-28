const std = @import("std");

const arm = @import("cortex-m0.zig");

export fn exceptionHandler() callconv(.Naked) noreturn {
    asm volatile (
    // Push R4-R7 (callee-saved registers)
        \\push {r4-r7}
        // Save LR to R0 and push it onto the stack
        \\mov r0, lr
        \\push {r0}
        // Call the real handler
        \\bl exceptionHandlerReal
        // Restore LR
        \\pop {r0}
        \\mov lr, r0
        // Pop R4-R7 (callee-saved registers)
        \\pop {r4-r7}
        // Return from the interrupt
        \\bx lr
        ::: "r0", "r1", "r2", "r3", "r12", "lr", "pc", "memory");
}

const Exception = enum(u6) {
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
};

pub var SoftExceptionHandler = std.EnumMap(Exception, *const fn () void){};

export fn exceptionHandlerReal() callconv(.C) void {
    const e: Exception = @enumFromInt(arm.ICSR.vectactive);

    std.log.debug("exception handler: {s}", .{@tagName(e)});

    if (SoftExceptionHandler.get(e)) |handler| {
        handler();
    } else {
        std.log.err("unhandled exception: {s}", .{@tagName(e)});
        while (true) {}
    }
}
