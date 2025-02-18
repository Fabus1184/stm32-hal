pub const Ipv4Header = packed struct {
    ihl: u4,
    version: enum(u4) {
        Ipv4 = 4,
        _,
    },
    ecn: u2,
    dscp: u6,
    total_length: u16,
    identification: u16,
    fragment_offset: u13,
    flags: packed struct(u3) {
        reserved: u1,
        df: u1,
        mf: u1,
    },
    ttl: u8,
    protocol: enum(u8) {
        icmp = 0x01,
        tcp = 0x06,
        udp = 0x11,
        _,
    },
    header_checksum: u16,
    source_address: Ipv4Address,
    destination_address: Ipv4Address,
};

pub const Ipv4Address = packed struct(u32) { a: u8, b: u8, c: u8, d: u8 };
