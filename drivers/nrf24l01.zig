const std = @import("std");

const hal = @import("hal");

spi: hal.spi.Spi,
ce: hal.gpio.OutputPin,
cs: hal.gpio.OutputPin,

const Register = struct {
    address: u5,
    t: type,
};

const ConfigRegister = MakeRegister(0x00, packed struct(u8) {
    prim_rx: enum(u1) { tx = 0, rx = 1 },
    pwr_up: u1,
    crco: enum(u1) { @"1byte" = 0, @"2byte" = 1 },
    en_crc: u1,
    mask_max_rt: u1,
    mask_tx_ds: u1,
    mask_rx_dr: u1,
    _0: u1 = 0,
});
const EnAARegister = MakeRegister(0x01, packed struct(u8) {
    en_aa_pipe0: u1,
    en_aa_pipe1: u1,
    en_aa_pipe2: u1,
    en_aa_pipe3: u1,
    en_aa_pipe4: u1,
    en_aa_pipe5: u1,
    _0: u2 = 0b00,
});
const EnRxAddrRegister = MakeRegister(0x02, packed struct(u8) {
    en_rxaddr_pipe0: u1,
    en_rxaddr_pipe1: u1,
    en_rxaddr_pipe2: u1,
    en_rxaddr_pipe3: u1,
    en_rxaddr_pipe4: u1,
    en_rxaddr_pipe5: u1,
    _0: u2 = 0b00,
});
const SetupAwRegister = MakeRegister(0x03, packed struct(u8) {
    const Aw = enum(u2) { bytes3 = 1, bytes4 = 2, bytes5 = 3 };
    aw: Aw,
    _0: u6 = 0b000000,
});
const SetupRetrRegister = MakeRegister(0x04, packed struct(u8) {
    arc: u4,
    ard: u4,
});
const RfChRegister = MakeRegister(0x05, packed struct(u8) {
    rf_ch: u7,
    _0: u1 = 0,
});
const RfSetupRegister = MakeRegister(0x06, packed struct(u8) {
    lna_hcurr: u1,
    rf_pwr: enum(u2) { @"-18dBm" = 0, @"-12dBm" = 1, @"-6dBm" = 2, @"0dBm" = 3 },
    rf_dr: enum(u1) { @"1Mbps" = 0, @"2Mbps" = 1 },
    pll_lock: u1,
    _0: u3 = 0b000,
});
const StatusRegister = MakeRegister(0x07, packed struct(u8) {
    tx_full: u1,
    rx_p_no: u3,
    max_rt: u1,
    tx_ds: u1,
    rx_dr: u1,
    _0: u1 = 0,
});
const ObserveTxRegister = MakeRegister(0x08, packed struct(u8) {
    arc_cnt: u4,
    plos_cnt: u4,
});
const CarrierDetectRegister = MakeRegister(0x09, packed struct(u8) {
    cd: u1,
    _0: u7 = 0,
});
const RxAddrP0Register = MakeRegister(0x0A, []const u8);
const TxAddrRegister = MakeRegister(0x10, []const u8);
const DynpdRegister = MakeRegister(0x1C, packed struct(u8) {
    dpl_p0: u1,
    dpl_p1: u1,
    dpl_p2: u1,
    dpl_p3: u1,
    dpl_p4: u1,
    dpl_p5: u1,
    _0: u2 = 0b00,
});
const FeatureRegister = MakeRegister(0x1D, packed struct(u8) {
    en_dyn_ack: u1,
    en_ack_pay: u1,
    en_dpl: u1,
    _0: u5 = 0b00000,
});

fn MakeRegister(comptime address: u8, comptime T: type) Register {
    return Register{ .address = address, .t = T };
}

fn spiTransfer(self: @This(), data: []u8) !void {
    self.cs.setLevel(0);
    hal.utils.delayMicros(1);

    defer {
        hal.utils.delayMicros(1);
        self.cs.setLevel(1);
    }

    try self.spi.transfer(data);
}

fn spiTransferWriteOnly(self: @This(), data: []const u8) !void {
    self.cs.setLevel(0);
    hal.utils.delayMicros(1);

    defer {
        hal.utils.delayMicros(1);
        self.cs.setLevel(1);
    }

    try self.spi.transferSendOnly(data);
}

