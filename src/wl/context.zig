const std = @import("std");
const fifo = std.fifo;
const Client = @import("../client.zig").Client;
const txrx = @import("txrx.zig");
const AutoHashMap = std.hash_map.AutoHashMap;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;
const FdBuffer = LinearFifo(i32, LinearFifoBufferType{ .Static = MAX_FDS });
const MAX_FDS = @import("txrx.zig").MAX_FDS;
const BUFFER_SIZE = 4096;

pub fn Context(comptime T: type) type {
    return struct {
        client: T,
        fd: i32 = -1,
        read_offset: usize = 0,
        write_offset: usize = 0,
        rx_fds: FdBuffer,
        rx_buf: [BUFFER_SIZE]u8,
        objects: AutoHashMap(u32, Object),
        tx_fds: FdBuffer,
        tx_buf: [BUFFER_SIZE]u8,
        tx_write_offset: usize = 0,

        const Self = @This();

        pub const Object = struct {
            dispatch: fn (Object, u16) anyerror!void,
            context: *Self,
            container: usize,
            id: u32,
            version: u32,
        };

        pub fn init(self: *Self, fd: i32, client: T) void {
            self.fd = fd;
            self.client = client;
            self.read_offset = 0;
            self.write_offset = 0;

            self.rx_fds = FdBuffer.init();
            self.tx_fds = FdBuffer.init();

            self.objects = AutoHashMap(u32, Object).init(std.heap.page_allocator);
        }

        pub fn deinit(self: *Self) void {
            self.objects.deinit();
        }

        pub fn dispatch(self: *Self) anyerror!void {
            var n = try txrx.recvMsg(self.fd, self.rx_buf[self.write_offset..self.rx_buf.len], &self.rx_fds);
            n = self.write_offset + n;

            self.read_offset = 0;
            defer {
                self.write_offset = n - self.read_offset;
                std.mem.copy(u8, self.rx_buf[0..self.write_offset], self.rx_buf[self.read_offset..n]);
            }

            while (self.read_offset < n) {
                const remaining = n - self.read_offset;

                // We need to have read at least a header
                if (remaining < @sizeOf(Header)) return;

                const message_start_offset = self.read_offset;
                const header = @ptrCast(*Header, &self.rx_buf[message_start_offset]);

                // We need to have read a full message
                if (remaining < header.length) return;

                self.read_offset += @sizeOf(Header);
                const object = self.objects.get(header.id) orelse return error.CouldntFindExpectedId;
                try object.dispatch(object, header.opcode);

                if ((self.read_offset - message_start_offset) != header.length) {
                    self.read_offset = 0;
                    return error.MessageWrongLength;
                }
            }
        }

        pub fn next_u32(self: *Self) !u32 {
            var next_offset = self.read_offset + @sizeOf(u32);
            if (next_offset > self.rx_buf.len) {
                return error.NextReadsPastEndOfBuffer;
            }

            defer {
                self.read_offset = next_offset;
            }
            return @ptrCast(*u32, @alignCast(@alignOf(u32), &self.rx_buf[self.read_offset])).*;
        }

        pub fn next_i32(self: *Self) !i32 {
            var next_offset = self.read_offset + @sizeOf(i32);
            if (next_offset > self.rx_buf.len) {
                return error.NextReadsPastEndOfBuffer;
            }

            defer {
                self.read_offset = next_offset;
            }
            return @ptrCast(*i32, @alignCast(@alignOf(i32), &self.rx_buf[self.read_offset])).*;
        }

        // we just expose a pointer to the rx_buf for the
        // extent of the dispatch call. This will become invalid
        // after the dispatch function returns and so we cannot
        // hang on to this pointer. If we want to retain the string
        // we should copy it.
        pub fn next_string(self: *Self) ![]u8 {
            var length = try self.next_u32();
            var next_offset = self.read_offset + @sizeOf(u32) * @divTrunc(length - 1, @sizeOf(u32)) + @sizeOf(u32);
            if (next_offset > self.rx_buf.len) {
                return error.NextReadsPastEndOfBuffer;
            }

            var s: []u8 = undefined;
            s.ptr = @ptrCast([*]u8, &self.rx_buf[self.read_offset]);
            s.len = length;
            self.read_offset = next_offset;
            return s;
        }

        // we just expose a pointer to the rx_buf for the
        // extent of the dispatch call. This will become invalid
        // after the dispatch function returns and so we cannot
        // hang on to this pointer. If we want to retain the array
        // we should copy it.
        pub fn next_array(self: *Self) ![]u32 {
            var length = try self.next_u32();
            var next_offset = self.read_offset + length;
            if (next_offset > self.rx_buf.len) {
                return error.NextReadsPastEndOfBuffer;
            }

            var s: []u32 = undefined;
            s.ptr = @ptrCast(*u32, @alignCast(@alignOf(u32), &self.rx_buf[self.read_offset]));
            s.len = length / @sizeOf(u32);
            self.read_offset = next_offset;
            return s;
        }

        pub fn next_fd(self: *Self) !i32 {
            return self.rx_fds.readItem() orelse return error.FdReadFailed;
        }

        pub fn get(self: *Self, id: u32) ?*Object {
            if (self.objects.get(id)) |*o| {
                return o;
            }
            return null;
        }

        pub fn register(self: *Self, object: Object) !void {
            var x = try self.objects.put(object.id, object);
            return;
        }

        pub fn unregister(self: *Self, object: Object) !void {
            if (self.objects.remove(object.id)) |x| {
                // std.debug.warn("unregistered: {}\n", .{x.key});
            } else {
                std.debug.warn("attempted to deregister object ({}) that didn't exist\n", .{object.id});
            }
            return;
        }

        pub fn startWrite(self: *Self) void {
            self.tx_write_offset = 0;
            self.tx_write_offset += @sizeOf(Header);
        }

        pub fn finishWrite(self: *Self, id: u32, opcode: u16) void {
            var h = Header{
                .id = id,
                .opcode = opcode,
                .length = @intCast(u16, self.tx_write_offset),
            };
            var h_ptr = @ptrCast(*Header, &self.tx_buf[0]);
            h_ptr.* = h;
            var x = txrx.sendMsg(self.fd, self.tx_buf[0..self.tx_write_offset], &self.tx_fds);
        }

        pub fn putU32(self: *Self, value: u32) void {
            var u32_ptr = @ptrCast(*u32, @alignCast(@alignOf(u32), &self.tx_buf[self.tx_write_offset]));
            u32_ptr.* = value;
            self.tx_write_offset += @sizeOf(u32);
        }

        pub fn putI32(self: *Self, value: i32) void {
            var i32_ptr = @ptrCast(*i32, @alignCast(@alignOf(i32), &self.tx_buf[self.tx_write_offset]));
            i32_ptr.* = value;
            self.tx_write_offset += @sizeOf(i32);
        }

        pub fn putFd(self: *Self, value: i32) void {
            // TODO: I guess we need to error
            self.tx_fds.writeItem(value) catch return;
        }

        pub fn putFixed(self: *Self, value: f64) void {
            var fixed = doubleToFixed(value);
            var i32_ptr = @ptrCast(*i32, @alignCast(@alignOf(i32), &self.tx_buf[self.tx_write_offset]));
            i32_ptr.* = fixed;
            self.tx_write_offset += @sizeOf(i32);
        }

        pub fn putArray(self: *Self, array: []u32) void {
            // Write our array length (in bytes) into buffer
            var len_ptr = @ptrCast(*u32, @alignCast(@alignOf(u32), &self.tx_buf[self.tx_write_offset]));
            len_ptr.* = @intCast(u32, @sizeOf(u32) * array.len);
            self.tx_write_offset += @sizeOf(u32);

            // Copy data from array into tx_buf
            var tx_buf: []u32 = undefined;
            tx_buf.ptr = @ptrCast([*]u32, @alignCast(@alignOf(u32), &self.tx_buf[self.tx_write_offset]));
            tx_buf.len = (self.tx_buf.len - self.tx_write_offset) / @sizeOf(u32);

            std.mem.copy(u32, tx_buf, array[0..array.len]);
            self.tx_write_offset += @sizeOf(u32) * array.len;
        }

        // string is assumed to have a null byte within its contents / length
        pub fn putString(self: *Self, string: []const u8) void {
            // Write our array length (in bytes) into buffer
            var length = @sizeOf(u32) * @divTrunc(string.len - 1, @sizeOf(u32)) + @sizeOf(u32);
            var len_ptr = @ptrCast(*u32, @alignCast(@alignOf(u32), &self.tx_buf[self.tx_write_offset]));
            len_ptr.* = @intCast(u32, length);
            self.tx_write_offset += @sizeOf(u32);

            std.mem.copy(u8, self.tx_buf[self.tx_write_offset .. self.tx_write_offset + string.len], string);
            std.mem.set(u8, self.tx_buf[self.tx_write_offset + string.len .. self.tx_write_offset + length], 0);
            self.tx_write_offset += length;
        }
    };
}

pub const Header = packed struct {
    id: u32,
    opcode: u16,
    length: u16,
};

pub fn doubleToFixed(f: f64) i32 {
    var x: f64 = f + (3 << (51 - 8));
    var x_ptr = @ptrCast(*i32, &x);
    return x_ptr.*;
}

pub fn fixedToDouble(f: i32) f64 {
    var x: i32 = ((1023 + 44) << 52) + (1 << 51) + f;
    var x_ptr = @ptrCast(*f64, &x);
    return x_ptr.*;
}
