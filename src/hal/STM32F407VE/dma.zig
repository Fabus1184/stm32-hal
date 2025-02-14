const Register = @import("../../register.zig").Register;

pub const isr = packed struct(u32) {
    /// Stream 0 FIFO error interrupt flag
    feif0: u1,
    _0: u1,
    /// Stream 0 Direct mode error interrupt flag
    dmeif0: u1,
    /// Stream 0 Transfer error interrupt flag
    teif0: u1,
    /// Stream 0 Half transfer interrupt flag
    htif0: u1,
    /// Stream 0 Transfer complete interrupt flag
    tcif0: u1,
    /// Stream 0 FIFO error interrupt flag
    feif1: u1,
    _1: u1,
    /// Stream 1 Direct mode error interrupt flag
    dmeif1: u1,
    /// Stream 1 Transfer error interrupt flag
    teif1: u1,
    /// Stream 1 Half transfer interrupt flag
    htif1: u1,
    /// Stream 1 Transfer complete interrupt flag
    tcif1: u1,
    _2: u4,
    /// Stream 2 FIFO error interrupt flag
    feif2: u1,
    _3: u1,
    /// Stream 2 Direct mode error interrupt flag
    dmeif2: u1,
    /// Stream 2 Transfer error interrupt flag
    teif2: u1,
    /// Stream 2 Half transfer interrupt flag
    htif2: u1,
    /// Stream 2 Transfer complete interrupt flag
    tcif2: u1,
    /// Stream 3 FIFO error interrupt flag
    feif3: u1,
    _4: u1,
    /// Stream 3 Direct mode error interrupt flag
    dmeif3: u1,
    /// Stream 3 Transfer error interrupt flag
    teif3: u1,
    /// Stream 3 Half transfer interrupt flag
    htif3: u1,
    /// Stream 3 Transfer complete interrupt flag
    tcif3: u1,
    _5: u4,
};

