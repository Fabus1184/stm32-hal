/// Basic Mode Control Register
const bmcr = packed struct(u16) {
    _0: u7,
    /// Collision test
    ct: u1,
    /// Duplex mode
    dm: enum(u1) {
        half = 0,
        full = 1,
    },
    /// Restart auto-negotiation
    ranc: u1,
    /// Isolate
    iso: u1,
    /// Power down
    pd: u1,
    /// Auto-negotiation enable
    ane: u1,
    /// Speed select
    ss: enum(u1) {
        @"100M" = 1,
        @"10M" = 0,
    },
    /// Loopback mode
    lb: u1,
    /// Reset
    rst: u1,
};

/// Basic Mode Status Register
const bmsr = packed struct(u16) {
    /// Extended capability
    ec: u1,
    /// Jabber detect
    jd: u1,
    /// Link status
    ls: enum(u1) {
        down = 0,
        up = 1,
    },
    /// Auto-negotiation ability
    an: u1,
    /// Remote fault
    rf: u1,
    /// Auto-negotiation complete
    anc: u1,
    /// Preamble suppression
    ps: u1,
    _0: u4,
    /// 10BASE-T half duplex
    hd10: u1,
    /// 10BASE-T full duplex
    fd10: u1,
    /// 100BASE-TX half duplex
    hd100: u1,
    /// 100BASE-TX full duplex
    fd100: u1,
    /// 100BASE-T4
    t4: u1,
};

pub const Register = enum(u5) {
    /// Basic Mode Control Register
    bmcr = 0,
    /// Basic Mode Status Register
    bmsr = 1,
    /// PHY Identifier Register 1
    idr1 = 2,
    /// PHY Identifier Register 2
    idr2 = 3,

    pub fn registerType(self: @This()) type {
        return switch (self) {
            .bmcr => bmcr,
            .bmsr => bmsr,
            .idr1 => u16,
            .idr2 => u16,
        };
    }
};
