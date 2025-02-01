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
const macffr = packed struct(u32) { pm: u1, hu: u1, hm: u1, daif: u1, pam: u1, bfd: u1, pcf: u2, saif: u1, saf: u1, hpf: u1, _0: u20, ra: u1 };

const macmiiar = packed struct(u32) { mb: u1, mw: u1, cr: u4, mr: u5, pa: u5, _0: u16 };

const macfcr = packed struct(u32) { fcb_bpa: u1, tfce: u1, rfce: u1, upfd: u1, plt: u2, _0: u1, zqpd: u1, _1: u8, pt: u16 };
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
    ts: u1,
    tpss: u1,
    tbus: u1,
    tjts: u1,
    ros: u1,
    tus: u1,
    rs: u1,
    rbus: u1,
    rpss: u1,
    rwts: u1,
    ets: u1,
    _0: u2,
    fbes: u1,
    ers: u1,
    ais: u1,
    nis: u1,
    rps: u3,
    tps: u3,
    ebs: u3,
    _1: u1,
    mmcs: u1,
    pmts: u1,
    tsts: u1,
    _2: u2,
};
const dmaomr = packed struct(u32) { _0: u1, sr: u1, osf: u1, rtc: u2, _1: u1, fugf: u1, fef: u1, _2: u5, st: u1, ttc: u3, _3: u3, ftf: u1, tsf: u1, _4: u2, dfrf: u1, rsf: u1, dtcefd: u1, _5: u5 };
const dmaier = packed struct(u32) { tie: u1, tpsie: u1, tbuie: u1, tjtie: u1, roie: u1, tuie: u1, rie: u1, rbuie: u1, rpsie: u1, rwtie: u1, etie: u1, _0: u2, fbeie: u1, erie: u1, aise: u1, nise: u1, _1: u15 };
const dmamfbocr = packed struct(u32) { mfc: u16, omfc: u1, mfa: u11, ofoc: u1, _0: u3 };

pub fn Ethernet(baseAddress: [*]align(4) volatile u8) type {
    return struct {
        // MAC registers
        maccr: *volatile maccr = @ptrCast(&baseAddress[0x00]),
        macffr: *volatile macffr = @ptrCast(&baseAddress[0x04]),
        machthr: *volatile u32 = @ptrCast(&baseAddress[0x08]),
        machtlr: *volatile u32 = @ptrCast(&baseAddress[0x0C]),
        macmiiar: *volatile macmiiar = @ptrCast(&baseAddress[0x10]),
        macmiidr: *volatile packed struct(u32) { value: u16, _0: u16 } = @ptrCast(&baseAddress[0x14]),
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
        dmabmr: *volatile dmabmr = @ptrCast(&baseAddress[0x1000]),
        dmatpdr: *volatile u32 = @ptrCast(&baseAddress[0x1004]),
        dmarpdr: *volatile u32 = @ptrCast(&baseAddress[0x1008]),
        dmardlar: *volatile u32 = @ptrCast(&baseAddress[0x100C]),
        dmatdlar: *volatile u32 = @ptrCast(&baseAddress[0x1010]),
        dmasr: *volatile dmasr = @ptrCast(&baseAddress[0x1014]),
        dmaomr: *volatile dmaomr = @ptrCast(&baseAddress[0x1018]),
        dmaier: *volatile dmaier = @ptrCast(&baseAddress[0x101C]),
        dmamfbocr: *volatile dmamfbocr = @ptrCast(&baseAddress[0x1020]),
        dmarswtr: *volatile packed struct(u32) { rswtc: u8, _0: u24 } = @ptrCast(&baseAddress[0x1024]),
        // DMA channel registers
        dmachtdr: *volatile u32 = @ptrCast(&baseAddress[0x1048]),
        dmachrdr: *volatile u32 = @ptrCast(&baseAddress[0x104C]),
        dmachtbar: *volatile u32 = @ptrCast(&baseAddress[0x1050]),
        dmachrbar: *volatile u32 = @ptrCast(&baseAddress[0x1054]),
    };
}
