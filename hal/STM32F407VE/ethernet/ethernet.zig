const std = @import("std");

const phy = @import("phy.zig");

const maccr = packed struct(u32) {
    _0: u2,
    /// Receiver enable
    re: u1,
    /// Transmitter enable
    te: u1,
    /// Deferral check
    dc: u1,
    /// Back-off limit
    bl: u2,
    /// Automatic Pad/CRC stripping
    apcs: u1,
    _1: u1,
    /// Retry disables
    rd: u1,
    /// IPv4 checksum offload
    ipco: u1,
    /// full duplex mode
    dm: u1,
    /// loopback mode
    lm: u1,
    /// Receive own disable
    rod: u1,
    /// Fast Ethernet speed
    fes: enum(u1) {
        @"10M" = 0,
        @"100M" = 1,
    },
    _2: u1,
    /// Carrier sense disable
    csd: u1,
    /// Interframe gap
    ifg: u3,
    _3: u2,
    /// Jabber disable
    jd: u1,
    /// Watchdog disable
    wd: u1,
    _4: u1,
    /// CRC stripping for Type frames
    cstf: u1,
    _5: u6,
};
const macffr = packed struct(u32) {
    /// Promiscuous mode
    pm: u1,
    /// Hash unicast
    hu: u1,
    /// Hash multicast
    hm: u1,
    /// Destination address inverse filtering
    daif: u1,
    /// Pass all multicast
    pam: u1,
    /// Broadcast frames disable
    bfd: u1,
    /// Pass control frames
    pcf: u2,
    /// Source address inverse filtering
    saif: u1,
    /// Source address filter
    saf: u1,
    /// Hash or perfect filter
    hpf: u1,
    _0: u20,
    /// Receive all
    ra: u1,
};

const macmiiar = packed struct(u32) {
    /// MII busy
    mb: bool,
    /// MII write
    mw: u1,
    /// Clock range
    cr: u3,
    _0: u1,
    /// MII register
    mr: u5,
    /// PHY address
    pa: u5,
    _1: u16,
};

const macfcr = packed struct(u32) {
    /// Flow control busy/back pressure activate
    fcbBpa: u1,
    /// Transmit flow control enable
    tfce: u1,
    /// Receive flow control enable
    rfce: u1,
    /// Unicast pause frame detect
    upfd: u1,
    /// Pause low threshold
    plt: u2,
    _0: u1,
    /// Zero-quanta pause disable
    zqpd: u1,
    _1: u8,
    /// pause time
    pt: u16,
};
const macvlantr = packed struct(u32) { vlanti: u16, vlantc: u1, _0: u15 };

const macpmtcsr = packed struct(u32) {
    /// Power down
    pd: u1,
    /// Magic packet enable
    mpe: u1,
    /// Wake-up frame enable
    wfe: u1,
    _0: u2,
    /// Magic packet received
    mpr: u1,
    /// Wake-up frame received
    wfr: u1,
    _1: u2,
    /// Global unicast
    gu: u1,
    _2: u21,
    /// Wake-up frame filter register pointer reset
    wffrrr: u1,
};

const macdbgr = packed struct(u32) {
    /// MAC MII receive protocol engine active
    mmrpea: u1,
    /// MAC small FIFO read/write controller status
    msfrwcs: u2,
    _0: u1,
    /// Rx FIFO write controller active
    rfwra: u1,
    /// Rx FIFO read controller status
    rfrcs: u2,
    _1: u1,
    /// Rx FIFO fill level
    rffl: u2,
    _2: u6,
    /// MAC MII transmit engine active
    mmtea: u1,
    /// MAC transmit frame controller status
    mtfcs: enum(u2) {
        /// Idle
        idle = 0,
        /// Waiting for status of previous frame or IFG/backoff period to be over
        wfs = 1,
        /// Generating and transmitting a Pause control frame (in full duplex mode)
        gptpf = 2,
        /// Transferring input frame for transmission
        tif = 3,
    },
    /// MAC transmitter in pause
    mtp: u1,
    /// Tx FIFO read status
    tfrs: u2,
    /// Tx FIFO write active
    tfwa: u1,
    _3: u1,
    /// Tx FIFO not empty
    tfne: u1,
    /// Tx FIFO full
    ttf: u1,
    _4: u6,
};

