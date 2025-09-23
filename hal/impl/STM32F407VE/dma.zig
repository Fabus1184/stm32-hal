const std = @import("std");

const Register = @import("../register.zig").Register;

pub const isr = packed struct(u32) {
    /// Stream 0 FIFO error interrupt flag
    feif0: bool,
    _0: u1,
    /// Stream 0 Direct mode error interrupt flag
    dmeif0: bool,
    /// Stream 0 Transfer error interrupt flag
    teif0: bool,
    /// Stream 0 Half transfer interrupt flag
    htif0: bool,
    /// Stream 0 Transfer complete interrupt flag
    tcif0: bool,
    /// Stream 1 FIFO error interrupt flag
    feif1: bool,
    _1: u1,
    /// Stream 1 Direct mode error interrupt flag
    dmeif1: bool,
    /// Stream 1 Transfer error interrupt flag
    teif1: bool,
    /// Stream 1 Half transfer interrupt flag
    htif1: bool,
    /// Stream 1 Transfer complete interrupt flag
    tcif1: bool,
    _2: u4,
    /// Stream 2 FIFO error interrupt flag
    feif2: bool,
    _3: u1,
    /// Stream 2 Direct mode error interrupt flag
    dmeif2: bool,
    /// Stream 2 Transfer error interrupt flag
    teif2: bool,
    /// Stream 2 Half transfer interrupt flag
    htif2: bool,
    /// Stream 2 Transfer complete interrupt flag
    tcif2: bool,
    /// Stream 3 FIFO error interrupt flag
    feif3: bool,
    _4: u1,
    /// Stream 3 Direct mode error interrupt flag
    dmeif3: bool,
    /// Stream 3 Transfer error interrupt flag
    teif3: bool,
    /// Stream 3 Half transfer interrupt flag
    htif3: bool,
    /// Stream 3 Transfer complete interrupt flag
    tcif3: bool,
    _5: u4,
};

pub const scr = packed struct(u32) {
    /// Stream enable / flag stream ready when read low
    en: bool,
    /// Direct mode error interrupt enable
    dmeie: bool,
    /// Transfer error interrupt enable
    teie: bool,
    /// Half transfer interrupt enable
    htie: bool,
    /// Transfer complete interrupt enable
    tcie: bool,
    /// Peripheral flow controller
    pfctrl: enum(u1) {
        dma = 0,
        peripheral = 1,
    } = @enumFromInt(0),
    /// Data transfer direction
    dir: enum(u2) {
        peripheralToMemory = 0b00,
        memoryToPeripheral = 0b01,
        memoryToMemory = 0b10,
        _,
    } = @enumFromInt(0),
    /// Circular mode
    circ: bool,
    /// Peripheral increment mode
    pinc: bool,
    /// Memory increment mode
    minc: bool,
    /// Peripheral data size
    psize: enum(u2) {
        byte = 0b00,
        halfWord = 0b01,
        word = 0b10,
        _,
    } = @enumFromInt(0),
    /// Memory data size
    msize: enum(u2) {
        byte = 0b00,
        halfWord = 0b01,
        word = 0b10,
        _,
    } = @enumFromInt(0),
    /// Peripheral increment offset size
    pincos: bool,
    /// Priority level
    pl: enum(u2) {
        low = 0b00,
        medium = 0b01,
        high = 0b10,
        veryHigh = 0b11,
    } = @enumFromInt(0),
    /// Double buffer mode
    dbm: bool,
    /// Current target (only in double buffer mode)
    ct: bool,
    _0: u1,
    /// Peripheral burst transfer configuration
    pburst: enum(u2) {
        single = 0b00,
        incr4 = 0b01,
        incr8 = 0b10,
        incr16 = 0b11,
    } = @enumFromInt(0),
    /// Memory burst transfer configuration
    mburst: enum(u2) {
        single = 0b00,
        incr4 = 0b01,
        incr8 = 0b10,
        incr16 = 0b11,
    } = @enumFromInt(0),
    /// Channel selection
    chsel: u3,
    _1: u4,
};

