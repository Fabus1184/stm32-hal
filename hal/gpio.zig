pub const Gpio = struct {
    modeRegister: *volatile u32,
    outputTypeRegister: *volatile u32,
    outputSpeedRegister: *volatile u32,
    pullRegister: *volatile u32,
    inputDataRegister: *volatile u32,
    outputDataRegister: *volatile u32,
    bitSetResetRegister: *volatile u32,
    lockRegister: *volatile u32,
    alternateFunctionLowRegister: *volatile u32,
    alternateFunctionHighRegister: *volatile u32,
    bitResetRegister: *volatile u32,

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
        High = 0b10,
        VeryHigh = 0b11,
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

    inline fn setBitmask32(comptime T: type, register: *volatile u32, shift: u4, value: T) void {
        const shiftAmount: u5 = @as(u5, shift) * @bitSizeOf(T);
        const maxValue: u32 = (1 << @bitSizeOf(T)) - 1;
        const realValue: u32 = switch (@typeInfo(T)) {
            .int => |_| @intCast(value),
            .@"enum" => |_| @intFromEnum(value),
            else => @compileError("unsupported type"),
        };
        register.* = (register.* & ~(maxValue << shiftAmount)) | (realValue << shiftAmount);
    }

    inline fn setAlternateFunction(self: @This(), n: u4, f: AlternateFunction) void {
        if (n < 8) {
            setBitmask32(AlternateFunction, self.alternateFunctionLowRegister, n, f);
        } else {
            setBitmask32(AlternateFunction, self.alternateFunctionHighRegister, n - 8, f);
        }
    }

    pub fn setupOutput(
        self: @This(),
        pin: u4,
        setup: struct {
            outputType: Gpio.OutputType = Gpio.OutputType.PushPull,
            outputSpeed: Gpio.OutputSpeed = Gpio.OutputSpeed.Low,
            alternateFunction: ?Gpio.AlternateFunction = null,
            level: u1 = 0,
        },
    ) OutputPin {
        setBitmask32(Gpio.OutputType, self.outputTypeRegister, pin, setup.outputType);
        setBitmask32(Gpio.OutputSpeed, self.outputSpeedRegister, pin, setup.outputSpeed);

        if (setup.alternateFunction) |f| {
            self.setAlternateFunction(pin, f);
        }

        const outputPin = OutputPin{
            .pin = pin,
            .gpio = self,
        };

        outputPin.setLevel(setup.level);

        setBitmask32(
            Gpio.PinMode,
            self.modeRegister,
            pin,
            if (setup.alternateFunction) |_| Gpio.PinMode.AlternateFunction else Gpio.PinMode.Output,
        );

        return outputPin;
    }

    pub fn setupInput(
        self: @This(),
        pin: u4,
        setup: struct {
            pullMode: Gpio.PullMode = Gpio.PullMode.NoPull,
            alternateFunction: ?Gpio.AlternateFunction = null,
        },
    ) InputPin {
        setBitmask32(Gpio.PinMode, self.modeRegister, pin, if (setup.alternateFunction) |_| Gpio.PinMode.AlternateFunction else Gpio.PinMode.Input);
        setBitmask32(Gpio.PullMode, self.pullRegister, pin, setup.pullMode);

        if (setup.alternateFunction) |f| {
            self.setAlternateFunction(pin, f);
        }

        return InputPin{
            .pin = pin,
            .gpio = self,
        };
    }
};

pub fn MakeGpio(comptime baseAddress: [*]volatile u32) Gpio {
    return Gpio{
        .modeRegister = @ptrCast(&baseAddress[0]),
        .outputTypeRegister = @ptrCast(&baseAddress[1]),
        .outputSpeedRegister = @ptrCast(&baseAddress[2]),
        .pullRegister = @ptrCast(&baseAddress[3]),
        .inputDataRegister = @ptrCast(&baseAddress[4]),
        .outputDataRegister = @ptrCast(&baseAddress[5]),
        .bitSetResetRegister = @ptrCast(&baseAddress[6]),
        .lockRegister = @ptrCast(&baseAddress[7]),
        .alternateFunctionLowRegister = @ptrCast(&baseAddress[8]),
        .alternateFunctionHighRegister = @ptrCast(&baseAddress[9]),
        .bitResetRegister = @ptrCast(&baseAddress[10]),
    };
}

pub const InputPin = struct {
    pin: u4,
    gpio: Gpio,

    pub inline fn getLevel(self: @This()) u1 {
        return @truncate((self.gpio.inputDataRegister.* >> self.pin) & 1);
    }
};

pub const OutputPin = struct {
    pin: u4,
    gpio: Gpio,

    pub inline fn setLevel(self: @This(), level: u1) void {
        if (level == 1) {
            self.gpio.outputDataRegister.* |= @as(u32, 1) << self.pin;
        } else {
            self.gpio.outputDataRegister.* &= ~(@as(u32, 1) << self.pin);
        }
    }

    pub inline fn getLevel(self: @This()) u1 {
        return @truncate((self.gpio.inputDataRegister.* >> self.pin) & 1);
    }

    pub inline fn toggleLevel(self: @This()) void {
        self.setLevel(~self.getLevel());
    }
};
