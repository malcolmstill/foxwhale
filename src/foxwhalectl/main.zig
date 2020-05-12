const std = @import("std");
const fs = std.fs;
const prot = @import("protocols.zig");
const epoll = @import("epoll");
const connections = @import("connection.zig");
const Connection = @import("connection.zig").Connection;
const Context = @import("connection.zig").Context;
const Object = @import("connection.zig").Object;

var conn: Connection = undefined;
var waiting: bool = true;

pub fn main() anyerror!void {
    try epoll.init();

    prot.WL_DISPLAY.delete_id = delete_id;
    prot.WL_REGISTRY.global = global;
    prot.WL_CALLBACK.done = callback_done;
    prot.FW_CONTROL.client = client;
    prot.FW_CONTROL.done = done;

    var file = try std.net.connectUnixSocket("/run/user/1000/wayland-0");
    conn.dispatchable.impl = connections.dispatch;
    conn.context.init(file.handle, &conn);

    try epoll.addFd(file.handle, &conn.dispatchable);

    var wl_display = prot.new_wl_display(1, &conn.context, 0);
    try conn.context.register(wl_display);
    var wl_registry = prot.new_wl_registry(2, &conn.context, 0);
    try conn.context.register(wl_registry);
    var wl_callback = prot.new_wl_callback(3, &conn.context, 0);
    try conn.context.register(wl_callback);

    try prot.wl_display_send_get_registry(wl_display, 2);
    try prot.wl_display_send_sync(wl_display, 3);

    while (waiting) {
        var i: usize = 0;
        var n = epoll.wait(-1);

        while (i < n) {
            try epoll.dispatch(i);
            i = i + 1;
        }
    }
}

fn delete_id(context: *Context, wl_display: Object, id: u32) anyerror!void {
    if (context.objects.get(id)) |wl_object| {
        try context.unregister(wl_object.value);
    }
}

fn global(context: *Context, wl_registry: Object, name: u32, interface: []u8, version: u32) anyerror!void {
    if (std.mem.eql(u8, interface, "fw_control\x00\x00")) {
        try prot.wl_registry_send_bind(wl_registry, name, "fw_control\x00", 1, 4);
        var fw_control = prot.new_fw_control(4, context, 0);
        try conn.context.register(fw_control);

        // As soon as we've bound the interface we can send our query
        try prot.fw_control_send_get_clients(fw_control);
    }
}

fn callback_done(context: *Context, wl_callback: Object, callback_data: u32) anyerror!void {
    // std.debug.warn("done!\n", .{});
}

fn client(context: *Context, fw_control: Object, client_index: u32) anyerror!void {
    std.debug.warn("client[{}]\n", .{client_index});
}

fn done(context: *Context, fw_control: Object) anyerror!void {
    waiting = false;
}