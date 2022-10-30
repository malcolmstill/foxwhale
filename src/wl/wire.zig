const std = @import("std");
const io = std.io;
const mem = std.mem;
const fifo = std.fifo;
const math = std.math;
const txrx = @import("txrx.zig");
const WlObject = @import("protocols.zig").WlObject;
const WlMessage = @import("protocols.zig").WlMessage;
const LinearFifo = fifo.LinearFifo;
const LinearFifoBufferType = fifo.LinearFifoBufferType;
const FdBuffer = LinearFifo(i32, LinearFifoBufferType{ .Static = txrx.MAX_FDS });

const BUFFER_SIZE = 4096;

pub const Wire = struct {
    fd: i32 = -1,
    write_offset: usize = 0,
    rx: io.FixedBufferStream([]u8) = undefined,
    tx: io.FixedBufferStream([]u8) = undefined,
    rx_buf: [BUFFER_SIZE]u8,
    tx_buf: [BUFFER_SIZE]u8,
    rx_fds: FdBuffer,
    tx_fds: FdBuffer,
    tx_write_offset: usize = 0,
    n: usize = 0,

    const Self = @This();

    pub fn init(fd: i32) Self {
        return Self{
            .fd = fd,
            .write_offset = 0,

            .rx_fds = FdBuffer.init(),
            .tx_fds = FdBuffer.init(),

            .rx_buf = [_]u8{0} ** BUFFER_SIZE,
            .tx_buf = [_]u8{0} ** BUFFER_SIZE,
        };
    }

    pub fn deinit(_: *Self) void {}

    pub const Header = struct {
        id: u32,
        opcode: u16,
        length: u16,
    };

    pub fn startRead(self: *Self) !void {
        self.n = try txrx.recvMsg(self.fd, self.rx_buf[self.write_offset..self.rx_buf.len], &self.rx_fds);
        self.n = self.write_offset + self.n;

        self.rx = io.fixedBufferStream(self.rx_buf[self.write_offset..self.n]);
    }

    pub fn finishRead(self: *Self) !void {
        const read_offset = try self.rx.getPos();
        self.write_offset = self.n - read_offset;
        mem.copy(u8, self.rx_buf[0..self.write_offset], self.rx_buf[read_offset..self.n]);
    }

    pub fn readEvent(self: *Self, objects: anytype, comptime field: []const u8) anyerror!?WlMessage {
        const rdr = self.rx.reader();

        // We need to have read at least a header
        const remaining_before_header = (try self.rx.getEndPos()) - (try self.rx.getPos());
        if (remaining_before_header < @sizeOf(u32) + @sizeOf(u16) + @sizeOf(u16)) return null;

        const header = Header{
            .id = try rdr.readIntNative(u32),
            .opcode = try rdr.readIntNative(u16),
            .length = try rdr.readIntNative(u16),
        };

        const pos_before_message_body = try self.rx.getPos();

        // We need to have read a full message
        const remaining_before_body = (try self.rx.getEndPos()) - (try self.rx.getPos());
        if (remaining_before_body < header.length) return null;

        var object = @field(objects, field)(header.id) orelse return error.CouldntFindExpectedId;

        const event = try object.readMessage(objects, field, header.opcode);

        const actual_length = (try self.rx.getPos()) - pos_before_message_body;
        if (actual_length != header.length) return error.MessageWrongLength;

        return event;
    }

    pub fn nextU32(self: *Self) !u32 {
        return self.rx.reader().readIntNative(u32);
    }

    pub fn nextI32(self: *Self) !i32 {
        return self.rx.reader().readIntNative(i32);
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
        s.ptr = @ptrCast([*]u8, &self.rx_buf[start]);
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
        try self.tx.writer().writeIntNative(u32, 0);
        try self.tx.writer().writeIntNative(u16, 0);
        try self.tx.writer().writeIntNative(u16, 0);
    }

    pub fn finishWrite(self: *Self, id: u32, opcode: u16) !void {
        const end_pos = math.cast(u16, try self.tx.getPos()) orelse return error.EndPositionMustBeU16;
        self.tx.reset();

        try self.tx.writer().writeIntNative(u32, id);
        try self.tx.writer().writeIntNative(u16, opcode);
        try self.tx.writer().writeIntNative(u16, end_pos);

        _ = try txrx.sendMsg(self.fd, self.tx_buf[0..end_pos], &self.tx_fds);
    }

    pub fn putU32(self: *Self, value: u32) !void {
        try self.tx.writer().writeIntNative(u32, value);
    }

    pub fn putI32(self: *Self, value: i32) !void {
        try self.tx.writer().writeIntNative(i32, value);
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

        mem.copy(u8, self.tx_buf[start .. start + length], array);
    }

    // string is assumed to have a null byte within its contents / length
    pub fn putString(self: *Self, string: []const u8) !void {
        const length = math.cast(u32, string.len) orelse return error.ArrayTooBig;
        const padded_length = length + padding(length);

        try self.putU32(length);
        const start = try self.tx.getPos();

        try self.tx.seekBy(padded_length);

        std.mem.copy(u8, self.tx_buf[start .. start + length], string);
    }
    // };
};

fn doubleToFixed(f: f64) i32 {
    var x: f64 = f + (3 << (51 - 8));
    var x_ptr = @ptrCast(*i32, &x);
    return x_ptr.*;
}

fn fixedToDouble(f: i32) f64 {
    var x: i32 = ((1023 + 44) << 52) + (1 << 51) + f;
    var x_ptr = @ptrCast(*f64, &x);
    return x_ptr.*;
}

fn padding(num_bytes: u32) u32 {
    return (4 - num_bytes % 4) % 4;
}
