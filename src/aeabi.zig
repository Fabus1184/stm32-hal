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
