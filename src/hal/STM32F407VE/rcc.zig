const ControlRegister = packed struct(u32) {
    hsiOn: bool,
    hsiRdy: bool,
    _0: u1,
    hsiTrim: u5,
    hsiCal: u8,
    hseOn: bool,
    hseRdy: bool,
    hseByp: bool,
    cssOn: bool,
    _1: u4,
    pllOn: bool,
    pllRdy: bool,
    pllI2sOn: bool,
    pllI2sRdy: bool,
    _2: u4,
};
const PllConfigRegister = packed struct(u32) {
    /// Division factor for the main PLL and audio PLL (PLLI2S) input clock
    pllM: u6,
    /// Main PLL multiplication factor for VCO
    pllN: u9,
    _0: u1,
    /// Main PLL division factor for main system clock
    pllP: enum(u2) {
        div2 = 0b00,
        div4 = 0b01,
        div6 = 0b10,
        div8 = 0b11,

        fn value(self: @This()) u32 {
            return switch (self) {
                .div2 => 2,
                .div4 => 4,
                .div6 => 6,
                .div8 => 8,
            };
        }
    },
    _1: u4,
    /// Main PLL and audio PLL (PLLI2S) entry clock source
    pllSrc: enum(u1) {
        hsi = 0,
        hse = 1,
    },
    _2: u1,
    /// Main PLL division factor for USB OTG FS, SDIO and random number generator clocks
    pllQ: u4,
    _3: u4,
};
const ConfigRegister = packed struct(u32) {
    /// System clock switch
    sw: enum(u2) {
        hsi = 0,
        hse = 1,
        pll = 2,
        _, // not allowed
    },
    /// System clock switch status
    sws: enum(u2) {
        hsi = 0,
        hse = 1,
        pll = 2,
        _, // not allowed
    },
    /// AHB prescaler
    hpre: enum(u4) {
        notDivided = 0b0000,
        div2 = 0b1000,
        div4 = 0b1001,
        div8 = 0b1010,
        div16 = 0b1011,
        div64 = 0b1100,
        div128 = 0b1101,
        div256 = 0b1110,
        div512 = 0b1111,
        _, // not divided

        fn value(self: @This()) u32 {
            return switch (self) {
                .notDivided => 1,
                .div2 => 2,
                .div4 => 4,
                .div8 => 8,
                .div16 => 16,
                .div64 => 64,
                .div128 => 128,
                .div256 => 256,
                .div512 => 512,
                _ => 1,
            };
        }
    },
    _0: u2,
    /// APB Low speed prescaler (APB1)
    ppre1: enum(u3) {
        notDivided = 0b000,
        div2 = 0b100,
        div4 = 0b101,
        div8 = 0b110,
        div16 = 0b111,
        _, // not divided

        fn value(self: @This()) u32 {
            return switch (self) {
                .notDivided => 1,
                .div2 => 2,
                .div4 => 4,
                .div8 => 8,
                .div16 => 16,
                _ => 1,
            };
        }
    },
    /// APB High speed prescaler (APB2)
    ppre2: enum(u3) {
        notDivided = 0b000,
        div2 = 0b100,
        div4 = 0b101,
        div8 = 0b110,
        div16 = 0b111,
        _, // not divided

        fn value(self: @This()) u32 {
            return switch (self) {
                .notDivided => 1,
                .div2 => 2,
                .div4 => 4,
                .div8 => 8,
                .div16 => 16,
                _ => 1,
            };
        }
    },
    /// HSE division factor for RTC clock
    rtcpre: u5,
    /// Microcontroller clock output 1
    mco1: enum(u2) {
        hsi = 0b00,
        lse = 0b01,
        hse = 0b10,
        pll = 0b11,
    },
    /// I2S clock selection
    i2sSrc: u1,
    /// Microcontroller clock output 1 prescaler
    mco1Pre: enum(u3) {
        notDivided = 0b000,
        div2 = 0b100,
        div3 = 0b101,
        div4 = 0b110,
        div5 = 0b111,
        _,
    },
    /// Microcontroller clock output 2 prescaler
    mco2Pre: enum(u3) {
        notDivided = 0b000,
        div2 = 0b100,
        div3 = 0b101,
        div4 = 0b110,
        div5 = 0b111,
        _,
    },
    /// Microcontroller clock output 2
    mco2: enum(u2) {
        sysclk = 0b00,
        plli2s = 0b01,
        hse = 0b10,
        pll = 0b11,
    },
};
const ClockInterruptRegister = packed struct(u32) {
    lsiRdyF: u1,
    lseRdyF: u1,
    hsiRdyF: u1,
    hseRdyF: u1,
    pllRdyF: u1,
    pllI2sRdyF: u1,
    _0: u1,
    cssF: u1,
    lsiRdyIE: u1,
    lseRdyIE: u1,
    hsiRdyIE: u1,
    hseRdyIE: u1,
    pllRdyIE: u1,
    pllI2sRdyIE: u1,
    _1: u2,
    lsiRdyC: u1,
    lseRdyC: u1,
    hsiRdyC: u1,
    hseRdyC: u1,
    pllRdyC: u1,
    pllI2sRdyC: u1,
    _2: u1,
    cssC: u1,
    _3: u8,
};
const AHB1ResetRegister = packed struct(u32) {
    gpioARst: u1,
    gpioBRst: u1,
    gpioCRst: u1,
    gpioDRst: u1,
    gpioERst: u1,
    gpioFRst: u1,
    gpioGRst: u1,
    gpioHRst: u1,
    gpioIRst: u1,
    _0: u3,
    crcRst: u1,
    _1: u8,
    dma1Rst: u1,
    dma2Rst: u1,
    _2: u2,
    ethMacRst: u1,
    _3: u3,
    otgHsRst: u1,
    _4: u2,
};
const AHB2ResetRegister = packed struct(u32) {
    dcmiRst: u1,
    _0: u3,
    crypRst: u1,
    hashRst: u1,
    rngRst: u1,
    otgFsRst: u1,
    _1: u24,
};
const AHB3ResetRegister = packed struct(u32) {
    fsmcRst: u1,
    _0: u31,
};