pub const scr = packed struct(u32) {
    /// Stream enable / flag stream ready when read low
    en: u1 = 0,
    /// Direct mode error interrupt enable
    dmeie: u1 = 0,
    /// Transfer error interrupt enable
    teie: u1 = 0,
    /// Half transfer interrupt enable
    htie: u1 = 0,
    /// Transfer complete interrupt enable
    tcie: u1 = 0,
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
    circ: u1 = 0,
    /// Peripheral increment mode
    pinc: u1 = 0,
    /// Memory increment mode
    minc: u1 = 0,
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
    pincos: u1 = 0,
    /// Priority level
    pl: enum(u2) {
        low = 0b00,
        medium = 0b01,
        high = 0b10,
        veryHigh = 0b11,
    } = @enumFromInt(0),
    /// Double buffer mode
    dbm: u1 = 0,
    /// Current target (only in double buffer mode)
    ct: u1 = 0,
    _0: u1 = 0,
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
    chsel: u3 = 0,
    _1: u4 = 0,
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
    dmdis: u1,
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
    feie: u1,
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
        /// Stream 0 configuration register
        s0cr: Register(scr) = .{ .ptr = @ptrCast(&baseAddress[0x10]) },
        /// Stream 0 number of data register
        s0ndtr: Register(ndtr) = .{ .ptr = @ptrCast(&baseAddress[0x14]) },
        /// Stream 0 peripheral address register
        s0par: *volatile u32 = @ptrCast(&baseAddress[0x18]),
        /// Stream 0 memory 0 address register
        s0m0ar: *volatile u32 = @ptrCast(&baseAddress[0x1C]),
        /// Stream 0 memory 1 address register
        s0m1ar: *volatile u32 = @ptrCast(&baseAddress[0x20]),
        /// Stream 0 FIFO control register
        s0fcr: Register(fcr) = .{ .ptr = @ptrCast(&baseAddress[0x24]) },
        /// Stream 1 configuration register
        s1cr: Register(scr) = .{ .ptr = @ptrCast(&baseAddress[0x28]) },
        /// Stream 1 number of data register
        s1ndtr: Register(ndtr) = .{ .ptr = @ptrCast(&baseAddress[0x2C]) },
        /// Stream 1 peripheral address register
        s1par: *volatile u32 = @ptrCast(&baseAddress[0x30]),
        /// Stream 1 memory 0 address register
        s1m0ar: *volatile u32 = @ptrCast(&baseAddress[0x34]),
        /// Stream 1 memory 1 address register
        s1m1ar: *volatile u32 = @ptrCast(&baseAddress[0x38]),
        /// Stream 1 FIFO control register
        s1fcr: Register(fcr) = .{ .ptr = @ptrCast(&baseAddress[0x3C]) },
        /// Stream 2 configuration register
        s2cr: Register(scr) = .{ .ptr = @ptrCast(&baseAddress[0x40]) },
        /// Stream 2 number of data register
        s2ndtr: Register(ndtr) = .{ .ptr = @ptrCast(&baseAddress[0x44]) },
        /// Stream 2 peripheral address register
        s2par: *volatile u32 = @ptrCast(&baseAddress[0x48]),
        /// Stream 2 memory 0 address register
        s2m0ar: *volatile u32 = @ptrCast(&baseAddress[0x4C]),
        /// Stream 2 memory 1 address register
        s2m1ar: *volatile u32 = @ptrCast(&baseAddress[0x50]),
        /// Stream 2 FIFO control register
        s2fcr: Register(fcr) = .{ .ptr = @ptrCast(&baseAddress[0x54]) },
        /// Stream 3 configuration register
        s3cr: Register(scr) = .{ .ptr = @ptrCast(&baseAddress[0x58]) },
        /// Stream 3 number of data register
        s3ndtr: Register(ndtr) = .{ .ptr = @ptrCast(&baseAddress[0x5C]) },
        /// Stream 3 peripheral address register
        s3par: *volatile u32 = @ptrCast(&baseAddress[0x60]),
        /// Stream 3 memory 0 address register
        s3m0ar: *volatile u32 = @ptrCast(&baseAddress[0x64]),
        /// Stream 3 memory 1 address register
        s3m1ar: *volatile u32 = @ptrCast(&baseAddress[0x68]),
        /// Stream 3 FIFO control register
        s3fcr: Register(fcr) = .{ .ptr = @ptrCast(&baseAddress[0x6C]) },
        /// Stream 4 configuration register
        s4cr: Register(scr) = .{ .ptr = @ptrCast(&baseAddress[0x70]) },
        /// Stream 4 number of data register
        s4ndtr: *align(4) volatile ndtr = @ptrCast(&baseAddress[0x74]),
        /// Stream 4 peripheral address register
        s4par: *volatile u32 = @ptrCast(&baseAddress[0x78]),
        /// Stream 4 memory 0 address register
        s4m0ar: *volatile u32 = @ptrCast(&baseAddress[0x7C]),
        /// Stream 4 memory 1 address register
        s4m1ar: *volatile u32 = @ptrCast(&baseAddress[0x80]),
        /// Stream 4 FIFO control register
        s4fcr: Register(fcr) = .{ .ptr = @ptrCast(&baseAddress[0x84]) },
        /// Stream 5 configuration register
        s5cr: Register(scr) = .{ .ptr = @ptrCast(&baseAddress[0x88]) },
        /// Stream 5 number of data register
        s5ndtr: Register(ndtr) = .{ .ptr = @ptrCast(&baseAddress[0x8C]) },
        /// Stream 5 peripheral address register
        s5par: *volatile u32 = @ptrCast(&baseAddress[0x90]),
        /// Stream 5 memory 0 address register
        s5m0ar: *volatile u32 = @ptrCast(&baseAddress[0x94]),
        /// Stream 5 memory 1 address register
        s5m1ar: *volatile u32 = @ptrCast(&baseAddress[0x98]),
        /// Stream 5 FIFO control register
        s5fcr: Register(fcr) = .{ .ptr = @ptrCast(&baseAddress[0x9C]) },
        /// Stream 6 configuration register
        s6cr: Register(scr) = .{ .ptr = @ptrCast(&baseAddress[0xA0]) },
        /// Stream 6 number of data register
        s6ndtr: Register(ndtr) = .{ .ptr = @ptrCast(&baseAddress[0xA4]) },
        /// Stream 6 peripheral address register
        s6par: *volatile u32 = @ptrCast(&baseAddress[0xA8]),
        /// Stream 6 memory 0 address register
        s6m0ar: *volatile u32 = @ptrCast(&baseAddress[0xAC]),
        /// Stream 6 memory 1 address register
        s6m1ar: *volatile u32 = @ptrCast(&baseAddress[0xB0]),
        /// Stream 6 FIFO control register
        s6fcr: Register(fcr) = .{ .ptr = @ptrCast(&baseAddress[0xB4]) },
        /// Stream 7 configuration register
        s7cr: Register(scr) = .{ .ptr = @ptrCast(&baseAddress[0xB8]) },
        /// Stream 7 number of data register
        s7ndtr: Register(ndtr) = .{ .ptr = @ptrCast(&baseAddress[0xBC]) },
        /// Stream 7 peripheral address register
        s7par: *volatile u32 = @ptrCast(&baseAddress[0xC0]),
        /// Stream 7 memory 0 address register
        s7m0ar: *volatile u32 = @ptrCast(&baseAddress[0xC4]),
        /// Stream 7 memory 1 address register
        s7m1ar: *volatile u32 = @ptrCast(&baseAddress[0xC8]),
        /// Stream 7 FIFO control register
        s7fcr: Register(fcr) = .{ .ptr = @ptrCast(&baseAddress[0xCC]) },
    };
}
