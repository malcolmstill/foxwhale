const std = @import("std");
const os = std.os;
const Epoll = @import("epoll_pull.zig").Epoll;

const SubsystemTypes = enum {
    Input,
    Client,
};

const Event = union(SubsystemTypes) {
    Input: u8,
    Client: u8,
};

test "epoll is generic" {
    // Set up a couple of things on the other
    // end of epoll
    var input_data: [4]u8 = [_]u8{ 1, 2, 3, 4 };
    const input = try os.pipe();
    defer os.close(input[0]);
    defer os.close(input[1]);

    var client_data: [4]u8 = [_]u8{ 5, 6, 7, 8 };
    const client = try os.pipe();
    defer os.close(client[0]);
    defer os.close(client[1]);

    var e = try Epoll(Event).init(0);
    defer e.deinit();

    e.addFd(input[1], .Input);
    e.addFd(client[1], .Client);

    _ = try os.write(input[0], input_data[0..]);
    _ = try os.write(client[0], client_data[0..]);

    while (try e.next()) |ev| {
        //
    }
}
