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
const WlRegion = @import("protocols.zig").WlRegion;
const WlCallback = @import("protocols.zig").WlCallback;
const XdgWmBase = @import("protocols.zig").XdgWmBase;
const XdgSurface = @import("protocols.zig").XdgSurface;
const XdgToplevel = @import("protocols.zig").XdgToplevel;
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
    conn: std.net.StreamServer.Connection,
    context: Context,
    serial: u32 = 0,
    server_id: u32 = 0xFF00_0000 - 1,

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

    pub fn deinit(self: *Self) void {
        self.context.deinit();

        std.os.close(self.conn.stream.handle);

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
                        .client = self.client,
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
                            .client = self.client,
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
            .wl_display => |p| try self.handleWlDisplay(p),
            .wl_registry => |p| try self.handleWlRegistry(p),
            .wl_compositor => |p| try self.handleWlCompositor(p),
            .wl_surface => |p| try self.handleWlSurface(p),
            .xdg_wm_base => |p| try self.handleXdgWmBase(p),
            .xdg_surface => |p| try self.handleXdgSurface(p),
            .xdg_toplevel => |p| try self.handleXdgToplevel(p),
            else => {
                std.log.err("UNHANDLED = {}", .{msg});
                return error.UnhandledMessage;
            },
        }
    }

    pub fn handleWlDisplay(self: *Client, msg: WlDisplay.Message) !void {
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

    pub fn handleWlRegistry(self: *Client, msg: WlRegistry.Message) !void {
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

    pub fn handleWlCompositor(self: *Client, msg: WlCompositor.Message) !void {
        switch (msg) {
            .create_surface => |p| {
                const surface = WlSurface.init(p.id, self, 0, 0);

                // TODO: Add window and link to surface
                // const window = try win.newWindow(context.client, new_id);
                // window.view = context.client.compositor.current_view;

                try self.context.register(WlObject{ .wl_surface = surface });
            },
            .create_region => |p| {
                const region = WlRegion.init(p.id, self, 0, 0);

                // const region = try reg.newRegion(context.client, new_id);
                // const wl_region = prot.new_wl_region(new_id, context, @ptrToInt(region));

                try self.context.register(WlObject{ .wl_region = region });
            },
        }
    }

    pub fn handleWlSurface(_: *Client, msg: WlSurface.Message) !void {
        switch (msg) {
            .commit => |_| {},
            .damage => |_| {},
            else => {
                std.log.err("UNHANDLED = {}", .{msg});
                return error.UnhandledMessage;
            },
        }
    }

    pub fn handleXdgWmBase(self: *Client, msg: XdgWmBase.Message) !void {
        switch (msg) {
            .get_xdg_surface => |p| {
                const xdg_surface = XdgSurface.init(p.id, self, 0, 0);

                try self.context.register(WlObject{ .xdg_surface = xdg_surface });
            },
            else => return error.XdgWmBaseUnhandledMessage,
        }
    }

    pub fn handleXdgSurface(self: *Client, msg: XdgSurface.Message) !void {
        switch (msg) {
            .get_toplevel => |p| {
                const xdg_toplevel = XdgToplevel.init(p.id, self, 0, 0);

                try self.context.register(WlObject{ .xdg_toplevel = xdg_toplevel });
            },
            else => return error.XdgSurfaceUnhandledMessage,
        }
    }

    pub fn handleXdgToplevel(_: *Client, msg: XdgToplevel.Message) !void {
        switch (msg) {
            .set_title => |_| {},
            else => return error.XdgToplevelUnhandledMessage,
        }
    }
};
