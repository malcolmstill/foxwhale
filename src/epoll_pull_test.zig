const std = @import("std");
const os = std.os;
const Epoll = @import("epoll_pull.zig").Epoll;
const Dispatchable = @import("epoll_pull.zig").Epoll(Event).Dispatchable;

const SubsystemTypes = enum {
    Input,
    Client,
};

const Event = union(SubsystemTypes) {
    Input: u8,
    Client: ClientEvent,
};

const ClientEvent = struct {
    client_id: i32,
    payload: ClientEventPayload,
};

const ClientEventType = enum {
    HangUp,
    Even,
    Odd,
};

const ClientEventPayload = union(ClientEventType) {
    HangUp: void,
    Even: u8,
    Odd: u8,
};

const Client = struct {
    fd: i32,
    dispatchable: Dispatchable = undefined, // FIXME: no undefined

    fn init(fd: i32) Client {
        return Client{ .fd = fd };
    }

    fn addToEpoll(self: *Client, e: *Epoll(Event)) !void {
        self.dispatchable.impl = Client.dispatch;
        try e.addFd(self.fd, &self.dispatchable);
    }

    fn deinit(self: *Client) void {
        return;
    }

    fn dispatch(dispatchable: *Dispatchable, event_type: usize) anyerror!?Event {
        var client = @fieldParentPtr(Client, "dispatchable", dispatchable);

        var buf: [1]u8 = [_]u8{0} ** 1;

        if (event_type & os.linux.EPOLLHUP > 0) {
            return Event{
                .Client = .{
                    .client_id = client.fd,
                    .payload = .{ .HangUp = undefined },
                },
            };
        }

        // TODO: I want this api but seems weird we need to go as switching the
        // file descriptor to non-blocking to achieve it
        const n = os.read(client.fd, buf[0..]) catch |err| switch (err) {
            error.WouldBlock => return null,
            else => return err,
        };

        if (n == 1) {
            const v = buf[n - 1];
            if (v % 2 == 0) {
                return Event{
                    .Client = .{
                        .client_id = client.fd,
                        .payload = .{ .Even = v },
                    },
                };
            } else {
                return Event{
                    .Client = .{
                        .client_id = client.fd,
                        .payload = .{ .Odd = v },
                    },
                };
            }
        }

        return null;
    }
};

test "epoll is generic" {
    // Set up a couple of things on the other
    // end of epoll
    // var input_data: [4]u8 = [_]u8{ 1, 2, 3, 4 };
    // const input_fds = try os.pipe();
    // defer os.close(input_fds[0]);
    // defer os.close(input_fds[1]);

    var client_1_data: [4]u8 = [_]u8{ 5, 6, 7, 8 };
    const client_1_fds = try os.pipe();
    std.debug.print("fds = {any}\n", .{client_1_fds});
    // defer os.close(client_1_fds[0]);
    // defer os.close(client_1_fds[1]);

    var client_2_data: [5]u8 = [_]u8{ 9, 10, 11, 12, 13 };
    const client_2_fds = try os.pipe();
    // defer os.close(client_2_fds[0]);
    // defer os.close(client_2_fds[1]);

    var e = try Epoll(Event).init(0);
    defer e.deinit();

    // E.g. two clients connect
    var client_1 = Client.init(client_1_fds[0]);
    defer client_1.deinit();

    var client_2 = Client.init(client_2_fds[0]);
    defer client_2.deinit();

    // I want to pass the type of the file descriptor
    // I also need to specify the dispatch function
    // e.addFd(input_fds[1], .Input);
    // e.addFd(client_1_fds[1], .Client);
    try client_1.addToEpoll(&e);
    try client_2.addToEpoll(&e);

    // _ = try os.write(input_fds[0], input_data[0..]);
    _ = try os.write(client_1_fds[1], client_1_data[0..]);

    while (try e.next()) |ev| {
        std.debug.print("{}\n", .{ev});
    }

    std.debug.print("Done\n", .{});
}