fn writeRegister(self: @This(), comptime register: Register, value: register.t) !StatusRegister.t {
    return switch (register.t) {
        []const u8 => self.writeRegisterN(register, value),
        else => self.writeRegisterN(register, &.{@bitCast(value)}),
    };
}

fn readRegister(self: @This(), comptime register: Register) !register.t {
    var data: [2]u8 = .{ 0b000_00000 | @as(u8, register.address), 0 };

    try self.spiTransfer(&data);

    return @bitCast(data[1]);
}

fn modifyRegister(self: @This(), comptime register: Register, fields: anytype) !StatusRegister.t {
    var current = try self.readRegister(register);

    inline for (std.meta.fields(@TypeOf(fields))) |field| {
        @field(current, field.name) = @field(fields, field.name);
    }

    return try self.writeRegister(register, current);
}

fn nop(self: @This()) !StatusRegister.t {
    var cmd: [1]u8 = .{0b111_11111};
    try self.spiTransfer(&cmd);
    return @bitCast(cmd[0]);
}

fn writeRegisterN(self: @This(), comptime register: Register, value: []const u8) !StatusRegister.t {
    if (value.len > 32) {
        return error.TooMuchData;
    }

    var data: [1 + 32]u8 = undefined;
    data[0] = 0b001_00000 | @as(u8, register.address);
    std.mem.copyForwards(u8, data[1..], value);

    try self.spiTransfer(data[0 .. 1 + value.len]);

    return @bitCast(data[0]);
}

fn flushTx(self: @This()) !StatusRegister.t {
    var cmd: [1]u8 = .{0b1110_0001};
    try self.spiTransfer(&cmd);
    return @bitCast(cmd[0]);
}

fn flushRx(self: @This()) !StatusRegister.t {
    var cmd: [1]u8 = .{0b1110_0010};
    try self.spiTransfer(&cmd);
    return @bitCast(cmd[0]);
}

pub fn init(self: @This(), channel: u7) !void {
    self.ce.setLevel(0);

    // set to TX mode, power up, 1 byte CRC
    _ = try self.writeRegister(ConfigRegister, ConfigRegister.t{
        .prim_rx = .tx,
        .pwr_up = 1,
        .crco = .@"2byte",
        .en_crc = 1,
        .mask_max_rt = 0,
        .mask_tx_ds = 0,
        .mask_rx_dr = 0,
    });

    hal.utils.delayMicros(15_000); // Wait for the device to power up

    // set RF channel
    _ = try self.writeRegister(RfChRegister, RfChRegister.t{
        .rf_ch = channel,
    });

    // configure rf settings
    _ = try self.writeRegister(RfSetupRegister, RfSetupRegister.t{
        .lna_hcurr = 1,
        .rf_pwr = .@"-6dBm",
        .rf_dr = .@"1Mbps",
        .pll_lock = 0,
    });

    // setup addresses
    _ = try self.writeRegister(SetupAwRegister, SetupAwRegister.t{
        .aw = .bytes5,
    });

    // enable pipe 0 for auto acknowledgment
    _ = try self.writeRegister(EnAARegister, EnAARegister.t{
        .en_aa_pipe0 = 1,
        .en_aa_pipe1 = 0,
        .en_aa_pipe2 = 0,
        .en_aa_pipe3 = 0,
        .en_aa_pipe4 = 0,
        .en_aa_pipe5 = 0,
    });

    // enable rx address for pipe 0
    _ = try self.writeRegister(EnRxAddrRegister, EnRxAddrRegister.t{
        .en_rxaddr_pipe0 = 1,
        .en_rxaddr_pipe1 = 0,
        .en_rxaddr_pipe2 = 0,
        .en_rxaddr_pipe3 = 0,
        .en_rxaddr_pipe4 = 0,
        .en_rxaddr_pipe5 = 0,
    });

    // setup retries: 500us delay, 15 retries
    _ = try self.writeRegister(SetupRetrRegister, SetupRetrRegister.t{
        .arc = 15,
        .ard = 0b0010, // 500us
    });

    // enable dynamic payload length
    // activate feature register
    _ = try self.spiTransferWriteOnly(&.{ 0b0101_0000, 0x73 });
    _ = try self.writeRegister(FeatureRegister, FeatureRegister.t{
        .en_dpl = 1,
        .en_ack_pay = 0,
        .en_dyn_ack = 0,
    });
    _ = try self.writeRegister(DynpdRegister, DynpdRegister.t{
        .dpl_p0 = 1,
        .dpl_p1 = 0,
        .dpl_p2 = 0,
        .dpl_p3 = 0,
        .dpl_p4 = 0,
        .dpl_p5 = 0,
    });

    // flush FIFOs
    _ = try self.flushTx();
    _ = try self.flushRx();
}

