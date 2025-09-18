const std = @import("std");

const hal = @import("hal").STM32F407VE;

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = hal.utils.logFn(hal.USART1.writer(), .{ .time = true }),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

const Mbr = packed struct {
    diskSignature: u32,
    copyProtect: u16,
    partition1: PartitionEntry,
    partition2: PartitionEntry,
    partition3: PartitionEntry,
    partition4: PartitionEntry,
    signature: u16,

    const PartitionEntry = packed struct(u128) {
        status: u8,
        chsFirst: ChsAddress,
        partitionType: u8,
        chsLast: ChsAddress,
        lbaFirst: u32,
        sectors: u32,
    };

    const ChsAddress = packed struct(u24) {
        head: u8,
        sector: u6,
        cylinder: u10,
    };
};

const Fat32Bpb = packed struct {
    // BIOS Parameter Block (BPB)
    jumpBoot: @Vector(3, u8),
    oemName: @Vector(8, u8),
    bytesPerSector: u16,
    sectorsPerCluster: u8,
    reservedSectorCount: u16,
    numFats: u8,
    rootEntryCount: u16,
    totalSectors16: u16,
    media: u8,
    fatSize16: u16,
    sectorsPerTrack: u16,
    numHeads: u16,
    hiddenSectors: u32,
    totalSectors32: u32,
    // Extended Boot Record (EBR) for FAT32
    sectorsPerFat32: u32,
    extFlags: u16,
    fsVersion: u16,
    rootCluster: u32,
    fsInfo: u16,
    bkBootSec: u16,
    _1: @Vector(12, u8),
    driveNumber: u8,
    reserved1: u8,
    bootSignature: u8,
    volumeId: u32,
    volumeLabel: @Vector(11, u8),
    fsType: @Vector(8, u8),
    bootCode: @Vector(420, u8),
    bootSectorSig: u16,
};

const Fat32DirEntry = packed struct {
    name: @Vector(11, u8),
    attr: u8,
    ntres: u8,
    crtTimeTenth: u8,
    crtTime: u16,
    crtDate: u16,
    lstAccDate: u16,
    fstClusHI: u16,
    wrtTime: u16,
    wrtDate: u16,
    fstClusLO: u16,
    fileSize: u32,
};

const Fat32LongDirEntry = packed struct {
    ord: u8,
    name1: @Vector(10, u8),
    attr: u8,
    type_: u8,
    chksum: u8,
    name2: @Vector(12, u8),
    fstClusLO: u16,
    name3: @Vector(4, u8),
};

