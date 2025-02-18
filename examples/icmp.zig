pub const IcmpHeader = packed struct {
    type: u8,
    code: u8,
    checksum: u16,
    identifier: u16,
    sequence_number: u16,
    data: [32]u8,
};
