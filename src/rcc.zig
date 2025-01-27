/// Reset and clock control
fn Rcc(comptime baseAddress: [*]volatile u32) type {
    return struct {
        /// Clock control register
        cr: *volatile u32 = @ptrCast(&baseAddress[0]),
        /// Clock configuration register
        cfgr: *volatile u32 = @ptrCast(&baseAddress[1]),
        /// Clock interrupt register
        cir: *volatile u32 = @ptrCast(&baseAddress[2]),
        /// APB peripheral reset register 2
        apb2rstr: *volatile u32 = @ptrCast(&baseAddress[3]),
        /// APB peripheral reset register 1
        apb1rstr: *volatile u32 = @ptrCast(&baseAddress[4]),
        /// AHB peripheral clock enable register
        ahbenr: *volatile packed struct(u32) { dmaen: bool, _: u1, sramen: bool, __: u1, flitfen: bool, ___: u1, crcen: bool, ____: u10, gpioaen: bool, gpioben: bool, gpiocen: bool, gpioden: bool, _____: u1, gpiofen: bool, ______: u9 } = @ptrCast(&baseAddress[5]),
        /// APB2 peripheral clock enable register
        apb2enr: *volatile packed struct(u32) { syscfgcompen: bool, _: u4, usart6en: bool, __: u3, adcen: bool, ___: u1, time1en: bool, spi1en: bool, ____: u1, usart1en: bool, _____: u1, tim15en: bool, tim16en: bool, tim17en: bool, ______: u3, dbgmcuen: bool, _______: u9 } = @ptrCast(&baseAddress[6]),
        /// APB1 peripheral clock enable register
        apb1enr: *volatile packed struct(u32) { _: u1, tim3en: bool, __: u2, tim6en: bool, tim7en: bool, ___: u2, tim14en: bool, ____: u2, wwdgen: bool, _____: u2, spi2en: bool, ______: u2, usart2en: bool, usart3en: bool, usart4en: bool, usart5en: bool, i2c1en: bool, i2c2en: bool, usb: bool, _______: u4, pwren: bool, ________: u3 } = @ptrCast(&baseAddress[7]),
        /// RTC domain control register
        bdcr: *volatile packed struct(u32) {
            lseon: bool,
            lserdy: bool,
            lsebyp: bool,
            lsedrv: u2,
            _: u3,
            rtcsel: u2,
            __: u5,
            rtcen: bool,
            bdrst: bool,
            ___: u15,
        } = @ptrCast(&baseAddress[8]),
        /// Control/status register
        csr: *volatile packed struct(u32) {
            lsion: bool,
            lsirdy: bool,
            __: u21,
            v18pwrrstf: bool,
            rmvf: bool,
            oblrstf: bool,
            pinrstf: bool,
            porrstf: bool,
            sftrstf: bool,
            iwdgrstf: bool,
            wwdgrstf: bool,
            lpwrrstf: bool,
        } = @ptrCast(&baseAddress[9]),
        /// AHB peripheral reset register
        ahbrstr: *volatile u32 = @ptrCast(&baseAddress[10]),
        /// Clock configuration register 2
        cfgr2: *volatile u32 = @ptrCast(&baseAddress[11]),
        /// Clock configuration register 3
        cfgr3: *volatile u32 = @ptrCast(&baseAddress[12]),
        /// Clock control register 2
        cr2: *volatile u32 = @ptrCast(&baseAddress[13]),
    };
}

pub const RCC = Rcc(@ptrFromInt(0x4002_1000)){};