const macsr = packed struct(u32) {
    _0: u3,
    /// PMT status
    pmts: u1,
    /// MMC status
    mmcs: u1,
    /// MMC receive status
    mmcrs: u1,
    /// MMC transmit status
    mmcts: u1,
    _1: u2,
    /// Timestamp trigger status
    tsts: u1,
    _2: u22,
};
const macimr = packed struct(u32) { _0: u3, pmtim: u1, _1: u5, tstim: u1, _2: u22 };
const maca0hr = packed struct(u32) { maca0h: u16, _0: u15, mo: u1 };

const macaNhr = packed struct(u32) { maca1h: u16, _0: u8, mbc: u6, sa: u1, ae: u1 };

const mmccr = packed struct(u32) {
    /// Counter reset
    cr: u1,
    /// Counter stop rollover
    csr: u1,
    /// Reset on read
    ror: u1,
    /// MMC counter freeze
    mcf: u1,
    /// MMC counter preset
    mcp: u1,
    /// MMC counter full half preset
    mcfhp: u1,
    _0: u26,
};
const mmcrir = packed struct(u32) {
    _0: u5,
    /// Received frames CRC error status
    rfces: u1,
    /// Received frames alignment error status
    rfaes: u1,
    _1: u10,
    /// Received good unicast frames status
    rgufs: u1,
    _2: u14,
};
const mmctir = packed struct(u32) { _0: u14, tgfscs: u1, tgfmscs: u1, _1: u5, tgfs: u1, _2: u10 };
const mmcrimr = packed struct(u32) {
    _0: u5,
    /// Received frames CRC error mask
    rfcem: u1,
    /// Received frames alignment error mask
    rfaem: u1,
    _1: u10,
    /// Received good unicast frames mask
    rgufm: u1,
    _2: u14,
};
const mmctimr = packed struct(u32) { _0: u14, tgfscm: u1, tgfmscm: u1, _1: u5, tgfm: u1, _2: u10 };

const ptptscr = packed struct(u32) { tse: u1, tsfcu: u1, tssti: u1, tsstu: u1, tsite: u1, ttsaru: u1, _0: u2, tssarfe: u1, tssr: u1, tsptppsv2e: u1, tssptpoefe: u1, tssipv6fe: u1, tssipv4fe: u1, tsseme: u1, tssmrme: u1, tscnt: u2, tspffmae: u1, _1: u13 };

const dmabmr = packed struct(u32) {
    /// Software reset
    sr: u1,
    /// DMA Arbitration
    da: u1,
    /// Descriptor skip length
    dsl: u5,
    /// Enhanced descriptor format enable
    edfe: u1,
    /// Programmable burst length
    pbl: u6,
    /// Rx Tx priority ratio
    pm: u2,
    /// Fixed burst
    fb: u1,
    /// Rx DMA PBL
    rdp: u6,
    /// Use separate PBL
    usp: u1,
    /// 4xPBL mode
    fpm: u1,
    /// Address-aligned beats
    aab: u1,
    /// Mixed burst
    mb: u1,
    _0: u5,
};

