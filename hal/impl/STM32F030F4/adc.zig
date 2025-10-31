const Register = @import("hal").Register;

const Isr = packed struct(u32) {
    adrdy: u1,
    eosmp: u1,
    eoc: u1,
    eos: u1,
    ovr: u1,
    _0: u2,
    awd: u1,
    _1: u24,

    fn check(self: @This()) !void {
        if (self.ovr == 1) return error.Overrun;
    }
};

const Cr = packed struct(u32) {
    aden: u1,
    addis: u1,
    adstart: u1,
    _0: u1,
    adstp: u1,
    _1: u27,
};

const Cfgr1 = packed struct(u32) {
    const Resolution = enum(u2) {
        @"12Bits" = 0b00,
        @"10Bits" = 0b01,
        @"8Bits" = 0b10,
        @"6Bits" = 0b11,

        pub fn maxValue(self: @This()) f32 {
            return switch (self) {
                .@"12Bits" => 4095.0,
                .@"10Bits" => 1023.0,
                .@"8Bits" => 255.0,
                .@"6Bits" => 63.0,
            };
        }
    };

    dmaen: u1,
    dmacfg: u1,
    scandir: u1,
    res: Resolution,
    @"align": u1,
    extsel: u3,
    _0: u1,
    exten: u2,
    ovrmod: u1,
    cont: u1,
    wait: u1,
    autoff: u1,
    discen: u1,
    _1: u5,
    awdsgl: u1,
    awden: u1,
    _2: u2,
    awdch: u5,
    _3: u1,
};

const Smpr = packed struct(u32) {
    smp: enum(u3) {
        @"1.5" = 0b000,
        @"7.5" = 0b001,
        @"13.5" = 0b010,
        @"28.5" = 0b011,
        @"41.5" = 0b100,
        @"55.5" = 0b101,
        @"71.5" = 0b110,
        @"239.5" = 0b111,
    },
    _0: u29,
};

const Dr = packed struct(u32) {
    data: u16,
    _0: u16,
};

pub const Adc = struct {
    isr: Register(Isr),
    cr: Register(Cr),
    cfgr1: Register(Cfgr1),
    chselr: Register(u32),
    smpr: Register(Smpr),

    dr: Register(Dr),

    pub fn enable(self: @This()) void {
        self.cr.modify(.{ .aden = 1 });
    }

    pub fn convert(self: @This(), channel: u5) !f32 {
        try self.isr.load().check();

        self.chselr.store(@as(u32, 1) << channel);
        self.smpr.modify(.{ .smp = .@"239.5" });
        const resolution = Cfgr1.Resolution.@"12Bits";
        self.cfgr1.modify(.{ .res = resolution, .cont = 0 });

        self.cr.modify(.{ .adstart = 1 });
        while (self.isr.load().eos == 0) {}
        self.isr.modify(.{ .eos = 1 });

        try self.isr.load().check();

        const raw = self.dr.load().data;
        return @as(f32, @floatFromInt(raw)) / resolution.maxValue();
    }
};

pub fn MakeAdc(baseAddress: [*]align(4) volatile u8) Adc {
    return Adc{
        .isr = Register(Isr){ .ptr = @ptrCast(&baseAddress[0x0]) },
        .cr = Register(Cr){ .ptr = @ptrCast(&baseAddress[0x8]) },
        .cfgr1 = Register(Cfgr1){ .ptr = @ptrCast(&baseAddress[0xC]) },
        .chselr = Register(u32){ .ptr = @ptrCast(&baseAddress[0x28]) },
        .smpr = Register(Smpr){ .ptr = @ptrCast(&baseAddress[0x14]) },
        .dr = Register(Dr){ .ptr = @ptrCast(&baseAddress[0x40]) },
    };
}
