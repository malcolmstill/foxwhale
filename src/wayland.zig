
const std = @import("std");
const fs = std.fs;

pub fn socket() !std.net.StreamServer {
    var x = std.os.unlink("/run/user/1000/wayland-0");
    var addr = try std.net.Address.initUnix("/run/user/1000/wayland-0");
    
    var l = std.net.StreamServer.init(.{});
    // defer { l.deinit(); }
    try l.listen(addr);

    return l;
}