const dmasr = packed struct(u32) {
    /// Transmit status
    ts: u1,
    /// Transmit process stopped status
    tpss: u1,
    /// Transmit buffer unavailable status
    tbus: u1,
    /// Transmit jabber timeout status
    tjts: u1,
    /// Receive overflow status
    ros: u1,
    /// Transmit underflow status
    tus: u1,
    /// Receive status
    rs: u1,
    /// Receive buffer unavailable status
    rbus: u1,
    /// Receive process stopped status
    rpss: u1,
    /// Receive watchdog timeout status
    rwts: u1,
    /// Early transmit status
    ets: u1,
    _0: u2,
    /// Fatal bus error status
    fbes: u1,
    /// Early receive status
    ers: u1,
    /// Abnormal interrupt summary
    ais: u1,
    /// Normal interrupt summary
    nis: u1,
    /// Receive process state
    rps: enum(u3) {
        stopped = 0b000,
        fetching = 0b001,
        waiting = 0b011,
        suspended = 0b100,
        closing = 0b101,
        transferring = 0b111,
        _,
    },
    /// Transmit process state
    tps: enum(u3) {
        stopped = 0b000,
        fetching = 0b001,
        waiting = 0b010,
        reading = 0b011,
        suspended = 0b110,
        closing = 0b111,
        _,
    },
    /// Error bits status
    ebs: u3,
    _1: u1,
    /// MMC status
    mmcs: u1,
    /// PMT status
    pmts: u1,
    /// Timestamp trigger status
    tsts: u1,
    _2: u2,
};
const dmaomr = packed struct(u32) {
    _0: u1,
    /// Start/stop receive
    sr: u1,
    /// Operate on second frame
    osf: u1,
    /// Receive threshold control
    rtc: u2,
    _1: u1,
    /// Forward undersized good frames
    fugf: u1,
    /// Forward error frames
    fef: u1,
    _2: u5,
    /// Start/stop transmit
    st: u1,
    /// Transmit threshold control
    ttc: u3,
    _3: u3,
    /// Flush transmit FIFO
    ftf: u1,
    /// Transmit store and forward
    tsf: u1,
    _4: u2,
    /// Disable flushing of received frames
    dfrf: u1,
    /// Receive store and forward
    rsf: u1,
    /// Dropping of TCP/IP checksum error frames disable
    dtcefd: u1,
    _5: u5,
};
const dmaier = packed struct(u32) {
    /// Transmit interrupt enable
    tie: u1,
    /// Transmit process stopped interrupt enable
    tpsie: u1,
    /// Transmit buffer unavailable interrupt enable
    tbuie: u1,
    /// Transmit jabber timeout interrupt enable
    tjtie: u1,
    /// Receive overflow interrupt enable
    roie: u1,
    /// Transmit underflow interrupt enable
    tuie: u1,
    /// Receive interrupt enable
    rie: u1,
    /// Receive buffer unavailable interrupt enable
    rbuie: u1,
    /// Receive process stopped interrupt enable
    rpsie: u1,
    /// Receive watchdog timeout interrupt enable
    rwtie: u1,
    /// Early transmit interrupt enable
    etie: u1,
    _0: u2,
    /// Fatal bus error interrupt enable
    fbeie: u1,
    /// Early receive interrupt enable
    erie: u1,
    /// Abnormal interrupt summary enable
    aise: u1,
    /// Normal interrupt summary enable
    nise: u1,
    _1: u15,
};
const dmamfbocr = packed struct(u32) { mfc: u16, omfc: u1, mfa: u11, ofoc: u1, _0: u3 };

