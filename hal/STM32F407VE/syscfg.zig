pub fn Syscfg(comptime baseAddress: [*]align(4) volatile u8) type {
    return struct {
        const gpioBank = enum(u4) {
            A = 0b0000,
            B = 0b0001,
            C = 0b0010,
            D = 0b0011,
            E = 0b0100,
            F = 0b0101,
            G = 0b0110,
            H = 0b0111,
            I = 0b1000,
        };

        /// Memory remap register
        memrmp: *volatile packed struct(u32) {
            /// memory mapping selection
            memMode: enum(u2) {
                MainFlashAt0x0 = 0b0,
                SystemFlashAt0x0 = 0b1,
                FsmcBank1At0x0 = 0b10,
                EmbeddedSRAMAt0x0 = 0b11,
            },
            _0: u30,
        } = @ptrCast(&baseAddress[0x0]),
        /// Peripheral mode configuration register
        pmc: *volatile packed struct(u32) {
            _0: u23,
            /// Ethernet PHY interface selection
            miiRmiiSel: enum(u1) {
                MII = 0,
                RMII = 1,
            },
            _1: u8,
        } = @ptrCast(&baseAddress[0x4]),
        exticr1: *volatile packed struct(u32) { exti0: gpioBank, exti1: gpioBank, exti2: gpioBank, exti3: gpioBank, _0: u16 } = @ptrCast(&baseAddress[0x8]),
        exticr2: *volatile packed struct(u32) { exti4: gpioBank, exti5: gpioBank, exti6: gpioBank, exti7: gpioBank, _0: u16 } = @ptrCast(&baseAddress[0xC]),
        exticr3: *volatile packed struct(u32) { exti8: gpioBank, exti9: gpioBank, exti10: gpioBank, exti11: gpioBank, _0: u16 } = @ptrCast(&baseAddress[0x10]),
        exticr4: *volatile packed struct(u32) { exti12: gpioBank, exti13: gpioBank, exti14: gpioBank, exti15: gpioBank, _0: u16 } = @ptrCast(&baseAddress[0x14]),
        /// Compensation cell control register
        cmpcr: *volatile packed struct(u32) {
            /// Compensation cell power-down
            cmpPd: bool,
            _0: u6,
            /// Compensation cell ready flag
            ready: bool,
            _1: u24,
        } = @ptrCast(&baseAddress[0x20]),
    };
}
