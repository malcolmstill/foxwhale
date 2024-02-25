const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const net = std.net;
const epoll = @import("epoll.zig");
const Event = @import("subsystem.zig").Event;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;

const Window = @import("resource/window.zig").Window;
const Region = @import("resource/region.zig").Region;
const Output = @import("resource/output.zig").Output;
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
const Move = @import("move.zig").Move;
const Resize = @import("resize.zig").Resize;

pub const wl = @import("wl/protocols.zig").Wayland(.{
    .wl_surface = *Window,
    .wl_subsurface = *Window,
    .xdg_surface = *Window,
    .xdg_toplevel = *Window,
    .wl_region = *Region,
    .wl_output = *Output,
    .wl_buffer = *Buffer,
    .wl_shm_pool = *ShmPool,
});

pub const Client = struct {
    server: *Server,
    alloc: mem.Allocator,
    conn: net.StreamServer.Connection,
    wire: wl.Wire,
    serial: u32 = 0,
    server_id: u32 = 0xFF00_0000 - 1,

    windows: SubsetPool(Window, u16).Subset,
    regions: SubsetPool(Region, u16).Subset,
    buffers: SubsetPool(Buffer, u16).Subset,
    shm_pools: SubsetPool(ShmPool, u16).Subset,
    objects: SubsetPool(wl.WlObject, u16).Subset,

    wl_display: wl.WlDisplay,
    wl_registry: ?wl.WlRegistry = null,
    wl_compositor: ?wl.WlCompositor = null,
    xdg_wm_base: ?wl.XdgWmBase = null,
    wl_shm: ?wl.WlShm = null,
    wl_data_device_manager: ?wl.WlDataDeviceManager = null,
    wl_keyboard: ?wl.WlKeyboard = null,
    wl_pointer: ?wl.WlPointer = null,
    wl_seat: ?wl.WlSeat = null,
    wl_subcompositor: ?wl.WlSubcompositor = null,
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
        message: wl.WlMessage,
    };

    const Self = @This();

    pub fn init(alloc: mem.Allocator, server: *Server, conn: net.StreamServer.Connection, wl_display: wl.WlDisplay) Client {
        return Client{
            .alloc = alloc,
            .server = server,
            .conn = conn,
            .wl_display = wl_display,
            .wire = wl.Wire.init(conn.stream.handle),
            .windows = server.windows.subset(),
            .regions = server.regions.subset(),
            .buffers = server.buffers.subset(),
            .shm_pools = server.shm_pools.subset(),
            .objects = server.objects.subset(),
        };
    }

    pub fn deinit(client: *Self) void {
        std.os.close(client.conn.stream.handle);

        {
            // Release client's windows
            var it = client.windows.iterator();
            while (it.next()) |w| w.deinit();

            client.windows.deinit();
        }

        client.regions.deinit();
        client.buffers.deinit();
        client.shm_pools.deinit();

        client.objects.deinit();
    }

    pub fn nextSerial(client: *Self) u32 {
        client.serial += 1;
        return client.serial;
    }

    pub fn nextServerId(client: *Self) u32 {
        client.server_id += 1;
        return client.server_id;
    }

    // TODO: replace with IndexedPool
    pub fn getObject(client: *Self, id: u32) ?wl.WlObject {
        var it = client.objects.iterator();

        while (it.next()) |n| {
            if (n.id() == id) {
                return n.*;
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

        pub fn next(it: *Iterator, event_type: u32) !?Event {
            if (it.state == .done) return null;

            if (event_type & std.os.linux.EPOLL.HUP > 0) {
                it.state = .done;
                return Event{
                    .client = Client.TargetEvent{
                        .client = it.client,
                        .event = ClientEvent{
                            .hangup = 0,
                        },
                    },
                };
            }

            if (it.state == .begin) {
                try it.client.wire.startRead();
                it.state = .read_buffer;
            }

            const event = it.client.wire.readEvent(Client, it.client, "getObject") catch |err| {
                if (err == error.ClientSigbusd or builtin.mode != .Debug) {
                    return Event{
                        .client = Client.TargetEvent{
                            .client = it.client,
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
                        .client = it.client,
                        .event = ClientEvent{ .message = ev },
                    },
                };
            } else {
                try it.client.wire.finishRead();
                return null;
            }
        }
    };

    pub fn iterator(client: *Client) SubsystemIterator {
        return SubsystemIterator{ .client = Iterator.init(client) };
    }

    pub fn register(client: *Client, object: wl.WlObject) !void {
        _ = try client.objects.create(object);
    }

    pub fn unregister(client: *Client, id: u32) void {
        var it = client.objects.iterator();

        while (it.next()) |n| {
            if (n.id() == id) {
                client.objects.destroy(n);
                return;
            }
        }

        std.log.warn("No id {}", .{id});
    }

    pub fn removeWindow(client: *Client, window: *Window) void {
        client.windows.destroy(window);
        client.unregister(window.wl_surface.id);
    }

    pub fn removeRegion(client: *Client, region: *Region) void {
        client.regions.destroy(region);
        client.unregister(region.wl_region.id);
    }

    pub fn removeShmPool(client: *Client, shm_pool: *ShmPool) void {
        client.shm_pools.destroy(shm_pool);
        client.unregister(shm_pool.wl_shm_pool.id);
    }

    pub fn removeBuffer(client: *Client, buffer: *Buffer) void {
        client.buffers.destroy(buffer);
        client.unregister(buffer.wl_buffer.id);
    }

    pub fn dispatch(client: *Client, message: wl.WlMessage) !void {
        switch (message) {
            .wl_display => |msg| try client.handleWlDisplay(msg),
            .wl_registry => |msg| try client.handleWlRegistry(msg),
            .wl_callback => |_| return error.CallbackHasNoRequests,
            .wl_compositor => |msg| try client.handleWlCompositor(msg),
            .wl_shm_pool => |msg| try client.handleWlShmPool(msg),
            .wl_shm => |msg| try client.handleWlShm(msg),
            .wl_buffer => |msg| try client.handleWlBuffer(msg),
            .wl_data_offer => |_| return error.NotImplemented,
            .wl_data_source => |_| return error.NotImplemented,
            .wl_data_device => |_| return error.NotImplemented,
            .wl_data_device_manager => |_| return error.NotImplemented,
            .wl_shell => |_| return error.NotImplemented,
            .wl_shell_surface => |_| return error.NotImplemented,
            .wl_surface => |msg| try client.handleWlSurface(msg),
            .wl_seat => |msg| try client.handleWlSeat(msg),
            .wl_pointer => |_| return error.NotImplemented,
            .wl_keyboard => |_| return error.NotImplemented,
            .wl_touch => |_| return error.NotImplemented,
            .wl_output => |_| return error.NotImplemented,
            .wl_region => |msg| try client.handleWlRegion(msg),
            .wl_subcompositor => |msg| try client.handleWlSubcompositor(msg),
            .wl_subsurface => |msg| try client.handleWlSubsurface(msg),
            .xdg_wm_base => |msg| try client.handleXdgWmBase(msg),
            .xdg_positioner => |_| return error.NotImplemented,
            .xdg_surface => |msg| try client.handleXdgSurface(msg),
            .xdg_toplevel => |msg| try client.handleXdgToplevel(msg),
            .xdg_popup => |_| return error.NotImplemented,
            .zwp_linux_dmabuf_v1 => |_| return error.NotImplemented,
            .zwp_linux_buffer_params_v1 => |_| return error.NotImplemented,
            .zwp_linux_dmabuf_feedback_v1 => |_| return error.NotImplemented,
            .fw_control => |_| return error.NotImplemented,
        }
    }

    pub fn handleWlDisplay(client: *Client, message: wl.WlDisplay.Message) !void {
        switch (message) {
            .get_registry => |msg| {
                const wl_registry = wl.WlRegistry.init(msg.registry, &client.wire, 0, null);
                try client.register(.{ .wl_registry = wl_registry });

                client.wl_registry = wl_registry;

                try wl_registry.sendGlobal(1, "wl_compositor\x00", 4);
                try wl_registry.sendGlobal(2, "wl_subcompositor\x00", 1);
                try wl_registry.sendGlobal(3, "wl_seat\x00", 4);
                try wl_registry.sendGlobal(4, "xdg_wm_base\x00", 1);

                var it = client.server.outputs.iterator();
                while (it.next()) |output| {
                    try wl_registry.sendGlobal(output.id, "wl_output\x00", 2);
                }

                // try wl_registry.sendGlobal(6, "wl_data_device_manager\x00", 3);
                try wl_registry.sendGlobal(8, "wl_shm\x00", 1);
                // try wl_registry.sendGlobal(10, "zwp_linux_dmabuf_v1\x00", 3);
                try wl_registry.sendGlobal(11, "fw_control\x00", 1);
            },
            .sync => |msg| {
                const callback = wl.WlCallback.init(msg.callback, &client.wire, 0, null);

                try callback.sendDone(client.nextSerial());
                try client.wl_display.sendDeleteId(callback.id);
            },
        }
    }

    pub fn handleWlRegistry(client: *Client, message: wl.WlRegistry.Message) !void {
        switch (message) {
            .bind => |msg| {
                std.log.info("Client requested iterface {s}", .{msg.name_string});
                switch (msg.name) {
                    1 => {
                        if (!mem.eql(u8, msg.name_string, "wl_compositor\x00")) return error.UnexpectedName;

                        client.wl_compositor = wl.WlCompositor.init(msg.id, &client.wire, msg.version, null);
                        try client.register(.{ .wl_compositor = client.wl_compositor.? });
                    },
                    2 => {
                        if (!mem.eql(u8, msg.name_string, "wl_subcompositor\x00")) return error.UnexpectedName;

                        client.wl_subcompositor = wl.WlSubcompositor.init(msg.id, &client.wire, msg.version, null);
                        try client.register(.{ .wl_subcompositor = client.wl_subcompositor.? });
                    },
                    3 => {
                        if (!mem.eql(u8, msg.name_string, "wl_seat\x00")) return error.UnexpectedName;

                        if (client.wl_seat == null) {
                            client.wl_seat = wl.WlSeat.init(msg.id, &client.wire, msg.version, null);
                        }

                        try client.wl_seat.?.sendCapabilities(.{ .pointer = true, .keyboard = true });

                        try client.register(.{ .wl_seat = client.wl_seat.? });
                    },
                    4 => {
                        if (!mem.eql(u8, msg.name_string, "xdg_wm_base\x00")) return error.UnexpectedName;

                        client.xdg_wm_base = wl.XdgWmBase.init(msg.id, &client.wire, msg.version, null);
                        try client.register(.{ .xdg_wm_base = client.xdg_wm_base.? });
                    },
                    6 => {
                        if (!mem.eql(u8, msg.name_string, "wl_data_device_manager\x00")) return error.UnexpectedName;

                        client.wl_data_device_manager = wl.WlDataDeviceManager.init(msg.id, &client.wire, msg.version, null);
                        try client.register(.{ .wl_data_device_manager = client.wl_data_device_manager.? });
                    },
                    8 => {
                        if (!std.mem.eql(u8, msg.name_string, "wl_shm\x00")) return error.UnexpectedName;

                        client.wl_shm = wl.WlShm.init(msg.id, &client.wire, msg.version, null);
                        try client.register(.{ .wl_shm = client.wl_shm.? });

                        try client.wl_shm.?.sendFormat(wl.WlShm.Format.argb8888);
                        try client.wl_shm.?.sendFormat(wl.WlShm.Format.xrgb8888);
                    },

                    else => |id| {
                        if (id >= 1000) {
                            if (!mem.eql(u8, msg.name_string, "wl_output\x00")) return error.UnexpectedName;
                            var it = client.server.outputs.iterator();
                            while (it.next()) |output| {
                                if (id != output.id) continue;

                                const wl_output = wl.WlOutput.init(msg.id, &client.wire, msg.version, output);
                                try client.register(.{ .wl_output = wl_output });

                                try wl_output.sendGeometry(0, 0, 267, 200, .none, "unknown\x00", "unknown\x00", .normal);
                                try wl_output.sendMode(.{ .current = true }, output.getWidth(), output.getHeight(), 60000);
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

    pub fn handleWlCompositor(client: *Client, message: wl.WlCompositor.Message) !void {
        switch (message) {
            .create_surface => |msg| {
                const window = try client.windows.createPtr();
                errdefer client.windows.destroy(window);

                const wl_surface = wl.WlSurface.init(msg.id, &client.wire, 0, window);
                try client.register(.{ .wl_surface = wl_surface });

                window.* = Window.init(client, wl_surface);

                // The window's view will be the current view
                window.view = client.server.current_view;
            },
            .create_region => |msg| {
                const region = try client.regions.createPtr();
                errdefer client.regions.destroy(region);

                const wl_region = wl.WlRegion.init(msg.id, &client.wire, 0, region);
                try client.register(.{ .wl_region = wl_region });

                region.* = Region.init(client, wl_region);
            },
        }
    }

    pub fn handleWlShmPool(client: *Client, message: wl.WlShmPool.Message) !void {
        switch (message) {
            .create_buffer => |msg| {
                const buffer = try client.buffers.createPtr();
                errdefer client.buffers.destroy(buffer);

                const wl_buffer = wl.WlBuffer.init(msg.id, &client.wire, 0, buffer);
                try client.register(.{ .wl_buffer = wl_buffer });

                buffer.* = .{ .shm = ShmBuffer.init(client, msg.wl_shm_pool.resource, wl_buffer, msg.offset, msg.width, msg.height, msg.stride, msg.format) };
            },
            .destroy => |msg| {
                const wl_shm_pool = msg.wl_shm_pool;
                const shm_pool = wl_shm_pool.resource;

                shm_pool.to_be_destroyed = true;
                if (shm_pool.ref_count == 0) {
                    shm_pool.deinit();
                    _ = client.shm_pools.destroy(shm_pool);
                }

                try client.wl_display.sendDeleteId(wl_shm_pool.id);
                client.unregister(wl_shm_pool.id);
            },
            .resize => |msg| {
                const shm_pool = msg.wl_shm_pool.resource;
                try shm_pool.resize(msg.size);
            },
        }
    }

    pub fn handleWlShm(client: *Client, message: wl.WlShm.Message) !void {
        switch (message) {
            .create_pool => |msg| {
                const shm_pool = try client.shm_pools.createPtr();
                errdefer client.shm_pools.destroy(shm_pool);

                const wl_shm_pool = wl.WlShmPool.init(msg.id, &client.wire, 0, shm_pool);
                try client.register(.{ .wl_shm_pool = wl_shm_pool });
                errdefer client.unregister(wl_shm_pool.id);

                shm_pool.* = try ShmPool.init(client, msg.fd, wl_shm_pool, msg.size);
            },
        }
    }

    pub fn handleWlBuffer(client: *Client, message: wl.WlBuffer.Message) !void {
        switch (message) {
            .destroy => |msg| {
                const buffer = msg.wl_buffer.resource;
                switch (buffer.*) {
                    .shm => |*shmbuf| shmbuf.shm_pool.decrementRefCount(),
                    else => {},
                }
                try buffer.deinit();

                // We still want to do this
                try client.wl_display.sendDeleteId(msg.wl_buffer.id);
                client.unregister(msg.wl_buffer.id);
            },
        }
    }

    pub fn handleWlSurface(client: *Client, message: wl.WlSurface.Message) !void {
        switch (message) {
            .commit => |msg| {
                const window = msg.wl_surface.resource;

                // We may, without error, receive a .commit without an attached buffer.
                // In that case we can make no further process so we just return
                const wl_buffer = window.wl_buffer orelse return;

                const buffer = wl_buffer.resource;
                buffer.beginAccess();

                if (window.texture) |texture| {
                    window.texture = null;
                    try Renderer.releaseTexture(texture);
                }

                // We need to set pending here (rather than in ack_configure) because
                // we need to know the width and height of the new buffer
                if (client.server.resize) |resize| {
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

                if (!window.synchronized) window.flip();
            },
            .damage => |_| {},
            .attach => |msg| {
                const window = msg.wl_surface.resource;

                if (msg.buffer) |wl_buffer| {
                    window.wl_buffer = wl_buffer;
                } else {
                    window.wl_buffer = null;
                }
            },
            .frame => |msg| {
                const window = msg.wl_surface.resource;

                const wl_callback = wl.WlCallback.init(msg.callback, &client.wire, 0, null);
                try window.callbacks.writeItem(wl_callback);

                try client.register(.{ .wl_callback = wl_callback });
            },
            .destroy => |msg| {
                const window = msg.wl_surface.resource;
                // TODO: what about subsurfaces / popups?
                window.deinit();

                try client.wl_display.sendDeleteId(msg.wl_surface.id);
                client.unregister(msg.wl_surface.id);
            },
            .set_opaque_region => |msg| {
                const window = msg.wl_surface.resource;

                if (msg.region) |wl_region| {
                    const region = wl_region.resource;
                    region.window = window;

                    // If we set a second pending input region before the first pending input region has been
                    // flipped, we need to deinit the origin pending region
                    if (window.pending().opaque_region) |old_pending_region| {
                        if (old_pending_region != region and old_pending_region != window.current().opaque_region) {
                            // FIXME: this removes the region from the pool allocator...but what about the linkage
                            client.regions.destroy(old_pending_region);
                        }
                    }

                    window.pending().opaque_region = region;
                } else {
                    if (window.pending().opaque_region) |old_pending_region| {
                        if (old_pending_region != window.current().opaque_region) {
                            // FIXME: this removes the region from the pool allocator...but what about the linkage
                            client.regions.destroy(old_pending_region);
                        }
                    }
                    window.pending().opaque_region = null;
                }
            },
            .set_input_region => |msg| {
                const window = msg.wl_surface.resource;

                if (msg.region) |wl_region| {
                    const region = wl_region.resource;
                    region.window = window;

                    // If we set a second pending input region before the first pending input region has been
                    // flipped, we need to deinit the original pending region
                    if (window.pending().input_region) |old_pending_region| {
                        if (old_pending_region != region and old_pending_region != window.current().input_region) {
                            // FIXME: this removes the region from the pool allocator...but what about the linkage
                            client.regions.destroy(old_pending_region);
                        }
                    }

                    window.pending().input_region = region;
                } else {
                    if (window.pending().input_region) |old_pending_region| {
                        if (old_pending_region != window.current().input_region) {
                            // FIXME: this removes the region from the pool allocator...but what about the linkage
                            client.regions.destroy(old_pending_region);
                        }
                    }

                    window.pending().input_region = null;
                }
            },
            .set_buffer_transform => |_| return error.WlSurfaceSetBufferTransformNotImplemented,
            .set_buffer_scale => |_| return error.WlSurfaceSetBufferScaleNotImplemented,
            .damage_buffer => |_| return error.WlSurfaceDamageBufferNotImplemented,
            .offset => |_| return error.WlSurfaceOffsetNotImplemented,
        }
    }

    // wl_seat
    pub fn handleWlSeat(client: *Client, message: wl.WlSeat.Message) !void {
        switch (message) {
            .get_pointer => |msg| {
                const wl_pointer = wl.WlPointer.init(msg.id, &client.wire, 0, null);
                try client.register(.{ .wl_pointer = wl_pointer });

                client.wl_pointer = wl_pointer;
            },
            .get_keyboard => |msg| {
                const wl_keyboard = wl.WlKeyboard.init(msg.id, &client.wire, 0, null);
                try client.register(.{ .wl_keyboard = wl_keyboard });

                if (client.wl_seat != null) client.wl_keyboard = wl_keyboard;

                if (client.server.xkb) |*xkb| {
                    const fd_size = try xkb.getKeymap();

                    try wl_keyboard.sendKeymap(.xkb_v1, fd_size.fd, @intCast(fd_size.size));

                    if (msg.wl_seat.version >= 4) try wl_keyboard.sendRepeatInfo(1, 2000);
                }
            },
            .get_touch => |_| return error.NotImplement,
            .release => |_| return error.NotImplement,
        }
    }

    pub fn handleWlRegion(client: *Client, message: wl.WlRegion.Message) !void {
        switch (message) {
            .destroy => |msg| {
                const wl_region = msg.wl_region;
                const region = wl_region.resource;

                if (region.window == null) {
                    // TODO: What do we actually need to do here?
                    client.regions.destroy(region);
                }

                try client.wl_display.sendDeleteId(wl_region.id);
                client.unregister(wl_region.id);
            },
            .add => |msg| {
                const region = msg.wl_region.resource;

                const rect = RectangleOp{
                    .rectangle = Rectangle.init(msg.x, msg.y, msg.width, msg.height),
                    .op = RegionOp.Add,
                };

                try region.rectangles.writeItem(rect);
            },
            .subtract => |msg| {
                const region = msg.wl_region.resource;

                const rect = RectangleOp{
                    .rectangle = Rectangle.init(msg.x, msg.y, msg.width, msg.height),
                    .op = RegionOp.Subtract,
                };

                try region.rectangles.writeItem(rect);
            },
        }
    }

    pub fn handleWlSubcompositor(client: *Client, message: wl.WlSubcompositor.Message) !void {
        switch (message) {
            .destroy => |msg| {
                client.wl_subcompositor = null;
                try client.wl_display.sendDeleteId(msg.wl_subcompositor.id);
                client.unregister(msg.wl_subcompositor.id);
            },
            .get_subsurface => |msg| {
                const child = msg.surface.resource;
                const parent = msg.parent.resource;

                const wl_subsurface = wl.WlSubsurface.init(msg.id, &client.wire, 0, child);

                child.wl_subsurface = wl_subsurface;
                child.parent = parent;
                child.synchronized = true;

                child.detach();
                child.placeAbove(parent);

                try client.register(.{ .wl_subsurface = wl_subsurface });
            },
        }
    }

    pub fn handleWlSubsurface(client: *Client, message: wl.WlSubsurface.Message) !void {
        switch (message) {
            .destroy => |msg| {
                const window = msg.wl_subsurface.resource;
                window.wl_subsurface = null;
                try client.wl_display.sendDeleteId(msg.wl_subsurface.id);
                client.unregister(msg.wl_subsurface.id);
            },
            .set_position => |msg| {
                const window = msg.wl_subsurface.resource;
                window.pending().x = msg.x;
                window.pending().y = msg.y;
            },
            .place_above => |msg| {
                const window = msg.wl_subsurface.resource;
                const sibling = msg.sibling.resource;
                window.placeAbove(sibling);
            },
            .place_below => |msg| {
                const window = msg.wl_subsurface.resource;
                const sibling = msg.sibling.resource;
                window.placeBelow(sibling);
            },
            .set_sync => |msg| msg.wl_subsurface.resource.synchronized = true,
            .set_desync => |msg| {
                const window = msg.wl_subsurface.resource;
                window.synchronized = false;
                if (window.parent) |parent| {
                    if (!parent.synchronized) window.flip();
                }
            },
        }
    }

    pub fn handleXdgWmBase(client: *Client, message: wl.XdgWmBase.Message) !void {
        switch (message) {
            .get_xdg_surface => |msg| {
                const window = msg.surface.resource;

                const xdg_surface = wl.XdgSurface.init(msg.id, &client.wire, 0, window);
                try client.register(.{ .xdg_surface = xdg_surface });

                window.xdg_surface = xdg_surface;
            },
            .destroy => |msg| {
                try client.wl_display.sendDeleteId(msg.xdg_wm_base.id);
                client.unregister(msg.xdg_wm_base.id);
            },
            .create_positioner => |_| return error.NotImplemented,
            .pong => |_| return error.NotImplemented,
        }
    }

    pub fn handleXdgSurface(client: *Client, message: wl.XdgSurface.Message) !void {
        switch (message) {
            .get_toplevel => |msg| {
                const window = msg.xdg_surface.resource;
                const xdg_toplevel = wl.XdgToplevel.init(msg.id, &client.wire, 0, window);
                try client.register(.{ .xdg_toplevel = xdg_toplevel });

                window.xdg_toplevel = xdg_toplevel;

                var array = [_]u8{};
                const serial = client.nextSerial();
                try xdg_toplevel.sendConfigure(0, 0, array[0..]);
                try msg.xdg_surface.sendConfigure(serial);
            },
            .ack_configure => |msg| {
                const window = msg.xdg_surface.resource;

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
            .destroy => |msg| {
                const window = msg.xdg_surface.resource;
                window.xdg_surface = null;

                try client.wl_display.sendDeleteId(msg.xdg_surface.id);
                client.unregister(msg.xdg_surface.id);
            },
            .get_popup => |_| return error.NotImplemented,
            .set_window_geometry => |msg| {
                const window = msg.xdg_surface.resource;

                window.window_geometry = Rectangle.init(msg.x, msg.y, msg.width, msg.height);
            },
        }
    }

    pub fn handleXdgToplevel(client: *Client, message: wl.XdgToplevel.Message) !void {
        switch (message) {
            .set_title => |msg| {
                const window = msg.xdg_toplevel.resource;
                const length = @min(window.title.len, msg.title.len);
                mem.copyForwards(u8, window.title[0..length], msg.title[0..length]);
            },
            .destroy => |msg| {
                const window = msg.xdg_toplevel.resource;
                window.xdg_toplevel = null;

                try client.wl_display.sendDeleteId(msg.xdg_toplevel.id);
                client.unregister(msg.xdg_toplevel.id);
            },
            .set_parent => |msg| {
                const window = msg.xdg_toplevel.resource;
                window.parent = if (msg.parent) |p| p.resource else null;
            },
            .set_app_id => |msg| {
                const window = msg.xdg_toplevel.resource;
                const length = @min(window.app_id.len, msg.app_id.len);
                mem.copyForwards(u8, window.app_id[0..length], msg.app_id[0..length]);
            },
            .show_window_menu => |_| return error.NotImplemented,
            .move => |msg| {
                const window = msg.xdg_toplevel.resource;

                if (window.maximized != null) return;
                client.server.move = Move.init(window, window.current().x, window.current().y, client.server.pointer_x, client.server.pointer_y);
            },
            .resize => |msg| {
                const window = msg.xdg_toplevel.resource;
                client.server.resize = Resize.init(
                    window,
                    window.current().x,
                    window.current().y,
                    client.server.pointer_x,
                    client.server.pointer_y,
                    (if (window.window_geometry) |wg| wg.width else window.width),
                    (if (window.window_geometry) |wg| wg.height else window.height),
                    msg.edges,
                );
            },
            .set_max_size => |msg| {
                const window = msg.xdg_toplevel.resource;
                window.pending().max_width = if (msg.width <= 0) null else msg.width;
                window.pending().max_height = if (msg.height <= 0) null else msg.height;
            },
            .set_min_size => |msg| {
                const window = msg.xdg_toplevel.resource;
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
};

pub const RemoveError = error{
    NoSuchWindow,
    NoSuchRegion,
    NoSuchShmPool,
    NoSuchBuffer,
    InvalidPointer,
};
