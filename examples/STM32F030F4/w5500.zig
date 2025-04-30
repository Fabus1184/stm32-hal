const std = @import("std");

const hal = @import("hal").STM32F030F4;

usingnamespace hal.core;

// TODO: make this binary size wayyy smaller
pub fn log(comptime level: std.log.Level, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void {
    const colors = std.EnumMap(std.log.Level, []const u8).init(.{
        .debug = "\x1b[36m",
        .info = "\x1b[32m",
        .warn = "\x1b[33m",
        .err = "\x1b[31m",
    });
    const reset = "\x1b[0m";

    hal.USART1.send(colors.getAssertContains(level));
    hal.USART1.send("[" ++ @tagName(level) ++ "]" ++ "(" ++ @tagName(scope) ++ ")" ++ reset ++ ": ");

    const Writer = struct {
        pub const Error = error{};

        pub inline fn writeAll(_: @This(), bytes: []const u8) !void {
            hal.USART1.send(bytes);
        }

        pub inline fn writeBytesNTimes(_: @This(), bytes: []const u8, n: usize) !void {
            for (0..n) |_| {
                hal.USART1.send(bytes);
            }
        }
    };

    std.fmt.format(Writer{}, format, args) catch unreachable;

    hal.USART1.send("\n");
}

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = log,
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

export fn bareMain() noreturn {
    hal.memory.initializeMemory();

    main() catch |err| {
        std.log.err("main failed: {}", .{err});
        @trap();
    };

    @panic("main returned");
}

const W5500 = struct {
    spi: hal.spi.Spi,
    cs: hal.gpio.OutputPin,

    const ControlByte = packed struct(u8) {
        spiMode: enum(u2) {
            VariableDataLength = 0b00,
            Fixed1Byte = 0b01,
            Fixed2Byte = 0b10,
            Fixed4Byte = 0b11,
        },
        rw: enum(u1) { read = 0, write = 1 },
        block: u5,
    };

    const RegisterBlock = enum(u5) {
        Common = 0b00000,
        Socket0Register = 0b00001,
        Socket0TxBuffer = 0b00010,
        Socket0RxBuffer = 0b00011,
        Socket1Register = 0b00101,
        Socket1TxBuffer = 0b00110,
        Socket1RxBuffer = 0b00111,
        Socket2Register = 0b01001,
        Socket2TxBuffer = 0b01010,
        Socket2RxBuffer = 0b01011,
        Socket3Register = 0b01101,
        Socket3TxBuffer = 0b01110,
        Socket3RxBuffer = 0b01111,
        Socket4Register = 0b10001,
        Socket4TxBuffer = 0b10010,
        Socket4RxBuffer = 0b10011,
        Socket5Register = 0b10101,
        Socket5TxBuffer = 0b10110,
        Socket5RxBuffer = 0b10111,
        Socket6Register = 0b11001,
        Socket6TxBuffer = 0b11010,
        Socket6RxBuffer = 0b11011,
        Socket7Register = 0b11101,
        Socket7TxBuffer = 0b11110,
        Socket7RxBuffer = 0b11111,

        pub fn socketRegister(s: u4) RegisterBlock {
            return ([8]RegisterBlock{ .Socket0Register, .Socket1Register, .Socket2Register, .Socket3Register, .Socket4Register, .Socket5Register, .Socket6Register, .Socket7Register })[s];
        }

        pub fn socketTxBuffer(s: u4) RegisterBlock {
            return ([8]RegisterBlock{ .Socket0TxBuffer, .Socket1TxBuffer, .Socket2TxBuffer, .Socket3TxBuffer, .Socket4TxBuffer, .Socket5TxBuffer, .Socket6TxBuffer, .Socket7TxBuffer })[s];
        }

        pub fn socketRxBuffer(s: u4) RegisterBlock {
            return ([8]RegisterBlock{ .Socket0RxBuffer, .Socket1RxBuffer, .Socket2RxBuffer, .Socket3RxBuffer, .Socket4RxBuffer, .Socket5RxBuffer, .Socket6RxBuffer, .Socket7RxBuffer })[s];
        }
    };

    const CommonRegister = enum(u16) {
        Mode = 0x0000,
        GatewayAddress = 0x0001,
        SubnetMask = 0x0005,
        SourceHardwareAddress = 0x0009,
        SourceIpAddress = 0x000F,
        InterruptLowLevelTimer = 0x0013,
        Interrupt = 0x0015,
        InterruptMask = 0x0016,
        SocketInterrupt = 0x0017,
        SocketInterruptMask = 0x0018,
        RetryTime = 0x0019,
        RetryCount = 0x001B,
        UnreachableIpAddress = 0x0028,
        UnreachablePort = 0x002C,
        PHYConfig = 0x002E,
        Version = 0x0039,

        const TYPES: std.EnumArray(@This(), type) = std.EnumArray(@This(), type).init(.{
            .Mode = packed struct(u8) {
                _1: u1,
                forceArp: u1,
                _2: u1,
                pppoeMode: u1,
                pingBlockMode: u1,
                wakeOnLan: u1,
                _3: u1,
                reset: u1,
            },
            .GatewayAddress = [4]u8,
            .SubnetMask = [4]u8,
            .SourceHardwareAddress = [6]u8,
            .SourceIpAddress = [4]u8,
            .InterruptLowLevelTimer = u16,
            .Interrupt = u8,
            .InterruptMask = u8,
            .SocketInterrupt = u8,
            .SocketInterruptMask = u8,
            .RetryTime = u16,
            .RetryCount = u8,
            .UnreachableIpAddress = [4]u8,
            .UnreachablePort = u16,
            .PHYConfig = packed struct(u8) {
                linkStatus: u1,
                speedStatus: enum(u1) {
                    @"10Mbps" = 0,
                    @"100Mbps" = 1,
                },
                fullDuplexStatus: u1,
                operationMode: enum(u3) {
                    @"10BT HalfDuplex" = 0b000,
                    @"10BT FullDuplex" = 0b001,
                    @"100BT HalfDuplex" = 0b010,
                    @"100BT FullDuplex" = 0b011,
                    @"100BT HalfDuplex AutoNegotiate" = 0b100,
                    powerDown = 0b110,
                    allCapableAutoNegotiate = 0b111,
                },
                configureMode: enum(u1) {
                    hardwarePins = 0,
                    register = 1,
                },
                reset: u1,
            },
            .Version = u8,
        });
    };

    const SocketRegister = enum(u16) {
        Mode = 0x0000,
        Command = 0x0001,
        Interrupt = 0x0002,
        Status = 0x0003,
        SourcePort = 0x0004,
        DestinationMac = 0x0006,
        DestinationIp = 0x000C,
        DestinationPort = 0x0010,
        MaximumSegmentSize = 0x0012,
        IpTOS = 0x0015,
        IpTTL = 0x0016,
        RxBufferSize = 0x001E,
        TxBufferSize = 0x001F,
        TxFreeSize = 0x0020,
        TxReadPointer = 0x0022,
        TxWritePointer = 0x0024,
        RxReceivedSize = 0x0026,
        RxReadPointer = 0x0028,
        RxWritePointer = 0x002A,
        InterruptMask = 0x002C,
        FragmentOffset = 0x002D,
        KeepAliveTimer = 0x002F,

        const TYPES: std.EnumArray(@This(), type) = std.EnumArray(@This(), type).init(.{
            .Mode = packed struct(u8) {
                protocol: enum(u4) {
                    closed = 0b0000,
                    tcp = 0b0001,
                    udp = 0b0010,
                    macraw = 0b0011,
                },
                udpBlockUnicast: u1,
                tcpAckNoDelay: u1,
                udpMacrawBlockBroadcast: u1,
                udpMulticast: u1,
            },
            .Command = enum(u8) {
                open = 0x01,
                tcpListen = 0x02,
                connect = 0x04,
                disconnect = 0x08,
                close = 0x10,
                send = 0x20,
                udpSendMac = 0x21,
                tcpSendKeepAlive = 0x22,
                receive = 0x40,
            },
            .Interrupt = packed struct(u8) {
                connected: bool,
                disconnected: bool,
                received: bool,
                timeout: bool,
                sendOk: bool,
                _: u3,
            },
            .Status = enum(u8) {
                // permanent statuses
                closed = 0x00,
                tcpInit = 0x13,
                tcpListen = 0x14,
                tcpEstablished = 0x17,
                tcpCloseWait = 0x1C,
                udp = 0x22,
                macraw = 0x23,
                // temporary statuses
                tcpSynSent = 0x15,
                tcpSynReceived = 0x16,
                tcpFinWait = 0x18,
                tcpClosing = 0x1A,
                tcpTimeWait = 0x1B,
                tcpLastAck = 0x1D,
            },
            .SourcePort = u16,
            .DestinationMac = [4]u8,
            .DestinationIp = [4]u8,
            .DestinationPort = u16,
            .MaximumSegmentSize = u16,
            .IpTOS = u8,
            .IpTTL = u8,
            .RxBufferSize = u8,
            .TxBufferSize = u8,
            .TxFreeSize = u16,
            .TxReadPointer = u16,
            .TxWritePointer = u16,
            .RxReceivedSize = u16,
            .RxReadPointer = u16,
            .RxWritePointer = u16,
            .InterruptMask = u8,
            .FragmentOffset = u16,
            .KeepAliveTimer = u8,
        });
    };

    fn read(self: @This(), block: u5, address: u16, dest: []u8) !void {
        self.cs.setLevel(0);

        try hal.SPI1.send(u8, @intCast(address >> 8));
        try hal.SPI1.send(u8, @truncate(address & 0xFF));
        _ = try hal.SPI1.receive(u8);
        _ = try hal.SPI1.receive(u8);

        try hal.SPI1.send(u8, @bitCast(ControlByte{
            .spiMode = .VariableDataLength,
            .rw = .read,
            .block = block,
        }));
        _ = try hal.SPI1.receive(u8);

        for (0..dest.len) |i| {
            try hal.SPI1.send(u8, 0x00);
            dest[i] = try hal.SPI1.receive(u8);
        }

        self.cs.setLevel(1);
    }

    fn write(self: @This(), block: u5, address: u16, data: []const u8) !void {
        self.cs.setLevel(0);

        try hal.SPI1.send(u8, @intCast(@as(u16, address) >> 8));
        try hal.SPI1.send(u8, @truncate(@as(u16, address) & 0xFF));
        _ = try hal.SPI1.receive(u8);
        _ = try hal.SPI1.receive(u8);

        try hal.SPI1.send(u8, @bitCast(ControlByte{
            .spiMode = .VariableDataLength,
            .rw = .write,
            .block = block,
        }));
        _ = try hal.SPI1.receive(u8);

        for (0..data.len) |i| {
            try hal.SPI1.send(u8, data[i]);
            _ = try hal.SPI1.receive(u8);
        }

        self.cs.setLevel(1);
    }

    fn readCommonRegister(self: @This(), comptime register: CommonRegister) !CommonRegister.TYPES.get(register) {
        const Type = CommonRegister.TYPES.get(register);

        var value: [@bitSizeOf(Type) / 8]u8 = undefined;
        try self.read(@intFromEnum(RegisterBlock.Common), @intFromEnum(register), &value);

        const x = std.mem.bytesToValue(Type, &value);

        return switch (@typeInfo(Type)) {
            .int => @byteSwap(x),
            else => x,
        };
    }

    fn writeCommonRegister(self: @This(), comptime register: CommonRegister, value: CommonRegister.TYPES.get(register)) !void {
        const Type = CommonRegister.TYPES.get(register);

        const data: [@bitSizeOf(Type) / 8]u8 = std.mem.toBytes(switch (@typeInfo(Type)) {
            .int => @byteSwap(value),
            else => value,
        });
        try self.write(@intFromEnum(RegisterBlock.Common), @intFromEnum(register), &data);
    }

    fn modifyCommonRegister(self: @This(), comptime register: CommonRegister, changes: anytype) !void {
        const Type = CommonRegister.TYPES.get(register);

        var value: Type = try self.readCommonRegister(register);
        inline for (@typeInfo(@TypeOf(changes)).@"struct".fields) |field| {
            @field(value, field.name) = @field(changes, field.name);
        }

        const data: [@bitSizeOf(Type) / 8]u8 = std.mem.toBytes(value);
        try self.write(@intFromEnum(RegisterBlock.Common), @intFromEnum(register), &data);
    }

    fn readSocketRegister(self: @This(), sock: u4, comptime register: SocketRegister) !SocketRegister.TYPES.get(register) {
        const Type = SocketRegister.TYPES.get(register);

        var value: [@bitSizeOf(Type) / 8]u8 = undefined;
        try self.read(@intFromEnum(RegisterBlock.Socket0Register) + sock, @intFromEnum(register), &value);

        const x = std.mem.bytesToValue(Type, &value);

        return switch (@typeInfo(Type)) {
            .int => @byteSwap(x),
            else => x,
        };
    }

    fn writeSocketRegister(self: @This(), sock: u4, comptime register: SocketRegister, value: SocketRegister.TYPES.get(register)) !void {
        const Type = SocketRegister.TYPES.get(register);

        const data: [@bitSizeOf(Type) / 8]u8 = std.mem.toBytes(switch (@typeInfo(Type)) {
            .int => @byteSwap(value),
            else => value,
        });
        try self.write(@intFromEnum(RegisterBlock.Socket0Register) + sock, @intFromEnum(register), &data);
    }

    fn reset(self: @This()) !void {
        try self.modifyCommonRegister(.Mode, .{ .reset = 1 });
        while ((try self.readCommonRegister(.Mode)).reset == 1) {
            for (0..1_000_000) |_| asm volatile ("nop");
        }
    }

    fn resetPhy(self: @This()) !void {
        try self.modifyCommonRegister(.PHYConfig, .{ .reset = 0 });
        for (0..1_000_000) |_| asm volatile ("nop");
        try self.modifyCommonRegister(.PHYConfig, .{ .reset = 1 });
    }

    const Socket = struct {
        w5500: W5500,
        socket: u4,

        fn ackInterrupts(self: @This()) !SocketRegister.TYPES.get(.Interrupt) {
            const i = try self.w5500.readSocketRegister(self.socket, .Interrupt);
            try self.w5500.writeSocketRegister(self.socket, .Interrupt, i);
            return i;
        }

        fn close(self: @This()) !void {
            try self.w5500.writeSocketRegister(self.socket, .Command, .close);
            const status = try self.w5500.readSocketRegister(self.socket, .Status);
            if (status != .closed) {
                std.log.warn("socket {} not closed: {}", .{ self.socket, status });
                return error.SocketNotClosed;
            }
        }

        fn openTcp(self: @This(), port: u16) !void {
            try self.w5500.writeSocketRegister(self.socket, .Mode, .{
                .protocol = .tcp,
                .udpBlockUnicast = 0,
                .tcpAckNoDelay = 0,
                .udpMacrawBlockBroadcast = 0,
                .udpMulticast = 0,
            });
            try self.w5500.writeSocketRegister(self.socket, .SourcePort, port);

            try self.w5500.writeSocketRegister(self.socket, .Command, .open);
            const status = try self.w5500.readSocketRegister(self.socket, .Status);
            if (status != .tcpInit) {
                std.log.warn("socket {} not opened: {}", .{ self.socket, status });
                return error.SocketNotOpened;
            }

            try self.w5500.writeSocketRegister(self.socket, .RxReadPointer, 0);
            try self.w5500.writeSocketRegister(self.socket, .RxWritePointer, 0);
            try self.w5500.writeSocketRegister(self.socket, .RxReceivedSize, 0);
            try self.w5500.writeSocketRegister(self.socket, .Command, .receive);

            try self.w5500.writeSocketRegister(self.socket, .TxReadPointer, 0);
            try self.w5500.writeSocketRegister(self.socket, .TxWritePointer, 0);
            try self.w5500.writeSocketRegister(self.socket, .Command, .send);
        }

        fn listen(self: @This()) !void {
            try self.w5500.writeSocketRegister(self.socket, .Command, .tcpListen);
            const status = try self.w5500.readSocketRegister(self.socket, .Status);
            if (status != .tcpListen) {
                std.log.warn("socket {} not listening: {}", .{ self.socket, status });
                return error.SocketNotListening;
            }
        }

        fn waitForConnection(self: @This()) !void {
            const status = try self.w5500.readSocketRegister(self.socket, .Status);
            if (status != .tcpListen) {
                std.log.warn("waitForConnection: socket {} not listening: {}", .{ self.socket, status });
                return error.SocketNotConnected;
            }

            if (!(try self.ackInterrupts()).connected) {
                asm volatile ("wfi");
                const i = try self.ackInterrupts();

                if (!i.connected) {
                    std.log.warn("waitForConnection: socket {} not connected: {}", .{ self.socket, i });
                    return error.SocketNotConnected;
                }
            }
        }

        fn receive(self: @This(), dest: []u8) !usize {
            if (!(try self.ackInterrupts()).received and try self.w5500.readSocketRegister(self.socket, .RxReceivedSize) == 0) {
                const status = try self.w5500.readSocketRegister(self.socket, .Status);
                if (status != .tcpEstablished) {
                    std.log.warn("receive: socket {} not connected: {}", .{ self.socket, status });
                    return error.SocketNotConnected;
                }

                try self.w5500.writeSocketRegister(self.socket, .Command, .receive);

                asm volatile ("wfi");
                const i = try self.ackInterrupts();

                if (!i.received) {
                    std.log.warn("receive: socket {} not received: {}", .{ self.socket, i });
                    return error.SocketNotReceived;
                }
            }

            const readPointer = try self.w5500.readSocketRegister(self.socket, .RxReadPointer);
            const size = @min(try self.w5500.readSocketRegister(self.socket, .RxReceivedSize), dest.len);
            std.log.debug("receive: socket {} readPointer {} size {}", .{ self.socket, readPointer, size });

            try self.w5500.read(
                @intFromEnum(RegisterBlock.socketRxBuffer(self.socket)),
                readPointer,
                dest[0..size],
            );

            try self.w5500.writeSocketRegister(self.socket, .RxReadPointer, readPointer + size);
            try self.w5500.writeSocketRegister(self.socket, .RxReceivedSize, try self.w5500.readSocketRegister(self.socket, .RxReceivedSize) - size);

            try self.w5500.writeSocketRegister(self.socket, .Command, .receive);

            return size;
        }

        fn send(self: @This(), data: []const u8) !void {
            const freeSize = try self.w5500.readSocketRegister(self.socket, .TxFreeSize);
            if (freeSize < data.len) {
                std.log.warn("send: socket {} not enough space: {} < {}", .{ self.socket, freeSize, data.len });
                return error.SocketNotEnoughSpace;
            }

            const writePointer = try self.w5500.readSocketRegister(self.socket, .TxWritePointer);

            std.log.debug("send: socket {} writePointer {} freeSize {}", .{ self.socket, writePointer, freeSize });

            try self.w5500.write(
                @intFromEnum(RegisterBlock.socketTxBuffer(self.socket)),
                writePointer,
                data,
            );

            //try self.w5500.writeSocketRegister(self.socket, .TxReadPointer, writePointer);
            try self.w5500.writeSocketRegister(self.socket, .TxWritePointer, writePointer + @as(u16, @intCast(data.len)));
            try self.w5500.writeSocketRegister(self.socket, .Command, .send);

            var i = try self.ackInterrupts();
            if (!i.sendOk) {
                const status = try self.w5500.readSocketRegister(self.socket, .Status);
                if (status != .tcpEstablished) {
                    std.log.warn("send: socket {} not connected: {}", .{ self.socket, status });
                    return error.SocketNotConnected;
                }

                asm volatile ("wfi");
                i = try self.ackInterrupts();
            }

            if (!i.sendOk) {
                std.log.warn("send: socket {} not sendOk: {}", .{ self.socket, i });
                return error.SocketNotSendOk;
            }

            std.log.debug("send: socket {} sent {} bytes", .{ self.socket, data.len });
        }

        fn disconnect(self: @This()) !void {
            try self.w5500.writeSocketRegister(self.socket, .Command, .disconnect);
        }
    };

    pub inline fn socket(self: @This(), sock: u4) Socket {
        return Socket{ .w5500 = self, .socket = sock };
    }
};

fn interrupt() void {
    hal.EXTI.clearPending(7);
}

var LED: hal.gpio.OutputPin = undefined;

fn main() !void {
    hal.RCC.ahbenr.gpioaen = true;
    hal.RCC.ahbenr.gpioben = true;
    hal.RCC.apb2enr.usart1en = true;
    hal.RCC.apb2enr.spi1en = true;
    hal.RCC.apb2enr.syscfgen = true;

    const USART_TX = 2;
    _ = hal.GPIOA.setupOutput(USART_TX, .{ .alternateFunction = .AF1 });
    hal.USART1.init(115_200);
    //hal.RCC.apb1Clock()
    std.log.info("USART1 initialized", .{});

    LED = hal.GPIOA.setupOutput(4, .{});
    LED.setLevel(1);

    const SPI_CS = hal.GPIOB.setupOutput(1, .{});
    SPI_CS.setLevel(1);

    const RESET = hal.GPIOA.setupOutput(9, .{});
    RESET.setLevel(0);

    _ = hal.GPIOA.setupInput(10, .{ .pullMode = .PullUp });
    hal.core.SoftExceptionHandler.put(.IRQ7, interrupt);
    std.log.debug("irq7 handler: {*}", .{hal.core.SoftExceptionHandler.get(.IRQ7)});

    hal.SYSCFG.exticr3.modify(.{ .exti10 = .A });
    hal.EXTI.configureLineInterrupt(10, .fallingEdge);
    hal.core.cortex.NVIC.enableInterrupt(7);

    _ = hal.GPIOA.setupOutput(5, .{ .alternateFunction = .AF0, .outputSpeed = .VeryHigh });
    _ = hal.GPIOA.setupInput(6, .{ .alternateFunction = .AF0, .pullMode = .PullUp });
    _ = hal.GPIOA.setupOutput(7, .{ .alternateFunction = .AF0, .outputSpeed = .VeryHigh });

    hal.SPI1.initMaster(.Div16, .Bit8);

    const w5500 = W5500{ .spi = hal.SPI1, .cs = SPI_CS };

    RESET.setLevel(1);
    for (0..1_000_000) |_| asm volatile ("nop");

    const version = try w5500.readCommonRegister(.Version);
    std.log.debug("version {}", .{version});

    try w5500.reset();
    std.log.debug("w5500 reset", .{});

    try w5500.modifyCommonRegister(.PHYConfig, .{
        .operationMode = .allCapableAutoNegotiate,
        .configureMode = .register,
    });
    try w5500.modifyCommonRegister(.PHYConfig, .{ .reset = 0 });

    try w5500.resetPhy();
    std.log.debug("PHY reset", .{});

    while ((try w5500.readCommonRegister(.PHYConfig)).linkStatus == 0) {
        for (0..100_000) |_| asm volatile ("nop");
    }

    std.log.debug("link established: {}", .{try w5500.readCommonRegister(.PHYConfig)});

    try w5500.writeCommonRegister(.SourceHardwareAddress, .{ 0xDE, 0xAD, 0xBE, 0xEF, 0x69, 0x42 });
    try w5500.writeCommonRegister(.SourceIpAddress, .{ 10, 69, 69, 7 });
    try w5500.writeCommonRegister(.GatewayAddress, .{ 10, 69, 69, 1 });
    try w5500.writeCommonRegister(.SubnetMask, .{ 255, 255, 255, 0 });

    try w5500.writeCommonRegister(.InterruptMask, 0xFF);
    try w5500.writeCommonRegister(.SocketInterruptMask, 0xFF);

    try w5500.writeSocketRegister(0, .InterruptMask, 0xFF);

    const socket = w5500.socket(0);

    while (true) {
        try socket.close();
        std.log.debug("socket closed", .{});

        try socket.openTcp(80);
        std.log.debug("socket opened", .{});

        try socket.listen();
        std.log.debug("socket listening", .{});

        try socket.waitForConnection();
        std.log.debug("socket connected", .{});

        var buf: [255]u8 = undefined;
        const n = socket.receive(&buf) catch |err| {
            std.log.warn("socket receive failed: {}", .{err});
            continue;
        };
        const data = buf[0..n];
        std.log.debug("socket received {} bytes: {s}", .{ n, data });

        if (std.mem.eql(u8, data, "pulse")) {
            LED.setLevel(0);
            for (0..1_000_000) |_| asm volatile ("nop");
            LED.setLevel(1);
        }

        socket.send("ok") catch |err| {
            std.log.warn("socket send failed: {}", .{err});
            continue;
        };

        socket.disconnect() catch |err| {
            std.log.warn("socket disconnect failed: {}", .{err});
            continue;
        };
    }
}
