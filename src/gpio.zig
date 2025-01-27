const std = @import("std");

fn Gpio(comptime baseAddress: [*]volatile u32) type {
    return struct {
        const Self = @This();

        modeRegister: *volatile u32 = @ptrCast(&baseAddress[0]),
        outputTypeRegister: *volatile u32 = @ptrCast(&baseAddress[1]),
        outputSpeedRegister: *volatile u32 = @ptrCast(&baseAddress[2]),
        pullRegister: *volatile u32 = @ptrCast(&baseAddress[3]),
        inputDataRegister: *volatile u32 = @ptrCast(&baseAddress[4]),
        outputDataRegister: *volatile u32 = @ptrCast(&baseAddress[5]),
        bitSetResetRegister: *volatile u32 = @ptrCast(&baseAddress[6]),
        lockRegister: *volatile u32 = @ptrCast(&baseAddress[7]),
        alternateFunctionLowRegister: *volatile u32 = @ptrCast(&baseAddress[8]),
        alternateFunctionHighRegister: *volatile u32 = @ptrCast(&baseAddress[9]),
        bitResetRegister: *volatile u32 = @ptrCast(&baseAddress[10]),

        const PinMode = enum(u2) {
            Input = 0b00,
            Output = 0b01,
            AlternateFunction = 0b10,
            Analog = 0b11,
        };

        const OutputType = enum(u1) {
            PushPull = 0,
            OpenDrain = 1,
        };

        const OutputSpeed = enum(u2) {
            Low = 0b00,
            Medium = 0b01,
            High = 0b11,
        };

        const PullMode = enum(u2) {
            NoPull = 0b00,
            PullUp = 0b01,
            PullDown = 0b10,
        };

        const AlternateFunction = enum(u4) {
            AF0 = 0b0000,
            AF1 = 0b0001,
            AF2 = 0b0010,
            AF3 = 0b0011,
            AF4 = 0b0100,
            AF5 = 0b0101,
            AF6 = 0b0110,
            AF7 = 0b0111,
        };

        fn setBitmask32(comptime T: type, register: *volatile u32, shift: u4, value: T) void {
            const shiftAmount = shift * @bitSizeOf(T);
            const maxValue: u32 = (1 << @bitSizeOf(T)) - 1;
            const realValue = switch (@typeInfo(T)) {
                .Int => |_| value,
                .Enum => |_| @intFromEnum(value),
                else => @compileError("unsupported type"),
            };
            register.* = (register.* & ~(maxValue << shiftAmount)) | (@as(u32, realValue) << shiftAmount);
        }

        pub fn setMode(self: @This(), pin: u4, mode: PinMode) void {
            Self.setBitmask32(PinMode, self.modeRegister, pin, mode);
        }

        pub fn setOutputType(self: @This(), pin: u4, output_type: OutputType) void {
            Self.setBitmask32(OutputType, self.outputTypeRegister, pin, output_type);
        }

        pub fn setOutputSpeed(self: @This(), pin: u4, output_speed: OutputSpeed) void {
            Self.setBitmask32(OutputSpeed, self.outputSpeedRegister, pin, output_speed);
        }

        pub fn setPullMode(self: @This(), pin: u4, pull_mode: PullMode) void {
            Self.setBitmask32(PullMode, self.pullRegister, pin, pull_mode);
        }

        pub fn setAlternateFunction(self: @This(), pin: u4, f: AlternateFunction) void {
            if (pin < 8) {
                Self.setBitmask32(AlternateFunction, self.alternateFunctionLowRegister, pin, f);
            } else {
                Self.setBitmask32(AlternateFunction, self.alternateFunctionHighRegister, pin - 8, f);
            }
        }

        pub fn setLevel(self: @This(), pin: u4, level: u1) void {
            if (level == 1) {
                Self.setBitmask32(u1, self.bitSetResetRegister, pin, 1);
            } else {
                Self.setBitmask32(u1, self.bitResetRegister, pin, 1);
            }
        }

        pub fn getLevel(self: @This(), pin: u4) u1 {
            return @truncate((self.outputDataRegister.* >> pin) & 1);
        }
    };
}

pub const GPIOA = Gpio(@ptrFromInt(0x48000000)){};
pub const GPIOB = Gpio(@ptrFromInt(0x48000400)){};
pub const GPIOC = Gpio(@ptrFromInt(0x48000800)){};
pub const GPIOD = Gpio(@ptrFromInt(0x48000C00)){};
pub const GPIOF = Gpio(@ptrFromInt(0x48001400)){};
