const std = @import("std");

fn Spi(comptime baseAddress: [*]volatile u32) type {
    return struct {
        /// control register 1
        cr1: *align(4) volatile packed struct(u16) {
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
            spe: bool = false,
            /// Frame format LSB first
            lsbfirst: bool = false,
            /// Internal slave select
            ssi: bool = false,
            /// Software slave management
            ssm: bool = false,
            /// Receive only mode enabled
            rxonly: bool = false,
            /// CRC length
            crcl: enum(u1) {
                @"8Bit" = 0,
                @"16Bit" = 1,
            } = .@"8Bit",
            /// Transmit CRC next
            crcnext: bool = false,
            /// Hardware CRC calculation enable
            crcen: bool = false,
            /// Output enable in bidirectional mode
            bidioe: bool = false,
            /// Bidirectional data mode enable
            bidimode: bool = false,
        } = @ptrCast(&baseAddress[0]),
        /// control register 2
        cr2: *align(4) volatile packed struct(u16) {
            /// Rx buffer DMA enable
            rxdmaen: bool = false,
            /// Tx buffer DMA enable
            txdmaen: bool = false,
            /// SS output enable
            ssoe: bool = false,
            /// NSS pulse management
            nssp: bool = false,
            /// Frame format
            frf: enum(u1) {
                Motorola = 0,
                TI = 1,
            } = .Motorola,
            /// Error interrupt enable
            errie: bool = false,
            /// RX buffer not empty interrupt enable
            rxneie: bool = false,
            /// Tx buffer empty interrupt enable
            txeie: bool = false,
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
            } = @enumFromInt(0b000),
            /// FIFO reception threshold
            frxth: enum(u1) {
                Half = 0,
                Quarter = 1,
            } = .Quarter,
            /// Last DMA transfer for reception
            ldma_rx: enum(u1) {
                Even = 0,
                Odd = 1,
            } = .Odd,
            /// Last DMA transfer for transmission
            ldma_tx: enum(u1) {
                Even = 0,
                Odd = 1,
            } = .Odd,
            _: u1 = 0,
        } = @ptrCast(&baseAddress[1]),
        /// status register
        sr: *align(4) volatile packed struct(u16) {
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
        } = @ptrCast(&baseAddress[2]),
        /// data register
        dr: *align(4) volatile anyopaque = @ptrCast(&baseAddress[3]),
        /// CRC polynomial register
        crcpr: *align(4) volatile u16 = @ptrCast(&baseAddress[4]),
        /// Rx CRC register
        rxcrcr: *align(4) volatile u16 = @ptrCast(&baseAddress[5]),
        /// Tx CRC register
        txcrcr: *align(4) volatile u16 = @ptrCast(&baseAddress[6]),

        pub fn initMaster(
            self: @This(),
            baudrateDivider: @TypeOf(self.cr1.br),
            dataSize: @TypeOf(self.cr2.ds),
        ) void {
            self.cr1.* = .{
                .mstr = .Master,
                .br = baudrateDivider,
                .ssm = true,
                .ssi = true,
            };
            self.cr2.* = .{
                .ds = dataSize,
            };
            self.cr1.spe = true;
        }

        pub fn send(self: @This(), comptime T: type, data: T) void {
            while (!self.sr.txe) {}

            switch (T) {
                u8 => @as(*volatile u8, @ptrCast(self.dr)).* = data,
                u16 => @as(*volatile u16, @ptrCast(self.dr)).* = data,
                else => @compileError("unsupported data type"),
            }

            while (!self.sr.bsy) {}
        }

        pub fn receive(self: @This(), comptime T: type) T {
            while (!self.sr.rxne) {}

            switch (T) {
                u8 => return @as(u8, @as(*volatile u8, @ptrCast(self.dr)).*),
                u16 => return @as(u16, @as(*volatile u16, @ptrCast(self.dr)).*),
                else => @compileError("unsupported data type"),
            }
        }
    };
}

pub const SPI1 = Spi(@ptrFromInt(0x4001_3000)){};
pub const SPI2 = Spi(@ptrFromInt(0x4000_3800)){};
