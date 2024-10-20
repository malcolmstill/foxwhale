const std = @import("std");
const os = std.os;
const linux = std.os.linux;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;
const FdBuffer = LinearFifo(i32, LinearFifoBufferType{ .Static = MAX_FDS });

pub const MAX_FDS = 28;

pub fn recvMsg(fd: i32, buffer: []u8, fds: *FdBuffer) !usize {
    var iov: std.posix.iovec = undefined;
    iov.base = @ptrCast(&buffer[0]);
    iov.len = buffer.len;

    var control: [cmsg_space(MAX_FDS * @sizeOf(i32))]u8 = undefined;

    var msg = linux.msghdr{
        .name = null,
        .namelen = 0,
        .iov = @ptrCast(&iov),
        .iovlen = 1,
        .control = &control[0],
        .controllen = control.len,
        .flags = 0,
        .__pad1 = 0,
        .__pad2 = 0,
    };

    var rc: usize = 0;
    while (true) {
        rc = linux.recvmsg(fd, @ptrCast(&msg), linux.MSG.DONTWAIT | linux.MSG.CMSG_CLOEXEC);
        switch (std.posix.errno(rc)) {
            .SUCCESS => break,
            linux.E.INTR => continue,
            linux.E.INVAL => unreachable,
            linux.E.FAULT => unreachable,
            // linux.E.AGAIN => if (std.event.Loop.instance) |loop| {
            //     loop.waitUntilFdReadable(fd);
            //     continue;
            // } else {
            //     return error.WouldBlock;
            // },
            linux.E.AGAIN => return error.WouldBlock,
            linux.E.BADF => unreachable, // Always a race condition.
            linux.E.IO => return error.InputOutput,
            linux.E.ISDIR => return error.IsDir,
            linux.E.NOBUFS => return error.SystemResources,
            linux.E.NOMEM => return error.SystemResources,
            linux.E.CONNRESET => return error.ConnectionResetByPeer,
            else => |_| return error.Unexpected,
        }
    }

    // TOOD: we should not assume a single CMSG
    const maybe_cmsg = cmsg_firsthdr(&msg);
    if (maybe_cmsg) |cmsg| {
        if (cmsg.cmsg_type == SCM_RIGHTS and cmsg.cmsg_level == linux.SOL.SOCKET) {
            var data: []i32 = undefined;
            data.ptr = @ptrCast(@alignCast(cmsg_data(cmsg)));
            data.len = (cmsg.cmsg_len - cmsg_len(0)) / @sizeOf(i32);

            const writable = try fds.writableWithSize(data.len);
            std.mem.copyForwards(i32, writable, data);
            fds.update(data.len);
        }
    }

    return @intCast(rc);
}

pub fn sendMsg(fd: i32, buffer: []u8, fds: *FdBuffer) !usize {
    var iov: std.posix.iovec_const = undefined;
    iov.base = @ptrCast(&buffer[0]);
    iov.len = buffer.len;

    var control: [cmsg_space(MAX_FDS * @sizeOf(i32))]u8 = undefined;
    var msg_hdr: *cmsghdr = @ptrCast(@alignCast(&control[0]));

    // Copy fds from `fds` to control
    const incoming_slice = fds.readableSlice(0);
    msg_hdr.cmsg_len = cmsg_len(@sizeOf(i32) * incoming_slice.len);
    msg_hdr.cmsg_type = SCM_RIGHTS;
    msg_hdr.cmsg_level = linux.SOL.SOCKET;
    var fds_ptr: []i32 = undefined;
    fds_ptr.len = MAX_FDS;
    fds_ptr.ptr = @ptrCast(@alignCast(cmsg_data(msg_hdr)));
    std.mem.copyForwards(i32, fds_ptr, incoming_slice);
    fds.discard(incoming_slice.len);

    const msg = linux.msghdr_const{
        .name = null,
        .namelen = 0,
        .iov = @ptrCast(&iov),
        .iovlen = 1,
        .control = if (incoming_slice.len == 0) null else msg_hdr, // we'll need to change this when send file descriptor
        .controllen = if (incoming_slice.len == 0) 0 else @truncate(msg_hdr.cmsg_len), // we'll need to change this when we send file desricptor
        .flags = 0,
        .__pad1 = 0,
        .__pad2 = 0,
    };

    return try std.posix.sendmsg(fd, &msg, linux.MSG.NOSIGNAL);
}

// Probably not portable stuff is below
const SCM_RIGHTS = 0x01;

pub const cmsghdr = extern struct {
    // cmsg_len: linux.socklen_t does not work as this struct has align 4 (msghdr align 8 which upsets firsthdr)
    // go has this value a u64 for amd64 linux
    cmsg_len: u64,
    cmsg_level: c_int,
    cmsg_type: c_int,
};

// New implementation

fn cmsg_align(size: usize) usize {
    return (size + @sizeOf(usize) - 1) & ~(@as(usize, @intCast(@sizeOf(usize) - 1)));
}

fn cmsg_len(size: usize) usize {
    return cmsg_align(@sizeOf(cmsghdr)) + size;
}

fn cmsg_space(size: usize) usize {
    return cmsg_align(size) + cmsg_align(@sizeOf(cmsghdr));
}

fn cmsg_data(cmsg: *cmsghdr) *u8 {
    // currently only written for x86_64 linux...compatibility coming later
    // in the case of x86_64 linux the header is 16 bytes which is itself
    // align(4) and therefore there is no padding between header and data
    return @ptrFromInt(@intFromPtr(cmsg) + @sizeOf(cmsghdr));
}

fn cmsg_firsthdr(msg: *linux.msghdr) ?*cmsghdr {
    if (msg.controllen < @sizeOf(cmsghdr)) {
        return null;
    }

    return @ptrCast(@alignCast(msg.control));
}