const APB1ResetRegister = packed struct(u32) {
    tim2Rst: u1,
    tim3Rst: u1,
    tim4Rst: u1,
    tim5Rst: u1,
    tim6Rst: u1,
    tim7Rst: u1,
    tim12Rst: u1,
    tim13Rst: u1,
    tim14Rst: u1,
    _0: u2,
    wwdgRst: u1,
    _1: u2,
    spi2Rst: u1,
    spi3Rst: u1,
    _2: u1,
    uart2Rst: u1,
    uart3Rst: u1,
    uart4Rst: u1,
    uart5Rst: u1,
    i2c1Rst: u1,
    i2c2Rst: u1,
    i2c3Rst: u1,
    _3: u1,
    can1Rst: u1,
    can2Rst: u1,
    _4: u1,
    pwrRst: u1,
    dacRst: u1,
    _5: u2,
};
const APB2ResetRegister = packed struct(u32) {
    tim1Rst: u1,
    tim8Rst: u1,
    _0: u2,
    usart1Rst: u1,
    usart6Rst: u1,
    _1: u2,
    adcRst: u1,
    _2: u2,
    sdioRst: u1,
    spi1Rst: u1,
    _3: u1,
    syscfgRst: u1,
    _4: u1,
    tim9Rst: u1,
    tim10Rst: u1,
    tim11Rst: u1,
    _5: u13,
};
const AHB1EnableRegister = packed struct(u32) {
    gpioAEn: bool,
    gpioBEn: bool,
    gpioCEn: bool,
    gpioDEn: bool,
    gpioEEn: bool,
    gpioFEn: bool,
    gpioGEn: bool,
    gpioHEn: bool,
    gpioIEn: bool,
    _0: u3,
    crcEn: bool,
    _1: u5,
    bkpSramEn: bool,
    _2: u1,
    ccmDataRamEn: bool,
    dma1En: bool,
    dma2En: bool,
    _3: u2,
    ethMacEn: bool,
    ethMacTxEn: bool,
    ethMacRxEn: bool,
    ethMacPtpEn: bool,
    otgHsEn: bool,
    otgHsUlpiEn: bool,
    _4: u1,
};
const AHB2EnableRegister = packed struct(u32) {
    dcmiEn: bool,
    _0: u3,
    crypEn: bool,
    hashEn: bool,
    rngEn: bool,
    otgFsEn: bool,
    _1: u24,
};
const AHB3EnableRegister = packed struct(u32) {
    fsmcEn: bool,
    _0: u31,
};