fn Fat32Fs(comptime Ctx: type) type {
    return struct {
        blockCache: [512]u8 = undefined,
        currentBlock: ?u32 = null,

        bpb: Fat32Bpb,

        readBlockFn: *const fn (ctx: Ctx, blockAddress: u32, block: *[512]u8) anyerror!void,
        readBlockOffset: u32,
        readBlockCtx: Ctx,

        const Self = @This();

        fn init(ctx: Ctx, readBlockFn: *const fn (ctx: Ctx, blockAddress: u32, block: *[512]u8) anyerror!void, readBlockOffset: u32) !@This() {
            var self = @This(){
                .readBlockFn = readBlockFn,
                .readBlockOffset = readBlockOffset,
                .readBlockCtx = ctx,
                .bpb = undefined,
            };

            // read BPB
            try self.readBlockFn(self.readBlockCtx, self.readBlockOffset, &self.blockCache);
            self.bpb = std.mem.bytesToValue(Fat32Bpb, &self.blockCache);

            if (self.bpb.bytesPerSector != 512) {
                return error.UnsupportedBytesPerSector;
            }
            if (self.bpb.fatSize16 != 0) {
                return error.NotFat32;
            }
            if (self.bpb.sectorsPerFat32 == 0) {
                return error.NotFat32;
            }
            if (self.bpb.rootCluster < 2) {
                return error.InvalidRootCluster;
            }

            std.log.debug("Loaded FAT32 filesystem, label: '{s}', volume ID: {x}, size: {d} sectors ({d} MiB)", .{
                std.mem.trimRight(u8, &@as([11]u8, self.bpb.volumeLabel), " "),
                self.bpb.volumeId,
                self.bpb.totalSectors32,
                self.bpb.totalSectors32 / (2 * 1024),
            });

            return self;
        }

        fn readBlock(self: *@This(), blockAddress: u32) anyerror![]u8 {
            if (self.currentBlock != blockAddress) {
                try self.readBlockFn(self.readBlockCtx, blockAddress + self.readBlockOffset, &self.blockCache);
                self.currentBlock = blockAddress;
            }
            return &self.blockCache;
        }

        fn clusterToLba(self: @This(), cluster: u32) u32 {
            const firstDataSector =
                @as(u32, self.bpb.reservedSectorCount) +
                @as(u32, self.bpb.numFats) * @as(u32, self.bpb.sectorsPerFat32);
            return firstDataSector + (cluster - 2) * @as(u32, self.bpb.sectorsPerCluster);
        }

        fn iterator(self: *@This()) Iterator {
            var it = Iterator{
                .fs = self,
                .stackSize = 1,
            };
            it.stack[0] = .{
                .cluster = self.bpb.rootCluster,
                .sectorInCluster = 0,
                .entryIndex = 0,
            };
            return it;
        }

        fn nextCluster(self: *@This(), cluster: u32) !u32 {
            const fatOffset = cluster * 4;
            const fatSector = @as(u32, self.bpb.reservedSectorCount) + (fatOffset / 512);
            const fatIndex = fatOffset % 512;
            const fatBlock = try self.readBlock(fatSector);
            var next = (@as(u32, fatBlock[fatIndex + 0]) << 0) |
                (@as(u32, fatBlock[fatIndex + 1]) << 8) |
                (@as(u32, fatBlock[fatIndex + 2]) << 16) |
                (@as(u32, fatBlock[fatIndex + 3]) << 24);
            next &= 0x0FFFFFFF;
            return next;
        }

        const EntryType = enum { dir, file };
        const Entry = union(EntryType) {
            dir: struct { name: [64]u8, nameLength: usize, cluster: u32 },
            file: struct { name: [64]u8, nameLength: usize, cluster: u32, size: u32 },
        };

        const Iterator = struct {
            fs: *Self,

            stack: [16]struct {
                cluster: u32,
                sectorInCluster: u32,
                entryIndex: u32,

                lfnStack: [20]Fat32LongDirEntry = undefined, // max segments per file
                lfnCount: usize = 0,
            } = undefined,
            stackSize: usize = 0,

            pub fn next(self: *@This()) !?Entry {
                unrecurse: while (true) {
                    const state = &self.stack[self.stackSize - 1];

                    // if we have exhausted all entries in the current sector, load the next sector
                    if (state.entryIndex >= 16) {
                        state.entryIndex = 0;
                        state.sectorInCluster += 1;
                        if (state.sectorInCluster >= self.fs.bpb.sectorsPerCluster) {
                            // load next cluster
                            const nc = try self.fs.nextCluster(state.cluster);
                            if (nc < 2 or nc >= 0x0FFFFFF8) {
                                // end of cluster chain
                                if (self.stackSize == 1) {
                                    return null; // we are at root and have exhausted all entries
                                }
                                self.stackSize -= 1;
                                continue :unrecurse;
                            }
                            state.cluster = nc;
                            state.sectorInCluster = 0;
                        }
                    }

                    // ensure the current sector is loaded
                    const sector = self.fs.clusterToLba(state.cluster) + state.sectorInCluster;
                    const block = try self.fs.readBlock(sector);

                    const entryOffset = state.entryIndex * @sizeOf(Fat32DirEntry);
                    const entry = std.mem.bytesToValue(Fat32DirEntry, block[entryOffset .. entryOffset + @sizeOf(Fat32DirEntry)]);
                    state.entryIndex += 1;
                    if (entry.name[0] == 0) {
                        // no more entries in this directory
                        if (self.stackSize == 1) {
                            return null; // we are at root and have exhausted all entries
                        }
                        self.stackSize -= 1;
                        continue :unrecurse;
                    }
                    if (entry.name[0] == 0xE5) {
                        // deleted entry, skip
                        continue :unrecurse;
                    }
                    if (entry.attr == 0x0F) {
                        // long file name entry
                        if (state.lfnCount < state.lfnStack.len) {
                            state.lfnStack[state.lfnCount] = std.mem.bytesToValue(Fat32LongDirEntry, block[entryOffset .. entryOffset + @sizeOf(Fat32LongDirEntry)]);
                            state.lfnCount += 1;
                        }
                        continue :unrecurse;
                    }
                    if ((entry.attr & 0x08) != 0) {
                        // volume label, skip
                        state.lfnCount = 0;
                        continue :unrecurse;
                    }
                    // regular entry
                    var name: [64]u8 = undefined;
                    var nameLength: usize = 0;
                    if (state.lfnCount > 0) {
                        // assemble long file name
                        var utf16buf: [260]u16 = undefined; // max 260 UTF-16 code units
                        var utf16len: usize = 0;
                        for (0..state.lfnCount) |i_| {
                            const i = state.lfnCount - i_;
                            const lfn = state.lfnStack[i - 1];

                            for ([_][]const u8{
                                &@as([10]u8, lfn.name1),
                                &@as([12]u8, lfn.name2),
                                &@as([4]u8, lfn.name3),
                            }) |part| {
                                for (0..part.len / 2) |k| {
                                    const c = std.mem.bytesToValue(u16, part[k * 2 .. k * 2 + 2]);
                                    if (c == 0x0000 or c == 0xFFFF) break;
                                    if (utf16len < utf16buf.len) {
                                        utf16buf[utf16len] = c;
                                        utf16len += 1;
                                    }
                                }
                            }
                        }

                        const n = std.unicode.utf16LeToUtf8(&name, utf16buf[0..utf16len]) catch |e| {
                            std.log.err("invalid UTF-16 in long file name: {}", .{e});
                            return error.InvalidFileName;
                        };

                        nameLength = n;
                        state.lfnCount = 0;
                    } else {
                        // name part
                        const entryName = @as([11]u8, entry.name);
                        const base = std.mem.trimRight(u8, entryName[0..8], " ");
                        @memcpy(name[0..base.len], base);
                        nameLength += base.len;
                        // extension part
                        const ext = std.mem.trimRight(u8, entryName[8..11], " ");
                        if (ext.len > 0) {
                            if (nameLength + 1 + ext.len <= name.len) {
                                name[nameLength] = '.';
                                @memcpy(name[nameLength + 1 .. nameLength + 1 + ext.len], ext);
                                nameLength += 1 + ext.len;
                            }
                        }
                    }

                    const cluster = (@as(u32, entry.fstClusHI) << 16) | @as(u32, entry.fstClusLO);

                    if ((entry.attr & 0x10) != 0) {
                        // directory
                        if (std.mem.eql(u8, name[0..nameLength], ".") or
                            std.mem.eql(u8, name[0..nameLength], ".."))
                        {
                            // skip . and .. entries
                            continue :unrecurse;
                        }

                        // push directory onto stack
                        if (self.stackSize < self.stack.len) {
                            self.stack[self.stackSize] = .{
                                .cluster = cluster,
                                .sectorInCluster = 0,
                                .entryIndex = 0,
                                .lfnStack = undefined,
                                .lfnCount = 0,
                            };
                            self.stackSize += 1;
                        } else {
                            std.log.err("directory stack overflow", .{});
                            return error.StackOverflow;
                        }

                        return Entry{ .dir = .{
                            .name = name,
                            .nameLength = nameLength,
                            .cluster = cluster,
                        } };
                    } else {
                        // file
                        return Entry{ .file = .{
                            .name = name,
                            .nameLength = nameLength,
                            .cluster = cluster,
                            .size = entry.fileSize,
                        } };
                    }
                }
            }
        };
    };
}

