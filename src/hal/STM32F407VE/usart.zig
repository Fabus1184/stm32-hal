const std = @import("std");

/// Universal Synchronous Asynchronous Receiver Transmitter
pub fn Usart(comptime baseAddress: [*]align(4) volatile u8) type {
    return struct {
        sr: *volatile packed struct(u32) {
            /// Parity error
            pe: u1,
            /// Framing error
            fe: u1,
            /// Noise detected flag
            nf: u1,
            /// Overrun error
            ore: u1,
            /// IDLE line detected
            idle: u1,
            /// Read data register not empty
            rxne: u1,
            /// Transmission complete
            tc: u1,
            /// Transmit data register empty
            txe: u1,
            /// LIN break detection flag
            lbd: u1,
            /// CTS flag
            cts: u1,
            _0: u22,
        } = @ptrCast(&baseAddress[0x0]),
        dr: *volatile packed struct(u32) { data: u8, _0: u24 } = @ptrCast(&baseAddress[0x4]),
        brr: *volatile union {
            fractional: packed struct(u32) { fraction: u4, mantissa: u12, _0: u16 },
            integer: packed struct(u32) { mantissa: u16, _0: u16 },
        } = @ptrCast(&baseAddress[0x8]),
        cr1: *volatile packed struct(u32) {
            /// Send break
            sbk: bool,
            /// Receiver wakeup
            rwu: bool,
            /// Receiver enable
            re: bool,
            /// Transmitter enable
            te: bool,
            /// IDLE interrupt enable
            idleie: bool,
            /// RXNE interrupt enable
            rxneie: bool,
            /// Transmission complete interrupt enable
            tcie: bool,
            /// TXE interrupt enable
            txeie: bool,
            /// PE interrupt enable
            peie: bool,
            /// Parity selection
            ps: u1,
            /// Parity control enable
            pce: bool,
            /// Wake-up method
            wake: enum(u1) {
                IdleLine = 0,
                AddressMark = 1,
            },
            /// Word length
            m: enum(u1) {
                @"8N1" = 0,
                @"9N1" = 1,
            },
            /// USART enable
            ue: bool,
            /// Oversampling mode
            over8: enum(u1) {
                @"16" = 0,
                @"8" = 1,
            },
            _0: u17,
        } = @ptrCast(&baseAddress[0xC]),
        cr2: *volatile packed struct(u32) {
            /// Address of the USART node
            add: u4,
            _0: u1,
            /// LIN break detection length
            lbdl: u1,
            /// LIN break detection interrupt enable
            lbdie: u1,
            _1: u1,
            /// Last bit clock pulse
            lbcl: u1,
            /// Clock phase
            cpha: u1,
            /// Clock polarity
            cpol: u1,
            /// Clock enable
            clken: u1,
            /// STOP bits
            stop: enum(u2) {
                @"1" = 0,
                @"0.5" = 1,
                @"2" = 2,
                @"1.5" = 3,
            },
            /// LIN mode enable
            linen: u1,
            _2: u17,
        } = @ptrCast(&baseAddress[0x10]),
        cr3: *volatile packed struct(u32) {
            /// Error interrupt enable
            eie: u1,
            /// IrDA mode enable
            iren: u1,
            /// IrDA low-power
            irlp: u1,
            /// Half-duplex selection
            hdsel: u1,
            /// Smartcard NACK enable
            nack: u1,
            /// Smartcard mode enable
            scen: u1,
            /// DMA enable receiver
            dmar: u1,
            /// DMA enable transmitter
            dmat: u1,
            /// RTS enable
            rtse: u1,
            /// CTS enable
            ctse: u1,
            /// CTS interrupt enable
            ctsie: u1,
            /// Ont sample bit method enable
            onebit: u1,
            _0: u20,
        } = @ptrCast(&baseAddress[0x14]),
        gtpr: *volatile packed struct(u32) {
            psc: u8,
            gt: u8,
            _0: u16,
        } = @ptrCast(&baseAddress[0x18]),

        pub fn init(self: @This(), apb2clock: u32, baudrate: u32) void {
            if (self.cr1.over8 == .@"8") {
                @panic("Oversampling mode 8 is not supported");
            }

            self.brr.integer.mantissa = @intCast((apb2clock + (baudrate / 2)) / baudrate);

            self.cr1.ue = true;
            self.cr1.te = true;
        }

        pub fn send(self: @This(), bytes: []const u8) void {
            if (self.cr1.ue) {
                for (bytes) |byte| {
                    while (self.sr.txe == 0) {}
                    self.dr.data = byte;
                }

                while (self.sr.tc == 0) {}
            }
        }

        pub fn deinit(self: @This()) void {
            self.cr1.ue = false;
        }
    };
}
