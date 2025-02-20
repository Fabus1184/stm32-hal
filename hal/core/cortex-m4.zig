const std = @import("std");

pub const CPUID: *const packed struct(u32) {
    revision: u4,
    partno: u12,
    constant: u4,
    variant: u4,
    implementer: u8,
} = @ptrFromInt(0xE000_ED00);

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

pub const AICR: *volatile packed struct(u32) {
    _: u1,
    /// Reserved for debug use.
    vectclractive: bool,
    /// System reset request
    /// - 0: no effect
    /// - 1: requests a system level reset
    sysresetreq: bool,
    __: u12,
    /// Data endianness implemented
    /// - 0: little-endian
    /// - 1: big-endian
    endianness: u1,
    /// Vectkey
    /// On writes, write 0x05FA to this field, otherwise the processor ignores the write
    vectkey: u16,
} = @ptrFromInt(0xE000_ED20);

fn Systick(baseAddress: [*]volatile u32) type {
    return struct {
        /// Control and Status Register
        csr: *volatile packed struct(u32) {
            /// enables the counter
            enable: bool,
            /// enables the SysTick exception request
            tickint: u1,
            /// selects the clock source
            /// - 0: external reference clock
            /// - 1: processor clock
            clksource: u1,
            _: u13,
            /// 1 if the timer counted to 0 since the last read of this register
            countflag: bool,
            __: u15,
        } = @ptrCast(&baseAddress[0]),
        /// Reload Value Register
        rvr: *volatile packed struct(u32) {
            /// reload value
            value: u24,
            __: u8,
        } = @ptrCast(&baseAddress[1]),
        /// Current Value Register
        cvr: *volatile packed struct(u32) {
            /// current value
            value: u24,
            __: u8,
        } = @ptrCast(&baseAddress[2]),
        /// Calibration Value Register
        calib: *volatile packed struct(u32) {
            tenms: u24,
            _: u6,
            skew: bool,
            noref: bool,
        } = @ptrCast(&baseAddress[3]),
    };
}

pub const SYSTICK = Systick(@ptrFromInt(0xE000_E010)){};

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
        \\bl exceptionHandlerReal
        // Restore LR
        \\pop {r0}
        \\mov lr, r0
        // Pop R4-R7 (callee-saved registers)
        \\pop {r4-r7}
        // Return from the interrupt
        \\bx lr
        ::: "r0", "r1", "r2", "r3", "r12", "lr", "memory");
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
    //
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
    IRQ32 = 48,
    IRQ33 = 49,
    IRQ34 = 50,
    IRQ35 = 51,
    IRQ36 = 52,
    IRQ37 = 53,
    IRQ38 = 54,
    IRQ39 = 55,
    IRQ40 = 56,
    IRQ41 = 57,
    IRQ42 = 58,
    IRQ43 = 59,
    IRQ44 = 60,
    IRQ45 = 61,
    IRQ46 = 62,
    IRQ47 = 63,
};

pub var SoftExceptionHandler = std.EnumMap(Exception, *const fn () void){};

export fn exceptionHandlerReal(pc: u32) callconv(.C) void {
    const e: Exception = @enumFromInt(ICSR.vectactive);

    //std.log.debug("exception handler: {s}, pc: {x}", .{ @tagName(e), pc });

    if (SoftExceptionHandler.get(e)) |handler| {
        handler();
    } else {
        std.log.err("unhandled exception: {s}, pc: {x}", .{ @tagName(e), pc });
        std.builtin.panic("unhandled exception", null, pc);
    }
}

pub fn Nvic(comptime baseAddress: [*]align(4) volatile u8) type {
    return struct {
        pub const ictr = packed struct(u32) {
            intlinesnum: u4,
            __: u28,
        };

        ictr: *volatile ictr = @ptrCast(&baseAddress[0x4]),
        iser: [*]volatile u32 = @ptrCast(&baseAddress[0x100]),
        icer: [*]volatile u32 = @ptrCast(&baseAddress[0x180]),
        ispr: [*]volatile u32 = @ptrCast(&baseAddress[0x200]),
        icpr: [*]volatile u32 = @ptrCast(&baseAddress[0x280]),
        iabr: [*]volatile u32 = @ptrCast(&baseAddress[0x300]),
        ipr: [*]volatile u8 = @ptrCast(&baseAddress[0x400]),

        pub fn enableInterrupt(self: @This(), interrupt: u32) void {
            self.iser[interrupt / 32] |= @as(u32, 1) << @intCast(interrupt % 32);
            std.log.debug("enabled interrupt {}: {b:0<32}", .{ interrupt, self.iser[interrupt / 32] });
        }

        pub fn disableInterrupt(self: @This(), interrupt: u32) void {
            self.icer[interrupt / 32] |= @as(u32, 1) << @intCast(interrupt % 32);
        }

        pub fn setPending(self: @This(), interrupt: u32) void {
            self.ispr[interrupt / 32] |= @as(u32, 1) << @intCast(interrupt % 32);
            std.log.debug("set pending interrupt {}: {b:0<32}", .{ interrupt, self.ispr[interrupt / 32] });
        }

        pub fn clearPending(self: @This(), interrupt: u32) void {
            self.icpr[interrupt / 32] |= @as(u32, 1) << @intCast(interrupt % 32);
        }

        pub fn setPriority(self: @This(), interrupt: u32, priority: u4) void {
            self.ipr[interrupt] = @as(u8, priority) << 4;
        }
    };
}
