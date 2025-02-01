pub fn Gpio(comptime baseAddress: [*]volatile u32) type {
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
            AF0 = 0,
            AF1 = 1,
            AF2 = 2,
            AF3 = 3,
            AF4 = 4,
            AF5 = 5,
            AF6 = 6,
            AF7 = 7,
            AF8 = 8,
            AF9 = 9,
            AF10 = 10,
            AF11 = 11,
            AF12 = 12,
            AF13 = 13,
            AF14 = 14,
            AF15 = 15,
        };

        fn setBitmask32(comptime T: type, register: *volatile u32, shift: u4, value: T) void {
            const shiftAmount: u5 = @as(u5, shift) * @bitSizeOf(T);
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

        pub fn setupOutputPin(self: @This(), pin: u4, output_type: OutputType, output_speed: OutputSpeed) void {
            self.setMode(pin, .Output);
            self.setOutputType(pin, output_type);
            self.setOutputSpeed(pin, output_speed);
        }

        pub fn setupInputPin(self: @This(), pin: u4, pull_mode: PullMode) void {
            self.setMode(pin, .Input);
            self.setPullMode(pin, pull_mode);
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
                self.outputDataRegister.* |= @as(u32, 1) << pin;
            } else {
                self.outputDataRegister.* &= ~(@as(u32, 1) << pin);
            }
        }

        pub fn getLevel(self: @This(), pin: u4) u1 {
            return @truncate((self.inputDataRegister.* >> pin) & 1);
        }

        pub fn toggle(self: @This(), pin: u4) void {
            self.setLevel(pin, ~self.getLevel(pin));
        }

        pub fn getAlternateFunction(self: @This(), pin: u4) AlternateFunction {
            if (pin < 8) {
                const value: u4 = @truncate(self.alternateFunctionLowRegister.* >> (pin * 4) & 0xF);
                return @enumFromInt(value);
            } else {
                const value: u4 = @truncate(self.alternateFunctionHighRegister.* >> ((pin - 8) * 4) & 0xF);
                return @enumFromInt(value);
            }
        }
    };
}
