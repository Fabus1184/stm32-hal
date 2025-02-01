export fn __aeabi_memclr(ptr: *anyopaque, numBytes: usize) void {
    var dest: [*c]u8 = @ptrCast(ptr);
    for (0..numBytes) |i| {
        dest[i] = 0;
    }
}

export fn __aeabi_memcpy(ptrDest: *anyopaque, ptrSrc: *const anyopaque, numBytes: usize) void {
    var dest: [*c]u8 = @ptrCast(ptrDest);
    const src: [*c]const u8 = @ptrCast(ptrSrc);
    for (0..numBytes) |i| {
        dest[i] = src[i];
    }
}

export fn __aeabi_memcpy4(ptrDest: *align(4) anyopaque, ptrSrc: *align(4) const anyopaque, numBytes: usize) void {
    var dest: [*c]u32 = @ptrCast(ptrDest);
    const src: [*c]const u32 = @ptrCast(ptrSrc);
    for (0..numBytes / 4) |i| {
        dest[i] = src[i];
    }
}
