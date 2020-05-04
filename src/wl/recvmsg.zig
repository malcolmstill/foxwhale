const std = @import("std");
const linux = std.os.linux;

pub const MAX_FDS = 28;

pub fn recvMsg(fd: i32, buffer: []u8, fds: []i32) !usize {
    var iov: linux.iovec = undefined;
    iov.iov_base = @ptrCast([*]u8, &buffer[0]);
    iov.iov_len = buffer.len;

    var control: [cmsg_space(MAX_FDS*@sizeOf(i32))]u8 = undefined;

    std.debug.warn("control.len: {}\n", .{ control.len });

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

    // TOOD: we should not assume a single CMSG
    var maybe_cmsg = cmsg_firsthdr_ng2(&msg);
    if (maybe_cmsg) |cmsg| {
        if (cmsg.cmsg_type == SCM_RIGHTS and cmsg.cmsg_level == linux.SOL_SOCKET) {
            var data: []i32 = undefined;
            data.ptr = @ptrCast([*]i32, @alignCast(@alignOf(i32), cmsg_data_ng(cmsg)));
            data.len = (cmsg.cmsg_len - cmsg_len_ng(0))/@sizeOf(i32); 
            std.mem.copy(i32, fds[0..fds.len], data);
        }
    }

    return @intCast(usize, rc);
}


// Probably not portable stuff is below
const SCM_RIGHTS = 0x01;

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

fn cmsg_nxthdr(msg: *linux.msghdr, cmsg: *cmsghdr) ?*cmsghdr {
    return @ptrCast(?*c_void,
        (if ((@bitCast(c_ulong, @as(c_ulong, (@ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), cmsg))).cmsg_len)) < @sizeOf(cmsghdr)) or (((((@bitCast(c_ulong, @as(c_ulong, (@ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), cmsg))).cmsg_len)) +% @sizeOf(c_long)) -% @bitCast(c_ulong, @as(c_long, @as(c_int, 1)))) & @bitCast(c_ulong, ~@bitCast(c_long, (@sizeOf(c_long) -% @bitCast(c_ulong, @as(c_long, @as(c_int, 1))))))) +% @sizeOf(cmsghdr)) >= @bitCast(c_ulong, ((@ptrCast([*c]u8, @alignCast(@alignOf(u8), (@ptrCast(*linux.msghdr, @alignCast(@alignOf(linux.msghdr), msg))).msg_control)) + (@ptrCast(*linux.msghdr, @alignCast(@alignOf(linux.msghdr), msg))).msg_controllen) - @ptrToInt(@ptrCast([*c]u8, @alignCast(@alignOf(u8), (@ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), cmsg))))))))))
            null
        else
            @ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), (@ptrCast([*c]u8, @alignCast(@alignOf(u8), (@ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), cmsg))))) + (((@bitCast(c_ulong, @as(c_ulong, (@ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), cmsg))).cmsg_len)) +% @sizeOf(c_long)) -% @bitCast(c_ulong, @as(c_long, @as(c_int, 1)))) & @bitCast(c_ulong, ~@bitCast(c_long, (@sizeOf(c_long) -% @bitCast(c_ulong, @as(c_long, @as(c_int, 1))))))))))));
}

pub const cmsghdr = extern struct {
    // cmsg_len: linux.socklen_t does not work as this struct has align 4 (msghdr align 8 which upsets firsthdr)
    // go has this value a u64 for amd64 linux
    cmsg_len: u64, 
    cmsg_level: c_int,
    cmsg_type: c_int,
};

// New implementation

fn cmsg_align_ng(size: usize) usize {
    return (size + @sizeOf(usize) - 1) & ~(@intCast(usize, @sizeOf(usize) -1));
}

fn cmsg_len_ng(size: usize) usize {
    return cmsg_align_ng(@sizeOf(cmsghdr)) + size;
}

fn cmsg_space_ng(size: usize) usize {
    return cmsg_align_ng(size) + cmsg_align_ng(@sizeOf(cmsghdr));
}

fn cmsg_firsthdr_ng(msg: *linux.msghdr) ?*cmsghdr {
    if (msg.msg_controllen >= @sizeOf(cmsghdr)) {
        return @ptrCast(?*cmsghdr, msg.msg_control);
    } else {
        return null;
    }
}

fn cmsg_nxthdr_ng(mhdr: *linux.msghdr, cmsg: *cmsghdr) ?*cmsghdr {
    if ((cmsg.cmsg_len < @sizeOf(cmsghdr)) || ((__cmsg_len(cmsg) + @sizeOf(cmsghdr)) >= (__mgdr_end(mhdr) - @ptrCast(*u8, cmsg)))) {
        return null;
    } else {
        return __cmsg_next(cmsg);
    }
}

fn cmsg_data_ng(cmsg: *cmsghdr) *u8 {
    // return @ptrCast(*u8, (@ptrToInt(cmsg) + 1));
    return @intToPtr(*u8, @ptrToInt(cmsg) + 1);
}

fn __cmsg_next(cmsg: *cmsghdr) *u8 {
    return @ptrCast(*u8, cmsg) + __cmsg_len(cmsg);
}

fn __cmsg_len(cmsg: *cmsghdr) usize {
    return (cmsg.cmsg_len + @sizeOf(u64) - 1) & ~(@intCast(u64, @sizeOf(u64) - 1));
}

fn __mgdr_end(msg: *linux.msghdr) usize {
    return msg.msg_control + msg.msg_controllen;
}

fn cmsg_firsthdr_ng2(msg: *linux.msghdr) ?*cmsghdr {
    if (msg.msg_controllen < @sizeOf(cmsghdr)) {
        return null;
    }
    return @ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), @alignCast(@alignOf(linux.msghdr), msg).msg_control));
}