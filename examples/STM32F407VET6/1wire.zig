const std = @import("std");

const hal = @import("hal").STM32F407VE;

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = hal.utils.logFn(hal.USART1.writer(), .{}),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

// 1-Wire protocol
const OneWire = struct {
    gpio: hal.gpio.Gpio,
    pin: u4,

    pub fn init(gpio: hal.gpio.Gpio, pin: u4) OneWire {
        var ow = OneWire{
            .gpio = gpio,
            .pin = pin,
        };

        _ = ow.asInput();

        return ow;
    }

    fn asOutput(self: @This()) hal.gpio.OutputPin {
        return self.gpio.setupOutput(self.pin, .{
            .level = 1,
            .outputSpeed = .VeryHigh,
        });
    }

    fn asInput(self: @This()) hal.gpio.InputPin {
        return self.gpio.setupInput(self.pin, .{
            .pullMode = .PullUp,
        });
    }

    pub fn reset(self: OneWire) bool {
        const o = self.asOutput();

        o.setLevel(0);
        hal.utils.delayMicros(500);

        const i = self.asInput();

        hal.utils.delayMicros(70);

        const presence = i.getLevel() == 0; // Check if the device pulls the line low
        hal.utils.delayMicros(500); // Wait for the rest of the time

        return presence;
    }

    pub fn writeByte(self: OneWire, byte: u8) void {
        for ([_]u32{ 1, 2, 5, 10, 100, 200 }) |n| {
            for (0..10) |_| {
                hal.utils.delayMicros(n);
                DEBUG_PIN.toggleLevel();
            }

            hal.utils.delayMicros(200);
        }

        const o = self.asOutput();

        for (0..8) |i| {
            DEBUG_PIN.toggleLevel();

            o.setLevel(0);
            hal.utils.delayMicros(5);

            if (byte & (@as(u8, 1) << @intCast(i)) != 0) {
                o.setLevel(1); // Write 1
            }

            hal.utils.delayMicros(60); // Wait for 60us

            o.setLevel(1); // Release the line

            hal.utils.delayMicros(10);
        }

        _ = self.asInput(); // Switch back to input mode

    }

    pub fn readByte(self: OneWire) u8 {
        var byte: u8 = 0;
        for (0..8) |i| {
            const o = self.asOutput();

            o.setLevel(0);
            hal.utils.delayMicros(5); // Start bit

            const in = self.asInput();

            hal.utils.delayMicros(5); // Wait for the device to pull the line low

            DEBUG_PIN.toggleLevel();
            if (in.getLevel() == 1) {
                byte |= (@as(u8, 1) << @intCast(i)); // Read bit
            }

            hal.utils.delayMicros(50); // Wait for the rest of the time

            o.setLevel(1); // Release the line

            hal.utils.delayMicros(5);
        }

        return byte;
    }
};

var DEBUG_PIN: hal.gpio.OutputPin = undefined;

export fn main() noreturn {
    @setRuntimeSafety(true);

    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioAEn = true;
    hal.RCC.ahb1enr.gpioEEn = true;

    hal.core.DEBUG.cr.trcena = true;
    hal.core.DWT.enableCycleCounter();

    hal.RCC.apb2enr.usart1En = true;
    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh }); // USART1 TX
    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);

    // clear screen
    hal.USART1.send("\x1b[2J\x1b[H");
    std.log.info("1-Wire Example", .{});
    std.log.info("clocks: {}", .{hal.RCC.clocks()});

    hal.RCC.cr.hseOn = true;
    std.log.debug("waiting for HSE to stabilize", .{});
    while (!hal.RCC.cr.hseRdy) {}
    hal.RCC.cr.hsiOn = true;
    std.log.debug("waiting for HSI to stabilize", .{});
    while (!hal.RCC.cr.hsiRdy) {}

    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    // configure PLL
    hal.RCC.configurePll(.hse, 8, 336, .div2, 7);

    std.log.debug("PLL stabilized, switching to PLL", .{});
    hal.FLASH.acr.latency = 5;
    hal.RCC.cfgr.sw = .pll;
    while (hal.RCC.cfgr.sws != .pll) {}

    hal.RCC.cfgr.hpre = .notDivided;
    hal.RCC.cfgr.ppre1 = .div4;
    hal.RCC.cfgr.ppre2 = .div2;

    hal.USART1.deinit();
    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);

    std.log.info("clocks: {}", .{hal.RCC.clocks()});

    const led1 = hal.GPIOA.setupOutput(6, .{});
    const led2 = hal.GPIOA.setupOutput(7, .{});

    DEBUG_PIN = hal.GPIOE.setupOutput(14, .{ .level = 0, .outputSpeed = .VeryHigh });

    const ow = OneWire.init(hal.GPIOE, 4);

    const rom = [8]u8{ 0x28, 0x33, 0x86, 0x52, 0x5f, 0xe5, 0x78, 0xb6 };

    while (true) {
        hal.utils.delayMicros(1_000_000);

        led1.toggleLevel();
        led2.toggleLevel();

        if (!ow.reset()) {
            std.log.err("device not responding", .{});
            continue;
        }

        ow.writeByte(0x55); // Match ROM command
        for (rom) |b| ow.writeByte(b);

        ow.writeByte(0x44); // Convert T
        while (ow.readByte() == 0) {
            hal.utils.delayMicros(1000);
        }

        if (!ow.reset()) {
            std.log.err("device not responding", .{});
            continue;
        }

        ow.writeByte(0x55); // Match ROM command
        for (rom) |b| ow.writeByte(b);

        ow.writeByte(0xBE); // Read Scratchpad
        const lsb: u16 = @intCast(ow.readByte()); // Read LSB
        const msb: u16 = @intCast(ow.readByte()); // Read MSB
        const temperature = (msb << 8) | lsb; // Combine LSB
        std.log.info("{d:.4}°C", .{@as(f32, @floatFromInt(temperature)) * 0.0625});
    }
}
