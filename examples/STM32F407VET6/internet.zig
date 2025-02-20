const std = @import("std");

pub const MacAddress = packed struct(u48) {
    a: u8,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
    f: u8,

    const SIZE: usize = @bitSizeOf(@This()) / 8;

    pub fn isBroadcast(self: @This()) bool {
        return std.meta.eql(self, .{ .a = 0xFF, .b = 0xFF, .c = 0xFF, .d = 0xFF, .e = 0xFF, .f = 0xFF });
    }
};

pub const EthernetFrame = struct {
    const EthernetHeader = packed struct(u112) {
        destination: MacAddress,
        source: MacAddress,
        etherType: u16,

        const SIZE: usize = @bitSizeOf(@This()) / 8;
    };

    header: EthernetHeader,
    payload: []const u8,

    pub fn fromBigEndianBytes(bytes: []const u8) @This() {
        var i: usize = 0;

        var header = std.mem.bytesToValue(EthernetHeader, bytes[i..]);
        header.etherType = std.mem.bigToNative(u16, header.etherType);
        i += EthernetHeader.SIZE;

        return .{
            .header = header,
            .payload = bytes[i..],
        };
    }

    pub fn make(dest: MacAddress, source: MacAddress, etherType: u16, payload: []const u8, buffer: []u8) usize {
        var i: usize = 0;

        const header = EthernetHeader{
            .destination = dest,
            .source = source,
            .etherType = std.mem.nativeToBig(u16, etherType),
        };
        @memcpy(buffer[i .. i + EthernetHeader.SIZE], std.mem.toBytes(header)[0..EthernetHeader.SIZE]);
        i += EthernetHeader.SIZE;

        @memcpy(buffer[i .. i + payload.len], payload);
        i += payload.len;

        return i;
    }
};

pub const Ipv4Address = packed struct(u32) { a: u8, b: u8, c: u8, d: u8 };

