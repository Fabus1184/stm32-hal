extern var _start_data: u32; // address of the .data section in RAM
extern var _end_data: u32;
extern var _start_data_load: u32; // address of the .data section in flash
extern var _start_bss: u32; // address of the .bss section in RAM
extern var _end_bss: u32;
pub fn initializeMemory() void {
    // copy .data section from flash to ram
    const dataStart = @intFromPtr(&_start_data);
    const dataEnd = @intFromPtr(&_end_data);
    const dataLoadStart = @intFromPtr(&_start_data_load);
    const dataPtr: [*]u8 = @ptrFromInt(dataStart);
    const dataLoadPtr: [*]const u8 = @ptrFromInt(dataLoadStart);
    for (0..dataEnd - dataStart) |i| {
        dataPtr[i] = dataLoadPtr[i];
    }

    // zero out .bss section
    const bssStart = @intFromPtr(&_start_bss);
    const bssEnd = @intFromPtr(&_end_bss);
    const bssPtr: [*]u8 = @ptrFromInt(bssStart);
    for (0..bssEnd - bssStart) |i| {
        bssPtr[i] = 0;
    }
}
