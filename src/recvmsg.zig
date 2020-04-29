const std = @import("std");
const linux = std.os.linux;

pub fn recvMsg(fd: i32, buffer: []u8, fds: []i32) !usize {
    var iov: linux.iovec = undefined;
    iov.iov_base = @ptrCast([*]u8, &buffer[0]);
    iov.iov_len = buffer.len;

    var control: [128]u8 = undefined; // We need to figure out the correct size for this (see CMSG_SPACE / CMSG_LEN)

    var msg = linux.msghdr{
        .msg_name = null,
        .msg_namelen = 0,
        .msg_iov = @ptrCast([*]std.os.iovec, &iov),
        .msg_iovlen = 1,
        .msg_control = &control[0],
        .msg_controllen = control.len,
        .msg_flags = 0,
        .__pad1 = 0,
        .__pad2 = 0,
    };

    var rc: usize = 0;
    while (true) {
        rc = linux.recvmsg(fd, &msg, linux.MSG_DONTWAIT | linux.MSG_CMSG_CLOEXEC);
        switch (linux.getErrno(rc)) {
            0 => break,
            linux.EINTR => continue,
            linux.EINVAL => unreachable,
            linux.EFAULT => unreachable,
            linux.EAGAIN => if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdReadable(fd);
                continue;
            } else {
                return error.WouldBlock;
            },
            linux.EBADF => unreachable, // Always a race condition.
            linux.EIO => return error.InputOutput,
            linux.EISDIR => return error.IsDir,
            linux.ENOBUFS => return error.SystemResources,
            linux.ENOMEM => return error.SystemResources,
            linux.ECONNRESET => return error.ConnectionResetByPeer,
            else => |err| return error.Unexpected,
        }
    }

    var oobn = msg.msg_controllen;
    if (oobn > 0) {
        std.debug.warn("{x}\n", .{ control });
    }

    std.debug.warn("rc: {}, oobn: {}\n", .{ rc, oobn });

    std.debug.warn("msghdr size: {}\n", .{ @sizeOf(linux.msghdr) });
    std.debug.warn("msghdr alignment: {}\n", .{ @alignOf(linux.msghdr) });
    std.debug.warn("cmsghdr size: {}\n", .{ @sizeOf(cmsghdr) });
    std.debug.warn("cmsghdr alignment: {}\n", .{ @alignOf(cmsghdr) });
    std.debug.warn("x: {}\n", .{ cmsg_len(@sizeOf(i32)) });
    std.debug.warn("y: {}\n", .{ cmsg_firsthdr(@ptrCast(*linux.msghdr, &msg)) });

    return @intCast(usize, rc);
}

fn cmsg_space(size: comptime isize) c_int {
    return @bitCast(c_int, @truncate(c_uint, ((((@bitCast(c_ulong, @as(c_long, (size))) +% @sizeOf(usize)) -% @bitCast(c_ulong, @as(c_long, @as(c_int, 1)))) & @bitCast(usize, ~(@sizeOf(usize) -% @bitCast(c_ulong, @as(c_long, @as(c_int, 1)))))) +% ((((@sizeOf(cmsghdr)) +% @sizeOf(usize)) -% @bitCast(c_ulong, @as(c_long, @as(c_int, 1)))) & @bitCast(usize, ~(@sizeOf(usize) -% @bitCast(c_ulong, @as(c_long, @as(c_int, 1)))))))));
}

fn cmsg_len(size: comptime isize) c_int {
    return @bitCast(c_int, @truncate(c_uint, (((((@sizeOf(cmsghdr)) +% @sizeOf(usize)) -% @bitCast(c_ulong, @as(c_long, @as(c_int, 1)))) & @bitCast(usize, ~(@sizeOf(usize) -% @bitCast(c_ulong, @as(c_long, @as(c_int, 1)))))) +% @bitCast(c_ulong, @as(c_long, (size))))));                                        
}

fn cmsg_data(hdr: *cmsghdr) *i32 {
    return @ptrCast([*c]c_int, @alignCast(@alignOf(c_int), &((@ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), hdr))))));
}

fn cmsg_firsthdr(msg: *linux.msghdr) ?*cmsghdr {
    return @ptrCast(?*cmsghdr,
        (if ((@ptrCast(*linux.msghdr, @alignCast(@alignOf(cmsghdr), msg))).msg_controllen >= @sizeOf(cmsghdr))
            @ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), (@ptrCast(*linux.msghdr, @alignCast(@alignOf(linux.msghdr), msg))).msg_control))
        else
            @intToPtr(?*cmsghdr, @as(c_int, 0))));
}

pub const cmsghdr = extern struct {
    // cmsg_len: linux.socklen_t does not work as this struct has align 4 (msghdr align 8 which upsets firsthdr)
    // go has this value a u64 for amd64 linux
    cmsg_len: u64, 
    cmsg_level: c_int,
    cmsg_type: c_int,
};