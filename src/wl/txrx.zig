const std = @import("std");
const linux = std.os.linux;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;
const FdBuffer = LinearFifo(i32, LinearFifoBufferType{ .Static = MAX_FDS });

pub const MAX_FDS = 28;

pub fn recvMsg(fd: i32, buffer: []u8, fds: []i32) !usize {
    var iov: linux.iovec = undefined;
    iov.iov_base = @ptrCast([*]u8, &buffer[0]);
    iov.iov_len = buffer.len;

    var control: [cmsg_space(MAX_FDS*@sizeOf(i32))]u8 = undefined;

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
    var maybe_cmsg = cmsg_firsthdr(&msg);
    if (maybe_cmsg) |cmsg| {
        if (cmsg.cmsg_type == SCM_RIGHTS and cmsg.cmsg_level == linux.SOL_SOCKET) {
            var data: []i32 = undefined;
            data.ptr = @ptrCast([*]i32, @alignCast(@alignOf(i32), cmsg_data(cmsg)));
            data.len = (cmsg.cmsg_len - cmsg_len(0))/@sizeOf(i32);
            std.mem.copy(i32, fds[0..fds.len], data);
        }
    }

    return @intCast(usize, rc);
}

pub fn sendMsg(fd: i32, buffer: []u8, fds: *FdBuffer) !usize {
    var iov: linux.iovec_const = undefined;
    iov.iov_base = @ptrCast([*]u8, &buffer[0]);
    iov.iov_len = buffer.len;

    var control: [cmsg_space(MAX_FDS*@sizeOf(i32))]u8 = undefined;
    var msg_hdr: *cmsghdr = @ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), &control[0]));

    // Copy fds from `fds` to control
    var incoming_slice = fds.readableSlice(0);
    msg_hdr.cmsg_len = cmsg_len(@sizeOf(i32) * incoming_slice.len);
    msg_hdr.cmsg_type = SCM_RIGHTS;
    msg_hdr.cmsg_level = linux.SOL_SOCKET;
    var fds_ptr: []i32 = undefined;
    fds_ptr.len = MAX_FDS;
    fds_ptr.ptr = @ptrCast([*]i32, @alignCast(@alignOf(i32), cmsg_data(msg_hdr)));
    std.mem.copy(i32, fds_ptr, incoming_slice);
    fds.discard(incoming_slice.len);

    var msg = linux.msghdr_const{
        .msg_name = null,
        .msg_namelen = 0,
        .msg_iov = @ptrCast([*]std.os.iovec_const, &iov),
        .msg_iovlen = 1,
        .msg_control = if (incoming_slice.len == 0) null else msg_hdr, // we'll need to change this when send file descriptor
        .msg_controllen = if (incoming_slice.len == 0) 0 else @truncate(u32, msg_hdr.cmsg_len), // we'll need to change this when we send file desricptor
        .msg_flags = 0,
        .__pad1 = 0,
        .__pad2 = 0,
    };

    var rc: usize = 0;
    while (true) {
        rc = linux.sendmsg(fd, &msg, linux.MSG_NOSIGNAL);
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

    return @intCast(usize, rc);
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
    return (size + @sizeOf(usize) - 1) & ~(@intCast(usize, @sizeOf(usize) -1));
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
    return @intToPtr(*u8, @ptrToInt(cmsg) + @sizeOf(cmsghdr));
}

fn cmsg_firsthdr(msg: *linux.msghdr) ?*cmsghdr {
    if (msg.msg_controllen < @sizeOf(cmsghdr)) {
        return null;
    }
    return @ptrCast(*cmsghdr, @alignCast(@alignOf(cmsghdr), @alignCast(@alignOf(linux.msghdr), msg).msg_control));
}