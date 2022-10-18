const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const epoll = @import("epoll.zig");
const Event = @import("subsystem.zig").Event;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const ClientEvent = @import("subsystem.zig").ClientEvent;
const ClientTargetEvent = @import("subsystem.zig").ClientTargetEvent;
const Context = @import("wl/context.zig").Context;
const WlObject = @import("protocols.zig").WlObject;
const WlDisplay = @import("protocols.zig").WlDisplay;
const WlRegistry = @import("protocols.zig").WlRegistry;
const WlCompositor = @import("protocols.zig").WlCompositor;
const WlShm = @import("protocols.zig").WlShm;
const WlSurface = @import("protocols.zig").WlSurface;
const WlCallback = @import("protocols.zig").WlCallback;
const XdgWmBase = @import("protocols.zig").XdgWmBase;
const WlMessage = @import("protocols.zig").WlMessage;
// const shm_pool = @import("shm_pool.zig");
// const shm_buffer = @import("shm_buffer.zig");
// const window = @import("window.zig");
// const region = @import("region.zig");
// const positioner = @import("positioner.zig");
// const buffer = @import("buffer.zig");
// const Stalloc = @import("stalloc.zig").Stalloc;
// const Compositor = @import("compositor.zig").Compositor;

pub const Client = struct {
    // compositor: *Compositor,
    // alloc: mem.Allocator,
    connection: std.net.StreamServer.Connection,
    context: Context,
    serial: u32 = 0,
    server_id: u32 = 0xff000000 - 1,

    wl_display: WlDisplay,
    wl_registry: ?WlRegistry = null,
    wl_compositor: ?WlCompositor = null,
    xdg_wm_base: ?XdgWmBase = null,
    wl_shm: ?WlShm = null,
    // wl_data_device_manager_id: ?u32 = null,
    // wl_keyboard_id: ?u32 = null,
    // wl_output_id: ?u32 = null,
    // wl_pointer_id: ?u32 = null,
    // wl_seat_id: ?u32 = null,
    // wl_subcompositor_id: ?u32 = null,
    // fw_control_id: ?u32 = null,
    // zwp_linux_dmabuf_id: ?u32 = null,

    const Self = @This();

    pub fn initContext(self: *Self, conn: std.net.StreamServer.Connection) void {
        self.context.init(conn, self);

        try self.context.register(self.wl_display);
    }

    pub fn deinit(self: *Self) void {
        self.context.deinit();

        std.os.close(self.connection.stream.handle);

        // TODO: have caller destroy?
        self.alloc.destroy(self);
    }

    pub fn nextSerial(self: *Self) u32 {
        self.serial += 1;
        return self.serial;
    }

    pub fn nextServerId(self: *Self) u32 {
        self.server_id += 1;
        return self.server_id;
    }

    pub const Iterator = struct {
        client: *Client,
        state: State = .begin,

        const State = enum {
            begin,
            read_buffer,
            done,
        };

        pub fn init(client: *Client) Iterator {
            return Iterator{
                .client = client,
            };
        }

        pub fn next(self: *Iterator, event_type: u32) !?Event {
            if (self.state == .done) return null;

            if (event_type & std.os.linux.EPOLL.HUP > 0) {
                self.state = .done;
                return Event{
                    .client = ClientTargetEvent{
                        .target = self.client,
                        .event = ClientEvent{
                            .hangup = 0,
                        },
                    },
                };
            }

            if (self.state == .begin) {
                try self.client.context.readIntoBuffer();
                self.state = .read_buffer;
            }

            const event = self.client.context.readEvent(self.client) catch |err| {
                if (err == error.ClientSigbusd or builtin.mode != .Debug) {
                    return Event{
                        .client = ClientTargetEvent{
                            .target = self.client,
                            .event = ClientEvent{
                                .err = 0,
                            },
                        },
                    };
                } else {
                    return err;
                }
            };

            if (event == null) {
                self.client.context.finishRead();
            }

            return event;
        }
    };

    pub fn iterator(self: *Client) SubsystemIterator {
        return SubsystemIterator{ .client = Iterator.init(self) };
    }

    pub fn dispatch(self: *Client, msg: WlMessage) !void {
        switch (msg) {
            .wl_display => |p| try self.handleDisplay(p),
            .wl_registry => |p| try self.handleRegistry(p),
            .wl_compositor => |p| try self.handleCompositor(p),
            else => {
                std.log.err("UNHANDLED = {}", .{msg});
                return error.UnhandledMessage;
            },
        }
    }

    pub fn handleDisplay(self: *Client, msg: WlDisplay.Message) !void {
        switch (msg) {
            .get_registry => |p| {
                const registry = WlRegistry.init(p.registry, self, 0, 0);

                try registry.sendGlobal(1, "wl_compositor\x00", 4);
                try registry.sendGlobal(2, "wl_subcompositor\x00", 1);
                try registry.sendGlobal(3, "wl_seat\x00", 4);
                try registry.sendGlobal(4, "xdg_wm_base\x00", 1);

                // var output_base: u32 = out.OUTPUT_BASE;
                // for (context.client.compositor.outputs.items) |_| {
                //     try prot.wl_registry_send_global(wl_registry, output_base, "wl_output\x00", 2);
                //     output_base += 1;
                // }

                try registry.sendGlobal(6, "wl_data_device_manager\x00", 3);
                try registry.sendGlobal(8, "wl_shm\x00", 1);
                try registry.sendGlobal(10, "zwp_linux_dmabuf_v1\x00", 3);
                try registry.sendGlobal(11, "fw_control\x00", 1);

                self.wl_registry = registry;
                try self.context.register(WlObject{ .wl_registry = registry });
            },
            .sync => |p| {
                const callback = WlCallback.init(p.callback, self, 0, 0);

                try callback.sendDone(self.nextSerial());
                try self.wl_display.sendDeleteId(callback.id);
            },
        }
    }

    pub fn handleRegistry(self: *Client, msg: WlRegistry.Message) !void {
        switch (msg) {
            .bind => |p| switch (p.name) {
                1 => {
                    if (!mem.eql(u8, p.name_string, "wl_compositor\x00")) return error.UnexpectedName;
                    self.wl_compositor = WlCompositor.init(p.id, self, p.version, 0);
                    try self.context.register(WlObject{ .wl_compositor = self.wl_compositor.? });
                },
                4 => {
                    if (!mem.eql(u8, p.name_string, "xdg_wm_base\x00")) return error.UnexpectedName;
                    self.xdg_wm_base = XdgWmBase.init(p.id, self, p.version, 0);
                    try self.context.register(WlObject{ .xdg_wm_base = self.xdg_wm_base.? });
                },
                8 => {
                    if (!std.mem.eql(u8, p.name_string, "wl_shm\x00")) return error.UnexpectedName;
                    self.wl_shm = WlShm.init(p.id, self, p.version, 0);

                    try self.wl_shm.?.sendFormat(WlShm.Format.argb8888);
                    try self.wl_shm.?.sendFormat(WlShm.Format.xrgb8888);

                    try self.context.register(WlObject{ .wl_shm = self.wl_shm.? });
                },

                else => return error.NoSuchGlobal,
            },
        }
    }

    pub fn handleCompositor(self: *Client, msg: WlCompositor.Message) !void {
        switch (msg) {
            .create_surface => |p| {
                const surface = WlSurface.init(p.id, self, 0, 0);
                // TODO: Add window and link to surface
                try self.context.register(WlObject{ .wl_surface = surface });
            },
            else => return error.WlCompositorUnhandledMessage,
        }
    }
};
