const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const epoll = @import("epoll.zig");
const Event = @import("subsystem.zig").Event;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const Wire = @import("wl/wire.zig").Wire;
const WlObject = @import("wl/protocols.zig").WlObject;
const WlDisplay = @import("wl/protocols.zig").WlDisplay;
const WlRegistry = @import("wl/protocols.zig").WlRegistry;
const WlCompositor = @import("wl/protocols.zig").WlCompositor;
const WlSubcompositor = @import("wl/protocols.zig").WlSubcompositor;
const WlShm = @import("wl/protocols.zig").WlShm;
const WlSeat = @import("wl/protocols.zig").WlSeat;
const WlShmPool = @import("wl/protocols.zig").WlShmPool;
const WlSurface = @import("wl/protocols.zig").WlSurface;
const WlDataDeviceManager = @import("wl/protocols.zig").WlDataDeviceManager;
const WlRegion = @import("wl/protocols.zig").WlRegion;
const WlBuffer = @import("wl/protocols.zig").WlBuffer;
const WlCallback = @import("wl/protocols.zig").WlCallback;
const WlOutput = @import("wl/protocols.zig").WlOutput;
const XdgWmBase = @import("wl/protocols.zig").XdgWmBase;
const XdgSurface = @import("wl/protocols.zig").XdgSurface;
const XdgToplevel = @import("wl/protocols.zig").XdgToplevel;
const WlMessage = @import("wl/protocols.zig").WlMessage;
const Window = @import("resource/window.zig").Window;
const Region = @import("resource/region.zig").Region;
const RegionOp = @import("resource/region.zig").RegionOp;
const RectangleOp = @import("resource/region.zig").RectangleOp;
const Server = @import("server.zig").Server;
const ShmPool = @import("resource/shm_pool.zig").ShmPool;
const Buffer = @import("resource/buffer.zig").Buffer;
const ShmBuffer = @import("resource/shm_buffer.zig").ShmBuffer;
const Renderer = @import("renderer.zig").Renderer;
const Rectangle = @import("resource/rectangle.zig").Rectangle;
const XdgConfigurations = @import("resource/window.zig").XdgConfigurations;
const SubsetPool = @import("datastructures/subset_pool.zig").SubsetPool;
const ResourceObject = @import("server.zig").ResourceObject;
const Resource = @import("server.zig").Resource;

