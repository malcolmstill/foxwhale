const std = @import("std");
const fifo = std.fifo;
const txrx = @import("txrx.zig");
// const HashMap = std.hash_map.HashMap;
const AutoHashMap = std.hash_map.AutoHashMap;
const MAX_FDS = @import("txrx.zig").MAX_FDS;

pub const Context = struct {
    read_offset: usize = 0,
    write_offset: usize = 0,
    recv_fds: [MAX_FDS]i32,
    recv_buf: [512]u8,
    // fds: FifoType,
    objects: AutoHashMap(u32, Object),

    const Self = @This();
    // const FifoType = std.fifo.LinearFifo(isize, .Dynamic);

    pub fn init(self: *Self) void {
        self.objects = AutoHashMap(u32, Object).init(std.heap.page_allocator);
    }

    pub fn deinit(self: *Self) void {
        self.objects.deinit();
    }

    pub fn dispatch(self: *Self, fd: i32) !void {
        var n = try txrx.recvMsg(fd, self.recv_buf[self.write_offset..self.recv_buf.len], self.recv_fds[0..self.recv_fds.len]);
        n = self.write_offset + n;

        // var offset: usize = 0;
        self.read_offset = 0;
        defer {
            // self.write_offset = n - offset;
            self.write_offset = n - self.read_offset;
            std.mem.copy(u8, self.recv_buf[0..self.write_offset], self.recv_buf[self.read_offset..n]);
        }

        while (self.read_offset < n) {
            var remaining = n - self.read_offset;

            // We need to have read at least a header
            if (remaining < @sizeOf(Header)) {
                return;
            }

            var header = @ptrCast(*Header, &self.recv_buf[self.read_offset]);
            std.debug.warn("{}\n", .{ header });

            // We need to have read a full message
            if (remaining < header.length) {
                return;
            }

            // std.debug.warn("paylod: {x}\n", .{ self.recv_buf[offset..offset+header.length] });
            self.read_offset += @sizeOf(Header);
            if (self.objects.get(header.id)) |object| {
                // std.debug.warn("object: {}\n", .{object});
                object.value.dispatch(self, header.opcode);
            }

            // offset = offset + header.length;
        }
    }

    pub fn next_u32(self: *Self) u32 {
        defer { self.read_offset += @sizeOf(u32); }
        return @ptrCast(*u32, @alignCast(@alignOf(u32), &self.recv_buf[self.read_offset])).*;
    }

    pub fn next_i32(self: *Self) i32 {
        defer { self.read_offset += @sizeOf(i32); }
        return @ptrCast(*i32, @alignCast(@alignOf(i32), &self.recv_buf[self.read_offset])).*;
    }

    // we just expose a pointer to the recv_buf for the
    // extent of the dispatch call. This will become invalid
    // after the dispatch function returns and so we cannot
    // hang on to this pointer. If we want to retain the string
    // we should copy it.
    pub fn next_string(self: *Self) []u8 {
        var length = self.next_u32();
        var s: []u8 = undefined;
        s.ptr = &self.recv_buf[self.read_offset];
        s.len = length;
        self.read_offset += length;
        return s;
    }

    // we just expose a pointer to the recv_buf for the
    // extent of the dispatch call. This will become invalid
    // after the dispatch function returns and so we cannot
    // hang on to this pointer. If we want to retain the array
    // we should copy it.
    pub fn next_array(self: *Self) []u32 {
        var length = self.next_u32();
        var s: []32 = undefined;
        s.ptr = @ptrCast(*u32, @alignCast(@alignOf(u32), &self.recv_buf[self.read_offset]));
        s.len = length/@sizeOf(u32);
        self.read_offset += length;
        return s;
    }

    pub fn register(self: *Self, object: Object) !void {
        var x = try self.objects.put(object.id, object);
        return;
    }
};

pub const Object = struct {
    id: u32,
    dispatch: fn(*Context, u16) void,
};

pub const Header = packed struct {
    id: u32,
    opcode: u16,
    length: u16,
};