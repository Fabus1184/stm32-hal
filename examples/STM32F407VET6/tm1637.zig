const std = @import("std");

const hal = @import("hal");

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = hal.utils.logFn(hal.USART1.writer(), .{}),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

const Digits = std.StaticStringMap(u8).initComptime(.{
    .{ "0", 0x3F },
    .{ "1", 0x06 },
    .{ "2", 0x5B },
    .{ "3", 0x4F },
    .{ "4", 0x66 },
    .{ "5", 0x6D },
    .{ "6", 0x7D },
    .{ "7", 0x07 },
    .{ "8", 0x7F },
    .{ "9", 0x6F },
    .{ "A", 0x77 },
    .{ "B", 0x7C },
    .{ "C", 0x39 },
    .{ "D", 0x5E },
    .{ "E", 0x79 },
    .{ "F", 0x71 },
});

const TM1637 = struct {
    clk: hal.gpio.OutputPin,
    dio: hal.gpio.OutputPin,

    const CMD_WRITE_AUTO: u8 = 0b01_00_0000;
    const CMD_DISPLAY_CTRL_ON: u8 = 0b10_00_1000 | 0b0000_0111; // Display ON, brightness max

    const delay: u32 = 10; // microseconds

    pub fn init(clk: hal.gpio.OutputPin, dio: hal.gpio.OutputPin) TM1637 {
        clk.setHigh();
        dio.setHigh();

        return TM1637{
            .clk = clk,
            .dio = dio,
        };
    }

    pub fn displayString(self: *TM1637, str: []const u8) void {
        for (str) |c| {
            const byte = Digits.get(&.{c}) orelse @panic("invalid digit");
            self.display(&[_]u8{byte});
        }
    }

    pub fn display(self: *TM1637, data: []const u8) void {
        self.start();

        self.writeByte(CMD_WRITE_AUTO); // write command with auto-increment address

        self.stop();
        self.start();

        self.writeByte(0xC0); // start address

        for (data) |b| {
            self.writeByte(b);
        }

        self.stop();
        self.start();

        self.writeByte(CMD_DISPLAY_CTRL_ON); // display control command

        self.stop();
    }

    fn start(self: *TM1637) void {
        self.dio.setHigh();
        self.clk.setHigh();
        hal.utils.delayMicros(delay);
        self.dio.setLow();
        hal.utils.delayMicros(delay);
        self.clk.setLow();
        hal.utils.delayMicros(delay);
    }

    fn stop(self: *TM1637) void {
        self.clk.setLow();
        hal.utils.delayMicros(delay);
        self.dio.setLow();
        hal.utils.delayMicros(delay);
        self.clk.setHigh();
        hal.utils.delayMicros(delay);
        self.dio.setHigh();
        hal.utils.delayMicros(delay);
    }

    fn writeByte(self: *TM1637, byte: u8) void {
        var b = byte;
        for (0..8) |_| {
            self.clk.setLow();
            if ((b & 0x01) != 0) {
                self.dio.setHigh();
            } else {
                self.dio.setLow();
            }
            hal.utils.delayMicros(delay);
            self.clk.setHigh();
            hal.utils.delayMicros(delay);
            b >>= 1;
        }

        self.dio.setHigh(); // release dio

        self.clk.setLow();
        hal.utils.delayMicros(delay);
        self.clk.setHigh();
        hal.utils.delayMicros(delay);

        const ack = self.dio.getLevel(); // check for ack
        if (ack == 1) {
            @panic("no ack received");
        }
    }
};

export fn main() noreturn {
    @setRuntimeSafety(true);

    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioAEn = true;
    hal.RCC.apb2enr.usart1En = true;
    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh }); // USART1 TX
    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);
    hal.USART1.writer().writeAll("\x1B[2J\x1B[H") catch unreachable;
    std.log.info("Hello, world! clocks: {}", .{hal.RCC.clocks()});

    hal.RCC.ahb1enr.gpioBEn = true;

    const clk = hal.GPIOB.setupOutput(0, .{});
    const dio = hal.GPIOB.setupOutput(1, .{ .outputType = .OpenDrain });

    var tm1637 = TM1637.init(clk, dio);

    while (true) {
        const time = hal.RTC.readTime();
        var buf: [4]u8 = undefined;
        const str = std.fmt.bufPrint(&buf, "{:02}{:02}", .{ time.hour, time.minute }) catch unreachable;

        tm1637.display(&.{
            Digits.get(&.{str[0]}).?,
            Digits.get(&.{str[1]}).? | 0x80, // colon
            Digits.get(&.{str[2]}).?,
            Digits.get(&.{str[3]}).?,
        });
        hal.utils.delayMicros(1_000_000);
        tm1637.display(&.{
            Digits.get(&.{str[0]}).?,
            Digits.get(&.{str[1]}).?,
            Digits.get(&.{str[2]}).?,
            Digits.get(&.{str[3]}).?,
        });
        hal.utils.delayMicros(1_000_000);
    }
}
