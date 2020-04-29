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

    return @intCast(usize, rc);
}