pub const Ipv4Packet = struct {
    const Ipv4Header = packed struct {
        ihl: u4,
        version: enum(u4) {
            Ipv4 = 4,
            _,
        },
        ecn: u2,
        dscp: u6,
        total_length: u16,
        identification: u16,
        flags: packed struct(u16) {
            reserved: u1,
            df: u1,
            mf: u1,
            fragment_offset: u13,
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

        const SIZE: usize = @bitSizeOf(@This()) / 8;
    };
    header: Ipv4Header,
    payload: []const u8,

    pub fn fromBigEndianBytes(bytes: []const u8) @This() {
        var i: usize = 0;

        var header = std.mem.bytesToValue(Ipv4Header, bytes[i..]);
        header.total_length = std.mem.bigToNative(u16, header.total_length);
        header.identification = std.mem.bigToNative(u16, header.identification);
        header.header_checksum = std.mem.bigToNative(u16, header.header_checksum);
        i += Ipv4Header.SIZE;

        return .{
            .header = header,
            .payload = bytes[i..],
        };
    }

    pub fn make(dest: Ipv4Address, source: Ipv4Address, protocol: u8, identification: u16, payload: []const u8, buffer: []u8) usize {
        var i: usize = 0;

        const header = Ipv4Header{
            .ihl = 5,
            .version = .Ipv4,
            .ecn = 0,
            .dscp = 0,
            .total_length = std.mem.nativeToBig(u16, @intCast(Ipv4Header.SIZE + payload.len)),
            .identification = std.mem.nativeToBig(u16, identification),
            .flags = @bitCast(@as(u16, std.mem.nativeToBig(u16, 0x4000))),
            .ttl = 64,
            .protocol = @enumFromInt(protocol),
            .header_checksum = 0,
            .source_address = source,
            .destination_address = dest,
        };
        @memcpy(buffer[i .. i + Ipv4Header.SIZE], std.mem.toBytes(header)[0..Ipv4Header.SIZE]);
        i += Ipv4Header.SIZE;

        @memcpy(buffer[i .. i + payload.len], payload);
        i += payload.len;

        const checksum = std.mem.nativeToBig(u16, internetChecksum(buffer[0..Ipv4Header.SIZE]));
        @memcpy(buffer[10..12], std.mem.toBytes(checksum)[0..2]);

        return i;
    }
};

pub const ArpPacket = packed struct {
    hardware_type: u16,
    protocol_type: u16,
    hardware_length: u8,
    protocol_length: u8,
    operation: u16,
    sender_mac: MacAddress,
    sender_ip: Ipv4Address,
    target_mac: MacAddress,
    target_ip: Ipv4Address,

    const SIZE: usize = @bitSizeOf(@This()) / 8;

    pub fn fromBigEndianBytes(bytes: []const u8) !@This() {
        const raw = std.mem.bytesToValue(ArpPacket, bytes);

        return .{
            .hardware_type = raw.hardware_type,
            .protocol_type = std.mem.bigToNative(u16, raw.protocol_type),
            .hardware_length = raw.hardware_length,
            .protocol_length = raw.protocol_length,
            .operation = std.mem.bigToNative(u16, raw.operation),
            .sender_mac = raw.sender_mac,
            .sender_ip = raw.sender_ip,
            .target_mac = raw.target_mac,
            .target_ip = raw.target_ip,
        };
    }

    pub fn make(operation: u16, sender_mac: MacAddress, sender_ip: Ipv4Address, target_mac: MacAddress, target_ip: Ipv4Address, buffer: []u8) usize {
        const raw: ArpPacket = .{
            .hardware_type = std.mem.nativeToBig(u16, 1),
            .protocol_type = std.mem.nativeToBig(u16, 0x0800),
            .hardware_length = 6,
            .protocol_length = 4,
            .operation = std.mem.nativeToBig(u16, operation),
            .sender_mac = sender_mac,
            .sender_ip = sender_ip,
            .target_mac = target_mac,
            .target_ip = target_ip,
        };

        @memcpy(buffer[0..ArpPacket.SIZE], std.mem.toBytes(raw)[0..ArpPacket.SIZE]);

        return ArpPacket.SIZE;
    }
};

pub const IcmpPacket = struct {
    const IcmpHeader = packed struct {
        type: u8,
        code: u8,
        checksum: u16,
        rest: u32,

        const SIZE: usize = @bitSizeOf(@This()) / 8;
    };

    header: IcmpHeader,
    data: []const u8,

    pub fn fromBigEndianBytes(bytes: []const u8) @This() {
        var i: usize = 0;

        var header = std.mem.bytesToValue(IcmpHeader, bytes);
        header.checksum = std.mem.bigToNative(u16, header.checksum);
        header.rest = std.mem.bigToNative(u32, header.rest);
        i += IcmpHeader.SIZE;

        return .{
            .header = header,
            .data = bytes[i..],
        };
    }

    pub fn make(ty: u8, code: u8, rest: u32, data: []const u8, buffer: []u8) usize {
        var i: usize = 0;

        const raw: IcmpHeader = .{
            .type = ty,
            .code = code,
            .checksum = 0,
            .rest = std.mem.nativeToBig(u32, rest),
        };

        @memcpy(buffer[i .. i + IcmpHeader.SIZE], std.mem.toBytes(raw)[0..IcmpHeader.SIZE]);
        i += IcmpHeader.SIZE;

        @memcpy(buffer[i .. i + data.len], data);
        i += data.len;

        const checksum = std.mem.nativeToBig(u16, internetChecksum(buffer[0..i]));
        @memcpy(buffer[2..4], std.mem.toBytes(checksum)[0..2]);

        return i;
    }
};

pub fn internetChecksum(data: []const u8) u16 {
    var sum: u32 = 0;
    var i: usize = 0;

    // Process 16-bit words
    while (i + 1 < data.len) : (i += 2) {
        sum += (@as(u32, data[i]) << 8) | @as(u32, data[i + 1]);
    }

    // Handle remaining byte (if length is odd)
    if (i < data.len) {
        sum += @as(u32, data[i]) << 8;
    }

    // Fold 32-bit sum into 16 bits
    while (sum > 0xFFFF) {
        sum = (sum & 0xFFFF) + (sum >> 16);
    }

    return ~@as(u16, @truncate(sum)); // One's complement
}

test "internet checksum wikipedia example" {
    const data = [_]u8{
        0x45, 0x00, 0x00, 0x73, 0x00, 0x00, 0x40, 0x00, 0x40, 0x11, 0x00, 0x00, 0xc0, 0xa8, 0x00, 0x01,
        0xc0, 0xa8, 0x00, 0xc7,
    };

    try std.testing.expectEqual(internetChecksum(&data), 0xB861);
}

test "internet checksum icmp" {
    var buffer: [512]u8 = undefined;

    const n = IcmpPacket.make(0, 0, 0x02_00_33_00, &.{
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x64, 0x93, 0xfb, 0xb1,
    }, &buffer);

    try std.testing.expectEqual(internetChecksum(buffer[0..n]), 0x0000);
}
