const std = @import("std");
const prot = @import("protocols.zig");
const epoll = @import("epoll");

pub fn main() anyerror!void {
    try epoll.init();

    var connection = std.net.connectUnixSocket("/run/user/1000/wayland-0");
    // var context = 
    // var display = prot.new_wl_display(1, )

    while (true) {

    }
}