pub const Adc = struct {
    sr: *volatile packed struct(u32) {
        awd: u1,
        eoc: u1,
        jeoc: u1,
        jstrt: u1,
        strt: u1,
        ovr: u1,
        _0: u26,
    },
    cr1: *volatile packed struct(u32) {
        awdch: u5,
        eocie: u1,
        awdie: u1,
        jeocie: u1,
        scan: u1,
        awdSgl: u1,
        jauto: u1,
        discen: u1,
        jdiscen: u1,
        discnum: u3,
        _0: u6,
        jawden: u1,
        awden: u1,
        res: enum(u2) {
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
        },
        ovrie: u1,
        _1: u5,
    },
    cr2: *volatile packed struct(u32) {
        adon: u1,
        cont: u1,
        _0: u6,
        dma: u1,
        dds: u1,
        eocs: u1,
        @"align": u1,
        _1: u4,
        jextsel: u4,
        jexten: u2,
        jswstart: u1,
        _2: u1,
        extsel: u4,
        exten: u2,
        swstart: u1,
        _3: u1,
    },
    smpr1: *volatile packed struct(u32) {
        smp10: SampleTime,
        smp11: SampleTime,
        smp12: SampleTime,
        smp13: SampleTime,
        smp14: SampleTime,
        smp15: SampleTime,
        smp16: SampleTime,
        smp17: SampleTime,
        smp18: SampleTime,
        _0: u5,
    },
    smpr2: *volatile packed struct(u32) {
        smp0: SampleTime,
        smp1: SampleTime,
        smp2: SampleTime,
        smp3: SampleTime,
        smp4: SampleTime,
        smp5: SampleTime,
        smp6: SampleTime,
        smp7: SampleTime,
        smp8: SampleTime,
        smp9: SampleTime,
        _0: u2,
    },
    sqr1: *volatile packed struct(u32) {
        sq13: u5,
        sq14: u5,
        sq15: u5,
        sq16: u5,
        l: u4,
        _0: u8,
    },
    sqr2: *volatile packed struct(u32) {
        sq7: u5,
        sq8: u5,
        sq9: u5,
        sq10: u5,
        sq11: u5,
        sq12: u5,
        _0: u2,
    },
    sqr3: *volatile packed struct(u32) {
        sq1: u5,
        sq2: u5,
        sq3: u5,
        sq4: u5,
        sq5: u5,
        sq6: u5,
        _0: u2,
    },

    dr: *volatile u16,

    const SampleTime = enum(u3) {
        @"3Cycles" = 0b000,
        @"15Cycles" = 0b001,
        @"28Cycles" = 0b010,
        @"56Cycles" = 0b011,
        @"84Cycles" = 0b100,
        @"112Cycles" = 0b101,
        @"144Cycles" = 0b110,
        @"480Cycles" = 0b111,
    };

    pub fn init(self: @This()) void {
        self.cr2.adon = 1; // Enable ADC
    }

    pub fn convert(self: @This(), channel: u5) f32 {
        self.sqr3.sq1 = channel;

        const sampleTime = SampleTime.@"480Cycles";
        switch (channel) {
            0 => self.smpr2.smp0 = sampleTime,
            1 => self.smpr2.smp1 = sampleTime,
            2 => self.smpr2.smp2 = sampleTime,
            3 => self.smpr2.smp3 = sampleTime,
            4 => self.smpr2.smp4 = sampleTime,
            5 => self.smpr2.smp5 = sampleTime,
            6 => self.smpr2.smp6 = sampleTime,
            7 => self.smpr2.smp7 = sampleTime,
            8 => self.smpr2.smp8 = sampleTime,
            9 => self.smpr2.smp9 = sampleTime,
            10 => self.smpr1.smp10 = sampleTime,
            11 => self.smpr1.smp11 = sampleTime,
            12 => self.smpr1.smp12 = sampleTime,
            13 => self.smpr1.smp13 = sampleTime,
            14 => self.smpr1.smp14 = sampleTime,
            15 => self.smpr1.smp15 = sampleTime,
            16 => self.smpr1.smp16 = sampleTime,
            17 => self.smpr1.smp17 = sampleTime,
            18 => self.smpr1.smp18 = sampleTime,
            else => @panic("Invalid ADC channel"),
        }

        const resolution: @TypeOf(self.cr1.res) = .@"12Bits";

        self.cr1.res = resolution;
        self.cr2.cont = 0; // Single conversion mode
        self.sqr1.l = 0; // 1 conversion

        self.cr2.swstart = 1;

        while (self.sr.eoc == 0) {
            // wait for conversion to complete
        }

        const data: f32 = @floatFromInt(self.dr.*);

        // convert raw ADC value to voltage
        const vref = 3.3; // Reference voltage
        const maxValue = resolution.maxValue();
        const voltage = (data / maxValue) * vref;

        return voltage;
    }
};

pub const Common = struct {
    ccr: *volatile packed struct(u32) {
        multi: u5,
        _0: u3,
        delay: u4,
        _1: u1,
        dds: u1,
        dma: u2,
        adcpre: u2,
        _2: u4,
        vbate: u1,
        tsvrefe: u1,
        _3: u8,
    },

    pub fn enableTemperatureSensor(self: @This()) void {
        self.ccr.tsvrefe = 1; // Enable temperature sensor
    }
};

pub fn MakeAdc(baseAddress: [*]align(4) volatile u8) Adc {
    return Adc{
        .sr = @ptrCast(baseAddress + 0x00),
        .cr1 = @ptrCast(baseAddress + 0x04),
        .cr2 = @ptrCast(baseAddress + 0x08),
        .smpr1 = @ptrCast(baseAddress + 0x0C),
        .smpr2 = @ptrCast(baseAddress + 0x10),

        .sqr1 = @ptrCast(baseAddress + 0x2C),
        .sqr2 = @ptrCast(baseAddress + 0x30),
        .sqr3 = @ptrCast(baseAddress + 0x34),

        .dr = @ptrCast(baseAddress + 0x4C),
    };
}

pub fn MakeCommon(baseAddress: [*]align(4) volatile u8) Common {
    return Common{
        .ccr = @ptrCast(baseAddress + 0x04),
    };
}