pub fn Ethernet(baseAddress: [*]align(4) volatile u8) type {
    return struct {
        // MAC registers
        maccr: *volatile maccr = @ptrCast(&baseAddress[0x00]),
        /// MAC frame filter register
        macffr: *volatile macffr = @ptrCast(&baseAddress[0x04]),
        machthr: *volatile u32 = @ptrCast(&baseAddress[0x08]),
        machtlr: *volatile u32 = @ptrCast(&baseAddress[0x0C]),
        /// MAC MII address register
        macmiiar: *volatile macmiiar = @ptrCast(&baseAddress[0x10]),
        /// MAC MII data register
        macmiidr: *volatile packed struct(u32) { data: u16, _0: u16 } = @ptrCast(&baseAddress[0x14]),
        /// MAC flow control register
        macfcr: *volatile macfcr = @ptrCast(&baseAddress[0x18]),
        macvlantr: *volatile macvlantr = @ptrCast(&baseAddress[0x1C]),
        macrwuffr: *volatile u32 = @ptrCast(&baseAddress[0x28]),
        macpmtcsr: *volatile macpmtcsr = @ptrCast(&baseAddress[0x2C]),
        macdbgr: *volatile macdbgr = @ptrCast(&baseAddress[0x34]),
        macsr: *volatile macsr = @ptrCast(&baseAddress[0x38]),
        macimr: *volatile macimr = @ptrCast(&baseAddress[0x3C]),
        maca0hr: *volatile maca0hr = @ptrCast(&baseAddress[0x40]),
        maca0lr: *volatile u32 = @ptrCast(&baseAddress[0x44]),
        maca1hr: *volatile macaNhr = @ptrCast(&baseAddress[0x48]),
        maca1lr: *volatile u32 = @ptrCast(&baseAddress[0x4C]),
        maca2hr: *volatile macaNhr = @ptrCast(&baseAddress[0x50]),
        maca2lr: *volatile u32 = @ptrCast(&baseAddress[0x54]),
        maca3hr: *volatile macaNhr = @ptrCast(&baseAddress[0x58]),
        maca3lr: *volatile u32 = @ptrCast(&baseAddress[0x5C]),
        // MMC registers
        mmccr: *volatile mmccr = @ptrCast(&baseAddress[0x100]),
        mmcrir: *volatile mmcrir = @ptrCast(&baseAddress[0x104]),
        mmctir: *volatile mmctir = @ptrCast(&baseAddress[0x108]),
        mmcrimr: *volatile mmcrimr = @ptrCast(&baseAddress[0x10C]),
        mmctimr: *volatile mmctimr = @ptrCast(&baseAddress[0x110]),
        mmctfgsccr: *volatile u32 = @ptrCast(&baseAddress[0x14C]),
        mmctgfmsccr: *volatile u32 = @ptrCast(&baseAddress[0x150]),
        mmctgfcr: *volatile u32 = @ptrCast(&baseAddress[0x168]),
        mmcrfcecr: *volatile u32 = @ptrCast(&baseAddress[0x194]),
        mmcrfaecr: *volatile u32 = @ptrCast(&baseAddress[0x198]),
        mmcrgufcr: *volatile u32 = @ptrCast(&baseAddress[0x1C4]),
        // PTP registers
        ptptscr: *volatile ptptscr = @ptrCast(&baseAddress[0x700]),
        ptptssir: *volatile packed struct(u32) { stssi: u8, _0: u24 } = @ptrCast(&baseAddress[0x704]),
        ptpshr: *volatile u32 = @ptrCast(&baseAddress[0x708]),
        ptptslr: *volatile packed struct(u32) { sts: u31, stpns: u1 } = @ptrCast(&baseAddress[0x70C]),
        ptptshur: *volatile u32 = @ptrCast(&baseAddress[0x710]),
        ptptslur: *volatile packed struct(u32) { tsuss: u31, tsupns: u1 } = @ptrCast(&baseAddress[0x714]),
        ptptsar: *volatile u32 = @ptrCast(&baseAddress[0x718]),
        ptptthr: *volatile u32 = @ptrCast(&baseAddress[0x71C]),
        ptpttlr: *volatile u32 = @ptrCast(&baseAddress[0x720]),
        ptptpsr: *volatile packed struct(u32) { tsso: u1, tsttr: u1, _0: u30 } = @ptrCast(&baseAddress[0x728]),
        ptpppscr: *volatile packed struct(u32) { ppsfreq: u3, _0: u29 } = @ptrCast(&baseAddress[0x72C]),
        // DMA registers
        /// DMA bus mode register
        dmabmr: *volatile dmabmr = @ptrCast(&baseAddress[0x1000]),
        /// DMA transmit poll demand register
        dmatpdr: *volatile u32 = @ptrCast(&baseAddress[0x1004]),
        /// DMA receive poll demand register
        dmarpdr: *volatile u32 = @ptrCast(&baseAddress[0x1008]),
        /// DMA receive descriptor list address register
        dmardlar: *volatile u32 = @ptrCast(&baseAddress[0x100C]),
        /// DMA transmit descriptor list address register
        dmatdlar: *volatile u32 = @ptrCast(&baseAddress[0x1010]),
        /// DMA status register
        dmasr: *volatile dmasr = @ptrCast(&baseAddress[0x1014]),
        /// DMA operation mode register
        dmaomr: *volatile dmaomr = @ptrCast(&baseAddress[0x1018]),
        /// DMA interrupt enable register
        dmaier: *volatile dmaier = @ptrCast(&baseAddress[0x101C]),
        /// DMA missed frame and buffer overflow counter register
        dmamfbocr: *volatile dmamfbocr = @ptrCast(&baseAddress[0x1020]),
        /// DMA receive status watchdog timer register
        dmarswtr: *volatile packed struct(u32) { rswtc: u8, _0: u24 } = @ptrCast(&baseAddress[0x1024]),
        /// DMA current host transmit descriptor register
        dmachtdr: *volatile u32 = @ptrCast(&baseAddress[0x1048]),
        /// DMA current host receive descriptor register
        dmachrdr: *volatile u32 = @ptrCast(&baseAddress[0x104C]),
        /// DMA current host transmit buffer address register
        dmachtbar: *volatile u32 = @ptrCast(&baseAddress[0x1050]),
        /// DMA current host receive buffer address register
        dmachrbar: *volatile u32 = @ptrCast(&baseAddress[0x1054]),

        pub fn readPhyRegister(self: @This(), phyAddress: u5, comptime register: phy.Register) phy.Register.registerType(register) {
            while (self.macmiiar.mb) {}

            self.macmiiar.mw = 0;
            self.macmiiar.cr = 0b0111;
            self.macmiiar.mr = @intFromEnum(register);
            self.macmiiar.pa = phyAddress;

            self.macmiiar.mb = true;

            while (self.macmiiar.mb) {}

            return @bitCast(self.macmiidr.data);
        }

        pub fn writePhyRegister(self: @This(), phyAddress: u5, comptime register: phy.Register, data: phy.Register.registerType(register)) void {
            while (self.macmiiar.mb) {}

            self.macmiiar.mw = 1;
            self.macmiiar.cr = 0b0111;
            self.macmiiar.mr = @intFromEnum(register);
            self.macmiiar.pa = phyAddress;
            self.macmiidr.data = @bitCast(data);

            self.macmiiar.mb = true;

            while (self.macmiiar.mb) {}
        }

        pub fn sendFrameSync(self: @This(), frame: []const u8) !void {
            var txDescriptor1: DmaTransmitDescriptor align(4) = undefined;
            var txDescriptor2: DmaTransmitDescriptor align(4) = undefined;

            txDescriptor1 = .{
                .tdes0 = .{ .tch = 1, .ter = 0, .fs = 1, .ls = 1, .own = .cpu, .ic = 1 },
                .tdes1 = .{ .buffer1ByteCount = @intCast(frame.len), .buffer2ByteCount = 0 },
                .tdes2 = @intFromPtr(frame.ptr),
                .tdes3 = @intFromPtr(&txDescriptor2),
            };
            txDescriptor2 = .{
                .tdes0 = .{ .tch = 1, .ter = 0, .fs = 1, .ls = 1, .own = .cpu },
                .tdes1 = .{ .buffer1ByteCount = @intCast(frame.len), .buffer2ByteCount = 0 },
                .tdes2 = 0,
                .tdes3 = 0,
            };

            self.dmatdlar.* = @intFromPtr(&txDescriptor1);
            self.dmardlar.* = 0;

            self.maccr.te = 1;
            self.dmaomr.ftf = 1;
            self.dmaomr.st = 1;

            std.log.debug("sending frame with descriptor {}", .{std.json.fmt(txDescriptor1, .{})});

            txDescriptor1.tdes0.own = .dma;
            self.dmatpdr.* = 1;

            std.log.debug("waiting for frame to be sent", .{});
            while (txDescriptor1.tdes0.own == .dma) {
                if (self.dmasr.fbes == 1) {
                    std.log.err("fatal bus error, dmasr: {}", .{std.json.fmt(self.dmasr.*, .{})});
                    return error.@"fatal bus error";
                }
            }

            self.dmaomr.st = 0;

            std.log.debug("sent frame", .{});
        }

        pub fn receiveFrameSync(self: @This(), frame: []u8) !usize {
            var rxDescriptor1: DmaReceiveDescriptor align(4) = undefined;
            var rxDescriptor2: DmaReceiveDescriptor align(4) = undefined;

            rxDescriptor1 = .{
                .rdes0 = .{ .fs = 1, .ls = 1, .own = .cpu },
                .rdes1 = .{ .buffer1ByteCount = @intCast(frame.len), .buffer2ByteCount = 0, .rer = 0, .rch = 1 },
                .rdes2 = @intFromPtr(frame.ptr),
                .rdes3 = @intFromPtr(&rxDescriptor2),
            };
            rxDescriptor2 = .{
                .rdes0 = .{ .fs = 1, .ls = 1, .own = .cpu },
                .rdes1 = .{ .buffer1ByteCount = @intCast(frame.len), .buffer2ByteCount = 0, .rer = 0, .rch = 1 },
                .rdes2 = 0,
                .rdes3 = 0,
            };

            self.dmardlar.* = @intFromPtr(&rxDescriptor1);
            self.dmatdlar.* = 0;

            self.maccr.re = 1;
            self.dmaomr.sr = 1;

            std.log.info("receiving frame with descriptor {}", .{std.json.fmt(rxDescriptor1, .{})});

            rxDescriptor1.rdes0.own = .dma;
            self.dmarpdr.* = 1;

            std.log.debug("waiting for frame to be received", .{});
            while (rxDescriptor1.rdes0.own == .dma) {
                if (self.dmasr.fbes == 1) {
                    std.log.err("fatal bus error, dmasr: {}", .{std.json.fmt(self.dmasr.*, .{})});
                    return error.@"fatal bus error";
                }
            }

            self.dmaomr.sr = 0;

            std.log.info("received frame with length {}", .{rxDescriptor1.rdes0.fl});

            return rxDescriptor1.rdes0.fl;
        }
    };
}