export fn main() noreturn {
    @setRuntimeSafety(true);

    hal.memory.initializeMemory();

    hal.core.DEBUG.cr.trcena = true;
    hal.core.DWT.enableCycleCounter();

    hal.RCC.ahb1enr.gpioAEn = true;

    hal.RCC.apb2enr.usart1En = true;
    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh }); // USART1 TX
    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);

    hal.USART1.writer().writeAll("\x1B[2J\x1B[H") catch unreachable;
    std.log.info("Hello World!", .{});

    // enable PLL48CK
    hal.RCC.cr.hseOn = true;
    std.log.debug("waiting for HSE to stabilize", .{});
    while (!hal.RCC.cr.hseRdy) {}
    hal.RCC.configurePll(.hse, 8, 336, .div2, 7);
    std.log.debug("set up PLL", .{});

    // setup SDIO pins
    hal.RCC.ahb1enr.gpioCEn = true;
    hal.RCC.ahb1enr.gpioDEn = true;
    _ = hal.GPIOC.setupAlternateFunction(8, .AF12, .{ .outputSpeed = .VeryHigh }); // SDIO D0
    _ = hal.GPIOC.setupAlternateFunction(9, .AF12, .{ .outputSpeed = .VeryHigh }); // SDIO D1
    _ = hal.GPIOC.setupAlternateFunction(10, .AF12, .{ .outputSpeed = .VeryHigh }); // SDIO D2
    _ = hal.GPIOC.setupAlternateFunction(11, .AF12, .{ .outputSpeed = .VeryHigh }); // SDIO D3
    _ = hal.GPIOC.setupAlternateFunction(12, .AF12, .{ .outputSpeed = .VeryHigh }); // SDIO CLK
    _ = hal.GPIOD.setupAlternateFunction(2, .AF12, .{ .outputSpeed = .VeryHigh }); // SDIO CMD

    // initialize SDIO
    hal.RCC.apb2enr.sdioEn = true;
    hal.utils.delayMicros(10_000);
    hal.SDIO.power.modify(.{ .pwrctrl = 0b11 });
    hal.utils.delayMicros(10_000);
    hal.SDIO.clkcr.modify(.{ .clkdiv = 0x76, .clken = 1, .pwrsav = 0, .widbus = .oneBit });

    // CMD0: GO_IDLE_STATE
    hal.SDIO.sendCommandNoResponse(0, null) catch std.log.err("CMD0 failed", .{});
    hal.utils.delayMicros(50_000);
    // CMD8: SEND_IF_COND
    const cmd8_resp = hal.SDIO.sendCommandShortResponse(8, 0x1AA, false) catch |e| {
        std.log.err("CMD8 failed: {}", .{e});
        @panic("SD card initialization failed");
    };
    if (cmd8_resp != 0x1AA) {
        std.log.err("CMD8 response invalid: {x}", .{cmd8_resp});
        @panic("SD card initialization failed");
    }
    // ACMD41: SD_SEND_OP_COND
    while (true) {
        _ = hal.SDIO.sendCommandShortResponse(55, 0, false) catch |e| {
            std.log.err("CMD55 failed: {}", .{e});
            @panic("SD card initialization failed");
        };
        const acmd41_resp = hal.SDIO.sendCommandShortResponse(41, 0x4030_0000, true) catch |e| {
            std.log.err("ACMD41 failed: {}", .{e});
            @panic("SD card initialization failed");
        };
        if ((acmd41_resp & 0x8000_0000) != 0) {
            break;
        }
        hal.utils.delayMicros(100_000);
    }
    // CMD2: ALL_SEND_CID
    const cid = hal.SDIO.sendCommandLongResponse(2, 0) catch |e| {
        std.log.err("CMD2 failed: {}", .{e});
        @panic("SD card initialization failed");
    };
    std.log.info("CID: {x} {x} {x} {x}", .{ cid[0], cid[1], cid[2], cid[3] });
    // CMD3: SET_RELATIVE_ADDR
    const rca = (hal.SDIO.sendCommandShortResponse(3, 0, false) catch |e| {
        std.log.err("CMD3 failed: {}", .{e});
        @panic("SD card initialization failed");
    }) >> 16;
    std.log.info("RCA: {x}", .{rca});
    // CMD9: SEND_CSD
    const csd = hal.SDIO.sendCommandLongResponse(9, rca << 16) catch |e| {
        std.log.err("CMD9 failed: {}", .{e});
        @panic("SD card initialization failed");
    };
    std.log.info("CSD: {x} {x} {x} {x}", .{ csd[0], csd[1], csd[2], csd[3] });
    // CMD7: SELECT/DESELECT_CARD
    _ = hal.SDIO.sendCommandShortResponse(7, rca << 16, false) catch |e| {
        std.log.err("CMD7 failed: {}", .{e});
        @panic("SD card initialization failed");
    };
    // switch to 4-bit bus
    // ACMD6: SET_BUS_WIDTH
    _ = hal.SDIO.sendCommandShortResponse(55, rca << 16, false) catch |e| {
        std.log.err("CMD55 failed: {}", .{e});
        @panic("SD card initialization failed");
    };
    _ = hal.SDIO.sendCommandShortResponse(6, 2, false) catch |e| {
        std.log.err("ACMD6 failed: {}", .{e});
        @panic("SD card initialization failed");
    };
    hal.SDIO.clkcr.modify(.{ .widbus = .fourBit });
    std.log.info("SD card initialized", .{});

    // read block 0
    var block: [512]u8 = undefined;
    hal.SDIO.readBlock(0, &block) catch |e| {
        std.log.err("read block failed: {}", .{e});
        @panic("SD card read failed");
    };
    std.log.info("Block 0 data:", .{});
    for (0..512 / 16) |i| {
        std.log.info("0x{x:03}: {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02}", .{
            i * 16,
            block[i * 16 + 0],
            block[i * 16 + 1],
            block[i * 16 + 2],
            block[i * 16 + 3],
            block[i * 16 + 4],
            block[i * 16 + 5],
            block[i * 16 + 6],
            block[i * 16 + 7],
            block[i * 16 + 8],
            block[i * 16 + 9],
            block[i * 16 + 10],
            block[i * 16 + 11],
            block[i * 16 + 12],
            block[i * 16 + 13],
            block[i * 16 + 14],
            block[i * 16 + 15],
        });
    }

    const mbr = std.mem.bytesToValue(Mbr, block[0x1B8..]);
    std.log.info("MBR: {}", .{mbr});
    std.log.info("Partition 1: {}", .{mbr.partition1});

    // read first block of partition 1
    const partition1_start = mbr.partition1.lbaFirst;
    hal.SDIO.readBlock(partition1_start, &block) catch |e| {
        std.log.err("read block failed: {}", .{e});
        @panic("SD card read failed");
    };
    std.log.info("Partition 1, Block 0 data:", .{});
    for (0..512 / 16) |i| {
        std.log.info("0x{x:03}: {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02} {x:02}", .{
            i * 16,
            block[i * 16 + 0],
            block[i * 16 + 1],
            block[i * 16 + 2],
            block[i * 16 + 3],
            block[i * 16 + 4],
            block[i * 16 + 5],
            block[i * 16 + 6],
            block[i * 16 + 7],
            block[i * 16 + 8],
            block[i * 16 + 9],
            block[i * 16 + 10],
            block[i * 16 + 11],
            block[i * 16 + 12],
            block[i * 16 + 13],
            block[i * 16 + 14],
            block[i * 16 + 15],
        });
    }

    var fs = Fat32Fs(hal.sdio.Sdio).init(hal.SDIO, hal.sdio.Sdio.readBlock, partition1_start) catch |e| {
        std.log.err("FAT32 init failed: {}", .{e});
        @panic("FAT32 init failed");
    };

    var it = fs.iterator();
    while (it.next() catch |e| {
        std.log.err("FAT32 read dir failed: {}", .{e});
        @panic("FAT32 read dir failed");
    }) |entry| {
        const spacer = "| | | | | | | | | | | | | | | ";

        switch (entry) {
            .dir => |d| {
                std.log.info("{s}+ DIR {s} (cluster {d})", .{ spacer[0 .. (it.stackSize - 1) * 2], d.name[0..d.nameLength], d.cluster });
            },
            .file => |f| {
                std.log.info("{s}- FILE {s} size {d} (cluster {d})", .{ spacer[0 .. (it.stackSize - 0) * 2 - 2], f.name[0..f.nameLength], f.size, f.cluster });
            },
        }
    }

    // blink LEDs
    const led1 = hal.GPIOA.setupOutput(6, .{});
    const led2 = hal.GPIOA.setupOutput(7, .{});

    while (true) {
        led1.toggleLevel();
        led2.toggleLevel();

        for (0..500) |_| {
            hal.utils.delayMicros(1000);
        }
    }
}