pub const Client = struct {
    server: *Server,
    tombstone: bool = false,
    alloc: mem.Allocator,
    conn: std.net.StreamServer.Connection,
    wire: Wire,
    serial: u32 = 0,
    server_id: u32 = 0xFF00_0000 - 1,

    windows: SubsetPool(Window, u16).Subset,
    regions: SubsetPool(Region, u16).Subset,
    buffers: SubsetPool(Buffer, u16).Subset,
    shm_pools: SubsetPool(ShmPool, u16).Subset,
    objects: SubsetPool(ResourceObject, u16).Subset,

    wl_display: WlDisplay,
    wl_registry: ?WlRegistry = null,
    wl_compositor: ?WlCompositor = null,
    xdg_wm_base: ?XdgWmBase = null,
    wl_shm: ?WlShm = null,
    wl_data_device_manager: ?WlDataDeviceManager = null,
    // wl_keyboard_id: ?u32 = null,
    // wl_pointer_id: ?u32 = null,
    wl_seat: ?WlSeat = null,
    wl_subcompositor: ?WlSubcompositor = null,
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
            .wire = Wire.init(conn.stream.handle),
            .windows = server.windows.subset(),
            .regions = server.regions.subset(),
            .buffers = server.buffers.subset(),
            .shm_pools = server.shm_pools.subset(),
            .objects = server.objects.subset(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.wire.deinit();

        std.os.close(self.conn.stream.handle);

        self.tombstone = true;

        self.windows.deinit();
        self.regions.deinit();
        self.buffers.deinit();
        self.shm_pools.deinit();

        self.objects.deinit();
    }

    pub fn nextSerial(self: *Self) u32 {
        self.serial += 1;
        return self.serial;
    }

    pub fn nextServerId(self: *Self) u32 {
        self.server_id += 1;
        return self.server_id;
    }

    // TODO: replace with IndexedPool
    pub fn getObject(self: *Self, id: u32) ?WlObject {
        var it = self.objects.iterator();

        while (it.next()) |n| {
            if (n.object.id() == id) {
                return n.object;
            }
        }

        return null;
    }

    pub fn getResource(self: *Self, id: u32) ?Resource {
        var it = self.objects.iterator();

        while (it.next()) |n| {
            if (n.object.id() == id) {
                return n.resource;
            }
        }

        return null;
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
            if (self.state == .done or self.client.tombstone == true) return null;

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
                try self.client.wire.startRead();
                self.state = .read_buffer;
            }

            const event = self.client.wire.readEvent(self.client, "getObject") catch |err| {
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
                try self.client.wire.finishRead();
                return null;
            }
        }
    };

    pub fn iterator(self: *Client) SubsystemIterator {
        return SubsystemIterator{ .client = Iterator.init(self) };
    }

    pub fn getWindow(self: *Client, id: u32) ?*Window {
        return switch (self.getResource(id) orelse return null) {
            .window => |window| window,
            else => null,
        };
    }

    pub fn getRegion(self: *Client, id: u32) ?*Region {
        return switch (self.getResource(id) orelse return null) {
            .region => |region| region,
            else => null,
        };
    }

    pub fn getBuffer(self: *Client, id: u32) ?*Buffer {
        return switch (self.getResource(id) orelse return null) {
            .buffer => |buffer| buffer,
            else => null,
        };
    }

    pub fn getShmPool(self: *Client, id: u32) ?*ShmPool {
        return switch (self.getResource(id) orelse return null) {
            .shm_pool => |shm_pool| shm_pool,
            else => null,
        };
    }

    pub fn link(self: *Client, object: WlObject, resource: Resource) !void {
        _ = try self.objects.create(ResourceObject{ .object = object, .resource = resource });
    }

    pub fn unlink(self: *Self, id: u32) void {
        var it = self.objects.iterator();

        while (it.next()) |n| {
            if (n.object.id() == id) {
                self.objects.destroy(n);
                return;
            }
        }

        std.log.warn("No id {}", .{id});
    }

    pub fn removeWindow(self: *Client, id: u32) RemoveError!void {
        const window = self.getWindow(id) orelse return error.NoSuchWindow;
        self.windows.destroy(window);
        self.unlink(id);
    }

    pub fn removeRegion(self: *Client, id: u32) RemoveError!void {
        const region = self.getRegion(id) orelse return error.NoSuchRegion;
        self.regions.destroy(region);
        self.unlink(id);
    }

    pub fn removeShmPool(self: *Client, id: u32) RemoveError!void {
        const shm_pool = self.getShmPool(id) orelse return error.NoSuchShmPool;
        self.shm_pools.destroy(shm_pool);
        self.unlink(id);
    }

    pub fn removeBuffer(self: *Client, id: u32) RemoveError!void {
        const buffer = self.getBuffer(id) orelse return error.NoSuchBuffer;
        self.buffers.destroy(buffer);
        self.unlink(id);
    }

    pub fn dispatch(self: *Client, message: WlMessage) !void {
        switch (message) {
            .wl_display => |msg| try self.handleWlDisplay(msg),
            .wl_registry => |msg| try self.handleWlRegistry(msg),
            .wl_compositor => |msg| try self.handleWlCompositor(msg),
            .wl_surface => |msg| try self.handleWlSurface(msg),
            .wl_shm => |msg| try self.handleWlShm(msg),
            .wl_shm_pool => |msg| try self.handleWlShmPool(msg),
            .xdg_wm_base => |msg| try self.handleXdgWmBase(msg),
            .xdg_surface => |msg| try self.handleXdgSurface(msg),
            .xdg_toplevel => |msg| try self.handleXdgToplevel(msg),
            .wl_region => |msg| try self.handleWlRegion(msg),
            .wl_callback => |_| return error.NotImplemented,
            .wl_buffer => |_| return error.NotImplemented,
            .wl_data_offer => |_| return error.NotImplemented,
            .wl_data_source => |_| return error.NotImplemented,
            .wl_data_device => |_| return error.NotImplemented,
            .wl_data_device_manager => |_| return error.NotImplemented,
            .wl_shell => |_| return error.NotImplemented,
            .wl_shell_surface => |_| return error.NotImplemented,
            .wl_seat => |_| return error.NotImplemented,
            .wl_pointer => |_| return error.NotImplemented,
            .wl_keyboard => |_| return error.NotImplemented,
            .wl_touch => |_| return error.NotImplemented,
            .wl_output => |_| return error.NotImplemented,
            .wl_subcompositor => |_| return error.NotImplemented,
            .wl_subsurface => |_| return error.NotImplemented,
            .xdg_positioner => |_| return error.NotImplemented,
            .xdg_popup => |_| return error.NotImplemented,
            .zwp_linux_dmabuf_v1 => |_| return error.NotImplemented,
            .zwp_linux_buffer_params_v1 => |_| return error.NotImplemented,
            .fw_control => |_| return error.NotImplemented,
        }
    }

    pub fn handleWlDisplay(self: *Client, message: WlDisplay.Message) !void {
        switch (message) {
            .get_registry => |msg| {
                const wl_registry = WlRegistry.init(msg.registry, &self.wire, 0);
                try self.link(.{ .wl_registry = wl_registry }, .none);

                self.wl_registry = wl_registry;

                try wl_registry.sendGlobal(1, "wl_compositor\x00", 4);
                try wl_registry.sendGlobal(2, "wl_subcompositor\x00", 1);
                try wl_registry.sendGlobal(3, "wl_seat\x00", 4);
                try wl_registry.sendGlobal(4, "xdg_wm_base\x00", 1);

                var it = self.server.outputs.iterator();
                while (it.next()) |output| {
                    try wl_registry.sendGlobal(output.id, "wl_output\x00", 2);
                }

                // try wl_registry.sendGlobal(6, "wl_data_device_manager\x00", 3);
                try wl_registry.sendGlobal(8, "wl_shm\x00", 1);
                try wl_registry.sendGlobal(10, "zwp_linux_dmabuf_v1\x00", 3);
                try wl_registry.sendGlobal(11, "fw_control\x00", 1);
            },
            .sync => |msg| {
                const callback = WlCallback.init(msg.callback, &self.wire, 0);

                try callback.sendDone(self.nextSerial());
                try self.wl_display.sendDeleteId(callback.id);
            },
        }
    }

    pub fn handleWlRegistry(self: *Client, message: WlRegistry.Message) !void {
        switch (message) {
            .bind => |msg| {
                std.log.info("Client requested iterface {s}", .{msg.name_string});
                switch (msg.name) {
                    1 => {
                        if (!mem.eql(u8, msg.name_string, "wl_compositor\x00")) return error.UnexpectedName;

                        self.wl_compositor = WlCompositor.init(msg.id, &self.wire, msg.version);
                        try self.link(.{ .wl_compositor = self.wl_compositor.? }, .none);
                    },
                    2 => {
                        if (!mem.eql(u8, msg.name_string, "wl_subcompositor\x00")) return error.UnexpectedName;

                        self.wl_subcompositor = WlSubcompositor.init(msg.id, &self.wire, msg.version);
                        try self.link(.{ .wl_subcompositor = self.wl_subcompositor.? }, .none);
                    },
                    3 => {
                        if (!mem.eql(u8, msg.name_string, "wl_seat\x00")) return error.UnexpectedName;

                        self.wl_seat = WlSeat.init(msg.id, &self.wire, msg.version);
                        try self.link(.{ .wl_seat = self.wl_seat.? }, .none);
                    },
                    4 => {
                        if (!mem.eql(u8, msg.name_string, "xdg_wm_base\x00")) return error.UnexpectedName;

                        self.xdg_wm_base = XdgWmBase.init(msg.id, &self.wire, msg.version);
                        try self.link(.{ .xdg_wm_base = self.xdg_wm_base.? }, .none);
                    },
                    6 => {
                        if (!mem.eql(u8, msg.name_string, "wl_data_device_manager\x00")) return error.UnexpectedName;

                        self.wl_data_device_manager = WlDataDeviceManager.init(msg.id, &self.wire, msg.version);
                        try self.link(.{ .wl_data_device_manager = self.wl_data_device_manager.? }, .none);
                    },
                    8 => {
                        if (!std.mem.eql(u8, msg.name_string, "wl_shm\x00")) return error.UnexpectedName;

                        self.wl_shm = WlShm.init(msg.id, &self.wire, msg.version);
                        try self.link(.{ .wl_shm = self.wl_shm.? }, .none);

                        try self.wl_shm.?.sendFormat(WlShm.Format.argb8888);
                        try self.wl_shm.?.sendFormat(WlShm.Format.xrgb8888);
                    },

                    else => |id| {
                        if (id >= 1000) {
                            if (!mem.eql(u8, msg.name_string, "wl_output\x00")) return error.UnexpectedName;
                            var it = self.server.outputs.iterator();
                            while (it.next()) |output| {
                                if (id != output.id) continue;

                                const wl_output = WlOutput.init(msg.id, &self.wire, msg.version);
                                try self.link(.{ .wl_output = wl_output }, .{ .output = output });

                                try wl_output.sendGeometry(0, 0, 267, 200, .none, "unknown\x00", "unknown\x00", .normal);
                                try wl_output.sendMode(.current, output.getWidth(), output.getHeight(), 60000);
                                try wl_output.sendScale(1);
                                try wl_output.sendDone();

                                return;
                            }
                        }

                        std.log.warn("No such global {}", .{id});
                        return error.NoSuchGlobal;
                    },
                }
            },
        }
    }

    pub fn handleWlCompositor(self: *Client, message: WlCompositor.Message) !void {
        switch (message) {
            .create_surface => |msg| {
                const wl_surface = WlSurface.init(msg.id, &self.wire, 0);

                const window = try self.windows.create(Window.init(self, wl_surface));
                errdefer self.windows.destroy(window);
                try self.link(.{ .wl_surface = wl_surface }, .{ .window = window });
            },
            .create_region => |msg| {
                const wl_region = WlRegion.init(msg.id, &self.wire, 0);

                const region = try self.regions.create(Region.init(self, wl_region));
                errdefer self.regions.destroy(region);

                try self.link(.{ .wl_region = wl_region }, .{ .region = region });
            },
        }
    }

    pub fn handleWlSurface(self: *Client, message: WlSurface.Message) !void {
        switch (message) {
            .commit => |msg| {
                const window = self.getWindow(msg.wl_surface.id) orelse return error.NoSuchWindow;

                // We may, without error, receive a .commit without an attached buffer.
                // In that case we can make no further process so we just return
                const wl_buffer = window.wl_buffer orelse return;

                const buffer = self.getBuffer(wl_buffer.id) orelse return error.NoSuchBuffer;
                buffer.beginAccess();

                if (window.texture) |texture| {
                    window.texture = null;
                    try Renderer.releaseTexture(texture);
                }

                // We need to set pending here (rather than in ack_configure) because
                // we need to know the width and height of the new buffer
                if (self.server.resize) |resize| {
                    if (resize.window == window) {
                        window.pending().x += resize.offsetX(window.width, buffer.width());
                        window.pending().y += resize.offsetY(window.height, buffer.height());
                    }
                }

                window.width = buffer.width();
                window.height = buffer.height();
                window.texture = try buffer.makeTexture();

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
            .attach => |msg| {
                const window = self.getWindow(msg.wl_surface.id) orelse return error.NoSuchWindow;

                if (msg.buffer) |wl_buffer| {
                    window.wl_buffer = wl_buffer;
                } else {
                    window.wl_buffer = null;
                }
            },
            .frame => |msg| {
                const window = self.getWindow(msg.wl_surface.id) orelse return error.NoSuchWindow;

                const wl_callback = WlCallback.init(msg.callback, &self.wire, 0);
                try window.callbacks.writeItem(wl_callback);

                try self.link(.{ .wl_callback = wl_callback }, .none);
            },
            .destroy => |_| return error.WlSurfaceDestroyNotImplemented,
            .set_opaque_region => |msg| {
                const window = self.getWindow(msg.wl_surface.id) orelse return error.NoSuchWindow;

                if (msg.region) |wl_region| {
                    const region = self.getRegion(wl_region.id) orelse return error.NoSuchRegion;
                    region.window = window;

                    // If we set a second pending input region before the first pending input region has been
                    // flipped, we need to deinit the origin pending region
                    if (window.pending().opaque_region) |old_pending_region| {
                        if (old_pending_region != region and old_pending_region != window.current().opaque_region) {
                            // FIXME: this removes the region from the pool allocator...but what about the linkage
                            self.regions.destroy(old_pending_region);
                        }
                    }

                    window.pending().opaque_region = region;
                } else {
                    if (window.pending().opaque_region) |old_pending_region| {
                        if (old_pending_region != window.current().opaque_region) {
                            // FIXME: this removes the region from the pool allocator...but what about the linkage
                            self.regions.destroy(old_pending_region);
                        }
                    }
                    window.pending().opaque_region = null;
                }
            },
            .set_input_region => |msg| {
                const window = self.getWindow(msg.wl_surface.id) orelse return error.NoSuchWindow;

                if (msg.region) |wl_region| {
                    const region = self.getRegion(wl_region.id) orelse return error.NoSuchRegion;
                    region.window = window;

                    // If we set a second pending input region before the first pending input region has been
                    // flipped, we need to deinit the original pending region
                    if (window.pending().input_region) |old_pending_region| {
                        if (old_pending_region != region and old_pending_region != window.current().input_region) {
                            // FIXME: this removes the region from the pool allocator...but what about the linkage
                            self.regions.destroy(old_pending_region);
                        }
                    }

                    window.pending().input_region = region;
                } else {
                    if (window.pending().input_region) |old_pending_region| {
                        if (old_pending_region != window.current().input_region) {
                            // FIXME: this removes the region from the pool allocator...but what about the linkage
                            self.regions.destroy(old_pending_region);
                        }
                    }

                    window.pending().input_region = null;
                }
            },
            .set_buffer_transform => |_| return error.WlSurfaceSetBufferTransformNotImplemented,
            .set_buffer_scale => |_| return error.WlSurfaceSetBufferScaleNotImplemented,
            .damage_buffer => |_| return error.WlSurfaceDamageBufferNotImplemented,
        }
    }

    pub fn handleWlRegion(self: *Client, message: WlRegion.Message) !void {
        switch (message) {
            .destroy => |msg| {
                const wl_region = msg.wl_region;
                const region = self.getRegion(wl_region.id) orelse return error.NoSuchRegion;

                if (region.window == null) {
                    // TODO: What do we actually need to do here?
                    self.regions.destroy(region);
                }

                try self.wl_display.sendDeleteId(wl_region.id);
                self.unlink(wl_region.id);
            },
            .add => |msg| {
                const region = self.getRegion(msg.wl_region.id) orelse return error.NoSuchRegion;

                const rect = RectangleOp{
                    .rectangle = Rectangle.init(msg.x, msg.y, msg.width, msg.height),
                    .op = RegionOp.Add,
                };

                try region.rectangles.writeItem(rect);
            },
            .subtract => |msg| {
                const region = self.getRegion(msg.wl_region.id) orelse return error.NoSuchRegion;

                const rect = RectangleOp{
                    .rectangle = Rectangle.init(msg.x, msg.y, msg.width, msg.height),
                    .op = RegionOp.Subtract,
                };

                try region.rectangles.writeItem(rect);
            },
        }
    }

    pub fn handleXdgWmBase(self: *Client, message: XdgWmBase.Message) !void {
        switch (message) {
            .get_xdg_surface => |msg| {
                const window = self.getWindow(msg.surface.id) orelse return error.NoSuchWindow;

                const xdg_surface = XdgSurface.init(msg.id, &self.wire, 0);
                try self.link(.{ .xdg_surface = xdg_surface }, .{ .window = window });

                window.xdg_surface = xdg_surface;
            },
            .destroy => |_| return error.NotImplemented,
            .create_positioner => |_| return error.NotImplemented,
            .pong => |_| return error.NotImplemented,
        }
    }

    pub fn handleXdgSurface(self: *Client, message: XdgSurface.Message) !void {
        switch (message) {
            .get_toplevel => |msg| {
                const window = self.getWindow(msg.xdg_surface.id) orelse return error.NoSuchWindow;
                const xdg_toplevel = XdgToplevel.init(msg.id, &self.wire, 0);
                try self.link(.{ .xdg_toplevel = xdg_toplevel }, .{ .window = window });

                window.xdg_toplevel = xdg_toplevel;

                var array = [_]u8{};
                const serial = self.nextSerial();
                try xdg_toplevel.sendConfigure(0, 0, array[0..]);
                try msg.xdg_surface.sendConfigure(serial);
            },
            .ack_configure => |msg| {
                const window = self.getWindow(msg.xdg_surface.id) orelse return error.NoSuchWindow;

                while (window.xdg_configurations.readItem()) |xdg_configuration| {
                    if (msg.serial == xdg_configuration.serial) {
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
            .destroy => |_| return error.NotImplemented,
            .get_popup => |_| return error.NotImplemented,
            .set_window_geometry => |msg| {
                const window = self.getWindow(msg.xdg_surface.id) orelse return error.NoSuchWindow;

                window.window_geometry = Rectangle.init(msg.x, msg.y, msg.width, msg.height);
            },
        }
    }

    pub fn handleXdgToplevel(self: *Client, message: XdgToplevel.Message) !void {
        switch (message) {
            .set_title => |_| {},
            .destroy => |_| return error.NotImplemented,
            .set_parent => |_| return error.NotImplemented,
            .set_app_id => |_| return error.NotImplemented,
            .show_window_menu => |_| return error.NotImplemented,
            .move => |_| return error.NotImplemented,
            .resize => |_| return error.NotImplemented,
            .set_max_size => |msg| {
                const window = self.getWindow(msg.xdg_toplevel.id) orelse return error.NoSuchWindow;

                window.pending().max_width = if (msg.width <= 0) null else msg.width;
                window.pending().max_height = if (msg.height <= 0) null else msg.height;
            },
            .set_min_size => |msg| {
                const window = self.getWindow(msg.xdg_toplevel.id) orelse return error.NoSuchWindow;

                window.pending().min_width = if (msg.width <= 0) null else msg.width;
                window.pending().min_height = if (msg.height <= 0) null else msg.height;
            },
            .set_maximized => |_| return error.NotImplemented,
            .unset_maximized => |_| return error.NotImplemented,
            .set_fullscreen => |_| return error.NotImplemented,
            .unset_fullscreen => |_| return error.NotImplemented,
            .set_minimized => |_| return error.NotImplemented,
        }
    }

    pub fn handleWlShm(self: *Client, message: WlShm.Message) !void {
        switch (message) {
            .create_pool => |msg| {
                const wl_shm_pool = WlShmPool.init(msg.id, &self.wire, 0);

                const shm_pool = try self.shm_pools.create(try ShmPool.init(self, msg.fd, wl_shm_pool, msg.size));
                errdefer self.shm_pools.destroy(shm_pool);

                try self.link(.{ .wl_shm_pool = wl_shm_pool }, .{ .shm_pool = shm_pool });
            },
        }
    }

    pub fn handleWlShmPool(self: *Client, message: WlShmPool.Message) !void {
        switch (message) {
            .create_buffer => |msg| {
                const shm_pool = self.getShmPool(msg.wl_shm_pool.id) orelse return error.NoSuchShmPool;
                const offset = msg.offset;
                const width = msg.width;
                const height = msg.height;
                const stride = msg.stride;
                const format = msg.format;

                const wl_buffer = WlBuffer.init(msg.id, &self.wire, 0);
                const buffer = try self.buffers.create(.{ .shm = ShmBuffer.init(self, shm_pool, wl_buffer, offset, width, height, stride, format) });
                errdefer self.buffers.destroy(buffer);

                try self.link(.{ .wl_buffer = wl_buffer }, .{ .buffer = buffer });
            },
            .destroy => |msg| {
                const wl_shm_pool = msg.wl_shm_pool;
                const shm_pool = self.getShmPool(wl_shm_pool.id) orelse return error.NoSuchShmPool;

                shm_pool.to_be_destroyed = true;
                if (shm_pool.ref_count == 0) {
                    shm_pool.deinit();
                    _ = self.shm_pools.destroy(shm_pool);
                }

                try self.wl_display.sendDeleteId(wl_shm_pool.id);
                self.unlink(wl_shm_pool.id);
            },
            .resize => |msg| {
                const shm_pool = self.getShmPool(msg.wl_shm_pool.id) orelse return error.NoSuchShmPool;
                try shm_pool.resize(msg.size);
            },
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
