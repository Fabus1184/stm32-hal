const std = @import("std");

pub fn Register(comptime T: type) type {
    const structTypeInfo = switch (@typeInfo(T)) {
        .Struct => |s| s,
        else => @compileError("Register type must be a struct"),
    };

    switch (structTypeInfo.backing_integer orelse @compileError("Register struct must have a backing integer")) {
        u32 => {},
        else => @compileError("Register struct backing integer must be u32"),
    }

    comptime var hasReservedFields = false;
    for (structTypeInfo.fields) |field| {
        if (std.mem.startsWith(u8, field.name, "_")) {
            hasReservedFields = true;
        }
    }

    return struct {
        ptr: *volatile u32,

        pub fn load(self: @This()) T {
            return @bitCast(self.ptr.*);
        }

        pub fn store(self: @This(), value: T) void {
            if (hasReservedFields) {
                @compileError("Register struct has reserved fields");
            }

            self.ptr.* = @bitCast(value);
        }

        pub fn modify(self: @This(), fields: anytype) void {
            var value = self.load();
            inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
                @field(value, field.name) = @field(fields, field.name);
            }
            self.ptr.* = @bitCast(value);
        }
    };
}
