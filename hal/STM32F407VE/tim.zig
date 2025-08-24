const Register = @import("../register.zig").Register;

pub const Tim = struct {
    /// control register 1
    cr1: Register(packed struct(u16) {
        /// counter enable
        cen: bool,
        /// update disable
        udis: bool,
        /// update request source
        urs: bool,
        /// one-pulse mode
        opm: bool,
        /// direction
        dir: enum(u1) { up = 0, down = 1 },
        /// center-aligned mode selection
        cms: enum(u2) { edgeAligned = 0, centerAligned1 = 1, centerAligned2 = 2, centerAligned3 = 3 },
        /// auto-reload preload enable
        arpe: bool,
        /// clock division
        ckd: enum(u2) { div1 = 0, div2 = 1, div4 = 2, reserved = 3 },
        _: u6,
    }),

    cr2: *volatile u16,
    smcr: *volatile u16,
    dier: *volatile u16,
    sr: *volatile u16,
    egr: Register(packed struct(u16) {
        /// update generation
        ug: bool,
        /// capture/compare 1 generation
        cc1g: bool,
        /// capture/compare 2 generation
        cc2g: bool,
        /// capture/compare 3 generation
        cc3g: bool,
        /// capture/compare 4 generation
        cc4g: bool,
        /// capture/compare control update generation
        comg: bool,
        /// trigger generation
        tg: bool,
        /// break generation
        bg: bool,
        _: u8,
    }),

    /// TIM1/TIM8 capture/compare mode register 1
    ccmr1: Register(Ccmr),
    /// TIM1/TIM8 capture/compare mode register 2
    ccmr2: Register(Ccmr),

    /// TIM1/TIM8 capture/compare enable register
    ccer: Register(packed struct(u16) {
        /// capture/compare 1 output enable
        cc1e: bool,
        /// capture/compare 1 output polarity
        cc1p: bool,
        /// capture/compare 1 complementary output enable
        cc1ne: bool,
        /// capture/compare 1 complementary output polarity
        cc1np: bool,
        /// capture/compare 2 output enable
        cc2e: bool,
        /// capture/compare 2 output polarity
        cc2p: bool,
        /// capture/compare 2 complementary output enable
        cc2ne: bool,
        /// capture/compare 2 complementary output polarity
        cc2np: bool,
        /// capture/compare 3 output enable
        cc3e: bool,
        /// capture/compare 3 output polarity
        cc3p: bool,
        /// capture/compare 3 complementary output enable
        cc3ne: bool,
        /// capture/compare 3 complementary output polarity
        cc3np: bool,
        /// capture/compare 4 output enable
        cc4e: bool,
        /// capture/compare 4 output polarity
        cc4p: bool,
        _: u1,
        /// capture/compare 4 complementary output polarity
        cc4np: bool,
    }),

    cnt: *volatile u16,

    /// prescaler
    psc: *volatile u16,

    /// auto-reload register
    arr: *volatile u16,

    rcr: *volatile u16,

    /// capture/compare register 1
    ccr1: *volatile u16,
    /// capture/compare register 2
    ccr2: *volatile u16,
    /// capture/compare register 3
    ccr3: *volatile u16,
    /// capture/compare register 4
    ccr4: *volatile u16,

    bdtr: *volatile u16,
    dcr: *volatile u16,
    dmar: *volatile u16,

    const Ccmr = packed struct(u16) {
        const Selection = enum(u2) { output = 0, inputTi1 = 1, inputTi2 = 2, inputTrc = 3 };
        const Mode = enum(u3) {
            frozen = 0,
            activeOnMatch = 1,
            inactiveOnMatch = 2,
            toggle = 3,
            forceInactive = 4,
            forceActive = 5,
            pwmMode1 = 6,
            pwmMode2 = 7,
        };

        /// capture/compare 1 selection
        cc1s: Selection,
        /// output compare 1 fast enable
        oc1fe: bool,
        /// output compare 1 preload enable
        oc1pe: bool,
        /// output compare 1 mode
        oc1m: Mode,
        /// output compare 1 clear enable
        oc1ce: bool,

        /// capture/compare 2 selection
        cc2s: Selection,
        /// output compare 2 fast enable
        oc2fe: bool,
        /// output compare 2 preload enable
        oc2pe: bool,
        /// output compare 2 mode
        oc2m: Mode,
        /// output compare 2 clear enable
        oc2ce: bool,
    };

    inline fn update(self: @This()) void {
        self.egr.modify(.{ .ug = true });
    }

    pub fn start(self: @This(), prescaler: u16, cycleCount: u16, dutyCycle: f32) void {
        const duty = @as(f32, @floatFromInt(cycleCount)) * dutyCycle;

        self.arr.* = cycleCount;
        self.ccr1.* = @intFromFloat(duty);
        self.psc.* = prescaler;

        self.cr1.modify(.{ .arpe = true });

        self.update();

        self.cr1.modify(.{ .cen = true });
    }

    pub fn setDutyCycle(self: @This(), dutyCycle: f32) void {
        const duty = @as(f32, @floatFromInt(self.arr.*)) * dutyCycle;
        self.ccr1.* = @intFromFloat(duty);
        self.update();
    }

    pub fn setupCh1Pwm(self: @This()) void {
        self.ccer.modify(.{ .cc1e = false });

        self.ccmr1.modify(.{
            .oc1m = .pwmMode1,
            .oc1pe = true,
        });

        self.ccer.modify(.{ .cc1e = true });

        self.update();
    }
};

pub fn MakeTim(base: [*]align(4) u8) Tim {
    return Tim{
        .cr1 = .{ .ptr = @ptrCast(base + 0x00) },
        .cr2 = @ptrCast(base + 0x04),
        .smcr = @ptrCast(base + 0x08),
        .dier = @ptrCast(base + 0x0C),
        .sr = @ptrCast(base + 0x10),
        .egr = .{ .ptr = @ptrCast(base + 0x14) },
        .ccmr1 = .{ .ptr = @ptrCast(base + 0x18) },
        .ccmr2 = .{ .ptr = @ptrCast(base + 0x1C) },
        .ccer = .{ .ptr = @ptrCast(base + 0x20) },
        .cnt = @ptrCast(base + 0x24),
        .psc = @ptrCast(base + 0x28),
        .arr = @ptrCast(base + 0x2C),
        .rcr = @ptrCast(base + 0x30),
        .ccr1 = @ptrCast(base + 0x34),
        .ccr2 = @ptrCast(base + 0x38),
        .ccr3 = @ptrCast(base + 0x3C),
        .ccr4 = @ptrCast(base + 0x40),
        .bdtr = @ptrCast(base + 0x44),
        .dcr = @ptrCast(base + 0x48),
        .dmar = @ptrCast(base + 0x4C),
    };
}
