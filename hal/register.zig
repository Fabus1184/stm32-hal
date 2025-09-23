const std = @import("std");

pub fn Register(comptime T: type) type {
    @setEvalBranchQuota(2000);

    if (T == u32) {
        return struct {
            ptr: *align(4) volatile T,

            pub inline fn load(self: @This()) T {
                return self.ptr.*;
            }

            pub inline fn store(self: @This(), value: T) void {
                self.ptr.* = value;
            }
        };
    }

    if (@typeInfo(T) == .@"union") {
        if (@typeInfo(T).@"union".tag_type != null) {
            @compileError("Register union must not be tagged");
        }

        const Size = switch (@sizeOf(T)) {
            4 => u32,
            2 => u16,
            else => @compileError("Register union must be 2 or 4 bytes"),
        };

        return struct {
            ptr: *align(4) volatile Size,

            pub inline fn load(self: @This()) T {
                return @bitCast(self.ptr.*);
            }
        };
    }

    const structTypeInfo = switch (@typeInfo(T)) {
        .@"struct" => |structTypeInfo| structTypeInfo,
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

    var nonReservedFieldsOpt: [64]std.builtin.Type.StructField = undefined;
    var nonReservedFieldsCount: usize = 0;
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

    const modifyArgsType: type = @Type(std.builtin.Type{ .@"struct" = std.builtin.Type.Struct{
        .layout = std.builtin.Type.ContainerLayout.auto,
        .fields = nonReservedFieldsOpt[0..nonReservedFieldsCount],
        .decls = &.{},
        .is_tuple = false,
    } });

    return struct {
        ptr: *align(4) volatile Size,

        pub inline fn load(self: @This()) T {
            return @bitCast(self.ptr.*);
        }

        pub inline fn store(self: @This(), value: T) void {
            if (hasReservedFields) {
                @compileError("Register struct has reserved fields");
            }

            self.ptr.* = @bitCast(value);
        }

        pub inline fn modify(self: @This(), fields: modifyArgsType) void {
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