pub const DmaTransmitDescriptor = packed struct(u128) {
    tdes0: packed struct(u32) {
        /// deferred bit
        df: u1 = 0,
        /// underflow error
        uf: u1 = 0,
        /// excessive deferral
        ed: u1 = 0,
        /// collision count
        cc: u4 = 0,
        /// VLAN frame
        vf: u1 = 0,
        /// excessive collision
        ec: u1 = 0,
        /// late collision
        lco: u1 = 0,
        /// no carrier
        nc: u1 = 0,
        /// loss of carrier
        lca: u1 = 0,
        /// IP payload error
        ipe: u1 = 0,
        /// frame flushed
        ff: u1 = 0,
        /// jabber timeout
        jt: u1 = 0,
        /// error summary
        es: u1 = 0,
        /// IP header error
        ihe: u1 = 0,
        /// transmit time stamp status
        ttss: u1 = 0,
        _0: u2 = 0,
        /// second address chained
        tch: u1,
        /// transmit end of ring
        ter: u1,
        /// Checksum insertion control
        cic: enum(u2) {
            disabled = 0b00,
            onlyIpHeader = 0b01,
            ipHeaderAndPayload = 0b10,
            all = 0b11,
        } = .disabled,
        _1: u1 = 0,
        /// transmit timestamp enable
        ttse: u1 = 0,
        /// disable padding
        dp: u1 = 0,
        /// disable crc
        dc: u1 = 0,
        /// first segment
        fs: u1,
        /// last segment
        ls: u1,
        /// interrupt on completion
        ic: u1 = 0,
        /// own bit
        own: enum(u1) {
            cpu = 0,
            dma = 1,
        },
    },
    /// Buffer sizes
    tdes1: packed struct(u32) {
        buffer1ByteCount: u13,
        _0: u3 = 0, // reserved
        buffer2ByteCount: u13,
        _1: u3 = 0, // reserved
    },
    /// Buffer 1 pointer
    tdes2: u32,
    /// Buffer 2 pointer (if used)
    tdes3: u32,
};

