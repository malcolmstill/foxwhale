const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const epoll = @import("epoll.zig");
const Event = @import("subsystem.zig").Event;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const Context = @import("wl/context.zig").Context;
const WlObject = @import("wl/protocols.zig").WlObject;
const WlDisplay = @import("wl/protocols.zig").WlDisplay;
const WlRegistry = @import("wl/protocols.zig").WlRegistry;
const WlCompositor = @import("wl/protocols.zig").WlCompositor;
const WlShm = @import("wl/protocols.zig").WlShm;
const WlShmPool = @import("wl/protocols.zig").WlShmPool;
const WlSurface = @import("wl/protocols.zig").WlSurface;
const WlRegion = @import("wl/protocols.zig").WlRegion;
const WlBuffer = @import("wl/protocols.zig").WlBuffer;
const WlCallback = @import("wl/protocols.zig").WlCallback;
const XdgWmBase = @import("wl/protocols.zig").XdgWmBase;
const XdgSurface = @import("wl/protocols.zig").XdgSurface;
const XdgToplevel = @import("wl/protocols.zig").XdgToplevel;
const WlMessage = @import("wl/protocols.zig").WlMessage;
// const shm_pool = @import("shm_pool.zig");
// const shm_buffer = @import("shm_buffer.zig");
// const region = @import("region.zig");
// const positioner = @import("positioner.zig");
// const buffer = @import("buffer.zig");
// const Stalloc = @import("stalloc.zig").Stalloc;
const Window = @import("window.zig").Window;
const Region = @import("region.zig").Region;
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
    alloc: mem.Allocator,
    conn: std.net.StreamServer.Connection,
    context: Context,
    serial: u32 = 0,
    server_id: u32 = 0xFF00_0000 - 1,

    windows: std.AutoHashMap(u32, *Window),
    regions: std.AutoHashMap(u32, *Region),
    buffers: std.AutoHashMap(u32, *Buffer),
    shm_pools: std.AutoHashMap(u32, *ShmPool),

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

    pub const TargetEvent = struct {
        client: *Client,
        event: ClientEvent,
    };

    pub const EventType = enum {
        hangup,
        err,
        message,
    };

    pub const ClientEvent = union(EventType) {
        hangup: i32,
        err: i32,
        message: WlMessage,
    };

    const Self = @This();

    pub fn init(alloc: mem.Allocator, server: *Server, conn: std.net.StreamServer.Connection, wl_display: WlDisplay) Client {
        return Client{
            .alloc = alloc,
            .server = server,
            .conn = conn,
            .wl_display = wl_display,
            .context = Context.init(conn.stream.handle),
            .windows = std.AutoHashMap(u32, *Window).init(alloc),
            .regions = std.AutoHashMap(u32, *Region).init(alloc),
            .buffers = std.AutoHashMap(u32, *Buffer).init(alloc),
            .shm_pools = std.AutoHashMap(u32, *ShmPool).init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        self.context.deinit();

        std.os.close(self.conn.stream.handle);

        self.windows.deinit();
        self.regions.deinit();
        self.buffers.deinit();
        self.shm_pools.deinit();

        // TODO: have caller destroy?
        // self.alloc.destroy(self);
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
                    .client = Client.TargetEvent{
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

            const event = self.client.context.readEvent() catch |err| {
                if (err == error.ClientSigbusd or builtin.mode != .Debug) {
                    return Event{
                        .client = Client.TargetEvent{
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

            if (event) |ev| {
                return Event{
                    .client = Client.TargetEvent{
                        .client = self.client,
                        .event = ClientEvent{ .message = ev },
                    },
                };
            } else {
                self.client.context.finishRead();
                return null;
            }
        }
    };

    pub fn iterator(self: *Client) SubsystemIterator {
        return SubsystemIterator{ .client = Iterator.init(self) };
    }

    pub fn addWindow(self: *Client, id: u32, window: Window) !void {
        const window_ptr = try self.server.windows.create(window);
        errdefer self.server.windows.destroy(window_ptr);

        try self.windows.put(id, window_ptr);
    }

    pub fn addRegion(self: *Client, id: u32, region: Region) !void {
        const region_ptr = try self.server.regions.create(region);
        errdefer self.server.regions.destroy(region_ptr);

        try self.regions.put(id, region_ptr);
    }

    pub fn addShmPool(self: *Client, id: u32, shm_pool: ShmPool) !void {
        const shm_pool_ptr = try self.server.shm_pools.create(shm_pool);
        errdefer self.server.shm_pools.destroy(shm_pool_ptr);

        try self.shm_pools.put(id, shm_pool_ptr);
    }

    pub fn addBuffer(self: *Client, id: u32, buffer: Buffer) !void {
        const buffer_ptr = try self.server.buffers.create(buffer);
        errdefer self.server.buffers.destroy(buffer_ptr);

        try self.buffers.put(id, buffer_ptr);
    }

    pub fn removeWindow(self: *Client, id: u32) RemoveError!void {
        const window = self.windows.get(id) orelse return error.NoSuchWindow;
        self.server.windows.destroy(window);
        _ = self.windows.remove(id);
    }

    pub fn removeRegion(self: *Client, id: u32) RemoveError!void {
        const region = self.regions.get(id) orelse return error.NoSuchRegion;
        self.server.regions.destroy(region);
        _ = self.regions.remove(id);
    }

    pub fn removeShmPool(self: *Client, id: u32) RemoveError!void {
        const shm_pool = self.shm_pools.get(id) orelse return error.NoSuchShmPool;
        self.server.shm_pools.destroy(shm_pool);
        _ = self.shm_pools.remove(id);
    }

    pub fn removeBuffer(self: *Client, id: u32) RemoveError!void {
        const buffer = self.buffers.get(id) orelse return error.NoSuchBuffer;
        self.server.buffers.destroy(buffer);
        _ = self.buffers.remove(id);
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
                const wl_surface = WlSurface.init(p.id, &self.context, 0);
                try self.context.register(WlObject{ .wl_surface = wl_surface });

                try self.addWindow(wl_surface.id, Window.init(self, wl_surface));
            },
            .create_region => |p| {
                const region = WlRegion.init(p.id, &self.context, 0);

                // const region = try reg.newRegion(context.client, new_id);
                // const wl_region = prot.new_wl_region(new_id, context, @ptrToInt(region));

                try self.context.register(WlObject{ .wl_region = region });
            },
        }
    }

    pub fn handleWlSurface(self: *Client, msg: WlSurface.Message) !void {
        switch (msg) {
            .commit => |p| {
                const window = self.windows.get(p.wl_surface.id) orelse return error.NoSuchWindow;

                // We may, without error, receive a .commit without an attached buffer.
                // In that case we can make no further process so we just return
                const wl_buffer = window.wl_buffer orelse return;

                const buffer = self.buffers.get(wl_buffer.id) orelse return error.NoSuchBuffer; // @intToPtr(*Buffer, wl_buffer.container);
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

                if (!window.synchronized) try window.flip();
            },
            .damage => |_| {},
            .attach => |p| {
                const window = self.windows.get(p.wl_surface.id) orelse return error.NoSuchWindow;

                if (p.buffer) |wl_buffer| {
                    window.wl_buffer = wl_buffer;
                } else {
                    window.wl_buffer = null;
                }
            },
            .frame => |p| {
                const window = self.windows.get(p.wl_surface.id) orelse return error.NoSuchWindow;
                try window.callbacks.writeItem(p.callback);

                var callback = WlCallback.init(p.callback, &self.context, 0);
                try self.context.register(WlObject{ .wl_callback = callback });
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
                const window = self.windows.get(p.surface.id) orelse return error.NoSuchWindow;
                const xdg_surface = XdgSurface.init(p.id, &self.context, 0);
                try self.windows.put(xdg_surface.id, window);

                window.xdg_surface = xdg_surface;

                try self.context.register(WlObject{ .xdg_surface = xdg_surface });
            },
            else => return error.XdgWmBaseUnhandledMessage,
        }
    }

    pub fn handleXdgSurface(self: *Client, msg: XdgSurface.Message) !void {
        switch (msg) {
            .get_toplevel => |p| {
                const window = self.windows.get(p.xdg_surface.id) orelse return error.NoSuchWindow;
                const xdg_toplevel = XdgToplevel.init(p.id, &self.context, 0);
                try self.windows.put(xdg_toplevel.id, window);

                window.xdg_toplevel = xdg_toplevel;

                var array = [_]u32{};
                const serial = self.nextSerial();
                try xdg_toplevel.sendConfigure(0, 0, array[0..array.len]);
                try p.xdg_surface.sendConfigure(serial);

                try self.context.register(WlObject{ .xdg_toplevel = xdg_toplevel });
            },
            .ack_configure => |p| {
                const window = self.windows.get(p.xdg_surface.id) orelse return error.NoSuchWindow;

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

                _ = try self.addShmPool(wl_shm_pool.id, ShmPool.init(self, p.fd, wl_shm_pool));

                try self.context.register(WlObject{ .wl_shm_pool = wl_shm_pool });
            },
        }
    }

    pub fn handleWlShmPool(self: *Client, msg: WlShmPool.Message) !void {
        switch (msg) {
            .create_buffer => |p| {
                const wl_shm_pool = p.wl_shm_pool;
                const wl_buffer = WlBuffer.init(p.id, &self.context, 0);

                const shm_pool = self.shm_pools.get(wl_shm_pool.id) orelse return error.NoSuchShmPool;

                _ = try self.addBuffer(wl_buffer.id, Buffer{ .shm = ShmBuffer.init(self, shm_pool, wl_buffer) });

                try self.context.register(WlObject{ .wl_buffer = wl_buffer });
            },
            .destroy => |p| {
                const wl_shm_pool = p.wl_shm_pool;
                const shm_pool = self.shm_pools.get(wl_shm_pool.id) orelse return error.NoSuchShmPool;

                shm_pool.to_be_destroyed = true;
                if (shm_pool.ref_count == 0) {
                    shm_pool.deinit();
                    _ = self.shm_pools.remove(wl_shm_pool.id);
                }

                try self.wl_display.sendDeleteId(wl_shm_pool.id);
                try self.context.unregister(WlObject{ .wl_shm_pool = wl_shm_pool });
            },
            else => return error.UnhandledWlShmPool,
        }
    }
};

pub const RemoveError = error{
    NoSuchWindow,
    NoSuchRegion,
    NoSuchShmPool,
    NoSuchBuffer,
    InvalidPointer,
};