pub const ndtr = packed struct(u32) {
    /// Number of data items to transfer
    ndt: u16,
    _0: u16,
};

pub const fcr = packed struct(u32) {
    /// FIFO threshold selection
    fth: enum(u2) {
        quarter = 0b00,
        half = 0b01,
        threeQuarters = 0b10,
        full = 0b11,
    },
    /// Direct mode disable
    dmdis: bool,
    /// FIFO status
    fs: enum(u3) {
        lessThanOneQuarter = 0b000,
        lessThanHalf = 0b001,
        lessThanThreeQuarters = 0b010,
        lessThanFull = 0b011,
        empty = 0b100,
        full = 0b101,
        _,
    },
    _0: u1,
    /// FIFO error interrupt enable
    feie: bool,
    _1: u24,
};

pub fn Dma(baseAddress: [*]align(4) volatile u8) type {
    return struct {
        /// Low interrupt status register
        lisr: Register(isr) = .{ .ptr = @ptrCast(&baseAddress[0x00]) },
        /// High interrupt status register
        hisr: Register(isr) = .{ .ptr = @ptrCast(&baseAddress[0x04]) },
        /// Low interrupt flag clear register
        lifcr: Register(isr) = .{ .ptr = @ptrCast(&baseAddress[0x08]) },
        /// High interrupt flag clear register
        hifcr: Register(isr) = .{ .ptr = @ptrCast(&baseAddress[0x0C]) },

        /// DMA Streams
        streams: [8]Stream = [_]Stream{
            .{
                .scr = .{ .ptr = @ptrCast(&baseAddress[0x10]) },
                .ndtr = .{ .ptr = @ptrCast(&baseAddress[0x14]) },
                .par = @ptrCast(&baseAddress[0x18]),
                .m0ar = @ptrCast(&baseAddress[0x1C]),
                .m1ar = @ptrCast(&baseAddress[0x20]),
                .fcr = .{ .ptr = @ptrCast(&baseAddress[0x24]) },
            },
            .{
                .scr = .{ .ptr = @ptrCast(&baseAddress[0x28]) },
                .ndtr = .{ .ptr = @ptrCast(&baseAddress[0x2C]) },
                .par = @ptrCast(&baseAddress[0x30]),
                .m0ar = @ptrCast(&baseAddress[0x34]),
                .m1ar = @ptrCast(&baseAddress[0x38]),
                .fcr = .{ .ptr = @ptrCast(&baseAddress[0x3C]) },
            },
            .{
                .scr = .{ .ptr = @ptrCast(&baseAddress[0x40]) },
                .ndtr = .{ .ptr = @ptrCast(&baseAddress[0x44]) },
                .par = @ptrCast(&baseAddress[0x48]),
                .m0ar = @ptrCast(&baseAddress[0x4C]),
                .m1ar = @ptrCast(&baseAddress[0x50]),
                .fcr = .{ .ptr = @ptrCast(&baseAddress[0x54]) },
            },
            .{
                .scr = .{ .ptr = @ptrCast(&baseAddress[0x58]) },
                .ndtr = .{ .ptr = @ptrCast(&baseAddress[0x5C]) },
                .par = @ptrCast(&baseAddress[0x60]),
                .m0ar = @ptrCast(&baseAddress[0x64]),
                .m1ar = @ptrCast(&baseAddress[0x68]),
                .fcr = .{ .ptr = @ptrCast(&baseAddress[0x6C]) },
            },
            .{
                .scr = .{ .ptr = @ptrCast(&baseAddress[0x70]) },
                .ndtr = .{ .ptr = @ptrCast(&baseAddress[0x74]) },
                .par = @ptrCast(&baseAddress[0x78]),
                .m0ar = @ptrCast(&baseAddress[0x7C]),
                .m1ar = @ptrCast(&baseAddress[0x80]),
                .fcr = .{ .ptr = @ptrCast(&baseAddress[0x84]) },
            },
            .{
                .scr = .{ .ptr = @ptrCast(&baseAddress[0x88]) },
                .ndtr = .{ .ptr = @ptrCast(&baseAddress[0x8C]) },
                .par = @ptrCast(&baseAddress[0x90]),
                .m0ar = @ptrCast(&baseAddress[0x94]),
                .m1ar = @ptrCast(&baseAddress[0x98]),
                .fcr = .{ .ptr = @ptrCast(&baseAddress[0x9C]) },
            },
            .{
                .scr = .{ .ptr = @ptrCast(&baseAddress[0xA0]) },
                .ndtr = .{ .ptr = @ptrCast(&baseAddress[0xA4]) },
                .par = @ptrCast(&baseAddress[0xA8]),
                .m0ar = @ptrCast(&baseAddress[0xAC]),
                .m1ar = @ptrCast(&baseAddress[0xB0]),
                .fcr = .{ .ptr = @ptrCast(&baseAddress[0xB4]) },
            },
            .{
                .scr = .{ .ptr = @ptrCast(&baseAddress[0xB8]) },
                .ndtr = .{ .ptr = @ptrCast(&baseAddress[0xBC]) },
                .par = @ptrCast(&baseAddress[0xC0]),
                .m0ar = @ptrCast(&baseAddress[0xC4]),
                .m1ar = @ptrCast(&baseAddress[0xC8]),
                .fcr = .{ .ptr = @ptrCast(&baseAddress[0xCC]) },
            },
        },

        const Stream = struct {
            /// configuration register
            scr: Register(scr),
            /// number of data register
            ndtr: Register(ndtr),
            /// peripheral address register
            par: *volatile u32,
            /// memory 0 address register
            m0ar: *volatile u32,
            /// memory 1 address register
            m1ar: *volatile u32,
            /// FIFO control register
            fcr: Register(fcr),
        };

        pub fn ackChannelInterrupts(self: @This(), streamNumber: u3) struct { feif: bool, dmeif: bool, teif: bool, htif: bool, tcif: bool } {
            const reg = if (streamNumber < 4) self.lisr.load() else self.hisr.load();
            const offset: u2 = @intCast(streamNumber % 4);
            const feif = switch (offset) {
                0 => reg.feif0,
                1 => reg.feif1,
                2 => reg.feif2,
                3 => reg.feif3,
            };
            const dmeif = switch (offset) {
                0 => reg.dmeif0,
                1 => reg.dmeif1,
                2 => reg.dmeif2,
                3 => reg.dmeif3,
            };
            const teif = switch (offset) {
                0 => reg.teif0,
                1 => reg.teif1,
                2 => reg.teif2,
                3 => reg.teif3,
            };
            const htif = switch (offset) {
                0 => reg.htif0,
                1 => reg.htif1,
                2 => reg.htif2,
                3 => reg.htif3,
            };
            const tcif = switch (offset) {
                0 => reg.tcif0,
                1 => reg.tcif1,
                2 => reg.tcif2,
                3 => reg.tcif3,
            };

            const regPtr = if (streamNumber < 4) &self.lifcr else &self.hifcr;
            switch (offset) {
                0 => regPtr.modify(.{ .feif0 = true, .dmeif0 = true, .teif0 = true, .htif0 = true, .tcif0 = true }),
                1 => regPtr.modify(.{ .feif1 = true, .dmeif1 = true, .teif1 = true, .htif1 = true, .tcif1 = true }),
                2 => regPtr.modify(.{ .feif2 = true, .dmeif2 = true, .teif2 = true, .htif2 = true, .tcif2 = true }),
                3 => regPtr.modify(.{ .feif3 = true, .dmeif3 = true, .teif3 = true, .htif3 = true, .tcif3 = true }),
            }

            return .{ .feif = feif, .dmeif = dmeif, .teif = teif, .htif = htif, .tcif = tcif };
        }
    };
}