pub const DmaReceiveDescriptor = packed struct(u128) {
    rdes0: packed struct(u32) {
        /// Payload checksum error / extended status available
        pce_esa: u1 = 0,
        /// CRC error
        ce: u1 = 0,
        /// Dribble bit error
        dbe: u1 = 0,
        /// Receive error
        re: u1 = 0,
        /// Receive watchdog timeout
        rwt: u1 = 0,
        /// Frame type
        ft: u1 = 0,
        /// Late collision
        lc: u1 = 0,
        /// IP header checksum error / time stamp valid
        iphce_tsv: u1 = 0,
        /// Last descriptor
        ls: u1,
        /// First descriptor
        fs: u1,
        /// VLAN tag
        vlan: u1 = 0,
        /// Overflow error
        oe: u1 = 0,
        /// Length error
        le: u1 = 0,
        /// Source address filter fail
        saf: u1 = 0,
        /// Descriptor error
        de: u1 = 0,
        /// Error summary
        es: u1 = 0,
        /// Frame length
        fl: u14 = 0,
        /// Destination address filter fail
        afm: u1 = 0,
        /// Own bit
        own: enum(u1) {
            cpu = 0,
            dma = 1,
        },
    },
    rdes1: packed struct(u32) {
        buffer1ByteCount: u13,
        _0: u1 = 0,
        /// Second address chained
        rch: u1,
        /// Receive end of ring
        rer: u1,
        buffer2ByteCount: u13,
        _1: u2 = 0,
        /// Disable interrupt on completion
        dic: u1 = 0,
    },
    /// Buffer 1 address
    rdes2: u32,
    /// Buffer 2 address (if used)
    rdes3: u32,
};
