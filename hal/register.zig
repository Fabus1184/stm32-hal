const std = @import("std");

pub fn Register(comptime T: type) type {
    const structTypeInfo = switch (@typeInfo(T)) {
        .@"struct" => |s| s,
        else => @compileError("Register type must be a struct"),
    };

    const Size = switch (structTypeInfo.backing_integer orelse @compileError("Register struct must have a backing integer")) {
        u32 => u32,
        u16 => u16,
        else => @compileError("Register struct backing integer must be u32"),
    };

    comptime var hasReservedFields = false;
    for (structTypeInfo.fields) |field| {
        if (std.mem.startsWith(u8, field.name, "_")) {
            hasReservedFields = true;
        }
    }

    comptime var nonReservedFieldsOpt: [64]std.builtin.Type.StructField = undefined;
    comptime var nonReservedFieldsCount: usize = 0;
    for (structTypeInfo.fields) |field| {
        if (!std.mem.startsWith(u8, field.name, "_")) {
            const defaultValue: struct { value: ?field.type } = .{ .value = null };

            nonReservedFieldsOpt[nonReservedFieldsCount] = std.builtin.Type.StructField{
                .name = field.name,
                .type = @Type(std.builtin.Type{ .optional = .{ .child = field.type } }),
                .default_value_ptr = &defaultValue.value,
                .is_comptime = false,
                .alignment = @alignOf(field.type),
            };
            nonReservedFieldsCount += 1;
        }
    }

    const modifyArgsType = @Type(std.builtin.Type{ .@"struct" = std.builtin.Type.Struct{
        .layout = std.builtin.Type.ContainerLayout.auto,
        .fields = nonReservedFieldsOpt[0..nonReservedFieldsCount],
        .decls = &.{},
        .is_tuple = false,
    } });

    return struct {
        ptr: *align(4) volatile Size,

        pub fn load(self: @This()) T {
            return @bitCast(self.ptr.*);
        }

        pub fn store(self: @This(), value: T) void {
            if (hasReservedFields) {
                @compileError("Register struct has reserved fields");
            }

            self.ptr.* = @bitCast(value);
        }

        pub fn modify(self: @This(), fields: modifyArgsType) void {
            var newValue = self.load();
            inline for (@typeInfo(@TypeOf(fields)).@"struct".fields) |field| {
                const value = @field(fields, field.name);
                if (value) |v| {
                    @field(newValue, field.name) = v;
                }
            }
            self.ptr.* = @bitCast(newValue);
        }
    };
}
