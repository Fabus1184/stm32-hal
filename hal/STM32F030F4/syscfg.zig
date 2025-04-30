const Register = @import("../register.zig").Register;

pub fn Syscfg(comptime baseAddress: [*]align(4) volatile u32) type {
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

        /// Configuration register 1
        cfgr1: Register(packed struct(u32) { _: u32 }) = .{ .ptr = @ptrCast(&baseAddress[0x00]) },
        exticr1: Register(packed struct(u32) { exti0: gpioBank, exti1: gpioBank, exti2: gpioBank, exti3: gpioBank, _0: u16 }) = .{ .ptr = @ptrCast(&baseAddress[0x1]) },
        exticr2: Register(packed struct(u32) { exti4: gpioBank, exti5: gpioBank, exti6: gpioBank, exti7: gpioBank, _0: u16 }) = .{ .ptr = @ptrCast(&baseAddress[0xC]) },
        exticr3: Register(packed struct(u32) { exti8: gpioBank, exti9: gpioBank, exti10: gpioBank, exti11: gpioBank, _0: u16 }) = .{ .ptr = @ptrCast(&baseAddress[0x10]) },
        exticr4: Register(packed struct(u32) { exti12: gpioBank, exti13: gpioBank, exti14: gpioBank, exti15: gpioBank, _0: u16 }) = .{ .ptr = @ptrCast(&baseAddress[0x14]) },
        /// Configuration register 2
        cfgr2: Register(packed struct(u32) { _: u32 }) = .{ .ptr = @ptrCast(&baseAddress[0x18]) },
    };
}
