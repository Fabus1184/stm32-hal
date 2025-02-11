pub fn Syscfg(comptime baseAddress: [*]align(4) volatile u8) type {
    return struct {
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
        exticr1: *volatile packed struct(u32) { exti0: u4, exti1: u4, exti2: u4, exti3: u4, _0: u16 } = @ptrCast(&baseAddress[0x8]),
        exticr2: *volatile packed struct(u32) { exti4: u4, exti5: u4, exti6: u4, exti7: u4, _0: u16 } = @ptrCast(&baseAddress[0xC]),
        exticr3: *volatile packed struct(u32) { exti8: u4, exti9: u4, exti10: u4, exti11: u4, _0: u16 } = @ptrCast(&baseAddress[0x10]),
        exticr4: *volatile packed struct(u32) { exti12: u4, exti13: u4, exti14: u4, exti15: u4, _0: u16 } = @ptrCast(&baseAddress[0x14]),
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