const APB1EnableRegister = packed struct(u32) {
    tim2En: bool,
    tim3En: bool,
    tim4En: bool,
    tim5En: bool,
    tim6En: bool,
    tim7En: bool,
    tim12En: bool,
    tim13En: bool,
    tim14En: bool,
    _0: u2,
    wwdgEn: bool,
    _1: u2,
    spi2En: bool,
    spi3En: bool,
    _2: u1,
    usart2En: bool,
    usart3En: bool,
    usart4En: bool,
    usart5En: bool,
    i2c1En: bool,
    i2c2En: bool,
    i2c3En: bool,
    _3: u1,
    can1En: bool,
    can2En: bool,
    _4: u1,
    pwrEn: bool,
    dacEn: bool,
    _5: u2,
};
const APB2EnableRegister = packed struct(u32) {
    tim1En: bool,
    tim8En: bool,
    _0: u2,
    usart1En: bool,
    usart6En: bool,
    _1: u2,
    adc1En: bool,
    adc2En: bool,
    adc3En: bool,
    sdioEn: bool,
    spi1En: bool,
    _2: u1,
    syscfgEn: bool,
    _3: u1,
    tim9En: bool,
    tim10En: bool,
    tim11En: bool,
    _4: u13,
};
const AHB1LowPowerEnableRegister = packed struct(u32) {
    gpioALpEn: bool,
    gpioBLpEn: bool,
    gpioCLpEn: bool,
    gpioDLpEn: bool,
    gpioELpEn: bool,
    gpioFLpEn: bool,
    gpioGLpEn: bool,
    gpioHLpEn: bool,
    gpioILpEn: bool,
    _0: u3,
    crcLpEn: bool,
    _1: u2,
    flitfLpEn: bool,
    sram1LpEn: bool,
    sram2LpEn: bool,
    bkpSramLpEn: bool,
    _2: u2,
    dma1LpEn: bool,
    dma2LpEn: bool,
    _3: u2,
    ethMacLpEn: bool,
    ethMacTxLpEn: bool,
    ethMacRxLpEn: bool,
    ethMacPtpLpEn: bool,
    otgHsLpEn: bool,
    otgHsUlpiLpEn: bool,
    _4: u1,
};
const AHB2LowPowerEnableRegister = packed struct(u32) {
    dcmiLpEn: bool,
    _0: u3,
    crypLpEn: bool,
    hashLpEn: bool,
    rngLpEn: bool,
    otgFsLpEn: bool,
    _1: u24,
};
const AHB3LowPowerEnableRegister = packed struct(u32) {
    fsmcLpEn: bool,
    _0: u31,
};

const APB1LowPowerEnableRegister = packed struct(u32) {
    tim2LpEn: bool,
    tim3LpEn: bool,
    tim4LpEn: bool,
    tim5LpEn: bool,
    tim6LpEn: bool,
    tim7LpEn: bool,
    tim12LpEn: bool,
    tim13LpEn: bool,
    tim14LpEn: bool,
    _0: u2,
    wwdgLpEn: bool,
    _1: u2,
    spi2LpEn: bool,
    spi3LpEn: bool,
    _2: u1,
    usart2LpEn: bool,
    usart3LpEn: bool,
    usart4LpEn: bool,
    usart5LpEn: bool,
    i2c1LpEn: bool,
    i2c2LpEn: bool,
    i2c3LpEn: bool,
    _3: u1,
    can1LpEn: bool,
    can2LpEn: bool,
    _4: u1,
    pwrLpEn: bool,
    dacLpEn: bool,
    _5: u2,
};
const APB2LowPowerEnableRegister = packed struct(u32) {
    tim1LpEn: bool,
    tim8LpEn: bool,
    _0: u2,
    usart1LpEn: bool,
    usart6LpEn: bool,
    _1: u2,
    adc1LpEn: bool,
    adc2LpEn: bool,
    adc3LpEn: bool,
    sdioLpEn: bool,
    spi1LpEn: bool,
    _2: u1,
    syscfgLpEn: bool,
    _3: u1,
    tim9LpEn: bool,
    tim10LpEn: bool,
    tim11LpEn: bool,
    _4: u13,
};

