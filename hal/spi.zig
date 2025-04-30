const std = @import("std");

const Register = @import("register.zig").Register;

pub const Cr1 = packed struct(u16) {
    /// clock phase
    /// - 0: The first clock transition is the first data capture edge
    /// - 1: The second clock transition is the first data capture edge
    cpha: u1 = 0,
    /// Clock polarity
    /// - 0: CK to 0 when idle
    /// - 1: CK to 1 when idle
    cpol: u1 = 0,
    /// Master selection
    mstr: enum(u1) {
        Slave = 0,
        Master = 1,
    },
    /// Baud rate control
    br: enum(u3) {
        Div2 = 0b000,
        Div4 = 0b001,
        Div8 = 0b010,
        Div16 = 0b011,
        Div32 = 0b100,
        Div64 = 0b101,
        Div128 = 0b110,
        Div256 = 0b111,
    },
    /// SPI enable
    spe: bool,
    /// Frame format LSB first
    lsbfirst: bool,
    /// Internal slave select
    ssi: bool,
    /// Software slave management
    ssm: bool,
    /// Receive only mode enabled
    rxonly: bool,
    /// CRC length
    crcl: enum(u1) {
        @"8Bit",
        @"16Bit",
    } = .@"8Bit",
    /// Transmit CRC next
    crcnext: bool,
    /// Hardware CRC calculation enable
    crcen: bool,
    /// Output enable in bidirectional mode
    bidioe: bool,
    /// Bidirectional data mode enable
    bidimode: bool,
};

pub const Cr2 = packed struct(u16) {
    /// Rx buffer DMA enable
    rxdmaen: bool,
    /// Tx buffer DMA enable
    txdmaen: bool,
    /// SS output enable
    ssoe: bool,
    /// NSS pulse management
    nssp: bool,
    /// Frame format
    frf: enum(u1) {
        Motorola = 0,
        TI = 1,
    },
    /// Error interrupt enable
    errie: bool,
    /// RX buffer not empty interrupt enable
    rxneie: bool,
    /// Tx buffer empty interrupt enable
    txeie: bool,
    /// Data size
    ds: enum(u4) {
        Bit4 = 0b0011,
        Bit5 = 0b0100,
        Bit6 = 0b0101,
        Bit7 = 0b0110,
        Bit8 = 0b0111,
        Bit9 = 0b1000,
        Bit10 = 0b1001,
        Bit11 = 0b1010,
        Bit12 = 0b1011,
        Bit13 = 0b1100,
        Bit14 = 0b1101,
        Bit15 = 0b1110,
        Bit16 = 0b1111,
        _,
    },
    /// FIFO reception threshold
    frxth: enum(u1) {
        Half = 0,
        Quarter = 1,
    },
    /// Last DMA transfer for reception
    ldma_rx: enum(u1) {
        Even = 0,
        Odd = 1,
    },
    /// Last DMA transfer for transmission
    ldma_tx: enum(u1) {
        Even = 0,
        Odd = 1,
    },
    _: u1,
};

pub const Sr = packed struct(u16) {
    /// Receive buffer not empty
    rxne: bool,
    /// Transmit buffer empty
    txe: bool,
    _: u2,
    /// CRC error flag
    crcerr: bool,
    /// Mode fault
    modf: bool,
    /// Overrun flag
    ovr: bool,
    /// Busy flag
    bsy: bool,
    /// Frame format error
    fre: bool,
    /// FIFO reception level
    frlvl: enum(u2) {
        Empty = 0,
        Quarter = 1,
        Half = 2,
        Full = 3,
    },
    /// FIFO transmission level
    ftlvl: enum(u2) {
        Empty = 0,
        Quarter = 1,
        Half = 2,
        Full = 3,
    },
    __: u3 = 0,
};

pub const Spi = struct {
    /// control register 1
    cr1: Register(Cr1),
    /// control register 2
    cr2: Register(Cr2),
    /// status register
    sr: Register(Sr),
    /// data register
    dr: *align(4) volatile anyopaque,
    /// CRC polynomial register
    crcpr: *align(4) volatile u16,
    /// Rx CRC register
    rxcrcr: *align(4) volatile u16,
    /// Tx CRC register
    txcrcr: *align(4) volatile u16,

    pub fn initMaster(
        self: @This(),
        baudrateDivider: @TypeOf(@as(*Cr1, @ptrFromInt(0x4)).br),
        dataSize: @TypeOf(@as(*Cr2, @ptrFromInt(0x4)).ds),
    ) void {
        self.cr1.store(Cr1{
            .cpha = 0,
            .cpol = 0,
            .mstr = .Master,
            .br = baudrateDivider,
            .spe = false,
            .lsbfirst = false,
            .ssi = true,
            .ssm = true,
            .rxonly = false,
            .crcl = .@"8Bit",
            .crcnext = false,
            .crcen = false,
            .bidioe = false,
            .bidimode = false,
        });

        self.cr2.modify(.{
            .rxdmaen = false,
            .txdmaen = false,
            .ssoe = false,
            .nssp = false,
            .frf = .Motorola,
            .errie = false,
            .rxneie = false,
            .txeie = false,
            .ds = dataSize,
            .frxth = .Quarter,
            .ldma_rx = .Odd,
            .ldma_tx = .Odd,
        });

        self.cr1.modify(.{
            .spe = true,
        });
    }

    fn checkStatus(self: @This()) !void {
        const status = self.sr.load();

        if (status.fre) return error.FrameFormatError;
        if (status.ovr) return error.OverrunError;
        if (status.modf) return error.ModeFault;
        if (status.crcerr) return error.CrcError;
    }

    pub fn send(self: @This(), comptime T: type, data: T) !void {
        try self.checkStatus();

        while (!self.sr.load().txe) {}

        switch (T) {
            u8 => @as(*align(4) volatile u8, @ptrCast(self.dr)).* = data,
            u16 => @as(*align(4) volatile u16, @ptrCast(self.dr)).* = data,
            else => @compileError("unsupported data type"),
        }

        try self.checkStatus();

        while (!self.sr.load().bsy) {}

        try self.checkStatus();
    }

    pub fn sendAll(self: @This(), comptime T: type, data: []const T) !void {
        for (data) |item| {
            try self.send(T, item);
        }
    }

    pub fn receive(self: @This(), comptime T: type) !T {
        try self.checkStatus();

        while (!self.sr.load().rxne) {}

        const data = switch (T) {
            u8 => @as(u8, @as(*align(4) volatile u8, @ptrCast(self.dr)).*),
            u16 => @as(u16, @as(*align(4) volatile u16, @ptrCast(self.dr)).*),
            else => @compileError("unsupported data type"),
        };

        try self.checkStatus();

        return data;
    }
};

pub fn MakeSpi(comptime baseAddress: [*]align(4) volatile u32) Spi {
    return Spi{
        .cr1 = .{ .ptr = @ptrCast(&baseAddress[0]) },
        .cr2 = .{ .ptr = @ptrCast(&baseAddress[1]) },
        .sr = .{ .ptr = @ptrCast(&baseAddress[2]) },
        .dr = @ptrCast(&baseAddress[3]),
        .crcpr = @ptrCast(&baseAddress[4]),
        .rxcrcr = @ptrCast(&baseAddress[5]),
        .txcrcr = @ptrCast(&baseAddress[6]),
    };
}
