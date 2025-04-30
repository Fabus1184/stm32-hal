pub const CPUID: *const packed struct(u32) {
    revision: u4,
    partno: u12,
    constant: u4,
    variant: u4,
    implementer: u8,
} = @ptrFromInt(0xE000_ED00);

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

pub fn Nvic(comptime baseAddress: [*]align(4) volatile u8) type {
    return struct {
        ictr: *volatile packed struct(u32) {
            intlinesnum: u4,
            __: u28,
        } = @ptrCast(&baseAddress[0x4]),
        iser: [*]volatile u32 = @ptrCast(&baseAddress[0x100]),
        icer: [*]volatile u32 = @ptrCast(&baseAddress[0x180]),
        ispr: [*]volatile u32 = @ptrCast(&baseAddress[0x200]),
        icpr: [*]volatile u32 = @ptrCast(&baseAddress[0x280]),
        iabr: [*]volatile u32 = @ptrCast(&baseAddress[0x300]),
        ipr: [*]volatile u8 = @ptrCast(&baseAddress[0x400]),

        pub fn enableInterrupt(self: @This(), interrupt: u32) void {
            self.iser[interrupt / 32] |= @as(u32, 1) << @intCast(interrupt % 32);
        }

        pub fn disableInterrupt(self: @This(), interrupt: u32) void {
            self.icer[interrupt / 32] |= @as(u32, 1) << @intCast(interrupt % 32);
        }

        pub fn setPending(self: @This(), interrupt: u32) void {
            self.ispr[interrupt / 32] |= @as(u32, 1) << @intCast(interrupt % 32);
        }

        pub fn clearPending(self: @This(), interrupt: u32) void {
            self.icpr[interrupt / 32] |= @as(u32, 1) << @intCast(interrupt % 32);
        }

        pub fn setPriority(self: @This(), interrupt: u32, priority: u4) void {
            self.ipr[interrupt] = @as(u8, priority) << 4;
        }
    };
}

pub const NVIC = Nvic(@ptrFromInt(0xE000_E000)){};

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
