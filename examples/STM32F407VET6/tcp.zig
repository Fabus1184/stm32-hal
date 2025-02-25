const std = @import("std");

const inet = @import("internet.zig");

const TcpAcceptSocket = struct {
    state: State = State.Closed,
    remoteIp: inet.Ipv4Address = undefined,
    remotePort: u16 = undefined,
    localPort: u16 = undefined,
    sequenceNumber: u32 = undefined,

    const State = enum {
        Closed,
        SynReceived,
        Established,
        CloseWait,
        LastAck,
    };

    pub fn matches(self: @This(), ipv4Packet: inet.Ipv4Packet, tcpPacket: inet.TcpPacket) bool {
        return self.state != State.Closed //
        and std.meta.eql(self.remoteIp, ipv4Packet.header.source_address) //
        and self.remotePort == tcpPacket.header.source_port //
        and self.localPort == tcpPacket.header.destination_port;
    }

    pub fn makeTcpPacket(self: *@This(), flags: inet.TcpPacket.Flags, ackNumber: u32, payload: []const u8) inet.TcpPacket {
        const packet = inet.TcpPacket{
            .header = .{
                .source_port = self.localPort,
                .destination_port = self.remotePort,
                .sequence_number = self.sequenceNumber,
                .acknowledgment_number = ackNumber,
                .data_offset = 5,
                .flags = flags,
                .window_size = 500,
                .checksum = 0,
                .urgent_pointer = 0,
            },
            .data = payload,
        };

        self.sequenceNumber += @intCast(payload.len);

        return packet;
    }
};

pub fn TcpListener(socketCount: comptime_int) type {
    return struct {
        sockets: [socketCount]TcpAcceptSocket = .{TcpAcceptSocket{}} ** socketCount,

        localIp: inet.Ipv4Address = undefined,
        localPort: u16 = undefined,

        pub fn init(localIp: inet.Ipv4Address, localPort: u16) @This() {
            return .{
                .sockets = .{TcpAcceptSocket{}} ** socketCount,
                .localIp = localIp,
                .localPort = localPort,
            };
        }

        pub fn handlePacket(self: *@This(), ipv4Packet: inet.Ipv4Packet, tcpPacket: inet.TcpPacket) !?inet.TcpPacket {
            if (tcpPacket.header.flags.syn) {
                std.log.info("SYN packet from {}:{} to {}:{}", .{ ipv4Packet.header.source_address, tcpPacket.header.source_port, ipv4Packet.header.destination_address, tcpPacket.header.destination_port });

                const socket = for (&self.sockets) |*socket| {
                    if (socket.state == TcpAcceptSocket.State.Closed) {
                        break socket;
                    }
                } else null;

                if (socket) |s| {
                    s.* = .{
                        .state = TcpAcceptSocket.State.SynReceived,
                        .remoteIp = ipv4Packet.header.source_address,
                        .remotePort = tcpPacket.header.source_port,
                        .localPort = tcpPacket.header.destination_port,
                        .sequenceNumber = tcpPacket.header.sequence_number,
                    };

                    return s.makeTcpPacket(.{
                        .syn = true,
                        .ack = true,
                    }, tcpPacket.header.sequence_number + 1, &.{});
                } else {
                    return error.@"No free sockets";
                }
            }

            const socket = for (&self.sockets) |*socket| {
                if (socket.matches(ipv4Packet, tcpPacket)) {
                    break socket;
                }
            } else return error.@"No matching socket";

            std.log.info("found matching socket in state {s}", .{@tagName(socket.state)});

            switch (socket.state) {
                .SynReceived => {
                    if (tcpPacket.header.flags.ack) {
                        socket.state = TcpAcceptSocket.State.Established;

                        return null;
                    } else {
                        return error.@"Expected ACK";
                    }
                },
                .Established => {
                    // close on FIN
                    if (tcpPacket.header.flags.fin) {
                        socket.state = TcpAcceptSocket.State.CloseWait;

                        return socket.makeTcpPacket(.{
                            .ack = true,
                            .fin = true,
                        }, tcpPacket.header.sequence_number + 1, &.{});
                        // data on PSH
                    } else if (tcpPacket.header.flags.psh) {
                        return socket.makeTcpPacket(.{
                            .ack = true,
                        }, tcpPacket.header.sequence_number + tcpPacket.data.len, tcpPacket.data);
                    } else {
                        return error.@"Expected PSH or FIN";
                    }
                },
                .CloseWait => {
                    if (tcpPacket.header.flags.ack) {
                        socket.state = TcpAcceptSocket.State.LastAck;

                        return socket.makeTcpPacket(.{
                            .ack = true,
                        }, tcpPacket.header.sequence_number + 1, &.{});
                    } else {
                        return error.@"Expected ACK";
                    }
                },
                .LastAck => {
                    if (tcpPacket.header.flags.ack) {
                        socket.state = TcpAcceptSocket.State.Closed;

                        return socket.makeTcpPacket(.{
                            .ack = true,
                        }, tcpPacket.header.sequence_number + 1, &.{});
                    } else {
                        return error.@"Expected ACK";
                    }
                },
                else => @panic("tcp state not handled"),
            }
        }
    };
}