const BdcRegister = packed struct(u32) {
    lseOn: u1,
    lseRdy: u1,
    lseByp: u1,
    _0: u5,
    rtcSel: enum(u2) {
        noClock = 0b00,
        lse = 0b01,
        lsi = 0b10,
        hseDivided = 0b11,
    },
    _1: u5,
    rtcEn: bool,
    bdRst: u1,
    _2: u15,
};

const ClockSelectRegister = packed struct(u32) {
    lsiOn: u1,
    lsiRdy: u1,
    _0: u22,
    rmvF: u1,
    borRstF: u1,
    padRstF: u1,
    porRstF: u1,
    sftRstF: u1,
    wdgRstF: u1,
    wwdgRstF: u1,
    lpwrRstF: u1,
};

const Sscgr = packed struct(u32) {
    modPer: u13,
    incStep: u15,
    _0: u2,
    spreadSel: u1,
    sscgEn: bool,
};
const PllI2sConfigRegister = packed struct(u32) {
    _0: u6,
    pllI2sN: u9,
    _1: u13,
    pllI2sRx: u3,
    _2: u1,
};

/// Reset and clock control
pub fn Rcc(
    comptime baseAddress: [*]align(4) volatile u8,
    /// Internal high-speed clock frequency
    HSI_FREQ: u32,
    /// Internal low-speed clock frequency
    LSI_FREQ: u32,
    /// External high-speed clock frequency
    HSE_FREQ: u32,
    /// External low-speed clock frequency
    LSE_FREQ: u32,
) type {
    return struct {
        cr: *volatile ControlRegister = @ptrCast(&baseAddress[0x00]),
        pllcgfr: *volatile PllConfigRegister = @ptrCast(&baseAddress[0x04]),
        cfgr: *volatile ConfigRegister = @ptrCast(&baseAddress[0x08]),
        cir: *volatile ClockInterruptRegister = @ptrCast(&baseAddress[0x0C]),
        ahb1rstr: *volatile AHB1ResetRegister = @ptrCast(&baseAddress[0x10]),
        ahb2rstr: *volatile AHB2ResetRegister = @ptrCast(&baseAddress[0x14]),
        ahb3rstr: *volatile AHB3ResetRegister = @ptrCast(&baseAddress[0x18]),
        // reserved
        apb1rstr: *volatile APB1ResetRegister = @ptrCast(&baseAddress[0x20]),
        apb2rstr: *volatile APB2ResetRegister = @ptrCast(&baseAddress[0x24]),
        // reserved
        // reserved
        ahb1enr: *volatile AHB1EnableRegister = @ptrCast(&baseAddress[0x30]),
        ahb2enr: *volatile AHB2EnableRegister = @ptrCast(&baseAddress[0x34]),
        ahb3enr: *volatile AHB3EnableRegister = @ptrCast(&baseAddress[0x38]),
        // reserved
        apb1enr: *volatile APB1EnableRegister = @ptrCast(&baseAddress[0x40]),
        apb2enr: *volatile APB2EnableRegister = @ptrCast(&baseAddress[0x44]),
        // reserved
        // reserved
        ahb1lpenr: *volatile AHB1LowPowerEnableRegister = @ptrCast(&baseAddress[0x50]),
        ahb2lpenr: *volatile AHB2LowPowerEnableRegister = @ptrCast(&baseAddress[0x54]),
        ahb3lpenr: *volatile AHB3LowPowerEnableRegister = @ptrCast(&baseAddress[0x58]),
        // reserved
        apb1lpenr: *volatile APB1LowPowerEnableRegister = @ptrCast(&baseAddress[0x60]),
        apb2lpenr: *volatile APB2LowPowerEnableRegister = @ptrCast(&baseAddress[0x64]),
        // reserved
        // reserved
        bdcr: *volatile BdcRegister = @ptrCast(&baseAddress[0x70]),
        csr: *volatile ClockSelectRegister = @ptrCast(&baseAddress[0x74]),
        // reserved
        // reserved
        sscgr: *volatile Sscgr = @ptrCast(&baseAddress[0x80]),
        plli2scfgr: *volatile PllI2sConfigRegister = @ptrCast(&baseAddress[0x84]),

        const std = @import("std");

        pub fn pllClock(self: @This()) struct { pClock: u32, qClock: u32 } {
            const pllSrc: u64 = switch (self.pllcgfr.pllSrc) {
                .hsi => HSI_FREQ,
                .hse => HSE_FREQ,
            };

            const fVco: u64 = (pllSrc * @as(u64, self.pllcgfr.pllN)) / @as(u64, self.pllcgfr.pllM);

            return .{
                .pClock = @intCast(fVco / @as(u64, self.pllcgfr.pllP.value())),
                .qClock = @intCast(fVco / @as(u64, self.pllcgfr.pllQ)),
            };
        }

        pub fn ahbClock(self: @This()) u32 {
            return switch (self.cfgr.sws) {
                .hse => HSE_FREQ,
                .hsi => HSI_FREQ,
                .pll => self.pllClock().pClock,
                _ => 0,
            } / self.cfgr.hpre.value();
        }

        pub fn apb1Clock(self: @This()) u32 {
            return self.ahbClock() / self.cfgr.ppre1.value();
        }

        pub fn apb2Clock(self: @This()) u32 {
            return self.ahbClock() / self.cfgr.ppre2.value();
        }

        pub fn rtcClock(self: @This()) u32 {
            return switch (self.bdcr.rtcSel) {
                .noClock => 0,
                .lse => LSE_FREQ,
                .lsi => LSI_FREQ,
                .hseDivided => HSE_FREQ / @as(u32, self.cfgr.rtcpre),
            };
        }

        pub fn systemClock(self: @This()) u32 {
            return switch (self.cfgr.sws) {
                .hse => HSE_FREQ,
                .hsi => HSI_FREQ,
                .pll => self.pllClock().pClock,
                _ => 0,
            };
        }

        pub fn clocks(self: @This()) struct {
            ahb: u32,
            pll: @TypeOf(self.pllClock()),
            apb1: u32,
            apb2: u32,
            rtc: u32,
            system: u32,

            pub fn format(
                _self: @This(),
                comptime _: []const u8,
                _: anytype,
                writer: anytype,
            ) !void {
                try writer.print("AHB: {}, PLLp: {}, PLLq: {}, APB1: {}, APB2: {}, RTC: {}, System: {}", .{
                    _self.ahb,
                    _self.pll.pClock,
                    _self.pll.qClock,
                    _self.apb1,
                    _self.apb2,
                    _self.rtc,
                    _self.system,
                });
            }
        } {
            return .{
                .ahb = self.ahbClock(),
                .apb1 = self.apb1Clock(),
                .apb2 = self.apb2Clock(),
                .pll = self.pllClock(),
                .rtc = self.rtcClock(),
                .system = self.systemClock(),
            };
        }

        pub fn configurePll(self: @This(), src: @TypeOf(self.pllcgfr.pllSrc), m: u6, n: u9, p: @TypeOf(self.pllcgfr.pllP), q: u4) void {
            self.pllcgfr.pllSrc = src;
            self.pllcgfr.pllM = m;
            self.pllcgfr.pllN = n;
            self.pllcgfr.pllP = p;
            self.pllcgfr.pllQ = q;

            self.cr.pllOn = true;

            std.log.debug("waiting for PLL to stabilize", .{});
            while (!self.cr.pllRdy) {}
        }
    };
}
