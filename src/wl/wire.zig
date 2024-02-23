const std = @import("std");
const io = std.io;
const mem = std.mem;
const fifo = std.fifo;
const math = std.math;
const txrx = @import("txrx.zig");
const FdBuffer = fifo.LinearFifo(i32, fifo.LinearFifoBufferType{ .Static = txrx.MAX_FDS });

const endian = @import("builtin").cpu.arch.endian();

const BUFFER_SIZE = 4096;

pub fn Wire(comptime WlMessage: type) type {
    return struct {
        fd: i32 = -1,
        rx: io.FixedBufferStream([]u8) = undefined,
        tx: io.FixedBufferStream([]u8) = undefined,
        rx_buf: [BUFFER_SIZE]u8 = [_]u8{0} ** BUFFER_SIZE,
        tx_buf: [BUFFER_SIZE]u8 = [_]u8{0} ** BUFFER_SIZE,
        rx_fds: FdBuffer = FdBuffer.init(),
        tx_fds: FdBuffer = FdBuffer.init(),
        rx_write_offset: usize = 0,
        tx_write_offset: usize = 0,

        const Self = @This();

        pub fn init(fd: i32) Self {
            return Self{
                .fd = fd,
            };
        }

        const Header = struct {
            id: u32,
            opcode: u16,
            length: u16,
        };

        pub fn startRead(self: *Self) !void {
            const n = try txrx.recvMsg(self.fd, self.rx_buf[self.rx_write_offset..], &self.rx_fds);

            self.rx = io.fixedBufferStream(self.rx_buf[0 .. self.rx_write_offset + n]);
        }

        pub fn finishRead(self: *Self) !void {
            const read_offset = try self.rx.getPos();
            const buffer_end = try self.rx.getEndPos();

            const n = buffer_end - read_offset;

            self.rx_write_offset = n;

            mem.copyForwards(u8, self.rx_buf[0..n], self.rx_buf[read_offset .. read_offset + n]);
        }

        // Is objects just client?
        pub fn readEvent(self: *Self, comptime C: type, objects: anytype, comptime field: []const u8) !?WlMessage {
            const rdr = self.rx.reader();

            // We need to have read at least a header
            const remaining = (try self.rx.getEndPos()) - (try self.rx.getPos());
            if (remaining < @sizeOf(u32) + @sizeOf(u16) + @sizeOf(u16)) return null;

            const start = try self.rx.getPos();

            const header = Header{
                .id = try rdr.readInt(u32, endian),
                .opcode = try rdr.readInt(u16, endian),
                .length = try rdr.readInt(u16, endian),
            };

            // We need to have read a full message
            if (remaining < header.length) return null;

            // var object = @field(objects, field)(header.id) orelse return error.CouldntFindExpectedId;

            var object = @call(.auto, @field(C, field), .{ objects, header.id }) orelse return error.CouldntFindExpectedId;

            const event = try object.readMessage(C, objects, field, header.opcode);

            const actual_length = (try self.rx.getPos()) - start;
            if (actual_length != header.length) return error.MessageWrongLength;

            return event;
        }

        pub fn nextU32(self: *Self) !u32 {
            return self.rx.reader().readInt(u32, endian);
        }

        pub fn nextI32(self: *Self) !i32 {
            return self.rx.reader().readInt(i32, endian);
        }

        // we just expose a pointer to the rx_buf for the
        // extent of the dispatch call. This will become invalid
        // after the dispatch function returns and so we cannot
        // hang on to this pointer. If we want to retain the string
        // we should copy it.
        pub fn nextString(self: *Self) ![]u8 {
            const length = try self.nextU32();
            const padded_length = length + padding(length);

            const start = try self.rx.getPos();

            try self.rx.reader().skipBytes(padded_length, .{});

            var s: []u8 = undefined;
            s.ptr = @ptrCast(&self.rx_buf[start]);
            s.len = length;

            return s;
        }

        // we just expose a pointer to the rx_buf for the
        // extent of the dispatch call. This will become invalid
        // after the dispatch function returns and so we cannot
        // hang on to this pointer. If we want to retain the array
        // we should copy it.
        pub fn nextArray(self: *Self) ![]u8 {
            const length = try self.nextU32();
            const padded_length = length + padding(length);

            const start = try self.rx.getPos();

            try self.rx.reader().skipBytes(padded_length, .{});

            var s: []u8 = undefined;
            s.ptr = &self.rx_buf[start];
            s.len = length;
            return s;
        }

        pub fn nextFd(self: *Self) !i32 {
            return self.rx_fds.readItem() orelse return error.FdReadFailed;
        }

        pub fn startWrite(self: *Self) !void {
            self.tx = io.fixedBufferStream(self.tx_buf[0..]);
            try self.tx.writer().writeInt(u32, 0, endian);
            try self.tx.writer().writeInt(u16, 0, endian);
            try self.tx.writer().writeInt(u16, 0, endian);
        }

        pub fn finishWrite(self: *Self, id: u32, opcode: u16) !void {
            const end_pos = math.cast(u16, try self.tx.getPos()) orelse return error.EndPositionMustBeU16;
            self.tx.reset();

            try self.tx.writer().writeInt(u32, id, endian);
            try self.tx.writer().writeInt(u16, opcode, endian);
            try self.tx.writer().writeInt(u16, end_pos, endian);

            _ = txrx.sendMsg(self.fd, self.tx_buf[0..end_pos], &self.tx_fds) catch |err| switch (err) {
                error.BrokenPipe => return,
                else => return err,
            };
        }

        pub fn putU32(self: *Self, value: u32) !void {
            try self.tx.writer().writeInt(u32, value, endian);
        }

        pub fn putI32(self: *Self, value: i32) !void {
            try self.tx.writer().writeInt(i32, value, endian);
        }

        pub fn putFd(self: *Self, value: i32) !void {
            try self.tx_fds.writeItem(value);
        }

        pub fn putFixed(self: *Self, value: f64) !void {
            try self.putI32(doubleToFixed(value));
        }

        pub fn putArray(self: *Self, array: []u8) !void {
            const length = math.cast(u32, array.len) orelse return error.ArrayTooBig;
            const padded_length = length + padding(length);

            try self.putU32(length);

            const start = try self.tx.getPos();
            try self.tx.seekBy(padded_length);

            mem.copyForwards(u8, self.tx_buf[start .. start + length], array);
        }

        // string is assumed to have a null byte within its contents / length
        pub fn putString(self: *Self, string: []const u8) !void {
            const length = math.cast(u32, string.len) orelse return error.ArrayTooBig;
            const padded_length = length + padding(length);

            try self.putU32(length);
            const start = try self.tx.getPos();

            try self.tx.seekBy(padded_length);

            std.mem.copyForwards(u8, self.tx_buf[start .. start + length], string);
        }
    };
}

fn doubleToFixed(f: f64) i32 {
    var x: f64 = f + (3 << (51 - 8));
    const x_ptr: *i32 = @ptrCast(&x);
    return x_ptr.*;
}

fn fixedToDouble(f: i32) f64 {
    var x: i32 = ((1023 + 44) << 52) + (1 << 51) + f;
    const x_ptr: *f64 = @ptrCast(&x);
    return x_ptr.*;
}

fn padding(num_bytes: u32) u32 {
    return (4 - num_bytes % 4) % 4;
}