pub fn transmit(self: @This(), data: []const u8, address: [5]u8) !void {
    if (data.len > 32) {
        return error.TooMuchData;
    }

    // enter TX mode
    _ = try self.modifyRegister(ConfigRegister, .{ .prim_rx = .tx });

    // set TX address
    _ = try self.writeRegister(TxAddrRegister, &address);
    // set RX address for pipe 0 (for auto acknowledgment)
    _ = try self.writeRegister(RxAddrP0Register, &address);

    if ((try self.nop()).tx_full == 1) {
        std.log.warn("TX FIFO full, flushing", .{});
        _ = try self.flushTx();
    }

    var cmd: [1 + 32]u8 = undefined;
    cmd[0] = 0b1010_0000; // W_TX_PAYLOAD command
    @memcpy(cmd[1 .. 1 + data.len], data);

    try self.spiTransfer(cmd[0 .. 1 + data.len]);

    self.ce.setLevel(1);
    hal.utils.delayMicros(15); // minimum 10us pulse
    self.ce.setLevel(0);

    while (true) {
        const status = try self.nop();

        if (status.rx_dr == 1) {
            // received data
            _ = try self.flushRx();
            return error.UnexpectedDataReceived;
        } else if (status.tx_ds == 1) {
            // transmission successful
            break;
        } else if (status.max_rt == 1) {
            // max retries reached

            // clear max_rt flag
            _ = try self.writeRegister(StatusRegister, .{
                .tx_full = 0,
                .rx_p_no = 0,
                .max_rt = 1,
                .tx_ds = 0,
                .rx_dr = 0,
            });

            _ = try self.flushTx();

            std.log.warn("Transmission failed, max retries reached, status: {}", .{try self.nop()});

            return error.MaxRetriesReached;
        }
    }
}

pub fn startReceive(self: @This(), address: [5]u8) !void {
    // enter RX mode
    _ = try self.modifyRegister(ConfigRegister, .{ .prim_rx = .rx });

    _ = try self.writeRegister(RxAddrP0Register, &address);

    self.ce.setLevel(1);
}

pub fn checkReceive(self: @This(), buffer: []u8) !?usize {
    const status = try self.nop();

    if (status.rx_dr == 0) {
        return null;
    }

    self.ce.setLevel(0);

    hal.utils.delayMicros(150); // Tstby2a max 130us

    // read payload length
    var cmd_len: [2]u8 = .{ 0b0110_0000, 0 };
    try self.spiTransfer(&cmd_len);
    const len = cmd_len[1];
    if (len > buffer.len) {
        _ = try self.flushRx();
        return error.BufferTooSmall;
    }

    if (len == 0 or len > 32) {
        std.log.warn("Invalid payload length: {}, status: {}", .{ len, status });
        _ = try self.flushRx();

        // clear rx_dr flag
        _ = try self.writeRegister(StatusRegister, .{
            .tx_full = 0,
            .rx_p_no = 0,
            .max_rt = 0,
            .tx_ds = 0,
            .rx_dr = 1,
        });
        return error.InvalidPayloadLength;
    }

    var cmd: [1 + 32]u8 = .{0} ** 33;
    cmd[0] = 0b011_00001; // R_RX_PAYLOAD command

    try self.spiTransfer(&cmd);

    @memcpy(buffer[0..len], cmd[1 .. 1 + len]);

    // clear rx_dr flag
    _ = try self.writeRegister(StatusRegister, .{
        .tx_full = 0,
        .rx_p_no = 0,
        .max_rt = 0,
        .tx_ds = 0,
        .rx_dr = 1,
    });

    self.ce.setLevel(1);

    return len;
}

pub fn stopReceive(self: @This()) void {
    self.ce.setLevel(0);
}
