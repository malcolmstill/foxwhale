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
const WlShmPool = @import("protocols.zig").WlShmPool;
const WlSurface = @import("protocols.zig").WlSurface;
const WlRegion = @import("protocols.zig").WlRegion;
const WlBuffer = @import("protocols.zig").WlBuffer;
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
const Server = @import("server.zig").Server;
const ShmPool = @import("shm_pool.zig").ShmPool;
const Buffer = @import("buffer.zig").Buffer;
const ShmBuffer = @import("shm_buffer.zig").ShmBuffer;
const Renderer = @import("renderer.zig").Renderer;
const Rectangle = @import("rectangle.zig").Rectangle;
const XdgConfigurations = @import("window.zig").XdgConfigurations;

pub const Client = struct {
    server: *Server,
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
            .wl_shm => |p| try self.handleWlShm(p),
            .wl_shm_pool => |p| try self.handleWlShmPool(p),
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
                const registry = WlRegistry.init(p.registry, &self.context, 0);

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
                const callback = WlCallback.init(p.callback, &self.context, 0);

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
                    self.wl_compositor = WlCompositor.init(p.id, &self.context, p.version);
                    try self.context.register(WlObject{ .wl_compositor = self.wl_compositor.? });
                },
                4 => {
                    if (!mem.eql(u8, p.name_string, "xdg_wm_base\x00")) return error.UnexpectedName;
                    self.xdg_wm_base = XdgWmBase.init(p.id, &self.context, p.version);
                    try self.context.register(WlObject{ .xdg_wm_base = self.xdg_wm_base.? });
                },
                8 => {
                    if (!std.mem.eql(u8, p.name_string, "wl_shm\x00")) return error.UnexpectedName;
                    self.wl_shm = WlShm.init(p.id, &self.context, p.version);

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
                const surface = WlSurface.init(p.id, &self.context, 0);
                try self.context.register(WlObject{ .wl_surface = surface });
                _ = try self.server.addWindow(self, surface);
            },
            .create_region => |p| {
                const region = WlRegion.init(p.id, &self.context, 0);

                // const region = try reg.newRegion(context.client, new_id);
                // const wl_region = prot.new_wl_region(new_id, context, @ptrToInt(region));

                try self.context.register(WlObject{ .wl_region = region });
            },
        }
    }

    pub fn handleWlSurface(client: *Client, msg: WlSurface.Message) !void {
        switch (msg) {
            .commit => |p| {
                const window = client.server.windows.get(p.wl_surface.id) orelse return error.NoSuchWindow;
                defer {
                    if (!window.synchronized) window.flip();
                }

                const wl_buffer = window.wl_buffer orelse return;

                const buffer = client.server.buffers.get(wl_buffer.id) orelse return error.NoSuchBuffer; // @intToPtr(*Buffer, wl_buffer.container);
                buffer.beginAccess();

                if (window.texture) |texture| {
                    window.texture = null;
                    try Renderer.releaseTexture(texture);
                }

                // We need to set pending here (rather than in ack_configure) because
                // we need to know the width and height of the new buffer
                // TODO: reinstate
                // if (compositor.COMPOSITOR.resize) |resize| {
                //     if (resize.window == window) {
                //         window.pending().x += resize.offsetX(window.width, buffer.width());
                //         window.pending().y += resize.offsetY(window.height, buffer.height());
                //     }
                // }

                window.width = buffer.width();
                window.height = buffer.height();
                window.texture = try buffer.makeTexture();
                std.log.info("window.texture = {?}", .{window.texture});

                if (window.first_buffer == false) {
                    window.first_buffer = true;
                }

                try buffer.endAccess();
                try wl_buffer.sendRelease();
                window.wl_buffer = null;

                if (window.view) |view| {
                    if (window.xdg_toplevel != null) {
                        if (window.toplevel.prev == null and window.toplevel.next == null) {
                            view.remove(window);
                            view.push(window);
                        }
                    }
                }

                if (window.xdg_surface != null) {
                    if (window.first_configure and window.first_buffer and window.mapped == false) {
                        try window.firstCommit();
                        window.mapped = true;
                    }
                }
            },
            .damage => |_| {},
            .attach => |p| {
                const window = client.server.windows.get(p.wl_surface.id) orelse return error.NoSuchWindow;

                if (p.buffer) |wl_buffer| {
                    window.wl_buffer = wl_buffer;
                } else {
                    window.wl_buffer = null;
                }
            },
            else => {
                std.log.err("UNHANDLED = {}", .{msg});
                return error.UnhandledMessage;
            },
        }
    }

    pub fn handleXdgWmBase(self: *Client, msg: XdgWmBase.Message) !void {
        switch (msg) {
            .get_xdg_surface => |p| {
                const window = self.server.windows.get(p.surface.id) orelse return error.NoSuchWindow;
                const xdg_surface = XdgSurface.init(p.id, &self.context, 0);
                try self.server.windows.associate(xdg_surface.id, window);

                window.xdg_surface = xdg_surface;

                try self.context.register(WlObject{ .xdg_surface = xdg_surface });
            },
            else => return error.XdgWmBaseUnhandledMessage,
        }
    }

    pub fn handleXdgSurface(self: *Client, msg: XdgSurface.Message) !void {
        switch (msg) {
            .get_toplevel => |p| {
                const window = self.server.windows.get(p.xdg_surface.id) orelse return error.NoSuchWindow;
                const xdg_toplevel = XdgToplevel.init(p.id, &self.context, 0);
                try self.server.windows.associate(xdg_toplevel.id, window);

                window.xdg_toplevel = xdg_toplevel;

                var array = [_]u32{};
                const serial = self.nextSerial();
                try xdg_toplevel.sendConfigure(0, 0, array[0..array.len]);
                try p.xdg_surface.sendConfigure(serial);

                try self.context.register(WlObject{ .xdg_toplevel = xdg_toplevel });
            },
            .ack_configure => |p| {
                const window = self.server.windows.get(p.xdg_surface.id) orelse return error.NoSuchWindow;

                while (window.xdg_configurations.readItem()) |xdg_configuration| {
                    if (p.serial == xdg_configuration.serial) {
                        switch (xdg_configuration.operation) {
                            .Maximize => {
                                if (window.maximized == null) {
                                    window.pending().x = 0;
                                    window.pending().y = 0;

                                    window.maximized = Rectangle{
                                        .x = window.current().x,
                                        .y = window.current().y,
                                        .width = if (window.window_geometry) |wg| wg.width else window.width,
                                        .height = if (window.window_geometry) |wg| wg.height else window.height,
                                    };
                                }
                            },
                            .Unmaximize => {
                                if (window.maximized) |maximized| {
                                    window.pending().x = maximized.x;
                                    window.pending().y = maximized.y;
                                    window.maximized = null;
                                }
                            },
                        }
                    }
                }

                window.xdg_configurations = XdgConfigurations.init();

                if (window.first_configure == false) window.first_configure = true;
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

    pub fn handleWlShm(self: *Client, msg: WlShm.Message) !void {
        switch (msg) {
            .create_pool => |p| {
                const wl_shm_pool = WlShmPool.init(p.id, &self.context, 0);

                _ = try self.server.shm_pools.add(wl_shm_pool.id, ShmPool.init(self, p.fd, wl_shm_pool));

                try self.context.register(WlObject{ .wl_shm_pool = wl_shm_pool });
            },
        }
    }

    pub fn handleWlShmPool(self: *Client, msg: WlShmPool.Message) !void {
        switch (msg) {
            .create_buffer => |p| {
                const wl_shm_pool = p.wl_shm_pool;
                const wl_buffer = WlBuffer.init(p.id, &self.context, 0);

                const shm_pool = self.server.shm_pools.get(wl_shm_pool.id) orelse return error.NoSuchShmPool;

                _ = try self.server.buffers.add(wl_buffer.id, Buffer{ .shm = ShmBuffer.init(self, shm_pool, wl_buffer) });

                try self.context.register(WlObject{ .wl_buffer = wl_buffer });
            },
            .destroy => |p| {
                const wl_shm_pool = p.wl_shm_pool;
                const shm_pool = self.server.shm_pools.get(wl_shm_pool.id) orelse return error.NoSuchShmPool;

                shm_pool.to_be_destroyed = true;
                if (shm_pool.ref_count == 0) {
                    shm_pool.deinit();
                    self.server.shm_pools.remove(wl_shm_pool.id, shm_pool);
                }

                try self.wl_display.sendDeleteId(wl_shm_pool.id);
                try self.context.unregister(WlObject{ .wl_shm_pool = wl_shm_pool });
            },
            else => return error.UnhandledWlShmPool,
        }
    }
};
