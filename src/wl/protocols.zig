const std = @import("std");
const builtin = @import("builtin");
const WireFn = @import("wire.zig").Wire;

pub fn Wayland(comptime ResourceMap: struct {
    wl_display: type = ?void,
    wl_registry: type = ?void,
    wl_callback: type = ?void,
    wl_compositor: type = ?void,
    wl_shm_pool: type = ?void,
    wl_shm: type = ?void,
    wl_buffer: type = ?void,
    wl_data_offer: type = ?void,
    wl_data_source: type = ?void,
    wl_data_device: type = ?void,
    wl_data_device_manager: type = ?void,
    wl_shell: type = ?void,
    wl_shell_surface: type = ?void,
    wl_surface: type = ?void,
    wl_seat: type = ?void,
    wl_pointer: type = ?void,
    wl_keyboard: type = ?void,
    wl_touch: type = ?void,
    wl_output: type = ?void,
    wl_region: type = ?void,
    wl_subcompositor: type = ?void,
    wl_subsurface: type = ?void,
    xdg_wm_base: type = ?void,
    xdg_positioner: type = ?void,
    xdg_surface: type = ?void,
    xdg_toplevel: type = ?void,
    xdg_popup: type = ?void,
    zwp_linux_dmabuf_v1: type = ?void,
    zwp_linux_buffer_params_v1: type = ?void,
    zwp_linux_dmabuf_feedback_v1: type = ?void,
    fw_control: type = ?void,
}) type {
    return struct {
        pub const Wire = WireFn(WlMessage);

        /// wl_display
        /// core global object
        ///
        /// The core global object.  This is a special singleton object.  It
        /// is used for internal Wayland protocol features.
        ///
        pub const WlDisplay = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_display,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_display) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                invalid_object = 0,
                invalid_method = 1,
                no_memory = 2,
                implementation = 3,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // sync
                    0 => {
                        const callback: u32 = try self.wire.nextU32();
                        return Message{
                            .sync = SyncMessage{
                                .wl_display = self.*,
                                .callback = callback,
                            },
                        };
                    },
                    // get_registry
                    1 => {
                        const registry: u32 = try self.wire.nextU32();
                        return Message{
                            .get_registry = GetRegistryMessage{
                                .wl_display = self.*,
                                .registry = registry,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                sync,
                get_registry,
            };

            pub const Message = union(MessageType) {
                /// asynchronous roundtrip
                ///
                /// The sync request asks the server to emit the 'done' event
                /// on the returned wl_callback object.  Since requests are
                /// handled in-order and events are delivered in-order, this can
                /// be used as a barrier to ensure all previous requests and the
                /// resulting events have been handled.
                ///
                /// The object returned by this request will be destroyed by the
                /// compositor after the callback is fired and as such the client must not
                /// attempt to use it after that point.
                ///
                /// The callback_data passed in the callback is the event serial.
                ///
                sync: SyncMessage,

                /// get global registry object
                ///
                /// This request creates a registry object that allows the client
                /// to list and bind the global objects available from the
                /// compositor.
                ///
                /// It should be noted that the server side resources consumed in
                /// response to a get_registry request can only be released when the
                /// client disconnects, not when the client side proxy is destroyed.
                /// Therefore, clients should invoke get_registry as infrequently as
                /// possible to avoid wasting memory.
                ///
                get_registry: GetRegistryMessage,
            };

            /// asynchronous roundtrip
            ///
            /// The sync request asks the server to emit the 'done' event
            /// on the returned wl_callback object.  Since requests are
            /// handled in-order and events are delivered in-order, this can
            /// be used as a barrier to ensure all previous requests and the
            /// resulting events have been handled.
            ///
            /// The object returned by this request will be destroyed by the
            /// compositor after the callback is fired and as such the client must not
            /// attempt to use it after that point.
            ///
            /// The callback_data passed in the callback is the event serial.
            ///
            const SyncMessage = struct {
                wl_display: WlDisplay,
                /// callback object for the sync request
                callback: u32,
            };

            /// get global registry object
            ///
            /// This request creates a registry object that allows the client
            /// to list and bind the global objects available from the
            /// compositor.
            ///
            /// It should be noted that the server side resources consumed in
            /// response to a get_registry request can only be released when the
            /// client disconnects, not when the client side proxy is destroyed.
            /// Therefore, clients should invoke get_registry as infrequently as
            /// possible to avoid wasting memory.
            ///
            const GetRegistryMessage = struct {
                wl_display: WlDisplay,
                /// global registry object
                registry: u32,
            };

            //
            // The error event is sent out when a fatal (non-recoverable)
            // error has occurred.  The object_id argument is the object
            // where the error occurred, most often in response to a request
            // to that object.  The code identifies the error and is defined
            // by the object interface.  As such, each interface defines its
            // own set of error codes.  The message is a brief description
            // of the error, for (debugging) convenience.
            //
            pub fn sendError(self: Self, object_id: u32, code: u32, message: []const u8) !void {
                try self.wire.startWrite();
                try self.wire.putU32(object_id);
                try self.wire.putU32(code);
                try self.wire.putString(message);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // This event is used internally by the object ID management
            // logic. When a client deletes an object that it had created,
            // the server will send this event to acknowledge that it has
            // seen the delete request. When the client receives this event,
            // it will know that it can safely reuse the object ID.
            //
            pub fn sendDeleteId(self: Self, id: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(id);
                try self.wire.finishWrite(self.id, 1);
            }
        };

        /// wl_registry
        /// global registry object
        ///
        /// The singleton global registry object.  The server has a number of
        /// global objects that are available to all clients.  These objects
        /// typically represent an actual object in the server (for example,
        /// an input device) or they are singleton objects that provide
        /// extension functionality.
        ///
        /// When a client creates a registry object, the registry object
        /// will emit a global event for each global currently in the
        /// registry.  Globals come and go as a result of device or
        /// monitor hotplugs, reconfiguration or other events, and the
        /// registry will send out global and global_remove events to
        /// keep the client up to date with the changes.  To mark the end
        /// of the initial burst of events, the client can use the
        /// wl_display.sync request immediately after calling
        /// wl_display.get_registry.
        ///
        /// A client can bind to a global object by using the bind
        /// request.  This creates a client-side handle that lets the object
        /// emit events to the client and lets the client invoke requests on
        /// the object.
        ///
        pub const WlRegistry = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_registry,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_registry) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // bind
                    0 => {
                        const name: u32 = try self.wire.nextU32();
                        const name_string: []u8 = try self.wire.nextString();
                        const version: u32 = try self.wire.nextU32();
                        const id: u32 = try self.wire.nextU32();
                        return Message{
                            .bind = BindMessage{
                                .wl_registry = self.*,
                                .name = name,
                                .name_string = name_string,
                                .version = version,
                                .id = id,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                bind,
            };

            pub const Message = union(MessageType) {
                /// bind an object to the display
                ///
                /// Binds a new, client-created object to the server using the
                /// specified name as the identifier.
                ///
                bind: BindMessage,
            };

            /// bind an object to the display
            ///
            /// Binds a new, client-created object to the server using the
            /// specified name as the identifier.
            ///
            const BindMessage = struct {
                wl_registry: WlRegistry,
                /// unique numeric name of the object
                name: u32,
                name_string: []u8,
                version: u32,
                /// bounded object
                id: u32,
            };

            //
            // Notify the client of global objects.
            //
            // The event notifies the client that a global object with
            // the given name is now available, and it implements the
            // given version of the given interface.
            //
            pub fn sendGlobal(self: Self, name: u32, interface: []const u8, version: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(name);
                try self.wire.putString(interface);
                try self.wire.putU32(version);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // Notify the client of removed global objects.
            //
            // This event notifies the client that the global identified
            // by name is no longer available.  If the client bound to
            // the global using the bind request, the client should now
            // destroy that object.
            //
            // The object remains valid and requests to the object will be
            // ignored until the client destroys it, to avoid races between
            // the global going away and a client sending a request to it.
            //
            pub fn sendGlobalRemove(self: Self, name: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(name);
                try self.wire.finishWrite(self.id, 1);
            }
        };

        /// wl_callback
        /// callback object
        ///
        /// Clients can handle the 'done' event to get notified when
        /// the related request is done.
        ///
        pub const WlCallback = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_callback,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_callback) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {};

            const Message = struct {};

            //
            // Notify the client when the related request is done.
            //
            pub fn sendDone(self: Self, callback_data: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(callback_data);
                try self.wire.finishWrite(self.id, 0);
            }
        };

        /// wl_compositor
        /// the compositor singleton
        ///
        /// A compositor.  This object is a singleton global.  The
        /// compositor is in charge of combining the contents of multiple
        /// surfaces into one displayable output.
        ///
        pub const WlCompositor = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_compositor,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_compositor) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // create_surface
                    0 => {
                        const id: u32 = try self.wire.nextU32();
                        return Message{
                            .create_surface = CreateSurfaceMessage{
                                .wl_compositor = self.*,
                                .id = id,
                            },
                        };
                    },
                    // create_region
                    1 => {
                        const id: u32 = try self.wire.nextU32();
                        return Message{
                            .create_region = CreateRegionMessage{
                                .wl_compositor = self.*,
                                .id = id,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                create_surface,
                create_region,
            };

            pub const Message = union(MessageType) {
                /// create new surface
                ///
                /// Ask the compositor to create a new surface.
                ///
                create_surface: CreateSurfaceMessage,

                /// create new region
                ///
                /// Ask the compositor to create a new region.
                ///
                create_region: CreateRegionMessage,
            };

            /// create new surface
            ///
            /// Ask the compositor to create a new surface.
            ///
            const CreateSurfaceMessage = struct {
                wl_compositor: WlCompositor,
                /// the new surface
                id: u32,
            };

            /// create new region
            ///
            /// Ask the compositor to create a new region.
            ///
            const CreateRegionMessage = struct {
                wl_compositor: WlCompositor,
                /// the new region
                id: u32,
            };
        };

        /// wl_shm_pool
        /// a shared memory pool
        ///
        /// The wl_shm_pool object encapsulates a piece of memory shared
        /// between the compositor and client.  Through the wl_shm_pool
        /// object, the client can allocate shared memory wl_buffer objects.
        /// All objects created through the same pool share the same
        /// underlying mapped memory. Reusing the mapped memory avoids the
        /// setup/teardown overhead and is useful when interactively resizing
        /// a surface or for many small buffers.
        ///
        pub const WlShmPool = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_shm_pool,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_shm_pool) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // create_buffer
                    0 => {
                        const id: u32 = try self.wire.nextU32();
                        const offset: i32 = try self.wire.nextI32();
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        const stride: i32 = try self.wire.nextI32();
                        const format: WlShm.Format = @enumFromInt(try self.wire.nextU32()); // enum
                        return Message{
                            .create_buffer = CreateBufferMessage{
                                .wl_shm_pool = self.*,
                                .id = id,
                                .offset = offset,
                                .width = width,
                                .height = height,
                                .stride = stride,
                                .format = format,
                            },
                        };
                    },
                    // destroy
                    1 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .wl_shm_pool = self.*,
                            },
                        };
                    },
                    // resize
                    2 => {
                        const size: i32 = try self.wire.nextI32();
                        return Message{
                            .resize = ResizeMessage{
                                .wl_shm_pool = self.*,
                                .size = size,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                create_buffer,
                destroy,
                resize,
            };

            pub const Message = union(MessageType) {
                /// create a buffer from the pool
                ///
                /// Create a wl_buffer object from the pool.
                ///
                /// The buffer is created offset bytes into the pool and has
                /// width and height as specified.  The stride argument specifies
                /// the number of bytes from the beginning of one row to the beginning
                /// of the next.  The format is the pixel format of the buffer and
                /// must be one of those advertised through the wl_shm.format event.
                ///
                /// A buffer will keep a reference to the pool it was created from
                /// so it is valid to destroy the pool immediately after creating
                /// a buffer from it.
                ///
                create_buffer: CreateBufferMessage,

                /// destroy the pool
                ///
                /// Destroy the shared memory pool.
                ///
                /// The mmapped memory will be released when all
                /// buffers that have been created from this pool
                /// are gone.
                ///
                destroy: DestroyMessage,

                /// change the size of the pool mapping
                ///
                /// This request will cause the server to remap the backing memory
                /// for the pool from the file descriptor passed when the pool was
                /// created, but using the new size.  This request can only be
                /// used to make the pool bigger.
                ///
                resize: ResizeMessage,
            };

            /// create a buffer from the pool
            ///
            /// Create a wl_buffer object from the pool.
            ///
            /// The buffer is created offset bytes into the pool and has
            /// width and height as specified.  The stride argument specifies
            /// the number of bytes from the beginning of one row to the beginning
            /// of the next.  The format is the pixel format of the buffer and
            /// must be one of those advertised through the wl_shm.format event.
            ///
            /// A buffer will keep a reference to the pool it was created from
            /// so it is valid to destroy the pool immediately after creating
            /// a buffer from it.
            ///
            const CreateBufferMessage = struct {
                wl_shm_pool: WlShmPool,
                /// buffer to create
                id: u32,
                /// buffer byte offset within the pool
                offset: i32,
                /// buffer width, in pixels
                width: i32,
                /// buffer height, in pixels
                height: i32,
                /// number of bytes from the beginning of one row to the beginning of the next row
                stride: i32,
                /// buffer pixel format
                format: WlShm.Format,
            };

            /// destroy the pool
            ///
            /// Destroy the shared memory pool.
            ///
            /// The mmapped memory will be released when all
            /// buffers that have been created from this pool
            /// are gone.
            ///
            const DestroyMessage = struct {
                wl_shm_pool: WlShmPool,
            };

            /// change the size of the pool mapping
            ///
            /// This request will cause the server to remap the backing memory
            /// for the pool from the file descriptor passed when the pool was
            /// created, but using the new size.  This request can only be
            /// used to make the pool bigger.
            ///
            const ResizeMessage = struct {
                wl_shm_pool: WlShmPool,
                /// new size of the pool, in bytes
                size: i32,
            };
        };

        /// wl_shm
        /// shared memory support
        ///
        /// A singleton global object that provides support for shared
        /// memory.
        ///
        /// Clients can create wl_shm_pool objects using the create_pool
        /// request.
        ///
        /// At connection setup time, the wl_shm object emits one or more
        /// format events to inform clients about the valid pixel formats
        /// that can be used for buffers.
        ///
        pub const WlShm = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_shm,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_shm) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                invalid_format = 0,
                invalid_stride = 1,
                invalid_fd = 2,
            };

            pub const Format = enum(u32) {
                argb8888 = 0,
                xrgb8888 = 1,
                c8 = 0x20203843,
                rgb332 = 0x38424752,
                bgr233 = 0x38524742,
                xrgb4444 = 0x32315258,
                xbgr4444 = 0x32314258,
                rgbx4444 = 0x32315852,
                bgrx4444 = 0x32315842,
                argb4444 = 0x32315241,
                abgr4444 = 0x32314241,
                rgba4444 = 0x32314152,
                bgra4444 = 0x32314142,
                xrgb1555 = 0x35315258,
                xbgr1555 = 0x35314258,
                rgbx5551 = 0x35315852,
                bgrx5551 = 0x35315842,
                argb1555 = 0x35315241,
                abgr1555 = 0x35314241,
                rgba5551 = 0x35314152,
                bgra5551 = 0x35314142,
                rgb565 = 0x36314752,
                bgr565 = 0x36314742,
                rgb888 = 0x34324752,
                bgr888 = 0x34324742,
                xbgr8888 = 0x34324258,
                rgbx8888 = 0x34325852,
                bgrx8888 = 0x34325842,
                abgr8888 = 0x34324241,
                rgba8888 = 0x34324152,
                bgra8888 = 0x34324142,
                xrgb2101010 = 0x30335258,
                xbgr2101010 = 0x30334258,
                rgbx1010102 = 0x30335852,
                bgrx1010102 = 0x30335842,
                argb2101010 = 0x30335241,
                abgr2101010 = 0x30334241,
                rgba1010102 = 0x30334152,
                bgra1010102 = 0x30334142,
                yuyv = 0x56595559,
                yvyu = 0x55595659,
                uyvy = 0x59565955,
                vyuy = 0x59555956,
                ayuv = 0x56555941,
                nv12 = 0x3231564e,
                nv21 = 0x3132564e,
                nv16 = 0x3631564e,
                nv61 = 0x3136564e,
                yuv410 = 0x39565559,
                yvu410 = 0x39555659,
                yuv411 = 0x31315559,
                yvu411 = 0x31315659,
                yuv420 = 0x32315559,
                yvu420 = 0x32315659,
                yuv422 = 0x36315559,
                yvu422 = 0x36315659,
                yuv444 = 0x34325559,
                yvu444 = 0x34325659,
                r8 = 0x20203852,
                r16 = 0x20363152,
                rg88 = 0x38384752,
                gr88 = 0x38385247,
                rg1616 = 0x32334752,
                gr1616 = 0x32335247,
                xrgb16161616f = 0x48345258,
                xbgr16161616f = 0x48344258,
                argb16161616f = 0x48345241,
                abgr16161616f = 0x48344241,
                xyuv8888 = 0x56555958,
                vuy888 = 0x34325556,
                vuy101010 = 0x30335556,
                y210 = 0x30313259,
                y212 = 0x32313259,
                y216 = 0x36313259,
                y410 = 0x30313459,
                y412 = 0x32313459,
                y416 = 0x36313459,
                xvyu2101010 = 0x30335658,
                xvyu12_16161616 = 0x36335658,
                xvyu16161616 = 0x38345658,
                y0l0 = 0x304c3059,
                x0l0 = 0x304c3058,
                y0l2 = 0x324c3059,
                x0l2 = 0x324c3058,
                yuv420_8bit = 0x38305559,
                yuv420_10bit = 0x30315559,
                xrgb8888_a8 = 0x38415258,
                xbgr8888_a8 = 0x38414258,
                rgbx8888_a8 = 0x38415852,
                bgrx8888_a8 = 0x38415842,
                rgb888_a8 = 0x38413852,
                bgr888_a8 = 0x38413842,
                rgb565_a8 = 0x38413552,
                bgr565_a8 = 0x38413542,
                nv24 = 0x3432564e,
                nv42 = 0x3234564e,
                p210 = 0x30313250,
                p010 = 0x30313050,
                p012 = 0x32313050,
                p016 = 0x36313050,
                axbxgxrx106106106106 = 0x30314241,
                nv15 = 0x3531564e,
                q410 = 0x30313451,
                q401 = 0x31303451,
                xrgb16161616 = 0x38345258,
                xbgr16161616 = 0x38344258,
                argb16161616 = 0x38345241,
                abgr16161616 = 0x38344241,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // create_pool
                    0 => {
                        const id: u32 = try self.wire.nextU32();
                        const fd: i32 = try self.wire.nextFd();
                        const size: i32 = try self.wire.nextI32();
                        return Message{
                            .create_pool = CreatePoolMessage{
                                .wl_shm = self.*,
                                .id = id,
                                .fd = fd,
                                .size = size,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                create_pool,
            };

            pub const Message = union(MessageType) {
                /// create a shm pool
                ///
                /// Create a new wl_shm_pool object.
                ///
                /// The pool can be used to create shared memory based buffer
                /// objects.  The server will mmap size bytes of the passed file
                /// descriptor, to use as backing memory for the pool.
                ///
                create_pool: CreatePoolMessage,
            };

            /// create a shm pool
            ///
            /// Create a new wl_shm_pool object.
            ///
            /// The pool can be used to create shared memory based buffer
            /// objects.  The server will mmap size bytes of the passed file
            /// descriptor, to use as backing memory for the pool.
            ///
            const CreatePoolMessage = struct {
                wl_shm: WlShm,
                /// pool to create
                id: u32,
                /// file descriptor for the pool
                fd: i32,
                /// pool size, in bytes
                size: i32,
            };

            //
            // Informs the client about a valid pixel format that
            // can be used for buffers. Known formats include
            // argb8888 and xrgb8888.
            //
            pub fn sendFormat(self: Self, format: Format) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@intFromEnum(format)); // enum
                try self.wire.finishWrite(self.id, 0);
            }
        };

        /// wl_buffer
        /// content for a wl_surface
        ///
        /// A buffer provides the content for a wl_surface. Buffers are
        /// created through factory interfaces such as wl_shm, wp_linux_buffer_params
        /// (from the linux-dmabuf protocol extension) or similar. It has a width and
        /// a height and can be attached to a wl_surface, but the mechanism by which a
        /// client provides and updates the contents is defined by the buffer factory
        /// interface.
        ///
        /// If the buffer uses a format that has an alpha channel, the alpha channel
        /// is assumed to be premultiplied in the color channels unless otherwise
        /// specified.
        ///
        pub const WlBuffer = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_buffer,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_buffer) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .wl_buffer = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
            };

            pub const Message = union(MessageType) {
                /// destroy a buffer
                ///
                /// Destroy a buffer. If and how you need to release the backing
                /// storage is defined by the buffer factory interface.
                ///
                /// For possible side-effects to a surface, see wl_surface.attach.
                ///
                destroy: DestroyMessage,
            };

            /// destroy a buffer
            ///
            /// Destroy a buffer. If and how you need to release the backing
            /// storage is defined by the buffer factory interface.
            ///
            /// For possible side-effects to a surface, see wl_surface.attach.
            ///
            const DestroyMessage = struct {
                wl_buffer: WlBuffer,
            };

            //
            // Sent when this wl_buffer is no longer used by the compositor.
            // The client is now free to reuse or destroy this buffer and its
            // backing storage.
            //
            // If a client receives a release event before the frame callback
            // requested in the same wl_surface.commit that attaches this
            // wl_buffer to a surface, then the client is immediately free to
            // reuse the buffer and its backing storage, and does not need a
            // second buffer for the next surface content update. Typically
            // this is possible, when the compositor maintains a copy of the
            // wl_surface contents, e.g. as a GL texture. This is an important
            // optimization for GL(ES) compositors with wl_shm clients.
            //
            pub fn sendRelease(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 0);
            }
        };

        /// wl_data_offer
        /// offer to transfer data
        ///
        /// A wl_data_offer represents a piece of data offered for transfer
        /// by another client (the source client).  It is used by the
        /// copy-and-paste and drag-and-drop mechanisms.  The offer
        /// describes the different mime types that the data can be
        /// converted to and provides the mechanism for transferring the
        /// data directly from the source client.
        ///
        pub const WlDataOffer = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_data_offer,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_data_offer) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                invalid_finish = 0,
                invalid_action_mask = 1,
                invalid_action = 2,
                invalid_offer = 3,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // accept
                    0 => {
                        const serial: u32 = try self.wire.nextU32();
                        const mime_type: []u8 = try self.wire.nextString();
                        return Message{
                            .accept = AcceptMessage{
                                .wl_data_offer = self.*,
                                .serial = serial,
                                .mime_type = mime_type,
                            },
                        };
                    },
                    // receive
                    1 => {
                        const mime_type: []u8 = try self.wire.nextString();
                        const fd: i32 = try self.wire.nextFd();
                        return Message{
                            .receive = ReceiveMessage{
                                .wl_data_offer = self.*,
                                .mime_type = mime_type,
                                .fd = fd,
                            },
                        };
                    },
                    // destroy
                    2 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .wl_data_offer = self.*,
                            },
                        };
                    },
                    // finish
                    3 => {
                        return Message{
                            .finish = FinishMessage{
                                .wl_data_offer = self.*,
                            },
                        };
                    },
                    // set_actions
                    4 => {
                        const dnd_actions: WlDataDeviceManager.DndAction = @bitCast(try self.wire.nextU32()); // bitfield
                        const preferred_action: WlDataDeviceManager.DndAction = @bitCast(try self.wire.nextU32()); // bitfield
                        return Message{
                            .set_actions = SetActionsMessage{
                                .wl_data_offer = self.*,
                                .dnd_actions = dnd_actions,
                                .preferred_action = preferred_action,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                accept,
                receive,
                destroy,
                finish,
                set_actions,
            };

            pub const Message = union(MessageType) {
                /// accept one of the offered mime types
                ///
                /// Indicate that the client can accept the given mime type, or
                /// NULL for not accepted.
                ///
                /// For objects of version 2 or older, this request is used by the
                /// client to give feedback whether the client can receive the given
                /// mime type, or NULL if none is accepted; the feedback does not
                /// determine whether the drag-and-drop operation succeeds or not.
                ///
                /// For objects of version 3 or newer, this request determines the
                /// final result of the drag-and-drop operation. If the end result
                /// is that no mime types were accepted, the drag-and-drop operation
                /// will be cancelled and the corresponding drag source will receive
                /// wl_data_source.cancelled. Clients may still use this event in
                /// conjunction with wl_data_source.action for feedback.
                ///
                accept: AcceptMessage,

                /// request that the data is transferred
                ///
                /// To transfer the offered data, the client issues this request
                /// and indicates the mime type it wants to receive.  The transfer
                /// happens through the passed file descriptor (typically created
                /// with the pipe system call).  The source client writes the data
                /// in the mime type representation requested and then closes the
                /// file descriptor.
                ///
                /// The receiving client reads from the read end of the pipe until
                /// EOF and then closes its end, at which point the transfer is
                /// complete.
                ///
                /// This request may happen multiple times for different mime types,
                /// both before and after wl_data_device.drop. Drag-and-drop destination
                /// clients may preemptively fetch data or examine it more closely to
                /// determine acceptance.
                ///
                receive: ReceiveMessage,

                /// destroy data offer
                ///
                /// Destroy the data offer.
                ///
                destroy: DestroyMessage,

                /// the offer will no longer be used
                ///
                /// Notifies the compositor that the drag destination successfully
                /// finished the drag-and-drop operation.
                ///
                /// Upon receiving this request, the compositor will emit
                /// wl_data_source.dnd_finished on the drag source client.
                ///
                /// It is a client error to perform other requests than
                /// wl_data_offer.destroy after this one. It is also an error to perform
                /// this request after a NULL mime type has been set in
                /// wl_data_offer.accept or no action was received through
                /// wl_data_offer.action.
                ///
                /// If wl_data_offer.finish request is received for a non drag and drop
                /// operation, the invalid_finish protocol error is raised.
                ///
                finish: FinishMessage,

                /// set the available/preferred drag-and-drop actions
                ///
                /// Sets the actions that the destination side client supports for
                /// this operation. This request may trigger the emission of
                /// wl_data_source.action and wl_data_offer.action events if the compositor
                /// needs to change the selected action.
                ///
                /// This request can be called multiple times throughout the
                /// drag-and-drop operation, typically in response to wl_data_device.enter
                /// or wl_data_device.motion events.
                ///
                /// This request determines the final result of the drag-and-drop
                /// operation. If the end result is that no action is accepted,
                /// the drag source will receive wl_data_source.cancelled.
                ///
                /// The dnd_actions argument must contain only values expressed in the
                /// wl_data_device_manager.dnd_actions enum, and the preferred_action
                /// argument must only contain one of those values set, otherwise it
                /// will result in a protocol error.
                ///
                /// While managing an "ask" action, the destination drag-and-drop client
                /// may perform further wl_data_offer.receive requests, and is expected
                /// to perform one last wl_data_offer.set_actions request with a preferred
                /// action other than "ask" (and optionally wl_data_offer.accept) before
                /// requesting wl_data_offer.finish, in order to convey the action selected
                /// by the user. If the preferred action is not in the
                /// wl_data_offer.source_actions mask, an error will be raised.
                ///
                /// If the "ask" action is dismissed (e.g. user cancellation), the client
                /// is expected to perform wl_data_offer.destroy right away.
                ///
                /// This request can only be made on drag-and-drop offers, a protocol error
                /// will be raised otherwise.
                ///
                set_actions: SetActionsMessage,
            };

            /// accept one of the offered mime types
            ///
            /// Indicate that the client can accept the given mime type, or
            /// NULL for not accepted.
            ///
            /// For objects of version 2 or older, this request is used by the
            /// client to give feedback whether the client can receive the given
            /// mime type, or NULL if none is accepted; the feedback does not
            /// determine whether the drag-and-drop operation succeeds or not.
            ///
            /// For objects of version 3 or newer, this request determines the
            /// final result of the drag-and-drop operation. If the end result
            /// is that no mime types were accepted, the drag-and-drop operation
            /// will be cancelled and the corresponding drag source will receive
            /// wl_data_source.cancelled. Clients may still use this event in
            /// conjunction with wl_data_source.action for feedback.
            ///
            const AcceptMessage = struct {
                wl_data_offer: WlDataOffer,
                /// serial number of the accept request
                serial: u32,
                /// mime type accepted by the client
                mime_type: []u8,
            };

            /// request that the data is transferred
            ///
            /// To transfer the offered data, the client issues this request
            /// and indicates the mime type it wants to receive.  The transfer
            /// happens through the passed file descriptor (typically created
            /// with the pipe system call).  The source client writes the data
            /// in the mime type representation requested and then closes the
            /// file descriptor.
            ///
            /// The receiving client reads from the read end of the pipe until
            /// EOF and then closes its end, at which point the transfer is
            /// complete.
            ///
            /// This request may happen multiple times for different mime types,
            /// both before and after wl_data_device.drop. Drag-and-drop destination
            /// clients may preemptively fetch data or examine it more closely to
            /// determine acceptance.
            ///
            const ReceiveMessage = struct {
                wl_data_offer: WlDataOffer,
                /// mime type desired by receiver
                mime_type: []u8,
                /// file descriptor for data transfer
                fd: i32,
            };

            /// destroy data offer
            ///
            /// Destroy the data offer.
            ///
            const DestroyMessage = struct {
                wl_data_offer: WlDataOffer,
            };

            /// the offer will no longer be used
            ///
            /// Notifies the compositor that the drag destination successfully
            /// finished the drag-and-drop operation.
            ///
            /// Upon receiving this request, the compositor will emit
            /// wl_data_source.dnd_finished on the drag source client.
            ///
            /// It is a client error to perform other requests than
            /// wl_data_offer.destroy after this one. It is also an error to perform
            /// this request after a NULL mime type has been set in
            /// wl_data_offer.accept or no action was received through
            /// wl_data_offer.action.
            ///
            /// If wl_data_offer.finish request is received for a non drag and drop
            /// operation, the invalid_finish protocol error is raised.
            ///
            const FinishMessage = struct {
                wl_data_offer: WlDataOffer,
            };

            /// set the available/preferred drag-and-drop actions
            ///
            /// Sets the actions that the destination side client supports for
            /// this operation. This request may trigger the emission of
            /// wl_data_source.action and wl_data_offer.action events if the compositor
            /// needs to change the selected action.
            ///
            /// This request can be called multiple times throughout the
            /// drag-and-drop operation, typically in response to wl_data_device.enter
            /// or wl_data_device.motion events.
            ///
            /// This request determines the final result of the drag-and-drop
            /// operation. If the end result is that no action is accepted,
            /// the drag source will receive wl_data_source.cancelled.
            ///
            /// The dnd_actions argument must contain only values expressed in the
            /// wl_data_device_manager.dnd_actions enum, and the preferred_action
            /// argument must only contain one of those values set, otherwise it
            /// will result in a protocol error.
            ///
            /// While managing an "ask" action, the destination drag-and-drop client
            /// may perform further wl_data_offer.receive requests, and is expected
            /// to perform one last wl_data_offer.set_actions request with a preferred
            /// action other than "ask" (and optionally wl_data_offer.accept) before
            /// requesting wl_data_offer.finish, in order to convey the action selected
            /// by the user. If the preferred action is not in the
            /// wl_data_offer.source_actions mask, an error will be raised.
            ///
            /// If the "ask" action is dismissed (e.g. user cancellation), the client
            /// is expected to perform wl_data_offer.destroy right away.
            ///
            /// This request can only be made on drag-and-drop offers, a protocol error
            /// will be raised otherwise.
            ///
            const SetActionsMessage = struct {
                wl_data_offer: WlDataOffer,
                /// actions supported by the destination client
                dnd_actions: WlDataDeviceManager.DndAction,
                /// action preferred by the destination client
                preferred_action: WlDataDeviceManager.DndAction,
            };

            //
            // Sent immediately after creating the wl_data_offer object.  One
            // event per offered mime type.
            //
            pub fn sendOffer(self: Self, mime_type: []const u8) !void {
                try self.wire.startWrite();
                try self.wire.putString(mime_type);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // This event indicates the actions offered by the data source. It
            // will be sent right after wl_data_device.enter, or anytime the source
            // side changes its offered actions through wl_data_source.set_actions.
            //
            pub fn sendSourceActions(self: Self, source_actions: WlDataDeviceManager.DndAction) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@bitCast(source_actions)); // bitfield
                try self.wire.finishWrite(self.id, 1);
            }

            //
            // This event indicates the action selected by the compositor after
            // matching the source/destination side actions. Only one action (or
            // none) will be offered here.
            //
            // This event can be emitted multiple times during the drag-and-drop
            // operation in response to destination side action changes through
            // wl_data_offer.set_actions.
            //
            // This event will no longer be emitted after wl_data_device.drop
            // happened on the drag-and-drop destination, the client must
            // honor the last action received, or the last preferred one set
            // through wl_data_offer.set_actions when handling an "ask" action.
            //
            // Compositors may also change the selected action on the fly, mainly
            // in response to keyboard modifier changes during the drag-and-drop
            // operation.
            //
            // The most recent action received is always the valid one. Prior to
            // receiving wl_data_device.drop, the chosen action may change (e.g.
            // due to keyboard modifiers being pressed). At the time of receiving
            // wl_data_device.drop the drag-and-drop destination must honor the
            // last action received.
            //
            // Action changes may still happen after wl_data_device.drop,
            // especially on "ask" actions, where the drag-and-drop destination
            // may choose another action afterwards. Action changes happening
            // at this stage are always the result of inter-client negotiation, the
            // compositor shall no longer be able to induce a different action.
            //
            // Upon "ask" actions, it is expected that the drag-and-drop destination
            // may potentially choose a different action and/or mime type,
            // based on wl_data_offer.source_actions and finally chosen by the
            // user (e.g. popping up a menu with the available options). The
            // final wl_data_offer.set_actions and wl_data_offer.accept requests
            // must happen before the call to wl_data_offer.finish.
            //
            pub fn sendAction(self: Self, dnd_action: WlDataDeviceManager.DndAction) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@bitCast(dnd_action)); // bitfield
                try self.wire.finishWrite(self.id, 2);
            }
        };

        /// wl_data_source
        /// offer to transfer data
        ///
        /// The wl_data_source object is the source side of a wl_data_offer.
        /// It is created by the source client in a data transfer and
        /// provides a way to describe the offered data and a way to respond
        /// to requests to transfer the data.
        ///
        pub const WlDataSource = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_data_source,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_data_source) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                invalid_action_mask = 0,
                invalid_source = 1,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // offer
                    0 => {
                        const mime_type: []u8 = try self.wire.nextString();
                        return Message{
                            .offer = OfferMessage{
                                .wl_data_source = self.*,
                                .mime_type = mime_type,
                            },
                        };
                    },
                    // destroy
                    1 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .wl_data_source = self.*,
                            },
                        };
                    },
                    // set_actions
                    2 => {
                        const dnd_actions: WlDataDeviceManager.DndAction = @bitCast(try self.wire.nextU32()); // bitfield
                        return Message{
                            .set_actions = SetActionsMessage{
                                .wl_data_source = self.*,
                                .dnd_actions = dnd_actions,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                offer,
                destroy,
                set_actions,
            };

            pub const Message = union(MessageType) {
                /// add an offered mime type
                ///
                /// This request adds a mime type to the set of mime types
                /// advertised to targets.  Can be called several times to offer
                /// multiple types.
                ///
                offer: OfferMessage,

                /// destroy the data source
                ///
                /// Destroy the data source.
                ///
                destroy: DestroyMessage,

                /// set the available drag-and-drop actions
                ///
                /// Sets the actions that the source side client supports for this
                /// operation. This request may trigger wl_data_source.action and
                /// wl_data_offer.action events if the compositor needs to change the
                /// selected action.
                ///
                /// The dnd_actions argument must contain only values expressed in the
                /// wl_data_device_manager.dnd_actions enum, otherwise it will result
                /// in a protocol error.
                ///
                /// This request must be made once only, and can only be made on sources
                /// used in drag-and-drop, so it must be performed before
                /// wl_data_device.start_drag. Attempting to use the source other than
                /// for drag-and-drop will raise a protocol error.
                ///
                set_actions: SetActionsMessage,
            };

            /// add an offered mime type
            ///
            /// This request adds a mime type to the set of mime types
            /// advertised to targets.  Can be called several times to offer
            /// multiple types.
            ///
            const OfferMessage = struct {
                wl_data_source: WlDataSource,
                /// mime type offered by the data source
                mime_type: []u8,
            };

            /// destroy the data source
            ///
            /// Destroy the data source.
            ///
            const DestroyMessage = struct {
                wl_data_source: WlDataSource,
            };

            /// set the available drag-and-drop actions
            ///
            /// Sets the actions that the source side client supports for this
            /// operation. This request may trigger wl_data_source.action and
            /// wl_data_offer.action events if the compositor needs to change the
            /// selected action.
            ///
            /// The dnd_actions argument must contain only values expressed in the
            /// wl_data_device_manager.dnd_actions enum, otherwise it will result
            /// in a protocol error.
            ///
            /// This request must be made once only, and can only be made on sources
            /// used in drag-and-drop, so it must be performed before
            /// wl_data_device.start_drag. Attempting to use the source other than
            /// for drag-and-drop will raise a protocol error.
            ///
            const SetActionsMessage = struct {
                wl_data_source: WlDataSource,
                /// actions supported by the data source
                dnd_actions: WlDataDeviceManager.DndAction,
            };

            //
            // Sent when a target accepts pointer_focus or motion events.  If
            // a target does not accept any of the offered types, type is NULL.
            //
            // Used for feedback during drag-and-drop.
            //
            pub fn sendTarget(self: Self, mime_type: []const u8) !void {
                try self.wire.startWrite();
                try self.wire.putString(mime_type);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // Request for data from the client.  Send the data as the
            // specified mime type over the passed file descriptor, then
            // close it.
            //
            pub fn sendSend(self: Self, mime_type: []const u8, fd: i32) !void {
                try self.wire.startWrite();
                try self.wire.putString(mime_type);
                try self.wire.putFd(fd);
                try self.wire.finishWrite(self.id, 1);
            }

            //
            // This data source is no longer valid. There are several reasons why
            // this could happen:
            //
            // - The data source has been replaced by another data source.
            // - The drag-and-drop operation was performed, but the drop destination
            //   did not accept any of the mime types offered through
            //   wl_data_source.target.
            // - The drag-and-drop operation was performed, but the drop destination
            //   did not select any of the actions present in the mask offered through
            //   wl_data_source.action.
            // - The drag-and-drop operation was performed but didn't happen over a
            //   surface.
            // - The compositor cancelled the drag-and-drop operation (e.g. compositor
            //   dependent timeouts to avoid stale drag-and-drop transfers).
            //
            // The client should clean up and destroy this data source.
            //
            // For objects of version 2 or older, wl_data_source.cancelled will
            // only be emitted if the data source was replaced by another data
            // source.
            //
            pub fn sendCancelled(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 2);
            }

            //
            // The user performed the drop action. This event does not indicate
            // acceptance, wl_data_source.cancelled may still be emitted afterwards
            // if the drop destination does not accept any mime type.
            //
            // However, this event might however not be received if the compositor
            // cancelled the drag-and-drop operation before this event could happen.
            //
            // Note that the data_source may still be used in the future and should
            // not be destroyed here.
            //
            pub fn sendDndDropPerformed(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 3);
            }

            //
            // The drop destination finished interoperating with this data
            // source, so the client is now free to destroy this data source and
            // free all associated data.
            //
            // If the action used to perform the operation was "move", the
            // source can now delete the transferred data.
            //
            pub fn sendDndFinished(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 4);
            }

            //
            // This event indicates the action selected by the compositor after
            // matching the source/destination side actions. Only one action (or
            // none) will be offered here.
            //
            // This event can be emitted multiple times during the drag-and-drop
            // operation, mainly in response to destination side changes through
            // wl_data_offer.set_actions, and as the data device enters/leaves
            // surfaces.
            //
            // It is only possible to receive this event after
            // wl_data_source.dnd_drop_performed if the drag-and-drop operation
            // ended in an "ask" action, in which case the final wl_data_source.action
            // event will happen immediately before wl_data_source.dnd_finished.
            //
            // Compositors may also change the selected action on the fly, mainly
            // in response to keyboard modifier changes during the drag-and-drop
            // operation.
            //
            // The most recent action received is always the valid one. The chosen
            // action may change alongside negotiation (e.g. an "ask" action can turn
            // into a "move" operation), so the effects of the final action must
            // always be applied in wl_data_offer.dnd_finished.
            //
            // Clients can trigger cursor surface changes from this point, so
            // they reflect the current action.
            //
            pub fn sendAction(self: Self, dnd_action: WlDataDeviceManager.DndAction) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@bitCast(dnd_action)); // bitfield
                try self.wire.finishWrite(self.id, 5);
            }
        };

        /// wl_data_device
        /// data transfer device
        ///
        /// There is one wl_data_device per seat which can be obtained
        /// from the global wl_data_device_manager singleton.
        ///
        /// A wl_data_device provides access to inter-client data transfer
        /// mechanisms such as copy-and-paste and drag-and-drop.
        ///
        pub const WlDataDevice = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_data_device,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_data_device) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                role = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // start_drag
                    0 => {
                        const source: ?WlDataSource = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_data_source => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        const origin: WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const icon: ?WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        const serial: u32 = try self.wire.nextU32();
                        return Message{
                            .start_drag = StartDragMessage{
                                .wl_data_device = self.*,
                                .source = source,
                                .origin = origin,
                                .icon = icon,
                                .serial = serial,
                            },
                        };
                    },
                    // set_selection
                    1 => {
                        const source: ?WlDataSource = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_data_source => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        const serial: u32 = try self.wire.nextU32();
                        return Message{
                            .set_selection = SetSelectionMessage{
                                .wl_data_device = self.*,
                                .source = source,
                                .serial = serial,
                            },
                        };
                    },
                    // release
                    2 => {
                        return Message{
                            .release = ReleaseMessage{
                                .wl_data_device = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                start_drag,
                set_selection,
                release,
            };

            pub const Message = union(MessageType) {
                /// start drag-and-drop operation
                ///
                /// This request asks the compositor to start a drag-and-drop
                /// operation on behalf of the client.
                ///
                /// The source argument is the data source that provides the data
                /// for the eventual data transfer. If source is NULL, enter, leave
                /// and motion events are sent only to the client that initiated the
                /// drag and the client is expected to handle the data passing
                /// internally. If source is destroyed, the drag-and-drop session will be
                /// cancelled.
                ///
                /// The origin surface is the surface where the drag originates and
                /// the client must have an active implicit grab that matches the
                /// serial.
                ///
                /// The icon surface is an optional (can be NULL) surface that
                /// provides an icon to be moved around with the cursor.  Initially,
                /// the top-left corner of the icon surface is placed at the cursor
                /// hotspot, but subsequent wl_surface.attach request can move the
                /// relative position. Attach requests must be confirmed with
                /// wl_surface.commit as usual. The icon surface is given the role of
                /// a drag-and-drop icon. If the icon surface already has another role,
                /// it raises a protocol error.
                ///
                /// The current and pending input regions of the icon wl_surface are
                /// cleared, and wl_surface.set_input_region is ignored until the
                /// wl_surface is no longer used as the icon surface. When the use
                /// as an icon ends, the current and pending input regions become
                /// undefined, and the wl_surface is unmapped.
                ///
                start_drag: StartDragMessage,

                /// copy data to the selection
                ///
                /// This request asks the compositor to set the selection
                /// to the data from the source on behalf of the client.
                ///
                /// To unset the selection, set the source to NULL.
                ///
                set_selection: SetSelectionMessage,

                /// destroy data device
                ///
                /// This request destroys the data device.
                ///
                release: ReleaseMessage,
            };

            /// start drag-and-drop operation
            ///
            /// This request asks the compositor to start a drag-and-drop
            /// operation on behalf of the client.
            ///
            /// The source argument is the data source that provides the data
            /// for the eventual data transfer. If source is NULL, enter, leave
            /// and motion events are sent only to the client that initiated the
            /// drag and the client is expected to handle the data passing
            /// internally. If source is destroyed, the drag-and-drop session will be
            /// cancelled.
            ///
            /// The origin surface is the surface where the drag originates and
            /// the client must have an active implicit grab that matches the
            /// serial.
            ///
            /// The icon surface is an optional (can be NULL) surface that
            /// provides an icon to be moved around with the cursor.  Initially,
            /// the top-left corner of the icon surface is placed at the cursor
            /// hotspot, but subsequent wl_surface.attach request can move the
            /// relative position. Attach requests must be confirmed with
            /// wl_surface.commit as usual. The icon surface is given the role of
            /// a drag-and-drop icon. If the icon surface already has another role,
            /// it raises a protocol error.
            ///
            /// The current and pending input regions of the icon wl_surface are
            /// cleared, and wl_surface.set_input_region is ignored until the
            /// wl_surface is no longer used as the icon surface. When the use
            /// as an icon ends, the current and pending input regions become
            /// undefined, and the wl_surface is unmapped.
            ///
            const StartDragMessage = struct {
                wl_data_device: WlDataDevice,
                /// data source for the eventual transfer
                source: ?WlDataSource,
                /// surface where the drag originates
                origin: WlSurface,
                /// drag-and-drop icon surface
                icon: ?WlSurface,
                /// serial number of the implicit grab on the origin
                serial: u32,
            };

            /// copy data to the selection
            ///
            /// This request asks the compositor to set the selection
            /// to the data from the source on behalf of the client.
            ///
            /// To unset the selection, set the source to NULL.
            ///
            const SetSelectionMessage = struct {
                wl_data_device: WlDataDevice,
                /// data source for the selection
                source: ?WlDataSource,
                /// serial number of the event that triggered this request
                serial: u32,
            };

            /// destroy data device
            ///
            /// This request destroys the data device.
            ///
            const ReleaseMessage = struct {
                wl_data_device: WlDataDevice,
            };

            //
            // The data_offer event introduces a new wl_data_offer object,
            // which will subsequently be used in either the
            // data_device.enter event (for drag-and-drop) or the
            // data_device.selection event (for selections).  Immediately
            // following the data_device_data_offer event, the new data_offer
            // object will send out data_offer.offer events to describe the
            // mime types it offers.
            //
            pub fn sendDataOffer(self: Self, id: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(id);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // This event is sent when an active drag-and-drop pointer enters
            // a surface owned by the client.  The position of the pointer at
            // enter time is provided by the x and y arguments, in surface-local
            // coordinates.
            //
            pub fn sendEnter(self: Self, serial: u32, surface: u32, x: f32, y: f32, id: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.putU32(surface);
                try self.wire.putFixed(x);
                try self.wire.putFixed(y);
                try self.wire.putU32(id);
                try self.wire.finishWrite(self.id, 1);
            }

            //
            // This event is sent when the drag-and-drop pointer leaves the
            // surface and the session ends.  The client must destroy the
            // wl_data_offer introduced at enter time at this point.
            //
            pub fn sendLeave(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 2);
            }

            //
            // This event is sent when the drag-and-drop pointer moves within
            // the currently focused surface. The new position of the pointer
            // is provided by the x and y arguments, in surface-local
            // coordinates.
            //
            pub fn sendMotion(self: Self, time: u32, x: f32, y: f32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(time);
                try self.wire.putFixed(x);
                try self.wire.putFixed(y);
                try self.wire.finishWrite(self.id, 3);
            }

            //
            // The event is sent when a drag-and-drop operation is ended
            // because the implicit grab is removed.
            //
            // The drag-and-drop destination is expected to honor the last action
            // received through wl_data_offer.action, if the resulting action is
            // "copy" or "move", the destination can still perform
            // wl_data_offer.receive requests, and is expected to end all
            // transfers with a wl_data_offer.finish request.
            //
            // If the resulting action is "ask", the action will not be considered
            // final. The drag-and-drop destination is expected to perform one last
            // wl_data_offer.set_actions request, or wl_data_offer.destroy in order
            // to cancel the operation.
            //
            pub fn sendDrop(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 4);
            }

            //
            // The selection event is sent out to notify the client of a new
            // wl_data_offer for the selection for this device.  The
            // data_device.data_offer and the data_offer.offer events are
            // sent out immediately before this event to introduce the data
            // offer object.  The selection event is sent to a client
            // immediately before receiving keyboard focus and when a new
            // selection is set while the client has keyboard focus.  The
            // data_offer is valid until a new data_offer or NULL is received
            // or until the client loses keyboard focus.  Switching surface with
            // keyboard focus within the same client doesn't mean a new selection
            // will be sent.  The client must destroy the previous selection
            // data_offer, if any, upon receiving this event.
            //
            pub fn sendSelection(self: Self, id: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(id);
                try self.wire.finishWrite(self.id, 5);
            }
        };

        /// wl_data_device_manager
        /// data transfer interface
        ///
        /// The wl_data_device_manager is a singleton global object that
        /// provides access to inter-client data transfer mechanisms such as
        /// copy-and-paste and drag-and-drop.  These mechanisms are tied to
        /// a wl_seat and this interface lets a client get a wl_data_device
        /// corresponding to a wl_seat.
        ///
        /// Depending on the version bound, the objects created from the bound
        /// wl_data_device_manager object will have different requirements for
        /// functioning properly. See wl_data_source.set_actions,
        /// wl_data_offer.accept and wl_data_offer.finish for details.
        ///
        pub const WlDataDeviceManager = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_data_device_manager,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_data_device_manager) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const DndAction = packed struct(u32) { // bitfield
                // none 0 (removed from bitfield)
                copy: bool = false, // 1
                move: bool = false, // 2
                ask: bool = false, // 4
                _padding: u29 = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // create_data_source
                    0 => {
                        const id: u32 = try self.wire.nextU32();
                        return Message{
                            .create_data_source = CreateDataSourceMessage{
                                .wl_data_device_manager = self.*,
                                .id = id,
                            },
                        };
                    },
                    // get_data_device
                    1 => {
                        const id: u32 = try self.wire.nextU32();
                        const seat: WlSeat = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_seat => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        return Message{
                            .get_data_device = GetDataDeviceMessage{
                                .wl_data_device_manager = self.*,
                                .id = id,
                                .seat = seat,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                create_data_source,
                get_data_device,
            };

            pub const Message = union(MessageType) {
                /// create a new data source
                ///
                /// Create a new data source.
                ///
                create_data_source: CreateDataSourceMessage,

                /// create a new data device
                ///
                /// Create a new data device for a given seat.
                ///
                get_data_device: GetDataDeviceMessage,
            };

            /// create a new data source
            ///
            /// Create a new data source.
            ///
            const CreateDataSourceMessage = struct {
                wl_data_device_manager: WlDataDeviceManager,
                /// data source to create
                id: u32,
            };

            /// create a new data device
            ///
            /// Create a new data device for a given seat.
            ///
            const GetDataDeviceMessage = struct {
                wl_data_device_manager: WlDataDeviceManager,
                /// data device to create
                id: u32,
                /// seat associated with the data device
                seat: WlSeat,
            };
        };

        /// wl_shell
        /// create desktop-style surfaces
        ///
        /// This interface is implemented by servers that provide
        /// desktop-style user interfaces.
        ///
        /// It allows clients to associate a wl_shell_surface with
        /// a basic surface.
        ///
        /// Note! This protocol is deprecated and not intended for production use.
        /// For desktop-style user interfaces, use xdg_shell.
        ///
        pub const WlShell = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_shell,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_shell) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                role = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // get_shell_surface
                    0 => {
                        const id: u32 = try self.wire.nextU32();
                        const surface: WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        return Message{
                            .get_shell_surface = GetShellSurfaceMessage{
                                .wl_shell = self.*,
                                .id = id,
                                .surface = surface,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                get_shell_surface,
            };

            pub const Message = union(MessageType) {
                /// create a shell surface from a surface
                ///
                /// Create a shell surface for an existing surface. This gives
                /// the wl_surface the role of a shell surface. If the wl_surface
                /// already has another role, it raises a protocol error.
                ///
                /// Only one shell surface can be associated with a given surface.
                ///
                get_shell_surface: GetShellSurfaceMessage,
            };

            /// create a shell surface from a surface
            ///
            /// Create a shell surface for an existing surface. This gives
            /// the wl_surface the role of a shell surface. If the wl_surface
            /// already has another role, it raises a protocol error.
            ///
            /// Only one shell surface can be associated with a given surface.
            ///
            const GetShellSurfaceMessage = struct {
                wl_shell: WlShell,
                /// shell surface to create
                id: u32,
                /// surface to be given the shell surface role
                surface: WlSurface,
            };
        };

        /// wl_shell_surface
        /// desktop-style metadata interface
        ///
        /// An interface that may be implemented by a wl_surface, for
        /// implementations that provide a desktop-style user interface.
        ///
        /// It provides requests to treat surfaces like toplevel, fullscreen
        /// or popup windows, move, resize or maximize them, associate
        /// metadata like title and class, etc.
        ///
        /// On the server side the object is automatically destroyed when
        /// the related wl_surface is destroyed. On the client side,
        /// wl_shell_surface_destroy() must be called before destroying
        /// the wl_surface object.
        ///
        pub const WlShellSurface = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_shell_surface,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_shell_surface) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Resize = packed struct(u32) { // bitfield
                // none 0 (removed from bitfield)
                top: bool = false, // 1
                bottom: bool = false, // 2
                left: bool = false, // 4
                // top_left 5 (removed from bitfield)
                // bottom_left 6 (removed from bitfield)
                right: bool = false, // 8
                // top_right 9 (removed from bitfield)
                // bottom_right 10 (removed from bitfield)
                _padding: u28 = 0,
            };

            pub const Transient = packed struct(u32) { // bitfield
                inactive: bool = false, // 1
                _padding: u31 = 0,
            };

            pub const FullscreenMethod = enum(u32) {
                default = 0,
                scale = 1,
                driver = 2,
                fill = 3,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // pong
                    0 => {
                        const serial: u32 = try self.wire.nextU32();
                        return Message{
                            .pong = PongMessage{
                                .wl_shell_surface = self.*,
                                .serial = serial,
                            },
                        };
                    },
                    // move
                    1 => {
                        const seat: WlSeat = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_seat => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const serial: u32 = try self.wire.nextU32();
                        return Message{
                            .move = MoveMessage{
                                .wl_shell_surface = self.*,
                                .seat = seat,
                                .serial = serial,
                            },
                        };
                    },
                    // resize
                    2 => {
                        const seat: WlSeat = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_seat => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const serial: u32 = try self.wire.nextU32();
                        const edges: Resize = @bitCast(try self.wire.nextU32()); // bitfield
                        return Message{
                            .resize = ResizeMessage{
                                .wl_shell_surface = self.*,
                                .seat = seat,
                                .serial = serial,
                                .edges = edges,
                            },
                        };
                    },
                    // set_toplevel
                    3 => {
                        return Message{
                            .set_toplevel = SetToplevelMessage{
                                .wl_shell_surface = self.*,
                            },
                        };
                    },
                    // set_transient
                    4 => {
                        const parent: WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        const flags: Transient = @bitCast(try self.wire.nextU32()); // bitfield
                        return Message{
                            .set_transient = SetTransientMessage{
                                .wl_shell_surface = self.*,
                                .parent = parent,
                                .x = x,
                                .y = y,
                                .flags = flags,
                            },
                        };
                    },
                    // set_fullscreen
                    5 => {
                        const method: FullscreenMethod = @enumFromInt(try self.wire.nextU32()); // enum
                        const framerate: u32 = try self.wire.nextU32();
                        const output: ?WlOutput = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_output => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        return Message{
                            .set_fullscreen = SetFullscreenMessage{
                                .wl_shell_surface = self.*,
                                .method = method,
                                .framerate = framerate,
                                .output = output,
                            },
                        };
                    },
                    // set_popup
                    6 => {
                        const seat: WlSeat = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_seat => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const serial: u32 = try self.wire.nextU32();
                        const parent: WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        const flags: Transient = @bitCast(try self.wire.nextU32()); // bitfield
                        return Message{
                            .set_popup = SetPopupMessage{
                                .wl_shell_surface = self.*,
                                .seat = seat,
                                .serial = serial,
                                .parent = parent,
                                .x = x,
                                .y = y,
                                .flags = flags,
                            },
                        };
                    },
                    // set_maximized
                    7 => {
                        const output: ?WlOutput = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_output => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        return Message{
                            .set_maximized = SetMaximizedMessage{
                                .wl_shell_surface = self.*,
                                .output = output,
                            },
                        };
                    },
                    // set_title
                    8 => {
                        const title: []u8 = try self.wire.nextString();
                        return Message{
                            .set_title = SetTitleMessage{
                                .wl_shell_surface = self.*,
                                .title = title,
                            },
                        };
                    },
                    // set_class
                    9 => {
                        const class_: []u8 = try self.wire.nextString();
                        return Message{
                            .set_class = SetClassMessage{
                                .wl_shell_surface = self.*,
                                .class_ = class_,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                pong,
                move,
                resize,
                set_toplevel,
                set_transient,
                set_fullscreen,
                set_popup,
                set_maximized,
                set_title,
                set_class,
            };

            pub const Message = union(MessageType) {
                /// respond to a ping event
                ///
                /// A client must respond to a ping event with a pong request or
                /// the client may be deemed unresponsive.
                ///
                pong: PongMessage,

                /// start an interactive move
                ///
                /// Start a pointer-driven move of the surface.
                ///
                /// This request must be used in response to a button press event.
                /// The server may ignore move requests depending on the state of
                /// the surface (e.g. fullscreen or maximized).
                ///
                move: MoveMessage,

                /// start an interactive resize
                ///
                /// Start a pointer-driven resizing of the surface.
                ///
                /// This request must be used in response to a button press event.
                /// The server may ignore resize requests depending on the state of
                /// the surface (e.g. fullscreen or maximized).
                ///
                resize: ResizeMessage,

                /// make the surface a toplevel surface
                ///
                /// Map the surface as a toplevel surface.
                ///
                /// A toplevel surface is not fullscreen, maximized or transient.
                ///
                set_toplevel: SetToplevelMessage,

                /// make the surface a transient surface
                ///
                /// Map the surface relative to an existing surface.
                ///
                /// The x and y arguments specify the location of the upper left
                /// corner of the surface relative to the upper left corner of the
                /// parent surface, in surface-local coordinates.
                ///
                /// The flags argument controls details of the transient behaviour.
                ///
                set_transient: SetTransientMessage,

                /// make the surface a fullscreen surface
                ///
                /// Map the surface as a fullscreen surface.
                ///
                /// If an output parameter is given then the surface will be made
                /// fullscreen on that output. If the client does not specify the
                /// output then the compositor will apply its policy - usually
                /// choosing the output on which the surface has the biggest surface
                /// area.
                ///
                /// The client may specify a method to resolve a size conflict
                /// between the output size and the surface size - this is provided
                /// through the method parameter.
                ///
                /// The framerate parameter is used only when the method is set
                /// to "driver", to indicate the preferred framerate. A value of 0
                /// indicates that the client does not care about framerate.  The
                /// framerate is specified in mHz, that is framerate of 60000 is 60Hz.
                ///
                /// A method of "scale" or "driver" implies a scaling operation of
                /// the surface, either via a direct scaling operation or a change of
                /// the output mode. This will override any kind of output scaling, so
                /// that mapping a surface with a buffer size equal to the mode can
                /// fill the screen independent of buffer_scale.
                ///
                /// A method of "fill" means we don't scale up the buffer, however
                /// any output scale is applied. This means that you may run into
                /// an edge case where the application maps a buffer with the same
                /// size of the output mode but buffer_scale 1 (thus making a
                /// surface larger than the output). In this case it is allowed to
                /// downscale the results to fit the screen.
                ///
                /// The compositor must reply to this request with a configure event
                /// with the dimensions for the output on which the surface will
                /// be made fullscreen.
                ///
                set_fullscreen: SetFullscreenMessage,

                /// make the surface a popup surface
                ///
                /// Map the surface as a popup.
                ///
                /// A popup surface is a transient surface with an added pointer
                /// grab.
                ///
                /// An existing implicit grab will be changed to owner-events mode,
                /// and the popup grab will continue after the implicit grab ends
                /// (i.e. releasing the mouse button does not cause the popup to
                /// be unmapped).
                ///
                /// The popup grab continues until the window is destroyed or a
                /// mouse button is pressed in any other client's window. A click
                /// in any of the client's surfaces is reported as normal, however,
                /// clicks in other clients' surfaces will be discarded and trigger
                /// the callback.
                ///
                /// The x and y arguments specify the location of the upper left
                /// corner of the surface relative to the upper left corner of the
                /// parent surface, in surface-local coordinates.
                ///
                set_popup: SetPopupMessage,

                /// make the surface a maximized surface
                ///
                /// Map the surface as a maximized surface.
                ///
                /// If an output parameter is given then the surface will be
                /// maximized on that output. If the client does not specify the
                /// output then the compositor will apply its policy - usually
                /// choosing the output on which the surface has the biggest surface
                /// area.
                ///
                /// The compositor will reply with a configure event telling
                /// the expected new surface size. The operation is completed
                /// on the next buffer attach to this surface.
                ///
                /// A maximized surface typically fills the entire output it is
                /// bound to, except for desktop elements such as panels. This is
                /// the main difference between a maximized shell surface and a
                /// fullscreen shell surface.
                ///
                /// The details depend on the compositor implementation.
                ///
                set_maximized: SetMaximizedMessage,

                /// set surface title
                ///
                /// Set a short title for the surface.
                ///
                /// This string may be used to identify the surface in a task bar,
                /// window list, or other user interface elements provided by the
                /// compositor.
                ///
                /// The string must be encoded in UTF-8.
                ///
                set_title: SetTitleMessage,

                /// set surface class
                ///
                /// Set a class for the surface.
                ///
                /// The surface class identifies the general class of applications
                /// to which the surface belongs. A common convention is to use the
                /// file name (or the full path if it is a non-standard location) of
                /// the application's .desktop file as the class.
                ///
                set_class: SetClassMessage,
            };

            /// respond to a ping event
            ///
            /// A client must respond to a ping event with a pong request or
            /// the client may be deemed unresponsive.
            ///
            const PongMessage = struct {
                wl_shell_surface: WlShellSurface,
                /// serial number of the ping event
                serial: u32,
            };

            /// start an interactive move
            ///
            /// Start a pointer-driven move of the surface.
            ///
            /// This request must be used in response to a button press event.
            /// The server may ignore move requests depending on the state of
            /// the surface (e.g. fullscreen or maximized).
            ///
            const MoveMessage = struct {
                wl_shell_surface: WlShellSurface,
                /// seat whose pointer is used
                seat: WlSeat,
                /// serial number of the implicit grab on the pointer
                serial: u32,
            };

            /// start an interactive resize
            ///
            /// Start a pointer-driven resizing of the surface.
            ///
            /// This request must be used in response to a button press event.
            /// The server may ignore resize requests depending on the state of
            /// the surface (e.g. fullscreen or maximized).
            ///
            const ResizeMessage = struct {
                wl_shell_surface: WlShellSurface,
                /// seat whose pointer is used
                seat: WlSeat,
                /// serial number of the implicit grab on the pointer
                serial: u32,
                /// which edge or corner is being dragged
                edges: Resize,
            };

            /// make the surface a toplevel surface
            ///
            /// Map the surface as a toplevel surface.
            ///
            /// A toplevel surface is not fullscreen, maximized or transient.
            ///
            const SetToplevelMessage = struct {
                wl_shell_surface: WlShellSurface,
            };

            /// make the surface a transient surface
            ///
            /// Map the surface relative to an existing surface.
            ///
            /// The x and y arguments specify the location of the upper left
            /// corner of the surface relative to the upper left corner of the
            /// parent surface, in surface-local coordinates.
            ///
            /// The flags argument controls details of the transient behaviour.
            ///
            const SetTransientMessage = struct {
                wl_shell_surface: WlShellSurface,
                /// parent surface
                parent: WlSurface,
                /// surface-local x coordinate
                x: i32,
                /// surface-local y coordinate
                y: i32,
                /// transient surface behavior
                flags: Transient,
            };

            /// make the surface a fullscreen surface
            ///
            /// Map the surface as a fullscreen surface.
            ///
            /// If an output parameter is given then the surface will be made
            /// fullscreen on that output. If the client does not specify the
            /// output then the compositor will apply its policy - usually
            /// choosing the output on which the surface has the biggest surface
            /// area.
            ///
            /// The client may specify a method to resolve a size conflict
            /// between the output size and the surface size - this is provided
            /// through the method parameter.
            ///
            /// The framerate parameter is used only when the method is set
            /// to "driver", to indicate the preferred framerate. A value of 0
            /// indicates that the client does not care about framerate.  The
            /// framerate is specified in mHz, that is framerate of 60000 is 60Hz.
            ///
            /// A method of "scale" or "driver" implies a scaling operation of
            /// the surface, either via a direct scaling operation or a change of
            /// the output mode. This will override any kind of output scaling, so
            /// that mapping a surface with a buffer size equal to the mode can
            /// fill the screen independent of buffer_scale.
            ///
            /// A method of "fill" means we don't scale up the buffer, however
            /// any output scale is applied. This means that you may run into
            /// an edge case where the application maps a buffer with the same
            /// size of the output mode but buffer_scale 1 (thus making a
            /// surface larger than the output). In this case it is allowed to
            /// downscale the results to fit the screen.
            ///
            /// The compositor must reply to this request with a configure event
            /// with the dimensions for the output on which the surface will
            /// be made fullscreen.
            ///
            const SetFullscreenMessage = struct {
                wl_shell_surface: WlShellSurface,
                /// method for resolving size conflict
                method: FullscreenMethod,
                /// framerate in mHz
                framerate: u32,
                /// output on which the surface is to be fullscreen
                output: ?WlOutput,
            };

            /// make the surface a popup surface
            ///
            /// Map the surface as a popup.
            ///
            /// A popup surface is a transient surface with an added pointer
            /// grab.
            ///
            /// An existing implicit grab will be changed to owner-events mode,
            /// and the popup grab will continue after the implicit grab ends
            /// (i.e. releasing the mouse button does not cause the popup to
            /// be unmapped).
            ///
            /// The popup grab continues until the window is destroyed or a
            /// mouse button is pressed in any other client's window. A click
            /// in any of the client's surfaces is reported as normal, however,
            /// clicks in other clients' surfaces will be discarded and trigger
            /// the callback.
            ///
            /// The x and y arguments specify the location of the upper left
            /// corner of the surface relative to the upper left corner of the
            /// parent surface, in surface-local coordinates.
            ///
            const SetPopupMessage = struct {
                wl_shell_surface: WlShellSurface,
                /// seat whose pointer is used
                seat: WlSeat,
                /// serial number of the implicit grab on the pointer
                serial: u32,
                /// parent surface
                parent: WlSurface,
                /// surface-local x coordinate
                x: i32,
                /// surface-local y coordinate
                y: i32,
                /// transient surface behavior
                flags: Transient,
            };

            /// make the surface a maximized surface
            ///
            /// Map the surface as a maximized surface.
            ///
            /// If an output parameter is given then the surface will be
            /// maximized on that output. If the client does not specify the
            /// output then the compositor will apply its policy - usually
            /// choosing the output on which the surface has the biggest surface
            /// area.
            ///
            /// The compositor will reply with a configure event telling
            /// the expected new surface size. The operation is completed
            /// on the next buffer attach to this surface.
            ///
            /// A maximized surface typically fills the entire output it is
            /// bound to, except for desktop elements such as panels. This is
            /// the main difference between a maximized shell surface and a
            /// fullscreen shell surface.
            ///
            /// The details depend on the compositor implementation.
            ///
            const SetMaximizedMessage = struct {
                wl_shell_surface: WlShellSurface,
                /// output on which the surface is to be maximized
                output: ?WlOutput,
            };

            /// set surface title
            ///
            /// Set a short title for the surface.
            ///
            /// This string may be used to identify the surface in a task bar,
            /// window list, or other user interface elements provided by the
            /// compositor.
            ///
            /// The string must be encoded in UTF-8.
            ///
            const SetTitleMessage = struct {
                wl_shell_surface: WlShellSurface,
                /// surface title
                title: []u8,
            };

            /// set surface class
            ///
            /// Set a class for the surface.
            ///
            /// The surface class identifies the general class of applications
            /// to which the surface belongs. A common convention is to use the
            /// file name (or the full path if it is a non-standard location) of
            /// the application's .desktop file as the class.
            ///
            const SetClassMessage = struct {
                wl_shell_surface: WlShellSurface,
                /// surface class
                class_: []u8,
            };

            //
            // Ping a client to check if it is receiving events and sending
            // requests. A client is expected to reply with a pong request.
            //
            pub fn sendPing(self: Self, serial: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // The configure event asks the client to resize its surface.
            //
            // The size is a hint, in the sense that the client is free to
            // ignore it if it doesn't resize, pick a smaller size (to
            // satisfy aspect ratio or resize in steps of NxM pixels).
            //
            // The edges parameter provides a hint about how the surface
            // was resized. The client may use this information to decide
            // how to adjust its content to the new size (e.g. a scrolling
            // area might adjust its content position to leave the viewable
            // content unmoved).
            //
            // The client is free to dismiss all but the last configure
            // event it received.
            //
            // The width and height arguments specify the size of the window
            // in surface-local coordinates.
            //
            pub fn sendConfigure(self: Self, edges: Resize, width: i32, height: i32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@bitCast(edges)); // bitfield
                try self.wire.putI32(width);
                try self.wire.putI32(height);
                try self.wire.finishWrite(self.id, 1);
            }

            //
            // The popup_done event is sent out when a popup grab is broken,
            // that is, when the user clicks a surface that doesn't belong
            // to the client owning the popup surface.
            //
            pub fn sendPopupDone(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 2);
            }
        };

        /// wl_surface
        /// an onscreen surface
        ///
        /// A surface is a rectangular area that may be displayed on zero
        /// or more outputs, and shown any number of times at the compositor's
        /// discretion. They can present wl_buffers, receive user input, and
        /// define a local coordinate system.
        ///
        /// The size of a surface (and relative positions on it) is described
        /// in surface-local coordinates, which may differ from the buffer
        /// coordinates of the pixel content, in case a buffer_transform
        /// or a buffer_scale is used.
        ///
        /// A surface without a "role" is fairly useless: a compositor does
        /// not know where, when or how to present it. The role is the
        /// purpose of a wl_surface. Examples of roles are a cursor for a
        /// pointer (as set by wl_pointer.set_cursor), a drag icon
        /// (wl_data_device.start_drag), a sub-surface
        /// (wl_subcompositor.get_subsurface), and a window as defined by a
        /// shell protocol (e.g. wl_shell.get_shell_surface).
        ///
        /// A surface can have only one role at a time. Initially a
        /// wl_surface does not have a role. Once a wl_surface is given a
        /// role, it is set permanently for the whole lifetime of the
        /// wl_surface object. Giving the current role again is allowed,
        /// unless explicitly forbidden by the relevant interface
        /// specification.
        ///
        /// Surface roles are given by requests in other interfaces such as
        /// wl_pointer.set_cursor. The request should explicitly mention
        /// that this request gives a role to a wl_surface. Often, this
        /// request also creates a new protocol object that represents the
        /// role and adds additional functionality to wl_surface. When a
        /// client wants to destroy a wl_surface, they must destroy this 'role
        /// object' before the wl_surface.
        ///
        /// Destroying the role object does not remove the role from the
        /// wl_surface, but it may stop the wl_surface from "playing the role".
        /// For instance, if a wl_subsurface object is destroyed, the wl_surface
        /// it was created for will be unmapped and forget its position and
        /// z-order. It is allowed to create a wl_subsurface for the same
        /// wl_surface again, but it is not allowed to use the wl_surface as
        /// a cursor (cursor is a different role than sub-surface, and role
        /// switching is not allowed).
        ///
        pub const WlSurface = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_surface,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_surface) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                invalid_scale = 0,
                invalid_transform = 1,
                invalid_size = 2,
                invalid_offset = 3,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .wl_surface = self.*,
                            },
                        };
                    },
                    // attach
                    1 => {
                        const buffer: ?WlBuffer = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_buffer => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        return Message{
                            .attach = AttachMessage{
                                .wl_surface = self.*,
                                .buffer = buffer,
                                .x = x,
                                .y = y,
                            },
                        };
                    },
                    // damage
                    2 => {
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        return Message{
                            .damage = DamageMessage{
                                .wl_surface = self.*,
                                .x = x,
                                .y = y,
                                .width = width,
                                .height = height,
                            },
                        };
                    },
                    // frame
                    3 => {
                        const callback: u32 = try self.wire.nextU32();
                        return Message{
                            .frame = FrameMessage{
                                .wl_surface = self.*,
                                .callback = callback,
                            },
                        };
                    },
                    // set_opaque_region
                    4 => {
                        const region: ?WlRegion = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_region => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        return Message{
                            .set_opaque_region = SetOpaqueRegionMessage{
                                .wl_surface = self.*,
                                .region = region,
                            },
                        };
                    },
                    // set_input_region
                    5 => {
                        const region: ?WlRegion = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_region => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        return Message{
                            .set_input_region = SetInputRegionMessage{
                                .wl_surface = self.*,
                                .region = region,
                            },
                        };
                    },
                    // commit
                    6 => {
                        return Message{
                            .commit = CommitMessage{
                                .wl_surface = self.*,
                            },
                        };
                    },
                    // set_buffer_transform
                    7 => {
                        const transform: WlOutput.Transform = @enumFromInt(try self.wire.nextI32()); // enum
                        return Message{
                            .set_buffer_transform = SetBufferTransformMessage{
                                .wl_surface = self.*,
                                .transform = transform,
                            },
                        };
                    },
                    // set_buffer_scale
                    8 => {
                        const scale: i32 = try self.wire.nextI32();
                        return Message{
                            .set_buffer_scale = SetBufferScaleMessage{
                                .wl_surface = self.*,
                                .scale = scale,
                            },
                        };
                    },
                    // damage_buffer
                    9 => {
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        return Message{
                            .damage_buffer = DamageBufferMessage{
                                .wl_surface = self.*,
                                .x = x,
                                .y = y,
                                .width = width,
                                .height = height,
                            },
                        };
                    },
                    // offset
                    10 => {
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        return Message{
                            .offset = OffsetMessage{
                                .wl_surface = self.*,
                                .x = x,
                                .y = y,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                attach,
                damage,
                frame,
                set_opaque_region,
                set_input_region,
                commit,
                set_buffer_transform,
                set_buffer_scale,
                damage_buffer,
                offset,
            };

            pub const Message = union(MessageType) {
                /// delete surface
                ///
                /// Deletes the surface and invalidates its object ID.
                ///
                destroy: DestroyMessage,

                /// set the surface contents
                ///
                /// Set a buffer as the content of this surface.
                ///
                /// The new size of the surface is calculated based on the buffer
                /// size transformed by the inverse buffer_transform and the
                /// inverse buffer_scale. This means that at commit time the supplied
                /// buffer size must be an integer multiple of the buffer_scale. If
                /// that's not the case, an invalid_size error is sent.
                ///
                /// The x and y arguments specify the location of the new pending
                /// buffer's upper left corner, relative to the current buffer's upper
                /// left corner, in surface-local coordinates. In other words, the
                /// x and y, combined with the new surface size define in which
                /// directions the surface's size changes. Setting anything other than 0
                /// as x and y arguments is discouraged, and should instead be replaced
                /// with using the separate wl_surface.offset request.
                ///
                /// When the bound wl_surface version is 5 or higher, passing any
                /// non-zero x or y is a protocol violation, and will result in an
                /// 'invalid_offset' error being raised. To achieve equivalent semantics,
                /// use wl_surface.offset.
                ///
                /// Surface contents are double-buffered state, see wl_surface.commit.
                ///
                /// The initial surface contents are void; there is no content.
                /// wl_surface.attach assigns the given wl_buffer as the pending
                /// wl_buffer. wl_surface.commit makes the pending wl_buffer the new
                /// surface contents, and the size of the surface becomes the size
                /// calculated from the wl_buffer, as described above. After commit,
                /// there is no pending buffer until the next attach.
                ///
                /// Committing a pending wl_buffer allows the compositor to read the
                /// pixels in the wl_buffer. The compositor may access the pixels at
                /// any time after the wl_surface.commit request. When the compositor
                /// will not access the pixels anymore, it will send the
                /// wl_buffer.release event. Only after receiving wl_buffer.release,
                /// the client may reuse the wl_buffer. A wl_buffer that has been
                /// attached and then replaced by another attach instead of committed
                /// will not receive a release event, and is not used by the
                /// compositor.
                ///
                /// If a pending wl_buffer has been committed to more than one wl_surface,
                /// the delivery of wl_buffer.release events becomes undefined. A well
                /// behaved client should not rely on wl_buffer.release events in this
                /// case. Alternatively, a client could create multiple wl_buffer objects
                /// from the same backing storage or use wp_linux_buffer_release.
                ///
                /// Destroying the wl_buffer after wl_buffer.release does not change
                /// the surface contents. Destroying the wl_buffer before wl_buffer.release
                /// is allowed as long as the underlying buffer storage isn't re-used (this
                /// can happen e.g. on client process termination). However, if the client
                /// destroys the wl_buffer before receiving the wl_buffer.release event and
                /// mutates the underlying buffer storage, the surface contents become
                /// undefined immediately.
                ///
                /// If wl_surface.attach is sent with a NULL wl_buffer, the
                /// following wl_surface.commit will remove the surface content.
                ///
                attach: AttachMessage,

                /// mark part of the surface damaged
                ///
                /// This request is used to describe the regions where the pending
                /// buffer is different from the current surface contents, and where
                /// the surface therefore needs to be repainted. The compositor
                /// ignores the parts of the damage that fall outside of the surface.
                ///
                /// Damage is double-buffered state, see wl_surface.commit.
                ///
                /// The damage rectangle is specified in surface-local coordinates,
                /// where x and y specify the upper left corner of the damage rectangle.
                ///
                /// The initial value for pending damage is empty: no damage.
                /// wl_surface.damage adds pending damage: the new pending damage
                /// is the union of old pending damage and the given rectangle.
                ///
                /// wl_surface.commit assigns pending damage as the current damage,
                /// and clears pending damage. The server will clear the current
                /// damage as it repaints the surface.
                ///
                /// Note! New clients should not use this request. Instead damage can be
                /// posted with wl_surface.damage_buffer which uses buffer coordinates
                /// instead of surface coordinates.
                ///
                damage: DamageMessage,

                /// request a frame throttling hint
                ///
                /// Request a notification when it is a good time to start drawing a new
                /// frame, by creating a frame callback. This is useful for throttling
                /// redrawing operations, and driving animations.
                ///
                /// When a client is animating on a wl_surface, it can use the 'frame'
                /// request to get notified when it is a good time to draw and commit the
                /// next frame of animation. If the client commits an update earlier than
                /// that, it is likely that some updates will not make it to the display,
                /// and the client is wasting resources by drawing too often.
                ///
                /// The frame request will take effect on the next wl_surface.commit.
                /// The notification will only be posted for one frame unless
                /// requested again. For a wl_surface, the notifications are posted in
                /// the order the frame requests were committed.
                ///
                /// The server must send the notifications so that a client
                /// will not send excessive updates, while still allowing
                /// the highest possible update rate for clients that wait for the reply
                /// before drawing again. The server should give some time for the client
                /// to draw and commit after sending the frame callback events to let it
                /// hit the next output refresh.
                ///
                /// A server should avoid signaling the frame callbacks if the
                /// surface is not visible in any way, e.g. the surface is off-screen,
                /// or completely obscured by other opaque surfaces.
                ///
                /// The object returned by this request will be destroyed by the
                /// compositor after the callback is fired and as such the client must not
                /// attempt to use it after that point.
                ///
                /// The callback_data passed in the callback is the current time, in
                /// milliseconds, with an undefined base.
                ///
                frame: FrameMessage,

                /// set opaque region
                ///
                /// This request sets the region of the surface that contains
                /// opaque content.
                ///
                /// The opaque region is an optimization hint for the compositor
                /// that lets it optimize the redrawing of content behind opaque
                /// regions.  Setting an opaque region is not required for correct
                /// behaviour, but marking transparent content as opaque will result
                /// in repaint artifacts.
                ///
                /// The opaque region is specified in surface-local coordinates.
                ///
                /// The compositor ignores the parts of the opaque region that fall
                /// outside of the surface.
                ///
                /// Opaque region is double-buffered state, see wl_surface.commit.
                ///
                /// wl_surface.set_opaque_region changes the pending opaque region.
                /// wl_surface.commit copies the pending region to the current region.
                /// Otherwise, the pending and current regions are never changed.
                ///
                /// The initial value for an opaque region is empty. Setting the pending
                /// opaque region has copy semantics, and the wl_region object can be
                /// destroyed immediately. A NULL wl_region causes the pending opaque
                /// region to be set to empty.
                ///
                set_opaque_region: SetOpaqueRegionMessage,

                /// set input region
                ///
                /// This request sets the region of the surface that can receive
                /// pointer and touch events.
                ///
                /// Input events happening outside of this region will try the next
                /// surface in the server surface stack. The compositor ignores the
                /// parts of the input region that fall outside of the surface.
                ///
                /// The input region is specified in surface-local coordinates.
                ///
                /// Input region is double-buffered state, see wl_surface.commit.
                ///
                /// wl_surface.set_input_region changes the pending input region.
                /// wl_surface.commit copies the pending region to the current region.
                /// Otherwise the pending and current regions are never changed,
                /// except cursor and icon surfaces are special cases, see
                /// wl_pointer.set_cursor and wl_data_device.start_drag.
                ///
                /// The initial value for an input region is infinite. That means the
                /// whole surface will accept input. Setting the pending input region
                /// has copy semantics, and the wl_region object can be destroyed
                /// immediately. A NULL wl_region causes the input region to be set
                /// to infinite.
                ///
                set_input_region: SetInputRegionMessage,

                /// commit pending surface state
                ///
                /// Surface state (input, opaque, and damage regions, attached buffers,
                /// etc.) is double-buffered. Protocol requests modify the pending state,
                /// as opposed to the current state in use by the compositor. A commit
                /// request atomically applies all pending state, replacing the current
                /// state. After commit, the new pending state is as documented for each
                /// related request.
                ///
                /// On commit, a pending wl_buffer is applied first, and all other state
                /// second. This means that all coordinates in double-buffered state are
                /// relative to the new wl_buffer coming into use, except for
                /// wl_surface.attach itself. If there is no pending wl_buffer, the
                /// coordinates are relative to the current surface contents.
                ///
                /// All requests that need a commit to become effective are documented
                /// to affect double-buffered state.
                ///
                /// Other interfaces may add further double-buffered surface state.
                ///
                commit: CommitMessage,

                /// sets the buffer transformation
                ///
                /// This request sets an optional transformation on how the compositor
                /// interprets the contents of the buffer attached to the surface. The
                /// accepted values for the transform parameter are the values for
                /// wl_output.transform.
                ///
                /// Buffer transform is double-buffered state, see wl_surface.commit.
                ///
                /// A newly created surface has its buffer transformation set to normal.
                ///
                /// wl_surface.set_buffer_transform changes the pending buffer
                /// transformation. wl_surface.commit copies the pending buffer
                /// transformation to the current one. Otherwise, the pending and current
                /// values are never changed.
                ///
                /// The purpose of this request is to allow clients to render content
                /// according to the output transform, thus permitting the compositor to
                /// use certain optimizations even if the display is rotated. Using
                /// hardware overlays and scanning out a client buffer for fullscreen
                /// surfaces are examples of such optimizations. Those optimizations are
                /// highly dependent on the compositor implementation, so the use of this
                /// request should be considered on a case-by-case basis.
                ///
                /// Note that if the transform value includes 90 or 270 degree rotation,
                /// the width of the buffer will become the surface height and the height
                /// of the buffer will become the surface width.
                ///
                /// If transform is not one of the values from the
                /// wl_output.transform enum the invalid_transform protocol error
                /// is raised.
                ///
                set_buffer_transform: SetBufferTransformMessage,

                /// sets the buffer scaling factor
                ///
                /// This request sets an optional scaling factor on how the compositor
                /// interprets the contents of the buffer attached to the window.
                ///
                /// Buffer scale is double-buffered state, see wl_surface.commit.
                ///
                /// A newly created surface has its buffer scale set to 1.
                ///
                /// wl_surface.set_buffer_scale changes the pending buffer scale.
                /// wl_surface.commit copies the pending buffer scale to the current one.
                /// Otherwise, the pending and current values are never changed.
                ///
                /// The purpose of this request is to allow clients to supply higher
                /// resolution buffer data for use on high resolution outputs. It is
                /// intended that you pick the same buffer scale as the scale of the
                /// output that the surface is displayed on. This means the compositor
                /// can avoid scaling when rendering the surface on that output.
                ///
                /// Note that if the scale is larger than 1, then you have to attach
                /// a buffer that is larger (by a factor of scale in each dimension)
                /// than the desired surface size.
                ///
                /// If scale is not positive the invalid_scale protocol error is
                /// raised.
                ///
                set_buffer_scale: SetBufferScaleMessage,

                /// mark part of the surface damaged using buffer coordinates
                ///
                /// This request is used to describe the regions where the pending
                /// buffer is different from the current surface contents, and where
                /// the surface therefore needs to be repainted. The compositor
                /// ignores the parts of the damage that fall outside of the surface.
                ///
                /// Damage is double-buffered state, see wl_surface.commit.
                ///
                /// The damage rectangle is specified in buffer coordinates,
                /// where x and y specify the upper left corner of the damage rectangle.
                ///
                /// The initial value for pending damage is empty: no damage.
                /// wl_surface.damage_buffer adds pending damage: the new pending
                /// damage is the union of old pending damage and the given rectangle.
                ///
                /// wl_surface.commit assigns pending damage as the current damage,
                /// and clears pending damage. The server will clear the current
                /// damage as it repaints the surface.
                ///
                /// This request differs from wl_surface.damage in only one way - it
                /// takes damage in buffer coordinates instead of surface-local
                /// coordinates. While this generally is more intuitive than surface
                /// coordinates, it is especially desirable when using wp_viewport
                /// or when a drawing library (like EGL) is unaware of buffer scale
                /// and buffer transform.
                ///
                /// Note: Because buffer transformation changes and damage requests may
                /// be interleaved in the protocol stream, it is impossible to determine
                /// the actual mapping between surface and buffer damage until
                /// wl_surface.commit time. Therefore, compositors wishing to take both
                /// kinds of damage into account will have to accumulate damage from the
                /// two requests separately and only transform from one to the other
                /// after receiving the wl_surface.commit.
                ///
                damage_buffer: DamageBufferMessage,

                /// set the surface contents offset
                ///
                /// The x and y arguments specify the location of the new pending
                /// buffer's upper left corner, relative to the current buffer's upper
                /// left corner, in surface-local coordinates. In other words, the
                /// x and y, combined with the new surface size define in which
                /// directions the surface's size changes.
                ///
                /// Surface location offset is double-buffered state, see
                /// wl_surface.commit.
                ///
                /// This request is semantically equivalent to and the replaces the x and y
                /// arguments in the wl_surface.attach request in wl_surface versions prior
                /// to 5. See wl_surface.attach for details.
                ///
                offset: OffsetMessage,
            };

            /// delete surface
            ///
            /// Deletes the surface and invalidates its object ID.
            ///
            const DestroyMessage = struct {
                wl_surface: WlSurface,
            };

            /// set the surface contents
            ///
            /// Set a buffer as the content of this surface.
            ///
            /// The new size of the surface is calculated based on the buffer
            /// size transformed by the inverse buffer_transform and the
            /// inverse buffer_scale. This means that at commit time the supplied
            /// buffer size must be an integer multiple of the buffer_scale. If
            /// that's not the case, an invalid_size error is sent.
            ///
            /// The x and y arguments specify the location of the new pending
            /// buffer's upper left corner, relative to the current buffer's upper
            /// left corner, in surface-local coordinates. In other words, the
            /// x and y, combined with the new surface size define in which
            /// directions the surface's size changes. Setting anything other than 0
            /// as x and y arguments is discouraged, and should instead be replaced
            /// with using the separate wl_surface.offset request.
            ///
            /// When the bound wl_surface version is 5 or higher, passing any
            /// non-zero x or y is a protocol violation, and will result in an
            /// 'invalid_offset' error being raised. To achieve equivalent semantics,
            /// use wl_surface.offset.
            ///
            /// Surface contents are double-buffered state, see wl_surface.commit.
            ///
            /// The initial surface contents are void; there is no content.
            /// wl_surface.attach assigns the given wl_buffer as the pending
            /// wl_buffer. wl_surface.commit makes the pending wl_buffer the new
            /// surface contents, and the size of the surface becomes the size
            /// calculated from the wl_buffer, as described above. After commit,
            /// there is no pending buffer until the next attach.
            ///
            /// Committing a pending wl_buffer allows the compositor to read the
            /// pixels in the wl_buffer. The compositor may access the pixels at
            /// any time after the wl_surface.commit request. When the compositor
            /// will not access the pixels anymore, it will send the
            /// wl_buffer.release event. Only after receiving wl_buffer.release,
            /// the client may reuse the wl_buffer. A wl_buffer that has been
            /// attached and then replaced by another attach instead of committed
            /// will not receive a release event, and is not used by the
            /// compositor.
            ///
            /// If a pending wl_buffer has been committed to more than one wl_surface,
            /// the delivery of wl_buffer.release events becomes undefined. A well
            /// behaved client should not rely on wl_buffer.release events in this
            /// case. Alternatively, a client could create multiple wl_buffer objects
            /// from the same backing storage or use wp_linux_buffer_release.
            ///
            /// Destroying the wl_buffer after wl_buffer.release does not change
            /// the surface contents. Destroying the wl_buffer before wl_buffer.release
            /// is allowed as long as the underlying buffer storage isn't re-used (this
            /// can happen e.g. on client process termination). However, if the client
            /// destroys the wl_buffer before receiving the wl_buffer.release event and
            /// mutates the underlying buffer storage, the surface contents become
            /// undefined immediately.
            ///
            /// If wl_surface.attach is sent with a NULL wl_buffer, the
            /// following wl_surface.commit will remove the surface content.
            ///
            const AttachMessage = struct {
                wl_surface: WlSurface,
                /// buffer of surface contents
                buffer: ?WlBuffer,
                /// surface-local x coordinate
                x: i32,
                /// surface-local y coordinate
                y: i32,
            };

            /// mark part of the surface damaged
            ///
            /// This request is used to describe the regions where the pending
            /// buffer is different from the current surface contents, and where
            /// the surface therefore needs to be repainted. The compositor
            /// ignores the parts of the damage that fall outside of the surface.
            ///
            /// Damage is double-buffered state, see wl_surface.commit.
            ///
            /// The damage rectangle is specified in surface-local coordinates,
            /// where x and y specify the upper left corner of the damage rectangle.
            ///
            /// The initial value for pending damage is empty: no damage.
            /// wl_surface.damage adds pending damage: the new pending damage
            /// is the union of old pending damage and the given rectangle.
            ///
            /// wl_surface.commit assigns pending damage as the current damage,
            /// and clears pending damage. The server will clear the current
            /// damage as it repaints the surface.
            ///
            /// Note! New clients should not use this request. Instead damage can be
            /// posted with wl_surface.damage_buffer which uses buffer coordinates
            /// instead of surface coordinates.
            ///
            const DamageMessage = struct {
                wl_surface: WlSurface,
                /// surface-local x coordinate
                x: i32,
                /// surface-local y coordinate
                y: i32,
                /// width of damage rectangle
                width: i32,
                /// height of damage rectangle
                height: i32,
            };

            /// request a frame throttling hint
            ///
            /// Request a notification when it is a good time to start drawing a new
            /// frame, by creating a frame callback. This is useful for throttling
            /// redrawing operations, and driving animations.
            ///
            /// When a client is animating on a wl_surface, it can use the 'frame'
            /// request to get notified when it is a good time to draw and commit the
            /// next frame of animation. If the client commits an update earlier than
            /// that, it is likely that some updates will not make it to the display,
            /// and the client is wasting resources by drawing too often.
            ///
            /// The frame request will take effect on the next wl_surface.commit.
            /// The notification will only be posted for one frame unless
            /// requested again. For a wl_surface, the notifications are posted in
            /// the order the frame requests were committed.
            ///
            /// The server must send the notifications so that a client
            /// will not send excessive updates, while still allowing
            /// the highest possible update rate for clients that wait for the reply
            /// before drawing again. The server should give some time for the client
            /// to draw and commit after sending the frame callback events to let it
            /// hit the next output refresh.
            ///
            /// A server should avoid signaling the frame callbacks if the
            /// surface is not visible in any way, e.g. the surface is off-screen,
            /// or completely obscured by other opaque surfaces.
            ///
            /// The object returned by this request will be destroyed by the
            /// compositor after the callback is fired and as such the client must not
            /// attempt to use it after that point.
            ///
            /// The callback_data passed in the callback is the current time, in
            /// milliseconds, with an undefined base.
            ///
            const FrameMessage = struct {
                wl_surface: WlSurface,
                /// callback object for the frame request
                callback: u32,
            };

            /// set opaque region
            ///
            /// This request sets the region of the surface that contains
            /// opaque content.
            ///
            /// The opaque region is an optimization hint for the compositor
            /// that lets it optimize the redrawing of content behind opaque
            /// regions.  Setting an opaque region is not required for correct
            /// behaviour, but marking transparent content as opaque will result
            /// in repaint artifacts.
            ///
            /// The opaque region is specified in surface-local coordinates.
            ///
            /// The compositor ignores the parts of the opaque region that fall
            /// outside of the surface.
            ///
            /// Opaque region is double-buffered state, see wl_surface.commit.
            ///
            /// wl_surface.set_opaque_region changes the pending opaque region.
            /// wl_surface.commit copies the pending region to the current region.
            /// Otherwise, the pending and current regions are never changed.
            ///
            /// The initial value for an opaque region is empty. Setting the pending
            /// opaque region has copy semantics, and the wl_region object can be
            /// destroyed immediately. A NULL wl_region causes the pending opaque
            /// region to be set to empty.
            ///
            const SetOpaqueRegionMessage = struct {
                wl_surface: WlSurface,
                /// opaque region of the surface
                region: ?WlRegion,
            };

            /// set input region
            ///
            /// This request sets the region of the surface that can receive
            /// pointer and touch events.
            ///
            /// Input events happening outside of this region will try the next
            /// surface in the server surface stack. The compositor ignores the
            /// parts of the input region that fall outside of the surface.
            ///
            /// The input region is specified in surface-local coordinates.
            ///
            /// Input region is double-buffered state, see wl_surface.commit.
            ///
            /// wl_surface.set_input_region changes the pending input region.
            /// wl_surface.commit copies the pending region to the current region.
            /// Otherwise the pending and current regions are never changed,
            /// except cursor and icon surfaces are special cases, see
            /// wl_pointer.set_cursor and wl_data_device.start_drag.
            ///
            /// The initial value for an input region is infinite. That means the
            /// whole surface will accept input. Setting the pending input region
            /// has copy semantics, and the wl_region object can be destroyed
            /// immediately. A NULL wl_region causes the input region to be set
            /// to infinite.
            ///
            const SetInputRegionMessage = struct {
                wl_surface: WlSurface,
                /// input region of the surface
                region: ?WlRegion,
            };

            /// commit pending surface state
            ///
            /// Surface state (input, opaque, and damage regions, attached buffers,
            /// etc.) is double-buffered. Protocol requests modify the pending state,
            /// as opposed to the current state in use by the compositor. A commit
            /// request atomically applies all pending state, replacing the current
            /// state. After commit, the new pending state is as documented for each
            /// related request.
            ///
            /// On commit, a pending wl_buffer is applied first, and all other state
            /// second. This means that all coordinates in double-buffered state are
            /// relative to the new wl_buffer coming into use, except for
            /// wl_surface.attach itself. If there is no pending wl_buffer, the
            /// coordinates are relative to the current surface contents.
            ///
            /// All requests that need a commit to become effective are documented
            /// to affect double-buffered state.
            ///
            /// Other interfaces may add further double-buffered surface state.
            ///
            const CommitMessage = struct {
                wl_surface: WlSurface,
            };

            /// sets the buffer transformation
            ///
            /// This request sets an optional transformation on how the compositor
            /// interprets the contents of the buffer attached to the surface. The
            /// accepted values for the transform parameter are the values for
            /// wl_output.transform.
            ///
            /// Buffer transform is double-buffered state, see wl_surface.commit.
            ///
            /// A newly created surface has its buffer transformation set to normal.
            ///
            /// wl_surface.set_buffer_transform changes the pending buffer
            /// transformation. wl_surface.commit copies the pending buffer
            /// transformation to the current one. Otherwise, the pending and current
            /// values are never changed.
            ///
            /// The purpose of this request is to allow clients to render content
            /// according to the output transform, thus permitting the compositor to
            /// use certain optimizations even if the display is rotated. Using
            /// hardware overlays and scanning out a client buffer for fullscreen
            /// surfaces are examples of such optimizations. Those optimizations are
            /// highly dependent on the compositor implementation, so the use of this
            /// request should be considered on a case-by-case basis.
            ///
            /// Note that if the transform value includes 90 or 270 degree rotation,
            /// the width of the buffer will become the surface height and the height
            /// of the buffer will become the surface width.
            ///
            /// If transform is not one of the values from the
            /// wl_output.transform enum the invalid_transform protocol error
            /// is raised.
            ///
            const SetBufferTransformMessage = struct {
                wl_surface: WlSurface,
                /// transform for interpreting buffer contents
                transform: WlOutput.Transform,
            };

            /// sets the buffer scaling factor
            ///
            /// This request sets an optional scaling factor on how the compositor
            /// interprets the contents of the buffer attached to the window.
            ///
            /// Buffer scale is double-buffered state, see wl_surface.commit.
            ///
            /// A newly created surface has its buffer scale set to 1.
            ///
            /// wl_surface.set_buffer_scale changes the pending buffer scale.
            /// wl_surface.commit copies the pending buffer scale to the current one.
            /// Otherwise, the pending and current values are never changed.
            ///
            /// The purpose of this request is to allow clients to supply higher
            /// resolution buffer data for use on high resolution outputs. It is
            /// intended that you pick the same buffer scale as the scale of the
            /// output that the surface is displayed on. This means the compositor
            /// can avoid scaling when rendering the surface on that output.
            ///
            /// Note that if the scale is larger than 1, then you have to attach
            /// a buffer that is larger (by a factor of scale in each dimension)
            /// than the desired surface size.
            ///
            /// If scale is not positive the invalid_scale protocol error is
            /// raised.
            ///
            const SetBufferScaleMessage = struct {
                wl_surface: WlSurface,
                /// positive scale for interpreting buffer contents
                scale: i32,
            };

            /// mark part of the surface damaged using buffer coordinates
            ///
            /// This request is used to describe the regions where the pending
            /// buffer is different from the current surface contents, and where
            /// the surface therefore needs to be repainted. The compositor
            /// ignores the parts of the damage that fall outside of the surface.
            ///
            /// Damage is double-buffered state, see wl_surface.commit.
            ///
            /// The damage rectangle is specified in buffer coordinates,
            /// where x and y specify the upper left corner of the damage rectangle.
            ///
            /// The initial value for pending damage is empty: no damage.
            /// wl_surface.damage_buffer adds pending damage: the new pending
            /// damage is the union of old pending damage and the given rectangle.
            ///
            /// wl_surface.commit assigns pending damage as the current damage,
            /// and clears pending damage. The server will clear the current
            /// damage as it repaints the surface.
            ///
            /// This request differs from wl_surface.damage in only one way - it
            /// takes damage in buffer coordinates instead of surface-local
            /// coordinates. While this generally is more intuitive than surface
            /// coordinates, it is especially desirable when using wp_viewport
            /// or when a drawing library (like EGL) is unaware of buffer scale
            /// and buffer transform.
            ///
            /// Note: Because buffer transformation changes and damage requests may
            /// be interleaved in the protocol stream, it is impossible to determine
            /// the actual mapping between surface and buffer damage until
            /// wl_surface.commit time. Therefore, compositors wishing to take both
            /// kinds of damage into account will have to accumulate damage from the
            /// two requests separately and only transform from one to the other
            /// after receiving the wl_surface.commit.
            ///
            const DamageBufferMessage = struct {
                wl_surface: WlSurface,
                /// buffer-local x coordinate
                x: i32,
                /// buffer-local y coordinate
                y: i32,
                /// width of damage rectangle
                width: i32,
                /// height of damage rectangle
                height: i32,
            };

            /// set the surface contents offset
            ///
            /// The x and y arguments specify the location of the new pending
            /// buffer's upper left corner, relative to the current buffer's upper
            /// left corner, in surface-local coordinates. In other words, the
            /// x and y, combined with the new surface size define in which
            /// directions the surface's size changes.
            ///
            /// Surface location offset is double-buffered state, see
            /// wl_surface.commit.
            ///
            /// This request is semantically equivalent to and the replaces the x and y
            /// arguments in the wl_surface.attach request in wl_surface versions prior
            /// to 5. See wl_surface.attach for details.
            ///
            const OffsetMessage = struct {
                wl_surface: WlSurface,
                /// surface-local x coordinate
                x: i32,
                /// surface-local y coordinate
                y: i32,
            };

            //
            // This is emitted whenever a surface's creation, movement, or resizing
            // results in some part of it being within the scanout region of an
            // output.
            //
            // Note that a surface may be overlapping with zero or more outputs.
            //
            pub fn sendEnter(self: Self, output: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(output);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // This is emitted whenever a surface's creation, movement, or resizing
            // results in it no longer having any part of it within the scanout region
            // of an output.
            //
            // Clients should not use the number of outputs the surface is on for frame
            // throttling purposes. The surface might be hidden even if no leave event
            // has been sent, and the compositor might expect new surface content
            // updates even if no enter event has been sent. The frame event should be
            // used instead.
            //
            pub fn sendLeave(self: Self, output: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(output);
                try self.wire.finishWrite(self.id, 1);
            }
        };

        /// wl_seat
        /// group of input devices
        ///
        /// A seat is a group of keyboards, pointer and touch devices. This
        /// object is published as a global during start up, or when such a
        /// device is hot plugged.  A seat typically has a pointer and
        /// maintains a keyboard focus and a pointer focus.
        ///
        pub const WlSeat = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_seat,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_seat) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Capability = packed struct(u32) { // bitfield
                pointer: bool = false, // 1
                keyboard: bool = false, // 2
                touch: bool = false, // 4
                _padding: u29 = 0,
            };

            pub const Error = enum(u32) {
                missing_capability = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // get_pointer
                    0 => {
                        const id: u32 = try self.wire.nextU32();
                        return Message{
                            .get_pointer = GetPointerMessage{
                                .wl_seat = self.*,
                                .id = id,
                            },
                        };
                    },
                    // get_keyboard
                    1 => {
                        const id: u32 = try self.wire.nextU32();
                        return Message{
                            .get_keyboard = GetKeyboardMessage{
                                .wl_seat = self.*,
                                .id = id,
                            },
                        };
                    },
                    // get_touch
                    2 => {
                        const id: u32 = try self.wire.nextU32();
                        return Message{
                            .get_touch = GetTouchMessage{
                                .wl_seat = self.*,
                                .id = id,
                            },
                        };
                    },
                    // release
                    3 => {
                        return Message{
                            .release = ReleaseMessage{
                                .wl_seat = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                get_pointer,
                get_keyboard,
                get_touch,
                release,
            };

            pub const Message = union(MessageType) {
                /// return pointer object
                ///
                /// The ID provided will be initialized to the wl_pointer interface
                /// for this seat.
                ///
                /// This request only takes effect if the seat has the pointer
                /// capability, or has had the pointer capability in the past.
                /// It is a protocol violation to issue this request on a seat that has
                /// never had the pointer capability. The missing_capability error will
                /// be sent in this case.
                ///
                get_pointer: GetPointerMessage,

                /// return keyboard object
                ///
                /// The ID provided will be initialized to the wl_keyboard interface
                /// for this seat.
                ///
                /// This request only takes effect if the seat has the keyboard
                /// capability, or has had the keyboard capability in the past.
                /// It is a protocol violation to issue this request on a seat that has
                /// never had the keyboard capability. The missing_capability error will
                /// be sent in this case.
                ///
                get_keyboard: GetKeyboardMessage,

                /// return touch object
                ///
                /// The ID provided will be initialized to the wl_touch interface
                /// for this seat.
                ///
                /// This request only takes effect if the seat has the touch
                /// capability, or has had the touch capability in the past.
                /// It is a protocol violation to issue this request on a seat that has
                /// never had the touch capability. The missing_capability error will
                /// be sent in this case.
                ///
                get_touch: GetTouchMessage,

                /// release the seat object
                ///
                /// Using this request a client can tell the server that it is not going to
                /// use the seat object anymore.
                ///
                release: ReleaseMessage,
            };

            /// return pointer object
            ///
            /// The ID provided will be initialized to the wl_pointer interface
            /// for this seat.
            ///
            /// This request only takes effect if the seat has the pointer
            /// capability, or has had the pointer capability in the past.
            /// It is a protocol violation to issue this request on a seat that has
            /// never had the pointer capability. The missing_capability error will
            /// be sent in this case.
            ///
            const GetPointerMessage = struct {
                wl_seat: WlSeat,
                /// seat pointer
                id: u32,
            };

            /// return keyboard object
            ///
            /// The ID provided will be initialized to the wl_keyboard interface
            /// for this seat.
            ///
            /// This request only takes effect if the seat has the keyboard
            /// capability, or has had the keyboard capability in the past.
            /// It is a protocol violation to issue this request on a seat that has
            /// never had the keyboard capability. The missing_capability error will
            /// be sent in this case.
            ///
            const GetKeyboardMessage = struct {
                wl_seat: WlSeat,
                /// seat keyboard
                id: u32,
            };

            /// return touch object
            ///
            /// The ID provided will be initialized to the wl_touch interface
            /// for this seat.
            ///
            /// This request only takes effect if the seat has the touch
            /// capability, or has had the touch capability in the past.
            /// It is a protocol violation to issue this request on a seat that has
            /// never had the touch capability. The missing_capability error will
            /// be sent in this case.
            ///
            const GetTouchMessage = struct {
                wl_seat: WlSeat,
                /// seat touch interface
                id: u32,
            };

            /// release the seat object
            ///
            /// Using this request a client can tell the server that it is not going to
            /// use the seat object anymore.
            ///
            const ReleaseMessage = struct {
                wl_seat: WlSeat,
            };

            //
            // This is emitted whenever a seat gains or loses the pointer,
            // keyboard or touch capabilities.  The argument is a capability
            // enum containing the complete set of capabilities this seat has.
            //
            // When the pointer capability is added, a client may create a
            // wl_pointer object using the wl_seat.get_pointer request. This object
            // will receive pointer events until the capability is removed in the
            // future.
            //
            // When the pointer capability is removed, a client should destroy the
            // wl_pointer objects associated with the seat where the capability was
            // removed, using the wl_pointer.release request. No further pointer
            // events will be received on these objects.
            //
            // In some compositors, if a seat regains the pointer capability and a
            // client has a previously obtained wl_pointer object of version 4 or
            // less, that object may start sending pointer events again. This
            // behavior is considered a misinterpretation of the intended behavior
            // and must not be relied upon by the client. wl_pointer objects of
            // version 5 or later must not send events if created before the most
            // recent event notifying the client of an added pointer capability.
            //
            // The above behavior also applies to wl_keyboard and wl_touch with the
            // keyboard and touch capabilities, respectively.
            //
            pub fn sendCapabilities(self: Self, capabilities: Capability) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@bitCast(capabilities)); // bitfield
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // In a multi-seat configuration the seat name can be used by clients to
            // help identify which physical devices the seat represents.
            //
            // The seat name is a UTF-8 string with no convention defined for its
            // contents. Each name is unique among all wl_seat globals. The name is
            // only guaranteed to be unique for the current compositor instance.
            //
            // The same seat names are used for all clients. Thus, the name can be
            // shared across processes to refer to a specific wl_seat global.
            //
            // The name event is sent after binding to the seat global. This event is
            // only sent once per seat object, and the name does not change over the
            // lifetime of the wl_seat global.
            //
            // Compositors may re-use the same seat name if the wl_seat global is
            // destroyed and re-created later.
            //
            pub fn sendName(self: Self, name: []const u8) !void {
                try self.wire.startWrite();
                try self.wire.putString(name);
                try self.wire.finishWrite(self.id, 1);
            }
        };

        /// wl_pointer
        /// pointer input device
        ///
        /// The wl_pointer interface represents one or more input devices,
        /// such as mice, which control the pointer location and pointer_focus
        /// of a seat.
        ///
        /// The wl_pointer interface generates motion, enter and leave
        /// events for the surfaces that the pointer is located over,
        /// and button and axis events for button presses, button releases
        /// and scrolling.
        ///
        pub const WlPointer = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_pointer,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_pointer) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                role = 0,
            };

            pub const ButtonState = enum(u32) {
                released = 0,
                pressed = 1,
            };

            pub const Axis = enum(u32) {
                vertical_scroll = 0,
                horizontal_scroll = 1,
            };

            pub const AxisSource = enum(u32) {
                wheel = 0,
                finger = 1,
                continuous = 2,
                wheel_tilt = 3,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // set_cursor
                    0 => {
                        const serial: u32 = try self.wire.nextU32();
                        const surface: ?WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        const hotspot_x: i32 = try self.wire.nextI32();
                        const hotspot_y: i32 = try self.wire.nextI32();
                        return Message{
                            .set_cursor = SetCursorMessage{
                                .wl_pointer = self.*,
                                .serial = serial,
                                .surface = surface,
                                .hotspot_x = hotspot_x,
                                .hotspot_y = hotspot_y,
                            },
                        };
                    },
                    // release
                    1 => {
                        return Message{
                            .release = ReleaseMessage{
                                .wl_pointer = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                set_cursor,
                release,
            };

            pub const Message = union(MessageType) {
                /// set the pointer surface
                ///
                /// Set the pointer surface, i.e., the surface that contains the
                /// pointer image (cursor). This request gives the surface the role
                /// of a cursor. If the surface already has another role, it raises
                /// a protocol error.
                ///
                /// The cursor actually changes only if the pointer
                /// focus for this device is one of the requesting client's surfaces
                /// or the surface parameter is the current pointer surface. If
                /// there was a previous surface set with this request it is
                /// replaced. If surface is NULL, the pointer image is hidden.
                ///
                /// The parameters hotspot_x and hotspot_y define the position of
                /// the pointer surface relative to the pointer location. Its
                /// top-left corner is always at (x, y) - (hotspot_x, hotspot_y),
                /// where (x, y) are the coordinates of the pointer location, in
                /// surface-local coordinates.
                ///
                /// On surface.attach requests to the pointer surface, hotspot_x
                /// and hotspot_y are decremented by the x and y parameters
                /// passed to the request. Attach must be confirmed by
                /// wl_surface.commit as usual.
                ///
                /// The hotspot can also be updated by passing the currently set
                /// pointer surface to this request with new values for hotspot_x
                /// and hotspot_y.
                ///
                /// The current and pending input regions of the wl_surface are
                /// cleared, and wl_surface.set_input_region is ignored until the
                /// wl_surface is no longer used as the cursor. When the use as a
                /// cursor ends, the current and pending input regions become
                /// undefined, and the wl_surface is unmapped.
                ///
                /// The serial parameter must match the latest wl_pointer.enter
                /// serial number sent to the client. Otherwise the request will be
                /// ignored.
                ///
                set_cursor: SetCursorMessage,

                /// release the pointer object
                ///
                /// Using this request a client can tell the server that it is not going to
                /// use the pointer object anymore.
                ///
                /// This request destroys the pointer proxy object, so clients must not call
                /// wl_pointer_destroy() after using this request.
                ///
                release: ReleaseMessage,
            };

            /// set the pointer surface
            ///
            /// Set the pointer surface, i.e., the surface that contains the
            /// pointer image (cursor). This request gives the surface the role
            /// of a cursor. If the surface already has another role, it raises
            /// a protocol error.
            ///
            /// The cursor actually changes only if the pointer
            /// focus for this device is one of the requesting client's surfaces
            /// or the surface parameter is the current pointer surface. If
            /// there was a previous surface set with this request it is
            /// replaced. If surface is NULL, the pointer image is hidden.
            ///
            /// The parameters hotspot_x and hotspot_y define the position of
            /// the pointer surface relative to the pointer location. Its
            /// top-left corner is always at (x, y) - (hotspot_x, hotspot_y),
            /// where (x, y) are the coordinates of the pointer location, in
            /// surface-local coordinates.
            ///
            /// On surface.attach requests to the pointer surface, hotspot_x
            /// and hotspot_y are decremented by the x and y parameters
            /// passed to the request. Attach must be confirmed by
            /// wl_surface.commit as usual.
            ///
            /// The hotspot can also be updated by passing the currently set
            /// pointer surface to this request with new values for hotspot_x
            /// and hotspot_y.
            ///
            /// The current and pending input regions of the wl_surface are
            /// cleared, and wl_surface.set_input_region is ignored until the
            /// wl_surface is no longer used as the cursor. When the use as a
            /// cursor ends, the current and pending input regions become
            /// undefined, and the wl_surface is unmapped.
            ///
            /// The serial parameter must match the latest wl_pointer.enter
            /// serial number sent to the client. Otherwise the request will be
            /// ignored.
            ///
            const SetCursorMessage = struct {
                wl_pointer: WlPointer,
                /// serial number of the enter event
                serial: u32,
                /// pointer surface
                surface: ?WlSurface,
                /// surface-local x coordinate
                hotspot_x: i32,
                /// surface-local y coordinate
                hotspot_y: i32,
            };

            /// release the pointer object
            ///
            /// Using this request a client can tell the server that it is not going to
            /// use the pointer object anymore.
            ///
            /// This request destroys the pointer proxy object, so clients must not call
            /// wl_pointer_destroy() after using this request.
            ///
            const ReleaseMessage = struct {
                wl_pointer: WlPointer,
            };

            //
            // Notification that this seat's pointer is focused on a certain
            // surface.
            //
            // When a seat's focus enters a surface, the pointer image
            // is undefined and a client should respond to this event by setting
            // an appropriate pointer image with the set_cursor request.
            //
            pub fn sendEnter(self: Self, serial: u32, surface: u32, surface_x: f32, surface_y: f32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.putU32(surface);
                try self.wire.putFixed(surface_x);
                try self.wire.putFixed(surface_y);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // Notification that this seat's pointer is no longer focused on
            // a certain surface.
            //
            // The leave notification is sent before the enter notification
            // for the new focus.
            //
            pub fn sendLeave(self: Self, serial: u32, surface: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.putU32(surface);
                try self.wire.finishWrite(self.id, 1);
            }

            //
            // Notification of pointer location change. The arguments
            // surface_x and surface_y are the location relative to the
            // focused surface.
            //
            pub fn sendMotion(self: Self, time: u32, surface_x: f32, surface_y: f32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(time);
                try self.wire.putFixed(surface_x);
                try self.wire.putFixed(surface_y);
                try self.wire.finishWrite(self.id, 2);
            }

            //
            // Mouse button click and release notifications.
            //
            // The location of the click is given by the last motion or
            // enter event.
            // The time argument is a timestamp with millisecond
            // granularity, with an undefined base.
            //
            // The button is a button code as defined in the Linux kernel's
            // linux/input-event-codes.h header file, e.g. BTN_LEFT.
            //
            // Any 16-bit button code value is reserved for future additions to the
            // kernel's event code list. All other button codes above 0xFFFF are
            // currently undefined but may be used in future versions of this
            // protocol.
            //
            pub fn sendButton(self: Self, serial: u32, time: u32, button: u32, state: ButtonState) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.putU32(time);
                try self.wire.putU32(button);
                try self.wire.putU32(@intFromEnum(state)); // enum
                try self.wire.finishWrite(self.id, 3);
            }

            //
            // Scroll and other axis notifications.
            //
            // For scroll events (vertical and horizontal scroll axes), the
            // value parameter is the length of a vector along the specified
            // axis in a coordinate space identical to those of motion events,
            // representing a relative movement along the specified axis.
            //
            // For devices that support movements non-parallel to axes multiple
            // axis events will be emitted.
            //
            // When applicable, for example for touch pads, the server can
            // choose to emit scroll events where the motion vector is
            // equivalent to a motion event vector.
            //
            // When applicable, a client can transform its content relative to the
            // scroll distance.
            //
            pub fn sendAxis(self: Self, time: u32, axis: Axis, value: f32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(time);
                try self.wire.putU32(@intFromEnum(axis)); // enum
                try self.wire.putFixed(value);
                try self.wire.finishWrite(self.id, 4);
            }

            //
            // Indicates the end of a set of events that logically belong together.
            // A client is expected to accumulate the data in all events within the
            // frame before proceeding.
            //
            // All wl_pointer events before a wl_pointer.frame event belong
            // logically together. For example, in a diagonal scroll motion the
            // compositor will send an optional wl_pointer.axis_source event, two
            // wl_pointer.axis events (horizontal and vertical) and finally a
            // wl_pointer.frame event. The client may use this information to
            // calculate a diagonal vector for scrolling.
            //
            // When multiple wl_pointer.axis events occur within the same frame,
            // the motion vector is the combined motion of all events.
            // When a wl_pointer.axis and a wl_pointer.axis_stop event occur within
            // the same frame, this indicates that axis movement in one axis has
            // stopped but continues in the other axis.
            // When multiple wl_pointer.axis_stop events occur within the same
            // frame, this indicates that these axes stopped in the same instance.
            //
            // A wl_pointer.frame event is sent for every logical event group,
            // even if the group only contains a single wl_pointer event.
            // Specifically, a client may get a sequence: motion, frame, button,
            // frame, axis, frame, axis_stop, frame.
            //
            // The wl_pointer.enter and wl_pointer.leave events are logical events
            // generated by the compositor and not the hardware. These events are
            // also grouped by a wl_pointer.frame. When a pointer moves from one
            // surface to another, a compositor should group the
            // wl_pointer.leave event within the same wl_pointer.frame.
            // However, a client must not rely on wl_pointer.leave and
            // wl_pointer.enter being in the same wl_pointer.frame.
            // Compositor-specific policies may require the wl_pointer.leave and
            // wl_pointer.enter event being split across multiple wl_pointer.frame
            // groups.
            //
            pub fn sendFrame(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 5);
            }

            //
            // Source information for scroll and other axes.
            //
            // This event does not occur on its own. It is sent before a
            // wl_pointer.frame event and carries the source information for
            // all events within that frame.
            //
            // The source specifies how this event was generated. If the source is
            // wl_pointer.axis_source.finger, a wl_pointer.axis_stop event will be
            // sent when the user lifts the finger off the device.
            //
            // If the source is wl_pointer.axis_source.wheel,
            // wl_pointer.axis_source.wheel_tilt or
            // wl_pointer.axis_source.continuous, a wl_pointer.axis_stop event may
            // or may not be sent. Whether a compositor sends an axis_stop event
            // for these sources is hardware-specific and implementation-dependent;
            // clients must not rely on receiving an axis_stop event for these
            // scroll sources and should treat scroll sequences from these scroll
            // sources as unterminated by default.
            //
            // This event is optional. If the source is unknown for a particular
            // axis event sequence, no event is sent.
            // Only one wl_pointer.axis_source event is permitted per frame.
            //
            // The order of wl_pointer.axis_discrete and wl_pointer.axis_source is
            // not guaranteed.
            //
            pub fn sendAxisSource(self: Self, axis_source: AxisSource) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@intFromEnum(axis_source)); // enum
                try self.wire.finishWrite(self.id, 6);
            }

            //
            // Stop notification for scroll and other axes.
            //
            // For some wl_pointer.axis_source types, a wl_pointer.axis_stop event
            // is sent to notify a client that the axis sequence has terminated.
            // This enables the client to implement kinetic scrolling.
            // See the wl_pointer.axis_source documentation for information on when
            // this event may be generated.
            //
            // Any wl_pointer.axis events with the same axis_source after this
            // event should be considered as the start of a new axis motion.
            //
            // The timestamp is to be interpreted identical to the timestamp in the
            // wl_pointer.axis event. The timestamp value may be the same as a
            // preceding wl_pointer.axis event.
            //
            pub fn sendAxisStop(self: Self, time: u32, axis: Axis) !void {
                try self.wire.startWrite();
                try self.wire.putU32(time);
                try self.wire.putU32(@intFromEnum(axis)); // enum
                try self.wire.finishWrite(self.id, 7);
            }

            //
            // Discrete step information for scroll and other axes.
            //
            // This event carries the axis value of the wl_pointer.axis event in
            // discrete steps (e.g. mouse wheel clicks).
            //
            // This event does not occur on its own, it is coupled with a
            // wl_pointer.axis event that represents this axis value on a
            // continuous scale. The protocol guarantees that each axis_discrete
            // event is always followed by exactly one axis event with the same
            // axis number within the same wl_pointer.frame. Note that the protocol
            // allows for other events to occur between the axis_discrete and
            // its coupled axis event, including other axis_discrete or axis
            // events.
            //
            // This event is optional; continuous scrolling devices
            // like two-finger scrolling on touchpads do not have discrete
            // steps and do not generate this event.
            //
            // The discrete value carries the directional information. e.g. a value
            // of -2 is two steps towards the negative direction of this axis.
            //
            // The axis number is identical to the axis number in the associated
            // axis event.
            //
            // The order of wl_pointer.axis_discrete and wl_pointer.axis_source is
            // not guaranteed.
            //
            pub fn sendAxisDiscrete(self: Self, axis: Axis, discrete: i32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@intFromEnum(axis)); // enum
                try self.wire.putI32(discrete);
                try self.wire.finishWrite(self.id, 8);
            }
        };

        /// wl_keyboard
        /// keyboard input device
        ///
        /// The wl_keyboard interface represents one or more keyboards
        /// associated with a seat.
        ///
        pub const WlKeyboard = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_keyboard,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_keyboard) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const KeymapFormat = enum(u32) {
                no_keymap = 0,
                xkb_v1 = 1,
            };

            pub const KeyState = enum(u32) {
                released = 0,
                pressed = 1,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // release
                    0 => {
                        return Message{
                            .release = ReleaseMessage{
                                .wl_keyboard = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                release,
            };

            pub const Message = union(MessageType) {
                /// release the keyboard object
                release: ReleaseMessage,
            };

            /// release the keyboard object
            const ReleaseMessage = struct {
                wl_keyboard: WlKeyboard,
            };

            //
            // This event provides a file descriptor to the client which can be
            // memory-mapped in read-only mode to provide a keyboard mapping
            // description.
            //
            // From version 7 onwards, the fd must be mapped with MAP_PRIVATE by
            // the recipient, as MAP_SHARED may fail.
            //
            pub fn sendKeymap(self: Self, format: KeymapFormat, fd: i32, size: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@intFromEnum(format)); // enum
                try self.wire.putFd(fd);
                try self.wire.putU32(size);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // Notification that this seat's keyboard focus is on a certain
            // surface.
            //
            // The compositor must send the wl_keyboard.modifiers event after this
            // event.
            //
            pub fn sendEnter(self: Self, serial: u32, surface: u32, keys: []u8) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.putU32(surface);
                try self.wire.putArray(keys);
                try self.wire.finishWrite(self.id, 1);
            }

            //
            // Notification that this seat's keyboard focus is no longer on
            // a certain surface.
            //
            // The leave notification is sent before the enter notification
            // for the new focus.
            //
            // After this event client must assume that all keys, including modifiers,
            // are lifted and also it must stop key repeating if there's some going on.
            //
            pub fn sendLeave(self: Self, serial: u32, surface: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.putU32(surface);
                try self.wire.finishWrite(self.id, 2);
            }

            //
            // A key was pressed or released.
            // The time argument is a timestamp with millisecond
            // granularity, with an undefined base.
            //
            // The key is a platform-specific key code that can be interpreted
            // by feeding it to the keyboard mapping (see the keymap event).
            //
            // If this event produces a change in modifiers, then the resulting
            // wl_keyboard.modifiers event must be sent after this event.
            //
            pub fn sendKey(self: Self, serial: u32, time: u32, key: u32, state: KeyState) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.putU32(time);
                try self.wire.putU32(key);
                try self.wire.putU32(@intFromEnum(state)); // enum
                try self.wire.finishWrite(self.id, 3);
            }

            //
            // Notifies clients that the modifier and/or group state has
            // changed, and it should update its local state.
            //
            pub fn sendModifiers(self: Self, serial: u32, mods_depressed: u32, mods_latched: u32, mods_locked: u32, group: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.putU32(mods_depressed);
                try self.wire.putU32(mods_latched);
                try self.wire.putU32(mods_locked);
                try self.wire.putU32(group);
                try self.wire.finishWrite(self.id, 4);
            }

            //
            // Informs the client about the keyboard's repeat rate and delay.
            //
            // This event is sent as soon as the wl_keyboard object has been created,
            // and is guaranteed to be received by the client before any key press
            // event.
            //
            // Negative values for either rate or delay are illegal. A rate of zero
            // will disable any repeating (regardless of the value of delay).
            //
            // This event can be sent later on as well with a new value if necessary,
            // so clients should continue listening for the event past the creation
            // of wl_keyboard.
            //
            pub fn sendRepeatInfo(self: Self, rate: i32, delay: i32) !void {
                try self.wire.startWrite();
                try self.wire.putI32(rate);
                try self.wire.putI32(delay);
                try self.wire.finishWrite(self.id, 5);
            }
        };

        /// wl_touch
        /// touchscreen input device
        ///
        /// The wl_touch interface represents a touchscreen
        /// associated with a seat.
        ///
        /// Touch interactions can consist of one or more contacts.
        /// For each contact, a series of events is generated, starting
        /// with a down event, followed by zero or more motion events,
        /// and ending with an up event. Events relating to the same
        /// contact point can be identified by the ID of the sequence.
        ///
        pub const WlTouch = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_touch,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_touch) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // release
                    0 => {
                        return Message{
                            .release = ReleaseMessage{
                                .wl_touch = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                release,
            };

            pub const Message = union(MessageType) {
                /// release the touch object
                release: ReleaseMessage,
            };

            /// release the touch object
            const ReleaseMessage = struct {
                wl_touch: WlTouch,
            };

            //
            // A new touch point has appeared on the surface. This touch point is
            // assigned a unique ID. Future events from this touch point reference
            // this ID. The ID ceases to be valid after a touch up event and may be
            // reused in the future.
            //
            pub fn sendDown(self: Self, serial: u32, time: u32, surface: u32, id: i32, x: f32, y: f32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.putU32(time);
                try self.wire.putU32(surface);
                try self.wire.putI32(id);
                try self.wire.putFixed(x);
                try self.wire.putFixed(y);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // The touch point has disappeared. No further events will be sent for
            // this touch point and the touch point's ID is released and may be
            // reused in a future touch down event.
            //
            pub fn sendUp(self: Self, serial: u32, time: u32, id: i32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.putU32(time);
                try self.wire.putI32(id);
                try self.wire.finishWrite(self.id, 1);
            }

            //
            // A touch point has changed coordinates.
            //
            pub fn sendMotion(self: Self, time: u32, id: i32, x: f32, y: f32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(time);
                try self.wire.putI32(id);
                try self.wire.putFixed(x);
                try self.wire.putFixed(y);
                try self.wire.finishWrite(self.id, 2);
            }

            //
            // Indicates the end of a set of events that logically belong together.
            // A client is expected to accumulate the data in all events within the
            // frame before proceeding.
            //
            // A wl_touch.frame terminates at least one event but otherwise no
            // guarantee is provided about the set of events within a frame. A client
            // must assume that any state not updated in a frame is unchanged from the
            // previously known state.
            //
            pub fn sendFrame(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 3);
            }

            //
            // Sent if the compositor decides the touch stream is a global
            // gesture. No further events are sent to the clients from that
            // particular gesture. Touch cancellation applies to all touch points
            // currently active on this client's surface. The client is
            // responsible for finalizing the touch points, future touch points on
            // this surface may reuse the touch point ID.
            //
            pub fn sendCancel(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 4);
            }

            //
            // Sent when a touchpoint has changed its shape.
            //
            // This event does not occur on its own. It is sent before a
            // wl_touch.frame event and carries the new shape information for
            // any previously reported, or new touch points of that frame.
            //
            // Other events describing the touch point such as wl_touch.down,
            // wl_touch.motion or wl_touch.orientation may be sent within the
            // same wl_touch.frame. A client should treat these events as a single
            // logical touch point update. The order of wl_touch.shape,
            // wl_touch.orientation and wl_touch.motion is not guaranteed.
            // A wl_touch.down event is guaranteed to occur before the first
            // wl_touch.shape event for this touch ID but both events may occur within
            // the same wl_touch.frame.
            //
            // A touchpoint shape is approximated by an ellipse through the major and
            // minor axis length. The major axis length describes the longer diameter
            // of the ellipse, while the minor axis length describes the shorter
            // diameter. Major and minor are orthogonal and both are specified in
            // surface-local coordinates. The center of the ellipse is always at the
            // touchpoint location as reported by wl_touch.down or wl_touch.move.
            //
            // This event is only sent by the compositor if the touch device supports
            // shape reports. The client has to make reasonable assumptions about the
            // shape if it did not receive this event.
            //
            pub fn sendShape(self: Self, id: i32, major: f32, minor: f32) !void {
                try self.wire.startWrite();
                try self.wire.putI32(id);
                try self.wire.putFixed(major);
                try self.wire.putFixed(minor);
                try self.wire.finishWrite(self.id, 5);
            }

            //
            // Sent when a touchpoint has changed its orientation.
            //
            // This event does not occur on its own. It is sent before a
            // wl_touch.frame event and carries the new shape information for
            // any previously reported, or new touch points of that frame.
            //
            // Other events describing the touch point such as wl_touch.down,
            // wl_touch.motion or wl_touch.shape may be sent within the
            // same wl_touch.frame. A client should treat these events as a single
            // logical touch point update. The order of wl_touch.shape,
            // wl_touch.orientation and wl_touch.motion is not guaranteed.
            // A wl_touch.down event is guaranteed to occur before the first
            // wl_touch.orientation event for this touch ID but both events may occur
            // within the same wl_touch.frame.
            //
            // The orientation describes the clockwise angle of a touchpoint's major
            // axis to the positive surface y-axis and is normalized to the -180 to
            // +180 degree range. The granularity of orientation depends on the touch
            // device, some devices only support binary rotation values between 0 and
            // 90 degrees.
            //
            // This event is only sent by the compositor if the touch device supports
            // orientation reports.
            //
            pub fn sendOrientation(self: Self, id: i32, orientation: f32) !void {
                try self.wire.startWrite();
                try self.wire.putI32(id);
                try self.wire.putFixed(orientation);
                try self.wire.finishWrite(self.id, 6);
            }
        };

        /// wl_output
        /// compositor output region
        ///
        /// An output describes part of the compositor geometry.  The
        /// compositor works in the 'compositor coordinate system' and an
        /// output corresponds to a rectangular area in that space that is
        /// actually visible.  This typically corresponds to a monitor that
        /// displays part of the compositor space.  This object is published
        /// as global during start up, or when a monitor is hotplugged.
        ///
        pub const WlOutput = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_output,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_output) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Subpixel = enum(u32) {
                unknown = 0,
                none = 1,
                horizontal_rgb = 2,
                horizontal_bgr = 3,
                vertical_rgb = 4,
                vertical_bgr = 5,
            };

            pub const Transform = enum(u32) {
                normal = 0,
                @"90" = 1,
                @"180" = 2,
                @"270" = 3,
                flipped = 4,
                flipped_90 = 5,
                flipped_180 = 6,
                flipped_270 = 7,
            };

            pub const Mode = packed struct(u32) { // bitfield
                current: bool = false, // 1
                preferred: bool = false, // 2
                _padding: u30 = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // release
                    0 => {
                        return Message{
                            .release = ReleaseMessage{
                                .wl_output = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                release,
            };

            pub const Message = union(MessageType) {
                /// release the output object
                ///
                /// Using this request a client can tell the server that it is not going to
                /// use the output object anymore.
                ///
                release: ReleaseMessage,
            };

            /// release the output object
            ///
            /// Using this request a client can tell the server that it is not going to
            /// use the output object anymore.
            ///
            const ReleaseMessage = struct {
                wl_output: WlOutput,
            };

            //
            // The geometry event describes geometric properties of the output.
            // The event is sent when binding to the output object and whenever
            // any of the properties change.
            //
            // The physical size can be set to zero if it doesn't make sense for this
            // output (e.g. for projectors or virtual outputs).
            //
            // The geometry event will be followed by a done event (starting from
            // version 2).
            //
            // Note: wl_output only advertises partial information about the output
            // position and identification. Some compositors, for instance those not
            // implementing a desktop-style output layout or those exposing virtual
            // outputs, might fake this information. Instead of using x and y, clients
            // should use xdg_output.logical_position. Instead of using make and model,
            // clients should use name and description.
            //
            pub fn sendGeometry(self: Self, x: i32, y: i32, physical_width: i32, physical_height: i32, subpixel: Subpixel, make: []const u8, model: []const u8, transform: Transform) !void {
                try self.wire.startWrite();
                try self.wire.putI32(x);
                try self.wire.putI32(y);
                try self.wire.putI32(physical_width);
                try self.wire.putI32(physical_height);
                try self.wire.putU32(@intFromEnum(subpixel)); // enum
                try self.wire.putString(make);
                try self.wire.putString(model);
                try self.wire.putU32(@intFromEnum(transform)); // enum
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // The mode event describes an available mode for the output.
            //
            // The event is sent when binding to the output object and there
            // will always be one mode, the current mode.  The event is sent
            // again if an output changes mode, for the mode that is now
            // current.  In other words, the current mode is always the last
            // mode that was received with the current flag set.
            //
            // Non-current modes are deprecated. A compositor can decide to only
            // advertise the current mode and never send other modes. Clients
            // should not rely on non-current modes.
            //
            // The size of a mode is given in physical hardware units of
            // the output device. This is not necessarily the same as
            // the output size in the global compositor space. For instance,
            // the output may be scaled, as described in wl_output.scale,
            // or transformed, as described in wl_output.transform. Clients
            // willing to retrieve the output size in the global compositor
            // space should use xdg_output.logical_size instead.
            //
            // The vertical refresh rate can be set to zero if it doesn't make
            // sense for this output (e.g. for virtual outputs).
            //
            // The mode event will be followed by a done event (starting from
            // version 2).
            //
            // Clients should not use the refresh rate to schedule frames. Instead,
            // they should use the wl_surface.frame event or the presentation-time
            // protocol.
            //
            // Note: this information is not always meaningful for all outputs. Some
            // compositors, such as those exposing virtual outputs, might fake the
            // refresh rate or the size.
            //
            pub fn sendMode(self: Self, flags: Mode, width: i32, height: i32, refresh: i32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@bitCast(flags)); // bitfield
                try self.wire.putI32(width);
                try self.wire.putI32(height);
                try self.wire.putI32(refresh);
                try self.wire.finishWrite(self.id, 1);
            }

            //
            // This event is sent after all other properties have been
            // sent after binding to the output object and after any
            // other property changes done after that. This allows
            // changes to the output properties to be seen as
            // atomic, even if they happen via multiple events.
            //
            pub fn sendDone(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 2);
            }

            //
            // This event contains scaling geometry information
            // that is not in the geometry event. It may be sent after
            // binding the output object or if the output scale changes
            // later. If it is not sent, the client should assume a
            // scale of 1.
            //
            // A scale larger than 1 means that the compositor will
            // automatically scale surface buffers by this amount
            // when rendering. This is used for very high resolution
            // displays where applications rendering at the native
            // resolution would be too small to be legible.
            //
            // It is intended that scaling aware clients track the
            // current output of a surface, and if it is on a scaled
            // output it should use wl_surface.set_buffer_scale with
            // the scale of the output. That way the compositor can
            // avoid scaling the surface, and the client can supply
            // a higher detail image.
            //
            // The scale event will be followed by a done event.
            //
            pub fn sendScale(self: Self, factor: i32) !void {
                try self.wire.startWrite();
                try self.wire.putI32(factor);
                try self.wire.finishWrite(self.id, 3);
            }

            //
            // Many compositors will assign user-friendly names to their outputs, show
            // them to the user, allow the user to refer to an output, etc. The client
            // may wish to know this name as well to offer the user similar behaviors.
            //
            // The name is a UTF-8 string with no convention defined for its contents.
            // Each name is unique among all wl_output globals. The name is only
            // guaranteed to be unique for the compositor instance.
            //
            // The same output name is used for all clients for a given wl_output
            // global. Thus, the name can be shared across processes to refer to a
            // specific wl_output global.
            //
            // The name is not guaranteed to be persistent across sessions, thus cannot
            // be used to reliably identify an output in e.g. configuration files.
            //
            // Examples of names include 'HDMI-A-1', 'WL-1', 'X11-1', etc. However, do
            // not assume that the name is a reflection of an underlying DRM connector,
            // X11 connection, etc.
            //
            // The name event is sent after binding the output object. This event is
            // only sent once per output object, and the name does not change over the
            // lifetime of the wl_output global.
            //
            // Compositors may re-use the same output name if the wl_output global is
            // destroyed and re-created later. Compositors should avoid re-using the
            // same name if possible.
            //
            // The name event will be followed by a done event.
            //
            pub fn sendName(self: Self, name: []const u8) !void {
                try self.wire.startWrite();
                try self.wire.putString(name);
                try self.wire.finishWrite(self.id, 4);
            }

            //
            // Many compositors can produce human-readable descriptions of their
            // outputs. The client may wish to know this description as well, e.g. for
            // output selection purposes.
            //
            // The description is a UTF-8 string with no convention defined for its
            // contents. The description is not guaranteed to be unique among all
            // wl_output globals. Examples might include 'Foocorp 11" Display' or
            // 'Virtual X11 output via :1'.
            //
            // The description event is sent after binding the output object and
            // whenever the description changes. The description is optional, and may
            // not be sent at all.
            //
            // The description event will be followed by a done event.
            //
            pub fn sendDescription(self: Self, description: []const u8) !void {
                try self.wire.startWrite();
                try self.wire.putString(description);
                try self.wire.finishWrite(self.id, 5);
            }
        };

        /// wl_region
        /// region interface
        ///
        /// A region object describes an area.
        ///
        /// Region objects are used to describe the opaque and input
        /// regions of a surface.
        ///
        pub const WlRegion = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_region,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_region) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .wl_region = self.*,
                            },
                        };
                    },
                    // add
                    1 => {
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        return Message{
                            .add = AddMessage{
                                .wl_region = self.*,
                                .x = x,
                                .y = y,
                                .width = width,
                                .height = height,
                            },
                        };
                    },
                    // subtract
                    2 => {
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        return Message{
                            .subtract = SubtractMessage{
                                .wl_region = self.*,
                                .x = x,
                                .y = y,
                                .width = width,
                                .height = height,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                add,
                subtract,
            };

            pub const Message = union(MessageType) {
                /// destroy region
                ///
                /// Destroy the region.  This will invalidate the object ID.
                ///
                destroy: DestroyMessage,

                /// add rectangle to region
                ///
                /// Add the specified rectangle to the region.
                ///
                add: AddMessage,

                /// subtract rectangle from region
                ///
                /// Subtract the specified rectangle from the region.
                ///
                subtract: SubtractMessage,
            };

            /// destroy region
            ///
            /// Destroy the region.  This will invalidate the object ID.
            ///
            const DestroyMessage = struct {
                wl_region: WlRegion,
            };

            /// add rectangle to region
            ///
            /// Add the specified rectangle to the region.
            ///
            const AddMessage = struct {
                wl_region: WlRegion,
                /// region-local x coordinate
                x: i32,
                /// region-local y coordinate
                y: i32,
                /// rectangle width
                width: i32,
                /// rectangle height
                height: i32,
            };

            /// subtract rectangle from region
            ///
            /// Subtract the specified rectangle from the region.
            ///
            const SubtractMessage = struct {
                wl_region: WlRegion,
                /// region-local x coordinate
                x: i32,
                /// region-local y coordinate
                y: i32,
                /// rectangle width
                width: i32,
                /// rectangle height
                height: i32,
            };
        };

        /// wl_subcompositor
        /// sub-surface compositing
        ///
        /// The global interface exposing sub-surface compositing capabilities.
        /// A wl_surface, that has sub-surfaces associated, is called the
        /// parent surface. Sub-surfaces can be arbitrarily nested and create
        /// a tree of sub-surfaces.
        ///
        /// The root surface in a tree of sub-surfaces is the main
        /// surface. The main surface cannot be a sub-surface, because
        /// sub-surfaces must always have a parent.
        ///
        /// A main surface with its sub-surfaces forms a (compound) window.
        /// For window management purposes, this set of wl_surface objects is
        /// to be considered as a single window, and it should also behave as
        /// such.
        ///
        /// The aim of sub-surfaces is to offload some of the compositing work
        /// within a window from clients to the compositor. A prime example is
        /// a video player with decorations and video in separate wl_surface
        /// objects. This should allow the compositor to pass YUV video buffer
        /// processing to dedicated overlay hardware when possible.
        ///
        pub const WlSubcompositor = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_subcompositor,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_subcompositor) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                bad_surface = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .wl_subcompositor = self.*,
                            },
                        };
                    },
                    // get_subsurface
                    1 => {
                        const id: u32 = try self.wire.nextU32();
                        const surface: WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const parent: WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        return Message{
                            .get_subsurface = GetSubsurfaceMessage{
                                .wl_subcompositor = self.*,
                                .id = id,
                                .surface = surface,
                                .parent = parent,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                get_subsurface,
            };

            pub const Message = union(MessageType) {
                /// unbind from the subcompositor interface
                ///
                /// Informs the server that the client will not be using this
                /// protocol object anymore. This does not affect any other
                /// objects, wl_subsurface objects included.
                ///
                destroy: DestroyMessage,

                /// give a surface the role sub-surface
                ///
                /// Create a sub-surface interface for the given surface, and
                /// associate it with the given parent surface. This turns a
                /// plain wl_surface into a sub-surface.
                ///
                /// The to-be sub-surface must not already have another role, and it
                /// must not have an existing wl_subsurface object. Otherwise a protocol
                /// error is raised.
                ///
                /// Adding sub-surfaces to a parent is a double-buffered operation on the
                /// parent (see wl_surface.commit). The effect of adding a sub-surface
                /// becomes visible on the next time the state of the parent surface is
                /// applied.
                ///
                /// This request modifies the behaviour of wl_surface.commit request on
                /// the sub-surface, see the documentation on wl_subsurface interface.
                ///
                get_subsurface: GetSubsurfaceMessage,
            };

            /// unbind from the subcompositor interface
            ///
            /// Informs the server that the client will not be using this
            /// protocol object anymore. This does not affect any other
            /// objects, wl_subsurface objects included.
            ///
            const DestroyMessage = struct {
                wl_subcompositor: WlSubcompositor,
            };

            /// give a surface the role sub-surface
            ///
            /// Create a sub-surface interface for the given surface, and
            /// associate it with the given parent surface. This turns a
            /// plain wl_surface into a sub-surface.
            ///
            /// The to-be sub-surface must not already have another role, and it
            /// must not have an existing wl_subsurface object. Otherwise a protocol
            /// error is raised.
            ///
            /// Adding sub-surfaces to a parent is a double-buffered operation on the
            /// parent (see wl_surface.commit). The effect of adding a sub-surface
            /// becomes visible on the next time the state of the parent surface is
            /// applied.
            ///
            /// This request modifies the behaviour of wl_surface.commit request on
            /// the sub-surface, see the documentation on wl_subsurface interface.
            ///
            const GetSubsurfaceMessage = struct {
                wl_subcompositor: WlSubcompositor,
                /// the new sub-surface object ID
                id: u32,
                /// the surface to be turned into a sub-surface
                surface: WlSurface,
                /// the parent surface
                parent: WlSurface,
            };
        };

        /// wl_subsurface
        /// sub-surface interface to a wl_surface
        ///
        /// An additional interface to a wl_surface object, which has been
        /// made a sub-surface. A sub-surface has one parent surface. A
        /// sub-surface's size and position are not limited to that of the parent.
        /// Particularly, a sub-surface is not automatically clipped to its
        /// parent's area.
        ///
        /// A sub-surface becomes mapped, when a non-NULL wl_buffer is applied
        /// and the parent surface is mapped. The order of which one happens
        /// first is irrelevant. A sub-surface is hidden if the parent becomes
        /// hidden, or if a NULL wl_buffer is applied. These rules apply
        /// recursively through the tree of surfaces.
        ///
        /// The behaviour of a wl_surface.commit request on a sub-surface
        /// depends on the sub-surface's mode. The possible modes are
        /// synchronized and desynchronized, see methods
        /// wl_subsurface.set_sync and wl_subsurface.set_desync. Synchronized
        /// mode caches the wl_surface state to be applied when the parent's
        /// state gets applied, and desynchronized mode applies the pending
        /// wl_surface state directly. A sub-surface is initially in the
        /// synchronized mode.
        ///
        /// Sub-surfaces also have another kind of state, which is managed by
        /// wl_subsurface requests, as opposed to wl_surface requests. This
        /// state includes the sub-surface position relative to the parent
        /// surface (wl_subsurface.set_position), and the stacking order of
        /// the parent and its sub-surfaces (wl_subsurface.place_above and
        /// .place_below). This state is applied when the parent surface's
        /// wl_surface state is applied, regardless of the sub-surface's mode.
        /// As the exception, set_sync and set_desync are effective immediately.
        ///
        /// The main surface can be thought to be always in desynchronized mode,
        /// since it does not have a parent in the sub-surfaces sense.
        ///
        /// Even if a sub-surface is in desynchronized mode, it will behave as
        /// in synchronized mode, if its parent surface behaves as in
        /// synchronized mode. This rule is applied recursively throughout the
        /// tree of surfaces. This means, that one can set a sub-surface into
        /// synchronized mode, and then assume that all its child and grand-child
        /// sub-surfaces are synchronized, too, without explicitly setting them.
        ///
        /// If the wl_surface associated with the wl_subsurface is destroyed, the
        /// wl_subsurface object becomes inert. Note, that destroying either object
        /// takes effect immediately. If you need to synchronize the removal
        /// of a sub-surface to the parent surface update, unmap the sub-surface
        /// first by attaching a NULL wl_buffer, update parent, and then destroy
        /// the sub-surface.
        ///
        /// If the parent wl_surface object is destroyed, the sub-surface is
        /// unmapped.
        ///
        pub const WlSubsurface = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.wl_subsurface,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.wl_subsurface) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                bad_surface = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .wl_subsurface = self.*,
                            },
                        };
                    },
                    // set_position
                    1 => {
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        return Message{
                            .set_position = SetPositionMessage{
                                .wl_subsurface = self.*,
                                .x = x,
                                .y = y,
                            },
                        };
                    },
                    // place_above
                    2 => {
                        const sibling: WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        return Message{
                            .place_above = PlaceAboveMessage{
                                .wl_subsurface = self.*,
                                .sibling = sibling,
                            },
                        };
                    },
                    // place_below
                    3 => {
                        const sibling: WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        return Message{
                            .place_below = PlaceBelowMessage{
                                .wl_subsurface = self.*,
                                .sibling = sibling,
                            },
                        };
                    },
                    // set_sync
                    4 => {
                        return Message{
                            .set_sync = SetSyncMessage{
                                .wl_subsurface = self.*,
                            },
                        };
                    },
                    // set_desync
                    5 => {
                        return Message{
                            .set_desync = SetDesyncMessage{
                                .wl_subsurface = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                set_position,
                place_above,
                place_below,
                set_sync,
                set_desync,
            };

            pub const Message = union(MessageType) {
                /// remove sub-surface interface
                ///
                /// The sub-surface interface is removed from the wl_surface object
                /// that was turned into a sub-surface with a
                /// wl_subcompositor.get_subsurface request. The wl_surface's association
                /// to the parent is deleted, and the wl_surface loses its role as
                /// a sub-surface. The wl_surface is unmapped immediately.
                ///
                destroy: DestroyMessage,

                /// reposition the sub-surface
                ///
                /// This schedules a sub-surface position change.
                /// The sub-surface will be moved so that its origin (top left
                /// corner pixel) will be at the location x, y of the parent surface
                /// coordinate system. The coordinates are not restricted to the parent
                /// surface area. Negative values are allowed.
                ///
                /// The scheduled coordinates will take effect whenever the state of the
                /// parent surface is applied. When this happens depends on whether the
                /// parent surface is in synchronized mode or not. See
                /// wl_subsurface.set_sync and wl_subsurface.set_desync for details.
                ///
                /// If more than one set_position request is invoked by the client before
                /// the commit of the parent surface, the position of a new request always
                /// replaces the scheduled position from any previous request.
                ///
                /// The initial position is 0, 0.
                ///
                set_position: SetPositionMessage,

                /// restack the sub-surface
                ///
                /// This sub-surface is taken from the stack, and put back just
                /// above the reference surface, changing the z-order of the sub-surfaces.
                /// The reference surface must be one of the sibling surfaces, or the
                /// parent surface. Using any other surface, including this sub-surface,
                /// will cause a protocol error.
                ///
                /// The z-order is double-buffered. Requests are handled in order and
                /// applied immediately to a pending state. The final pending state is
                /// copied to the active state the next time the state of the parent
                /// surface is applied. When this happens depends on whether the parent
                /// surface is in synchronized mode or not. See wl_subsurface.set_sync and
                /// wl_subsurface.set_desync for details.
                ///
                /// A new sub-surface is initially added as the top-most in the stack
                /// of its siblings and parent.
                ///
                place_above: PlaceAboveMessage,

                /// restack the sub-surface
                ///
                /// The sub-surface is placed just below the reference surface.
                /// See wl_subsurface.place_above.
                ///
                place_below: PlaceBelowMessage,

                /// set sub-surface to synchronized mode
                ///
                /// Change the commit behaviour of the sub-surface to synchronized
                /// mode, also described as the parent dependent mode.
                ///
                /// In synchronized mode, wl_surface.commit on a sub-surface will
                /// accumulate the committed state in a cache, but the state will
                /// not be applied and hence will not change the compositor output.
                /// The cached state is applied to the sub-surface immediately after
                /// the parent surface's state is applied. This ensures atomic
                /// updates of the parent and all its synchronized sub-surfaces.
                /// Applying the cached state will invalidate the cache, so further
                /// parent surface commits do not (re-)apply old state.
                ///
                /// See wl_subsurface for the recursive effect of this mode.
                ///
                set_sync: SetSyncMessage,

                /// set sub-surface to desynchronized mode
                ///
                /// Change the commit behaviour of the sub-surface to desynchronized
                /// mode, also described as independent or freely running mode.
                ///
                /// In desynchronized mode, wl_surface.commit on a sub-surface will
                /// apply the pending state directly, without caching, as happens
                /// normally with a wl_surface. Calling wl_surface.commit on the
                /// parent surface has no effect on the sub-surface's wl_surface
                /// state. This mode allows a sub-surface to be updated on its own.
                ///
                /// If cached state exists when wl_surface.commit is called in
                /// desynchronized mode, the pending state is added to the cached
                /// state, and applied as a whole. This invalidates the cache.
                ///
                /// Note: even if a sub-surface is set to desynchronized, a parent
                /// sub-surface may override it to behave as synchronized. For details,
                /// see wl_subsurface.
                ///
                /// If a surface's parent surface behaves as desynchronized, then
                /// the cached state is applied on set_desync.
                ///
                set_desync: SetDesyncMessage,
            };

            /// remove sub-surface interface
            ///
            /// The sub-surface interface is removed from the wl_surface object
            /// that was turned into a sub-surface with a
            /// wl_subcompositor.get_subsurface request. The wl_surface's association
            /// to the parent is deleted, and the wl_surface loses its role as
            /// a sub-surface. The wl_surface is unmapped immediately.
            ///
            const DestroyMessage = struct {
                wl_subsurface: WlSubsurface,
            };

            /// reposition the sub-surface
            ///
            /// This schedules a sub-surface position change.
            /// The sub-surface will be moved so that its origin (top left
            /// corner pixel) will be at the location x, y of the parent surface
            /// coordinate system. The coordinates are not restricted to the parent
            /// surface area. Negative values are allowed.
            ///
            /// The scheduled coordinates will take effect whenever the state of the
            /// parent surface is applied. When this happens depends on whether the
            /// parent surface is in synchronized mode or not. See
            /// wl_subsurface.set_sync and wl_subsurface.set_desync for details.
            ///
            /// If more than one set_position request is invoked by the client before
            /// the commit of the parent surface, the position of a new request always
            /// replaces the scheduled position from any previous request.
            ///
            /// The initial position is 0, 0.
            ///
            const SetPositionMessage = struct {
                wl_subsurface: WlSubsurface,
                /// x coordinate in the parent surface
                x: i32,
                /// y coordinate in the parent surface
                y: i32,
            };

            /// restack the sub-surface
            ///
            /// This sub-surface is taken from the stack, and put back just
            /// above the reference surface, changing the z-order of the sub-surfaces.
            /// The reference surface must be one of the sibling surfaces, or the
            /// parent surface. Using any other surface, including this sub-surface,
            /// will cause a protocol error.
            ///
            /// The z-order is double-buffered. Requests are handled in order and
            /// applied immediately to a pending state. The final pending state is
            /// copied to the active state the next time the state of the parent
            /// surface is applied. When this happens depends on whether the parent
            /// surface is in synchronized mode or not. See wl_subsurface.set_sync and
            /// wl_subsurface.set_desync for details.
            ///
            /// A new sub-surface is initially added as the top-most in the stack
            /// of its siblings and parent.
            ///
            const PlaceAboveMessage = struct {
                wl_subsurface: WlSubsurface,
                /// the reference surface
                sibling: WlSurface,
            };

            /// restack the sub-surface
            ///
            /// The sub-surface is placed just below the reference surface.
            /// See wl_subsurface.place_above.
            ///
            const PlaceBelowMessage = struct {
                wl_subsurface: WlSubsurface,
                /// the reference surface
                sibling: WlSurface,
            };

            /// set sub-surface to synchronized mode
            ///
            /// Change the commit behaviour of the sub-surface to synchronized
            /// mode, also described as the parent dependent mode.
            ///
            /// In synchronized mode, wl_surface.commit on a sub-surface will
            /// accumulate the committed state in a cache, but the state will
            /// not be applied and hence will not change the compositor output.
            /// The cached state is applied to the sub-surface immediately after
            /// the parent surface's state is applied. This ensures atomic
            /// updates of the parent and all its synchronized sub-surfaces.
            /// Applying the cached state will invalidate the cache, so further
            /// parent surface commits do not (re-)apply old state.
            ///
            /// See wl_subsurface for the recursive effect of this mode.
            ///
            const SetSyncMessage = struct {
                wl_subsurface: WlSubsurface,
            };

            /// set sub-surface to desynchronized mode
            ///
            /// Change the commit behaviour of the sub-surface to desynchronized
            /// mode, also described as independent or freely running mode.
            ///
            /// In desynchronized mode, wl_surface.commit on a sub-surface will
            /// apply the pending state directly, without caching, as happens
            /// normally with a wl_surface. Calling wl_surface.commit on the
            /// parent surface has no effect on the sub-surface's wl_surface
            /// state. This mode allows a sub-surface to be updated on its own.
            ///
            /// If cached state exists when wl_surface.commit is called in
            /// desynchronized mode, the pending state is added to the cached
            /// state, and applied as a whole. This invalidates the cache.
            ///
            /// Note: even if a sub-surface is set to desynchronized, a parent
            /// sub-surface may override it to behave as synchronized. For details,
            /// see wl_subsurface.
            ///
            /// If a surface's parent surface behaves as desynchronized, then
            /// the cached state is applied on set_desync.
            ///
            const SetDesyncMessage = struct {
                wl_subsurface: WlSubsurface,
            };
        };

        /// xdg_wm_base
        /// create desktop-style surfaces
        ///
        /// The xdg_wm_base interface is exposed as a global object enabling clients
        /// to turn their wl_surfaces into windows in a desktop environment. It
        /// defines the basic functionality needed for clients and the compositor to
        /// create windows that can be dragged, resized, maximized, etc, as well as
        /// creating transient windows such as popup menus.
        ///
        pub const XdgWmBase = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.xdg_wm_base,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.xdg_wm_base) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                role = 0,
                defunct_surfaces = 1,
                not_the_topmost_popup = 2,
                invalid_popup_parent = 3,
                invalid_surface_state = 4,
                invalid_positioner = 5,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .xdg_wm_base = self.*,
                            },
                        };
                    },
                    // create_positioner
                    1 => {
                        const id: u32 = try self.wire.nextU32();
                        return Message{
                            .create_positioner = CreatePositionerMessage{
                                .xdg_wm_base = self.*,
                                .id = id,
                            },
                        };
                    },
                    // get_xdg_surface
                    2 => {
                        const id: u32 = try self.wire.nextU32();
                        const surface: WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        return Message{
                            .get_xdg_surface = GetXdgSurfaceMessage{
                                .xdg_wm_base = self.*,
                                .id = id,
                                .surface = surface,
                            },
                        };
                    },
                    // pong
                    3 => {
                        const serial: u32 = try self.wire.nextU32();
                        return Message{
                            .pong = PongMessage{
                                .xdg_wm_base = self.*,
                                .serial = serial,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                create_positioner,
                get_xdg_surface,
                pong,
            };

            pub const Message = union(MessageType) {
                /// destroy xdg_wm_base
                ///
                /// Destroy this xdg_wm_base object.
                ///
                /// Destroying a bound xdg_wm_base object while there are surfaces
                /// still alive created by this xdg_wm_base object instance is illegal
                /// and will result in a protocol error.
                ///
                destroy: DestroyMessage,

                /// create a positioner object
                ///
                /// Create a positioner object. A positioner object is used to position
                /// surfaces relative to some parent surface. See the interface description
                /// and xdg_surface.get_popup for details.
                ///
                create_positioner: CreatePositionerMessage,

                /// create a shell surface from a surface
                ///
                /// This creates an xdg_surface for the given surface. While xdg_surface
                /// itself is not a role, the corresponding surface may only be assigned
                /// a role extending xdg_surface, such as xdg_toplevel or xdg_popup. It is
                /// illegal to create an xdg_surface for a wl_surface which already has an
                /// assigned role and this will result in a protocol error.
                ///
                /// This creates an xdg_surface for the given surface. An xdg_surface is
                /// used as basis to define a role to a given surface, such as xdg_toplevel
                /// or xdg_popup. It also manages functionality shared between xdg_surface
                /// based surface roles.
                ///
                /// See the documentation of xdg_surface for more details about what an
                /// xdg_surface is and how it is used.
                ///
                get_xdg_surface: GetXdgSurfaceMessage,

                /// respond to a ping event
                ///
                /// A client must respond to a ping event with a pong request or
                /// the client may be deemed unresponsive. See xdg_wm_base.ping.
                ///
                pong: PongMessage,
            };

            /// destroy xdg_wm_base
            ///
            /// Destroy this xdg_wm_base object.
            ///
            /// Destroying a bound xdg_wm_base object while there are surfaces
            /// still alive created by this xdg_wm_base object instance is illegal
            /// and will result in a protocol error.
            ///
            const DestroyMessage = struct {
                xdg_wm_base: XdgWmBase,
            };

            /// create a positioner object
            ///
            /// Create a positioner object. A positioner object is used to position
            /// surfaces relative to some parent surface. See the interface description
            /// and xdg_surface.get_popup for details.
            ///
            const CreatePositionerMessage = struct {
                xdg_wm_base: XdgWmBase,
                id: u32,
            };

            /// create a shell surface from a surface
            ///
            /// This creates an xdg_surface for the given surface. While xdg_surface
            /// itself is not a role, the corresponding surface may only be assigned
            /// a role extending xdg_surface, such as xdg_toplevel or xdg_popup. It is
            /// illegal to create an xdg_surface for a wl_surface which already has an
            /// assigned role and this will result in a protocol error.
            ///
            /// This creates an xdg_surface for the given surface. An xdg_surface is
            /// used as basis to define a role to a given surface, such as xdg_toplevel
            /// or xdg_popup. It also manages functionality shared between xdg_surface
            /// based surface roles.
            ///
            /// See the documentation of xdg_surface for more details about what an
            /// xdg_surface is and how it is used.
            ///
            const GetXdgSurfaceMessage = struct {
                xdg_wm_base: XdgWmBase,
                id: u32,
                surface: WlSurface,
            };

            /// respond to a ping event
            ///
            /// A client must respond to a ping event with a pong request or
            /// the client may be deemed unresponsive. See xdg_wm_base.ping.
            ///
            const PongMessage = struct {
                xdg_wm_base: XdgWmBase,
                /// serial of the ping event
                serial: u32,
            };

            //
            // The ping event asks the client if it's still alive. Pass the
            // serial specified in the event back to the compositor by sending
            // a "pong" request back with the specified serial. See xdg_wm_base.pong.
            //
            // Compositors can use this to determine if the client is still
            // alive. It's unspecified what will happen if the client doesn't
            // respond to the ping request, or in what timeframe. Clients should
            // try to respond in a reasonable amount of time.
            //
            // A compositor is free to ping in any way it wants, but a client must
            // always respond to any xdg_wm_base object it created.
            //
            pub fn sendPing(self: Self, serial: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.finishWrite(self.id, 0);
            }
        };

        /// xdg_positioner
        /// child surface positioner
        ///
        /// The xdg_positioner provides a collection of rules for the placement of a
        /// child surface relative to a parent surface. Rules can be defined to ensure
        /// the child surface remains within the visible area's borders, and to
        /// specify how the child surface changes its position, such as sliding along
        /// an axis, or flipping around a rectangle. These positioner-created rules are
        /// constrained by the requirement that a child surface must intersect with or
        /// be at least partially adjacent to its parent surface.
        ///
        /// See the various requests for details about possible rules.
        ///
        /// At the time of the request, the compositor makes a copy of the rules
        /// specified by the xdg_positioner. Thus, after the request is complete the
        /// xdg_positioner object can be destroyed or reused; further changes to the
        /// object will have no effect on previous usages.
        ///
        /// For an xdg_positioner object to be considered complete, it must have a
        /// non-zero size set by set_size, and a non-zero anchor rectangle set by
        /// set_anchor_rect. Passing an incomplete xdg_positioner object when
        /// positioning a surface raises an error.
        ///
        pub const XdgPositioner = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.xdg_positioner,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.xdg_positioner) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                invalid_input = 0,
            };

            pub const Anchor = enum(u32) {
                none = 0,
                top = 1,
                bottom = 2,
                left = 3,
                right = 4,
                top_left = 5,
                bottom_left = 6,
                top_right = 7,
                bottom_right = 8,
            };

            pub const Gravity = enum(u32) {
                none = 0,
                top = 1,
                bottom = 2,
                left = 3,
                right = 4,
                top_left = 5,
                bottom_left = 6,
                top_right = 7,
                bottom_right = 8,
            };

            pub const ConstraintAdjustment = packed struct(u32) { // bitfield
                // none 0 (removed from bitfield)
                slide_x: bool = false, // 1
                slide_y: bool = false, // 2
                flip_x: bool = false, // 4
                flip_y: bool = false, // 8
                resize_x: bool = false, // 16
                resize_y: bool = false, // 32
                _padding: u26 = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .xdg_positioner = self.*,
                            },
                        };
                    },
                    // set_size
                    1 => {
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        return Message{
                            .set_size = SetSizeMessage{
                                .xdg_positioner = self.*,
                                .width = width,
                                .height = height,
                            },
                        };
                    },
                    // set_anchor_rect
                    2 => {
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        return Message{
                            .set_anchor_rect = SetAnchorRectMessage{
                                .xdg_positioner = self.*,
                                .x = x,
                                .y = y,
                                .width = width,
                                .height = height,
                            },
                        };
                    },
                    // set_anchor
                    3 => {
                        const anchor: Anchor = @enumFromInt(try self.wire.nextU32()); // enum
                        return Message{
                            .set_anchor = SetAnchorMessage{
                                .xdg_positioner = self.*,
                                .anchor = anchor,
                            },
                        };
                    },
                    // set_gravity
                    4 => {
                        const gravity: Gravity = @enumFromInt(try self.wire.nextU32()); // enum
                        return Message{
                            .set_gravity = SetGravityMessage{
                                .xdg_positioner = self.*,
                                .gravity = gravity,
                            },
                        };
                    },
                    // set_constraint_adjustment
                    5 => {
                        const constraint_adjustment: u32 = try self.wire.nextU32();
                        return Message{
                            .set_constraint_adjustment = SetConstraintAdjustmentMessage{
                                .xdg_positioner = self.*,
                                .constraint_adjustment = constraint_adjustment,
                            },
                        };
                    },
                    // set_offset
                    6 => {
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        return Message{
                            .set_offset = SetOffsetMessage{
                                .xdg_positioner = self.*,
                                .x = x,
                                .y = y,
                            },
                        };
                    },
                    // set_reactive
                    7 => {
                        return Message{
                            .set_reactive = SetReactiveMessage{
                                .xdg_positioner = self.*,
                            },
                        };
                    },
                    // set_parent_size
                    8 => {
                        const parent_width: i32 = try self.wire.nextI32();
                        const parent_height: i32 = try self.wire.nextI32();
                        return Message{
                            .set_parent_size = SetParentSizeMessage{
                                .xdg_positioner = self.*,
                                .parent_width = parent_width,
                                .parent_height = parent_height,
                            },
                        };
                    },
                    // set_parent_configure
                    9 => {
                        const serial: u32 = try self.wire.nextU32();
                        return Message{
                            .set_parent_configure = SetParentConfigureMessage{
                                .xdg_positioner = self.*,
                                .serial = serial,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                set_size,
                set_anchor_rect,
                set_anchor,
                set_gravity,
                set_constraint_adjustment,
                set_offset,
                set_reactive,
                set_parent_size,
                set_parent_configure,
            };

            pub const Message = union(MessageType) {
                /// destroy the xdg_positioner object
                ///
                /// Notify the compositor that the xdg_positioner will no longer be used.
                ///
                destroy: DestroyMessage,

                /// set the size of the to-be positioned rectangle
                ///
                /// Set the size of the surface that is to be positioned with the positioner
                /// object. The size is in surface-local coordinates and corresponds to the
                /// window geometry. See xdg_surface.set_window_geometry.
                ///
                /// If a zero or negative size is set the invalid_input error is raised.
                ///
                set_size: SetSizeMessage,

                /// set the anchor rectangle within the parent surface
                ///
                /// Specify the anchor rectangle within the parent surface that the child
                /// surface will be placed relative to. The rectangle is relative to the
                /// window geometry as defined by xdg_surface.set_window_geometry of the
                /// parent surface.
                ///
                /// When the xdg_positioner object is used to position a child surface, the
                /// anchor rectangle may not extend outside the window geometry of the
                /// positioned child's parent surface.
                ///
                /// If a negative size is set the invalid_input error is raised.
                ///
                set_anchor_rect: SetAnchorRectMessage,

                /// set anchor rectangle anchor
                ///
                /// Defines the anchor point for the anchor rectangle. The specified anchor
                /// is used derive an anchor point that the child surface will be
                /// positioned relative to. If a corner anchor is set (e.g. 'top_left' or
                /// 'bottom_right'), the anchor point will be at the specified corner;
                /// otherwise, the derived anchor point will be centered on the specified
                /// edge, or in the center of the anchor rectangle if no edge is specified.
                ///
                set_anchor: SetAnchorMessage,

                /// set child surface gravity
                ///
                /// Defines in what direction a surface should be positioned, relative to
                /// the anchor point of the parent surface. If a corner gravity is
                /// specified (e.g. 'bottom_right' or 'top_left'), then the child surface
                /// will be placed towards the specified gravity; otherwise, the child
                /// surface will be centered over the anchor point on any axis that had no
                /// gravity specified.
                ///
                set_gravity: SetGravityMessage,

                /// set the adjustment to be done when constrained
                ///
                /// Specify how the window should be positioned if the originally intended
                /// position caused the surface to be constrained, meaning at least
                /// partially outside positioning boundaries set by the compositor. The
                /// adjustment is set by constructing a bitmask describing the adjustment to
                /// be made when the surface is constrained on that axis.
                ///
                /// If no bit for one axis is set, the compositor will assume that the child
                /// surface should not change its position on that axis when constrained.
                ///
                /// If more than one bit for one axis is set, the order of how adjustments
                /// are applied is specified in the corresponding adjustment descriptions.
                ///
                /// The default adjustment is none.
                ///
                set_constraint_adjustment: SetConstraintAdjustmentMessage,

                /// set surface position offset
                ///
                /// Specify the surface position offset relative to the position of the
                /// anchor on the anchor rectangle and the anchor on the surface. For
                /// example if the anchor of the anchor rectangle is at (x, y), the surface
                /// has the gravity bottom|right, and the offset is (ox, oy), the calculated
                /// surface position will be (x + ox, y + oy). The offset position of the
                /// surface is the one used for constraint testing. See
                /// set_constraint_adjustment.
                ///
                /// An example use case is placing a popup menu on top of a user interface
                /// element, while aligning the user interface element of the parent surface
                /// with some user interface element placed somewhere in the popup surface.
                ///
                set_offset: SetOffsetMessage,

                /// continuously reconstrain the surface
                ///
                /// When set reactive, the surface is reconstrained if the conditions used
                /// for constraining changed, e.g. the parent window moved.
                ///
                /// If the conditions changed and the popup was reconstrained, an
                /// xdg_popup.configure event is sent with updated geometry, followed by an
                /// xdg_surface.configure event.
                ///
                set_reactive: SetReactiveMessage,

                ///
                ///
                /// Set the parent window geometry the compositor should use when
                /// positioning the popup. The compositor may use this information to
                /// determine the future state the popup should be constrained using. If
                /// this doesn't match the dimension of the parent the popup is eventually
                /// positioned against, the behavior is undefined.
                ///
                /// The arguments are given in the surface-local coordinate space.
                ///
                set_parent_size: SetParentSizeMessage,

                /// set parent configure this is a response to
                ///
                /// Set the serial of an xdg_surface.configure event this positioner will be
                /// used in response to. The compositor may use this information together
                /// with set_parent_size to determine what future state the popup should be
                /// constrained using.
                ///
                set_parent_configure: SetParentConfigureMessage,
            };

            /// destroy the xdg_positioner object
            ///
            /// Notify the compositor that the xdg_positioner will no longer be used.
            ///
            const DestroyMessage = struct {
                xdg_positioner: XdgPositioner,
            };

            /// set the size of the to-be positioned rectangle
            ///
            /// Set the size of the surface that is to be positioned with the positioner
            /// object. The size is in surface-local coordinates and corresponds to the
            /// window geometry. See xdg_surface.set_window_geometry.
            ///
            /// If a zero or negative size is set the invalid_input error is raised.
            ///
            const SetSizeMessage = struct {
                xdg_positioner: XdgPositioner,
                /// width of positioned rectangle
                width: i32,
                /// height of positioned rectangle
                height: i32,
            };

            /// set the anchor rectangle within the parent surface
            ///
            /// Specify the anchor rectangle within the parent surface that the child
            /// surface will be placed relative to. The rectangle is relative to the
            /// window geometry as defined by xdg_surface.set_window_geometry of the
            /// parent surface.
            ///
            /// When the xdg_positioner object is used to position a child surface, the
            /// anchor rectangle may not extend outside the window geometry of the
            /// positioned child's parent surface.
            ///
            /// If a negative size is set the invalid_input error is raised.
            ///
            const SetAnchorRectMessage = struct {
                xdg_positioner: XdgPositioner,
                /// x position of anchor rectangle
                x: i32,
                /// y position of anchor rectangle
                y: i32,
                /// width of anchor rectangle
                width: i32,
                /// height of anchor rectangle
                height: i32,
            };

            /// set anchor rectangle anchor
            ///
            /// Defines the anchor point for the anchor rectangle. The specified anchor
            /// is used derive an anchor point that the child surface will be
            /// positioned relative to. If a corner anchor is set (e.g. 'top_left' or
            /// 'bottom_right'), the anchor point will be at the specified corner;
            /// otherwise, the derived anchor point will be centered on the specified
            /// edge, or in the center of the anchor rectangle if no edge is specified.
            ///
            const SetAnchorMessage = struct {
                xdg_positioner: XdgPositioner,
                /// anchor
                anchor: Anchor,
            };

            /// set child surface gravity
            ///
            /// Defines in what direction a surface should be positioned, relative to
            /// the anchor point of the parent surface. If a corner gravity is
            /// specified (e.g. 'bottom_right' or 'top_left'), then the child surface
            /// will be placed towards the specified gravity; otherwise, the child
            /// surface will be centered over the anchor point on any axis that had no
            /// gravity specified.
            ///
            const SetGravityMessage = struct {
                xdg_positioner: XdgPositioner,
                /// gravity direction
                gravity: Gravity,
            };

            /// set the adjustment to be done when constrained
            ///
            /// Specify how the window should be positioned if the originally intended
            /// position caused the surface to be constrained, meaning at least
            /// partially outside positioning boundaries set by the compositor. The
            /// adjustment is set by constructing a bitmask describing the adjustment to
            /// be made when the surface is constrained on that axis.
            ///
            /// If no bit for one axis is set, the compositor will assume that the child
            /// surface should not change its position on that axis when constrained.
            ///
            /// If more than one bit for one axis is set, the order of how adjustments
            /// are applied is specified in the corresponding adjustment descriptions.
            ///
            /// The default adjustment is none.
            ///
            const SetConstraintAdjustmentMessage = struct {
                xdg_positioner: XdgPositioner,
                /// bit mask of constraint adjustments
                constraint_adjustment: u32,
            };

            /// set surface position offset
            ///
            /// Specify the surface position offset relative to the position of the
            /// anchor on the anchor rectangle and the anchor on the surface. For
            /// example if the anchor of the anchor rectangle is at (x, y), the surface
            /// has the gravity bottom|right, and the offset is (ox, oy), the calculated
            /// surface position will be (x + ox, y + oy). The offset position of the
            /// surface is the one used for constraint testing. See
            /// set_constraint_adjustment.
            ///
            /// An example use case is placing a popup menu on top of a user interface
            /// element, while aligning the user interface element of the parent surface
            /// with some user interface element placed somewhere in the popup surface.
            ///
            const SetOffsetMessage = struct {
                xdg_positioner: XdgPositioner,
                /// surface position x offset
                x: i32,
                /// surface position y offset
                y: i32,
            };

            /// continuously reconstrain the surface
            ///
            /// When set reactive, the surface is reconstrained if the conditions used
            /// for constraining changed, e.g. the parent window moved.
            ///
            /// If the conditions changed and the popup was reconstrained, an
            /// xdg_popup.configure event is sent with updated geometry, followed by an
            /// xdg_surface.configure event.
            ///
            const SetReactiveMessage = struct {
                xdg_positioner: XdgPositioner,
            };

            ///
            ///
            /// Set the parent window geometry the compositor should use when
            /// positioning the popup. The compositor may use this information to
            /// determine the future state the popup should be constrained using. If
            /// this doesn't match the dimension of the parent the popup is eventually
            /// positioned against, the behavior is undefined.
            ///
            /// The arguments are given in the surface-local coordinate space.
            ///
            const SetParentSizeMessage = struct {
                xdg_positioner: XdgPositioner,
                /// future window geometry width of parent
                parent_width: i32,
                /// future window geometry height of parent
                parent_height: i32,
            };

            /// set parent configure this is a response to
            ///
            /// Set the serial of an xdg_surface.configure event this positioner will be
            /// used in response to. The compositor may use this information together
            /// with set_parent_size to determine what future state the popup should be
            /// constrained using.
            ///
            const SetParentConfigureMessage = struct {
                xdg_positioner: XdgPositioner,
                /// serial of parent configure event
                serial: u32,
            };
        };

        /// xdg_surface
        /// desktop user interface surface base interface
        ///
        /// An interface that may be implemented by a wl_surface, for
        /// implementations that provide a desktop-style user interface.
        ///
        /// It provides a base set of functionality required to construct user
        /// interface elements requiring management by the compositor, such as
        /// toplevel windows, menus, etc. The types of functionality are split into
        /// xdg_surface roles.
        ///
        /// Creating an xdg_surface does not set the role for a wl_surface. In order
        /// to map an xdg_surface, the client must create a role-specific object
        /// using, e.g., get_toplevel, get_popup. The wl_surface for any given
        /// xdg_surface can have at most one role, and may not be assigned any role
        /// not based on xdg_surface.
        ///
        /// A role must be assigned before any other requests are made to the
        /// xdg_surface object.
        ///
        /// The client must call wl_surface.commit on the corresponding wl_surface
        /// for the xdg_surface state to take effect.
        ///
        /// Creating an xdg_surface from a wl_surface which has a buffer attached or
        /// committed is a client error, and any attempts by a client to attach or
        /// manipulate a buffer prior to the first xdg_surface.configure call must
        /// also be treated as errors.
        ///
        /// After creating a role-specific object and setting it up, the client must
        /// perform an initial commit without any buffer attached. The compositor
        /// will reply with an xdg_surface.configure event. The client must
        /// acknowledge it and is then allowed to attach a buffer to map the surface.
        ///
        /// Mapping an xdg_surface-based role surface is defined as making it
        /// possible for the surface to be shown by the compositor. Note that
        /// a mapped surface is not guaranteed to be visible once it is mapped.
        ///
        /// For an xdg_surface to be mapped by the compositor, the following
        /// conditions must be met:
        /// (1) the client has assigned an xdg_surface-based role to the surface
        /// (2) the client has set and committed the xdg_surface state and the
        /// role-dependent state to the surface
        /// (3) the client has committed a buffer to the surface
        ///
        /// A newly-unmapped surface is considered to have met condition (1) out
        /// of the 3 required conditions for mapping a surface if its role surface
        /// has not been destroyed, i.e. the client must perform the initial commit
        /// again before attaching a buffer.
        ///
        pub const XdgSurface = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.xdg_surface,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.xdg_surface) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                not_constructed = 1,
                already_constructed = 2,
                unconfigured_buffer = 3,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .xdg_surface = self.*,
                            },
                        };
                    },
                    // get_toplevel
                    1 => {
                        const id: u32 = try self.wire.nextU32();
                        return Message{
                            .get_toplevel = GetToplevelMessage{
                                .xdg_surface = self.*,
                                .id = id,
                            },
                        };
                    },
                    // get_popup
                    2 => {
                        const id: u32 = try self.wire.nextU32();
                        const parent: ?XdgSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .xdg_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        const positioner: XdgPositioner = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .xdg_positioner => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        return Message{
                            .get_popup = GetPopupMessage{
                                .xdg_surface = self.*,
                                .id = id,
                                .parent = parent,
                                .positioner = positioner,
                            },
                        };
                    },
                    // set_window_geometry
                    3 => {
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        return Message{
                            .set_window_geometry = SetWindowGeometryMessage{
                                .xdg_surface = self.*,
                                .x = x,
                                .y = y,
                                .width = width,
                                .height = height,
                            },
                        };
                    },
                    // ack_configure
                    4 => {
                        const serial: u32 = try self.wire.nextU32();
                        return Message{
                            .ack_configure = AckConfigureMessage{
                                .xdg_surface = self.*,
                                .serial = serial,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                get_toplevel,
                get_popup,
                set_window_geometry,
                ack_configure,
            };

            pub const Message = union(MessageType) {
                /// destroy the xdg_surface
                ///
                /// Destroy the xdg_surface object. An xdg_surface must only be destroyed
                /// after its role object has been destroyed.
                ///
                destroy: DestroyMessage,

                /// assign the xdg_toplevel surface role
                ///
                /// This creates an xdg_toplevel object for the given xdg_surface and gives
                /// the associated wl_surface the xdg_toplevel role.
                ///
                /// See the documentation of xdg_toplevel for more details about what an
                /// xdg_toplevel is and how it is used.
                ///
                get_toplevel: GetToplevelMessage,

                /// assign the xdg_popup surface role
                ///
                /// This creates an xdg_popup object for the given xdg_surface and gives
                /// the associated wl_surface the xdg_popup role.
                ///
                /// If null is passed as a parent, a parent surface must be specified using
                /// some other protocol, before committing the initial state.
                ///
                /// See the documentation of xdg_popup for more details about what an
                /// xdg_popup is and how it is used.
                ///
                get_popup: GetPopupMessage,

                /// set the new window geometry
                ///
                /// The window geometry of a surface is its "visible bounds" from the
                /// user's perspective. Client-side decorations often have invisible
                /// portions like drop-shadows which should be ignored for the
                /// purposes of aligning, placing and constraining windows.
                ///
                /// The window geometry is double buffered, and will be applied at the
                /// time wl_surface.commit of the corresponding wl_surface is called.
                ///
                /// When maintaining a position, the compositor should treat the (x, y)
                /// coordinate of the window geometry as the top left corner of the window.
                /// A client changing the (x, y) window geometry coordinate should in
                /// general not alter the position of the window.
                ///
                /// Once the window geometry of the surface is set, it is not possible to
                /// unset it, and it will remain the same until set_window_geometry is
                /// called again, even if a new subsurface or buffer is attached.
                ///
                /// If never set, the value is the full bounds of the surface,
                /// including any subsurfaces. This updates dynamically on every
                /// commit. This unset is meant for extremely simple clients.
                ///
                /// The arguments are given in the surface-local coordinate space of
                /// the wl_surface associated with this xdg_surface.
                ///
                /// The width and height must be greater than zero. Setting an invalid size
                /// will raise an error. When applied, the effective window geometry will be
                /// the set window geometry clamped to the bounding rectangle of the
                /// combined geometry of the surface of the xdg_surface and the associated
                /// subsurfaces.
                ///
                set_window_geometry: SetWindowGeometryMessage,

                /// ack a configure event
                ///
                /// When a configure event is received, if a client commits the
                /// surface in response to the configure event, then the client
                /// must make an ack_configure request sometime before the commit
                /// request, passing along the serial of the configure event.
                ///
                /// For instance, for toplevel surfaces the compositor might use this
                /// information to move a surface to the top left only when the client has
                /// drawn itself for the maximized or fullscreen state.
                ///
                /// If the client receives multiple configure events before it
                /// can respond to one, it only has to ack the last configure event.
                ///
                /// A client is not required to commit immediately after sending
                /// an ack_configure request - it may even ack_configure several times
                /// before its next surface commit.
                ///
                /// A client may send multiple ack_configure requests before committing, but
                /// only the last request sent before a commit indicates which configure
                /// event the client really is responding to.
                ///
                ack_configure: AckConfigureMessage,
            };

            /// destroy the xdg_surface
            ///
            /// Destroy the xdg_surface object. An xdg_surface must only be destroyed
            /// after its role object has been destroyed.
            ///
            const DestroyMessage = struct {
                xdg_surface: XdgSurface,
            };

            /// assign the xdg_toplevel surface role
            ///
            /// This creates an xdg_toplevel object for the given xdg_surface and gives
            /// the associated wl_surface the xdg_toplevel role.
            ///
            /// See the documentation of xdg_toplevel for more details about what an
            /// xdg_toplevel is and how it is used.
            ///
            const GetToplevelMessage = struct {
                xdg_surface: XdgSurface,
                id: u32,
            };

            /// assign the xdg_popup surface role
            ///
            /// This creates an xdg_popup object for the given xdg_surface and gives
            /// the associated wl_surface the xdg_popup role.
            ///
            /// If null is passed as a parent, a parent surface must be specified using
            /// some other protocol, before committing the initial state.
            ///
            /// See the documentation of xdg_popup for more details about what an
            /// xdg_popup is and how it is used.
            ///
            const GetPopupMessage = struct {
                xdg_surface: XdgSurface,
                id: u32,
                parent: ?XdgSurface,
                positioner: XdgPositioner,
            };

            /// set the new window geometry
            ///
            /// The window geometry of a surface is its "visible bounds" from the
            /// user's perspective. Client-side decorations often have invisible
            /// portions like drop-shadows which should be ignored for the
            /// purposes of aligning, placing and constraining windows.
            ///
            /// The window geometry is double buffered, and will be applied at the
            /// time wl_surface.commit of the corresponding wl_surface is called.
            ///
            /// When maintaining a position, the compositor should treat the (x, y)
            /// coordinate of the window geometry as the top left corner of the window.
            /// A client changing the (x, y) window geometry coordinate should in
            /// general not alter the position of the window.
            ///
            /// Once the window geometry of the surface is set, it is not possible to
            /// unset it, and it will remain the same until set_window_geometry is
            /// called again, even if a new subsurface or buffer is attached.
            ///
            /// If never set, the value is the full bounds of the surface,
            /// including any subsurfaces. This updates dynamically on every
            /// commit. This unset is meant for extremely simple clients.
            ///
            /// The arguments are given in the surface-local coordinate space of
            /// the wl_surface associated with this xdg_surface.
            ///
            /// The width and height must be greater than zero. Setting an invalid size
            /// will raise an error. When applied, the effective window geometry will be
            /// the set window geometry clamped to the bounding rectangle of the
            /// combined geometry of the surface of the xdg_surface and the associated
            /// subsurfaces.
            ///
            const SetWindowGeometryMessage = struct {
                xdg_surface: XdgSurface,
                x: i32,
                y: i32,
                width: i32,
                height: i32,
            };

            /// ack a configure event
            ///
            /// When a configure event is received, if a client commits the
            /// surface in response to the configure event, then the client
            /// must make an ack_configure request sometime before the commit
            /// request, passing along the serial of the configure event.
            ///
            /// For instance, for toplevel surfaces the compositor might use this
            /// information to move a surface to the top left only when the client has
            /// drawn itself for the maximized or fullscreen state.
            ///
            /// If the client receives multiple configure events before it
            /// can respond to one, it only has to ack the last configure event.
            ///
            /// A client is not required to commit immediately after sending
            /// an ack_configure request - it may even ack_configure several times
            /// before its next surface commit.
            ///
            /// A client may send multiple ack_configure requests before committing, but
            /// only the last request sent before a commit indicates which configure
            /// event the client really is responding to.
            ///
            const AckConfigureMessage = struct {
                xdg_surface: XdgSurface,
                /// the serial from the configure event
                serial: u32,
            };

            //
            // The configure event marks the end of a configure sequence. A configure
            // sequence is a set of one or more events configuring the state of the
            // xdg_surface, including the final xdg_surface.configure event.
            //
            // Where applicable, xdg_surface surface roles will during a configure
            // sequence extend this event as a latched state sent as events before the
            // xdg_surface.configure event. Such events should be considered to make up
            // a set of atomically applied configuration states, where the
            // xdg_surface.configure commits the accumulated state.
            //
            // Clients should arrange their surface for the new states, and then send
            // an ack_configure request with the serial sent in this configure event at
            // some point before committing the new surface.
            //
            // If the client receives multiple configure events before it can respond
            // to one, it is free to discard all but the last event it received.
            //
            pub fn sendConfigure(self: Self, serial: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(serial);
                try self.wire.finishWrite(self.id, 0);
            }
        };

        /// xdg_toplevel
        /// toplevel surface
        ///
        /// This interface defines an xdg_surface role which allows a surface to,
        /// among other things, set window-like properties such as maximize,
        /// fullscreen, and minimize, set application-specific metadata like title and
        /// id, and well as trigger user interactive operations such as interactive
        /// resize and move.
        ///
        /// Unmapping an xdg_toplevel means that the surface cannot be shown
        /// by the compositor until it is explicitly mapped again.
        /// All active operations (e.g., move, resize) are canceled and all
        /// attributes (e.g. title, state, stacking, ...) are discarded for
        /// an xdg_toplevel surface when it is unmapped. The xdg_toplevel returns to
        /// the state it had right after xdg_surface.get_toplevel. The client
        /// can re-map the toplevel by perfoming a commit without any buffer
        /// attached, waiting for a configure event and handling it as usual (see
        /// xdg_surface description).
        ///
        /// Attaching a null buffer to a toplevel unmaps the surface.
        ///
        pub const XdgToplevel = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.xdg_toplevel,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.xdg_toplevel) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                invalid_resize_edge = 0,
            };

            pub const ResizeEdge = enum(u32) {
                none = 0,
                top = 1,
                bottom = 2,
                left = 4,
                top_left = 5,
                bottom_left = 6,
                right = 8,
                top_right = 9,
                bottom_right = 10,
            };

            pub const State = enum(u32) {
                maximized = 1,
                fullscreen = 2,
                resizing = 3,
                activated = 4,
                tiled_left = 5,
                tiled_right = 6,
                tiled_top = 7,
                tiled_bottom = 8,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .xdg_toplevel = self.*,
                            },
                        };
                    },
                    // set_parent
                    1 => {
                        const parent: ?XdgToplevel = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .xdg_toplevel => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        return Message{
                            .set_parent = SetParentMessage{
                                .xdg_toplevel = self.*,
                                .parent = parent,
                            },
                        };
                    },
                    // set_title
                    2 => {
                        const title: []u8 = try self.wire.nextString();
                        return Message{
                            .set_title = SetTitleMessage{
                                .xdg_toplevel = self.*,
                                .title = title,
                            },
                        };
                    },
                    // set_app_id
                    3 => {
                        const app_id: []u8 = try self.wire.nextString();
                        return Message{
                            .set_app_id = SetAppIdMessage{
                                .xdg_toplevel = self.*,
                                .app_id = app_id,
                            },
                        };
                    },
                    // show_window_menu
                    4 => {
                        const seat: WlSeat = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_seat => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const serial: u32 = try self.wire.nextU32();
                        const x: i32 = try self.wire.nextI32();
                        const y: i32 = try self.wire.nextI32();
                        return Message{
                            .show_window_menu = ShowWindowMenuMessage{
                                .xdg_toplevel = self.*,
                                .seat = seat,
                                .serial = serial,
                                .x = x,
                                .y = y,
                            },
                        };
                    },
                    // move
                    5 => {
                        const seat: WlSeat = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_seat => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const serial: u32 = try self.wire.nextU32();
                        return Message{
                            .move = MoveMessage{
                                .xdg_toplevel = self.*,
                                .seat = seat,
                                .serial = serial,
                            },
                        };
                    },
                    // resize
                    6 => {
                        const seat: WlSeat = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_seat => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const serial: u32 = try self.wire.nextU32();
                        const edges: ResizeEdge = @enumFromInt(try self.wire.nextU32()); // enum
                        return Message{
                            .resize = ResizeMessage{
                                .xdg_toplevel = self.*,
                                .seat = seat,
                                .serial = serial,
                                .edges = edges,
                            },
                        };
                    },
                    // set_max_size
                    7 => {
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        return Message{
                            .set_max_size = SetMaxSizeMessage{
                                .xdg_toplevel = self.*,
                                .width = width,
                                .height = height,
                            },
                        };
                    },
                    // set_min_size
                    8 => {
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        return Message{
                            .set_min_size = SetMinSizeMessage{
                                .xdg_toplevel = self.*,
                                .width = width,
                                .height = height,
                            },
                        };
                    },
                    // set_maximized
                    9 => {
                        return Message{
                            .set_maximized = SetMaximizedMessage{
                                .xdg_toplevel = self.*,
                            },
                        };
                    },
                    // unset_maximized
                    10 => {
                        return Message{
                            .unset_maximized = UnsetMaximizedMessage{
                                .xdg_toplevel = self.*,
                            },
                        };
                    },
                    // set_fullscreen
                    11 => {
                        const output: ?WlOutput = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_output => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else null;
                        return Message{
                            .set_fullscreen = SetFullscreenMessage{
                                .xdg_toplevel = self.*,
                                .output = output,
                            },
                        };
                    },
                    // unset_fullscreen
                    12 => {
                        return Message{
                            .unset_fullscreen = UnsetFullscreenMessage{
                                .xdg_toplevel = self.*,
                            },
                        };
                    },
                    // set_minimized
                    13 => {
                        return Message{
                            .set_minimized = SetMinimizedMessage{
                                .xdg_toplevel = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                set_parent,
                set_title,
                set_app_id,
                show_window_menu,
                move,
                resize,
                set_max_size,
                set_min_size,
                set_maximized,
                unset_maximized,
                set_fullscreen,
                unset_fullscreen,
                set_minimized,
            };

            pub const Message = union(MessageType) {
                /// destroy the xdg_toplevel
                ///
                /// This request destroys the role surface and unmaps the surface;
                /// see "Unmapping" behavior in interface section for details.
                ///
                destroy: DestroyMessage,

                /// set the parent of this surface
                ///
                /// Set the "parent" of this surface. This surface should be stacked
                /// above the parent surface and all other ancestor surfaces.
                ///
                /// Parent windows should be set on dialogs, toolboxes, or other
                /// "auxiliary" surfaces, so that the parent is raised when the dialog
                /// is raised.
                ///
                /// Setting a null parent for a child window removes any parent-child
                /// relationship for the child. Setting a null parent for a window which
                /// currently has no parent is a no-op.
                ///
                /// If the parent is unmapped then its children are managed as
                /// though the parent of the now-unmapped parent has become the
                /// parent of this surface. If no parent exists for the now-unmapped
                /// parent then the children are managed as though they have no
                /// parent surface.
                ///
                set_parent: SetParentMessage,

                /// set surface title
                ///
                /// Set a short title for the surface.
                ///
                /// This string may be used to identify the surface in a task bar,
                /// window list, or other user interface elements provided by the
                /// compositor.
                ///
                /// The string must be encoded in UTF-8.
                ///
                set_title: SetTitleMessage,

                /// set application ID
                ///
                /// Set an application identifier for the surface.
                ///
                /// The app ID identifies the general class of applications to which
                /// the surface belongs. The compositor can use this to group multiple
                /// surfaces together, or to determine how to launch a new application.
                ///
                /// For D-Bus activatable applications, the app ID is used as the D-Bus
                /// service name.
                ///
                /// The compositor shell will try to group application surfaces together
                /// by their app ID. As a best practice, it is suggested to select app
                /// ID's that match the basename of the application's .desktop file.
                /// For example, "org.freedesktop.FooViewer" where the .desktop file is
                /// "org.freedesktop.FooViewer.desktop".
                ///
                /// Like other properties, a set_app_id request can be sent after the
                /// xdg_toplevel has been mapped to update the property.
                ///
                /// See the desktop-entry specification [0] for more details on
                /// application identifiers and how they relate to well-known D-Bus
                /// names and .desktop files.
                ///
                /// [0] http://standards.freedesktop.org/desktop-entry-spec/
                ///
                set_app_id: SetAppIdMessage,

                /// show the window menu
                ///
                /// Clients implementing client-side decorations might want to show
                /// a context menu when right-clicking on the decorations, giving the
                /// user a menu that they can use to maximize or minimize the window.
                ///
                /// This request asks the compositor to pop up such a window menu at
                /// the given position, relative to the local surface coordinates of
                /// the parent surface. There are no guarantees as to what menu items
                /// the window menu contains.
                ///
                /// This request must be used in response to some sort of user action
                /// like a button press, key press, or touch down event.
                ///
                show_window_menu: ShowWindowMenuMessage,

                /// start an interactive move
                ///
                /// Start an interactive, user-driven move of the surface.
                ///
                /// This request must be used in response to some sort of user action
                /// like a button press, key press, or touch down event. The passed
                /// serial is used to determine the type of interactive move (touch,
                /// pointer, etc).
                ///
                /// The server may ignore move requests depending on the state of
                /// the surface (e.g. fullscreen or maximized), or if the passed serial
                /// is no longer valid.
                ///
                /// If triggered, the surface will lose the focus of the device
                /// (wl_pointer, wl_touch, etc) used for the move. It is up to the
                /// compositor to visually indicate that the move is taking place, such as
                /// updating a pointer cursor, during the move. There is no guarantee
                /// that the device focus will return when the move is completed.
                ///
                move: MoveMessage,

                /// start an interactive resize
                ///
                /// Start a user-driven, interactive resize of the surface.
                ///
                /// This request must be used in response to some sort of user action
                /// like a button press, key press, or touch down event. The passed
                /// serial is used to determine the type of interactive resize (touch,
                /// pointer, etc).
                ///
                /// The server may ignore resize requests depending on the state of
                /// the surface (e.g. fullscreen or maximized).
                ///
                /// If triggered, the client will receive configure events with the
                /// "resize" state enum value and the expected sizes. See the "resize"
                /// enum value for more details about what is required. The client
                /// must also acknowledge configure events using "ack_configure". After
                /// the resize is completed, the client will receive another "configure"
                /// event without the resize state.
                ///
                /// If triggered, the surface also will lose the focus of the device
                /// (wl_pointer, wl_touch, etc) used for the resize. It is up to the
                /// compositor to visually indicate that the resize is taking place,
                /// such as updating a pointer cursor, during the resize. There is no
                /// guarantee that the device focus will return when the resize is
                /// completed.
                ///
                /// The edges parameter specifies how the surface should be resized, and
                /// is one of the values of the resize_edge enum. Values not matching
                /// a variant of the enum will cause a protocol error. The compositor
                /// may use this information to update the surface position for example
                /// when dragging the top left corner. The compositor may also use
                /// this information to adapt its behavior, e.g. choose an appropriate
                /// cursor image.
                ///
                resize: ResizeMessage,

                /// set the maximum size
                ///
                /// Set a maximum size for the window.
                ///
                /// The client can specify a maximum size so that the compositor does
                /// not try to configure the window beyond this size.
                ///
                /// The width and height arguments are in window geometry coordinates.
                /// See xdg_surface.set_window_geometry.
                ///
                /// Values set in this way are double-buffered. They will get applied
                /// on the next commit.
                ///
                /// The compositor can use this information to allow or disallow
                /// different states like maximize or fullscreen and draw accurate
                /// animations.
                ///
                /// Similarly, a tiling window manager may use this information to
                /// place and resize client windows in a more effective way.
                ///
                /// The client should not rely on the compositor to obey the maximum
                /// size. The compositor may decide to ignore the values set by the
                /// client and request a larger size.
                ///
                /// If never set, or a value of zero in the request, means that the
                /// client has no expected maximum size in the given dimension.
                /// As a result, a client wishing to reset the maximum size
                /// to an unspecified state can use zero for width and height in the
                /// request.
                ///
                /// Requesting a maximum size to be smaller than the minimum size of
                /// a surface is illegal and will result in a protocol error.
                ///
                /// The width and height must be greater than or equal to zero. Using
                /// strictly negative values for width and height will result in a
                /// protocol error.
                ///
                set_max_size: SetMaxSizeMessage,

                /// set the minimum size
                ///
                /// Set a minimum size for the window.
                ///
                /// The client can specify a minimum size so that the compositor does
                /// not try to configure the window below this size.
                ///
                /// The width and height arguments are in window geometry coordinates.
                /// See xdg_surface.set_window_geometry.
                ///
                /// Values set in this way are double-buffered. They will get applied
                /// on the next commit.
                ///
                /// The compositor can use this information to allow or disallow
                /// different states like maximize or fullscreen and draw accurate
                /// animations.
                ///
                /// Similarly, a tiling window manager may use this information to
                /// place and resize client windows in a more effective way.
                ///
                /// The client should not rely on the compositor to obey the minimum
                /// size. The compositor may decide to ignore the values set by the
                /// client and request a smaller size.
                ///
                /// If never set, or a value of zero in the request, means that the
                /// client has no expected minimum size in the given dimension.
                /// As a result, a client wishing to reset the minimum size
                /// to an unspecified state can use zero for width and height in the
                /// request.
                ///
                /// Requesting a minimum size to be larger than the maximum size of
                /// a surface is illegal and will result in a protocol error.
                ///
                /// The width and height must be greater than or equal to zero. Using
                /// strictly negative values for width and height will result in a
                /// protocol error.
                ///
                set_min_size: SetMinSizeMessage,

                /// maximize the window
                ///
                /// Maximize the surface.
                ///
                /// After requesting that the surface should be maximized, the compositor
                /// will respond by emitting a configure event. Whether this configure
                /// actually sets the window maximized is subject to compositor policies.
                /// The client must then update its content, drawing in the configured
                /// state. The client must also acknowledge the configure when committing
                /// the new content (see ack_configure).
                ///
                /// It is up to the compositor to decide how and where to maximize the
                /// surface, for example which output and what region of the screen should
                /// be used.
                ///
                /// If the surface was already maximized, the compositor will still emit
                /// a configure event with the "maximized" state.
                ///
                /// If the surface is in a fullscreen state, this request has no direct
                /// effect. It may alter the state the surface is returned to when
                /// unmaximized unless overridden by the compositor.
                ///
                set_maximized: SetMaximizedMessage,

                /// unmaximize the window
                ///
                /// Unmaximize the surface.
                ///
                /// After requesting that the surface should be unmaximized, the compositor
                /// will respond by emitting a configure event. Whether this actually
                /// un-maximizes the window is subject to compositor policies.
                /// If available and applicable, the compositor will include the window
                /// geometry dimensions the window had prior to being maximized in the
                /// configure event. The client must then update its content, drawing it in
                /// the configured state. The client must also acknowledge the configure
                /// when committing the new content (see ack_configure).
                ///
                /// It is up to the compositor to position the surface after it was
                /// unmaximized; usually the position the surface had before maximizing, if
                /// applicable.
                ///
                /// If the surface was already not maximized, the compositor will still
                /// emit a configure event without the "maximized" state.
                ///
                /// If the surface is in a fullscreen state, this request has no direct
                /// effect. It may alter the state the surface is returned to when
                /// unmaximized unless overridden by the compositor.
                ///
                unset_maximized: UnsetMaximizedMessage,

                /// set the window as fullscreen on an output
                ///
                /// Make the surface fullscreen.
                ///
                /// After requesting that the surface should be fullscreened, the
                /// compositor will respond by emitting a configure event. Whether the
                /// client is actually put into a fullscreen state is subject to compositor
                /// policies. The client must also acknowledge the configure when
                /// committing the new content (see ack_configure).
                ///
                /// The output passed by the request indicates the client's preference as
                /// to which display it should be set fullscreen on. If this value is NULL,
                /// it's up to the compositor to choose which display will be used to map
                /// this surface.
                ///
                /// If the surface doesn't cover the whole output, the compositor will
                /// position the surface in the center of the output and compensate with
                /// with border fill covering the rest of the output. The content of the
                /// border fill is undefined, but should be assumed to be in some way that
                /// attempts to blend into the surrounding area (e.g. solid black).
                ///
                /// If the fullscreened surface is not opaque, the compositor must make
                /// sure that other screen content not part of the same surface tree (made
                /// up of subsurfaces, popups or similarly coupled surfaces) are not
                /// visible below the fullscreened surface.
                ///
                set_fullscreen: SetFullscreenMessage,

                /// unset the window as fullscreen
                ///
                /// Make the surface no longer fullscreen.
                ///
                /// After requesting that the surface should be unfullscreened, the
                /// compositor will respond by emitting a configure event.
                /// Whether this actually removes the fullscreen state of the client is
                /// subject to compositor policies.
                ///
                /// Making a surface unfullscreen sets states for the surface based on the following:
                /// * the state(s) it may have had before becoming fullscreen
                /// * any state(s) decided by the compositor
                /// * any state(s) requested by the client while the surface was fullscreen
                ///
                /// The compositor may include the previous window geometry dimensions in
                /// the configure event, if applicable.
                ///
                /// The client must also acknowledge the configure when committing the new
                /// content (see ack_configure).
                ///
                unset_fullscreen: UnsetFullscreenMessage,

                /// set the window as minimized
                ///
                /// Request that the compositor minimize your surface. There is no
                /// way to know if the surface is currently minimized, nor is there
                /// any way to unset minimization on this surface.
                ///
                /// If you are looking to throttle redrawing when minimized, please
                /// instead use the wl_surface.frame event for this, as this will
                /// also work with live previews on windows in Alt-Tab, Expose or
                /// similar compositor features.
                ///
                set_minimized: SetMinimizedMessage,
            };

            /// destroy the xdg_toplevel
            ///
            /// This request destroys the role surface and unmaps the surface;
            /// see "Unmapping" behavior in interface section for details.
            ///
            const DestroyMessage = struct {
                xdg_toplevel: XdgToplevel,
            };

            /// set the parent of this surface
            ///
            /// Set the "parent" of this surface. This surface should be stacked
            /// above the parent surface and all other ancestor surfaces.
            ///
            /// Parent windows should be set on dialogs, toolboxes, or other
            /// "auxiliary" surfaces, so that the parent is raised when the dialog
            /// is raised.
            ///
            /// Setting a null parent for a child window removes any parent-child
            /// relationship for the child. Setting a null parent for a window which
            /// currently has no parent is a no-op.
            ///
            /// If the parent is unmapped then its children are managed as
            /// though the parent of the now-unmapped parent has become the
            /// parent of this surface. If no parent exists for the now-unmapped
            /// parent then the children are managed as though they have no
            /// parent surface.
            ///
            const SetParentMessage = struct {
                xdg_toplevel: XdgToplevel,
                parent: ?XdgToplevel,
            };

            /// set surface title
            ///
            /// Set a short title for the surface.
            ///
            /// This string may be used to identify the surface in a task bar,
            /// window list, or other user interface elements provided by the
            /// compositor.
            ///
            /// The string must be encoded in UTF-8.
            ///
            const SetTitleMessage = struct {
                xdg_toplevel: XdgToplevel,
                title: []u8,
            };

            /// set application ID
            ///
            /// Set an application identifier for the surface.
            ///
            /// The app ID identifies the general class of applications to which
            /// the surface belongs. The compositor can use this to group multiple
            /// surfaces together, or to determine how to launch a new application.
            ///
            /// For D-Bus activatable applications, the app ID is used as the D-Bus
            /// service name.
            ///
            /// The compositor shell will try to group application surfaces together
            /// by their app ID. As a best practice, it is suggested to select app
            /// ID's that match the basename of the application's .desktop file.
            /// For example, "org.freedesktop.FooViewer" where the .desktop file is
            /// "org.freedesktop.FooViewer.desktop".
            ///
            /// Like other properties, a set_app_id request can be sent after the
            /// xdg_toplevel has been mapped to update the property.
            ///
            /// See the desktop-entry specification [0] for more details on
            /// application identifiers and how they relate to well-known D-Bus
            /// names and .desktop files.
            ///
            /// [0] http://standards.freedesktop.org/desktop-entry-spec/
            ///
            const SetAppIdMessage = struct {
                xdg_toplevel: XdgToplevel,
                app_id: []u8,
            };

            /// show the window menu
            ///
            /// Clients implementing client-side decorations might want to show
            /// a context menu when right-clicking on the decorations, giving the
            /// user a menu that they can use to maximize or minimize the window.
            ///
            /// This request asks the compositor to pop up such a window menu at
            /// the given position, relative to the local surface coordinates of
            /// the parent surface. There are no guarantees as to what menu items
            /// the window menu contains.
            ///
            /// This request must be used in response to some sort of user action
            /// like a button press, key press, or touch down event.
            ///
            const ShowWindowMenuMessage = struct {
                xdg_toplevel: XdgToplevel,
                /// the wl_seat of the user event
                seat: WlSeat,
                /// the serial of the user event
                serial: u32,
                /// the x position to pop up the window menu at
                x: i32,
                /// the y position to pop up the window menu at
                y: i32,
            };

            /// start an interactive move
            ///
            /// Start an interactive, user-driven move of the surface.
            ///
            /// This request must be used in response to some sort of user action
            /// like a button press, key press, or touch down event. The passed
            /// serial is used to determine the type of interactive move (touch,
            /// pointer, etc).
            ///
            /// The server may ignore move requests depending on the state of
            /// the surface (e.g. fullscreen or maximized), or if the passed serial
            /// is no longer valid.
            ///
            /// If triggered, the surface will lose the focus of the device
            /// (wl_pointer, wl_touch, etc) used for the move. It is up to the
            /// compositor to visually indicate that the move is taking place, such as
            /// updating a pointer cursor, during the move. There is no guarantee
            /// that the device focus will return when the move is completed.
            ///
            const MoveMessage = struct {
                xdg_toplevel: XdgToplevel,
                /// the wl_seat of the user event
                seat: WlSeat,
                /// the serial of the user event
                serial: u32,
            };

            /// start an interactive resize
            ///
            /// Start a user-driven, interactive resize of the surface.
            ///
            /// This request must be used in response to some sort of user action
            /// like a button press, key press, or touch down event. The passed
            /// serial is used to determine the type of interactive resize (touch,
            /// pointer, etc).
            ///
            /// The server may ignore resize requests depending on the state of
            /// the surface (e.g. fullscreen or maximized).
            ///
            /// If triggered, the client will receive configure events with the
            /// "resize" state enum value and the expected sizes. See the "resize"
            /// enum value for more details about what is required. The client
            /// must also acknowledge configure events using "ack_configure". After
            /// the resize is completed, the client will receive another "configure"
            /// event without the resize state.
            ///
            /// If triggered, the surface also will lose the focus of the device
            /// (wl_pointer, wl_touch, etc) used for the resize. It is up to the
            /// compositor to visually indicate that the resize is taking place,
            /// such as updating a pointer cursor, during the resize. There is no
            /// guarantee that the device focus will return when the resize is
            /// completed.
            ///
            /// The edges parameter specifies how the surface should be resized, and
            /// is one of the values of the resize_edge enum. Values not matching
            /// a variant of the enum will cause a protocol error. The compositor
            /// may use this information to update the surface position for example
            /// when dragging the top left corner. The compositor may also use
            /// this information to adapt its behavior, e.g. choose an appropriate
            /// cursor image.
            ///
            const ResizeMessage = struct {
                xdg_toplevel: XdgToplevel,
                /// the wl_seat of the user event
                seat: WlSeat,
                /// the serial of the user event
                serial: u32,
                /// which edge or corner is being dragged
                edges: ResizeEdge,
            };

            /// set the maximum size
            ///
            /// Set a maximum size for the window.
            ///
            /// The client can specify a maximum size so that the compositor does
            /// not try to configure the window beyond this size.
            ///
            /// The width and height arguments are in window geometry coordinates.
            /// See xdg_surface.set_window_geometry.
            ///
            /// Values set in this way are double-buffered. They will get applied
            /// on the next commit.
            ///
            /// The compositor can use this information to allow or disallow
            /// different states like maximize or fullscreen and draw accurate
            /// animations.
            ///
            /// Similarly, a tiling window manager may use this information to
            /// place and resize client windows in a more effective way.
            ///
            /// The client should not rely on the compositor to obey the maximum
            /// size. The compositor may decide to ignore the values set by the
            /// client and request a larger size.
            ///
            /// If never set, or a value of zero in the request, means that the
            /// client has no expected maximum size in the given dimension.
            /// As a result, a client wishing to reset the maximum size
            /// to an unspecified state can use zero for width and height in the
            /// request.
            ///
            /// Requesting a maximum size to be smaller than the minimum size of
            /// a surface is illegal and will result in a protocol error.
            ///
            /// The width and height must be greater than or equal to zero. Using
            /// strictly negative values for width and height will result in a
            /// protocol error.
            ///
            const SetMaxSizeMessage = struct {
                xdg_toplevel: XdgToplevel,
                width: i32,
                height: i32,
            };

            /// set the minimum size
            ///
            /// Set a minimum size for the window.
            ///
            /// The client can specify a minimum size so that the compositor does
            /// not try to configure the window below this size.
            ///
            /// The width and height arguments are in window geometry coordinates.
            /// See xdg_surface.set_window_geometry.
            ///
            /// Values set in this way are double-buffered. They will get applied
            /// on the next commit.
            ///
            /// The compositor can use this information to allow or disallow
            /// different states like maximize or fullscreen and draw accurate
            /// animations.
            ///
            /// Similarly, a tiling window manager may use this information to
            /// place and resize client windows in a more effective way.
            ///
            /// The client should not rely on the compositor to obey the minimum
            /// size. The compositor may decide to ignore the values set by the
            /// client and request a smaller size.
            ///
            /// If never set, or a value of zero in the request, means that the
            /// client has no expected minimum size in the given dimension.
            /// As a result, a client wishing to reset the minimum size
            /// to an unspecified state can use zero for width and height in the
            /// request.
            ///
            /// Requesting a minimum size to be larger than the maximum size of
            /// a surface is illegal and will result in a protocol error.
            ///
            /// The width and height must be greater than or equal to zero. Using
            /// strictly negative values for width and height will result in a
            /// protocol error.
            ///
            const SetMinSizeMessage = struct {
                xdg_toplevel: XdgToplevel,
                width: i32,
                height: i32,
            };

            /// maximize the window
            ///
            /// Maximize the surface.
            ///
            /// After requesting that the surface should be maximized, the compositor
            /// will respond by emitting a configure event. Whether this configure
            /// actually sets the window maximized is subject to compositor policies.
            /// The client must then update its content, drawing in the configured
            /// state. The client must also acknowledge the configure when committing
            /// the new content (see ack_configure).
            ///
            /// It is up to the compositor to decide how and where to maximize the
            /// surface, for example which output and what region of the screen should
            /// be used.
            ///
            /// If the surface was already maximized, the compositor will still emit
            /// a configure event with the "maximized" state.
            ///
            /// If the surface is in a fullscreen state, this request has no direct
            /// effect. It may alter the state the surface is returned to when
            /// unmaximized unless overridden by the compositor.
            ///
            const SetMaximizedMessage = struct {
                xdg_toplevel: XdgToplevel,
            };

            /// unmaximize the window
            ///
            /// Unmaximize the surface.
            ///
            /// After requesting that the surface should be unmaximized, the compositor
            /// will respond by emitting a configure event. Whether this actually
            /// un-maximizes the window is subject to compositor policies.
            /// If available and applicable, the compositor will include the window
            /// geometry dimensions the window had prior to being maximized in the
            /// configure event. The client must then update its content, drawing it in
            /// the configured state. The client must also acknowledge the configure
            /// when committing the new content (see ack_configure).
            ///
            /// It is up to the compositor to position the surface after it was
            /// unmaximized; usually the position the surface had before maximizing, if
            /// applicable.
            ///
            /// If the surface was already not maximized, the compositor will still
            /// emit a configure event without the "maximized" state.
            ///
            /// If the surface is in a fullscreen state, this request has no direct
            /// effect. It may alter the state the surface is returned to when
            /// unmaximized unless overridden by the compositor.
            ///
            const UnsetMaximizedMessage = struct {
                xdg_toplevel: XdgToplevel,
            };

            /// set the window as fullscreen on an output
            ///
            /// Make the surface fullscreen.
            ///
            /// After requesting that the surface should be fullscreened, the
            /// compositor will respond by emitting a configure event. Whether the
            /// client is actually put into a fullscreen state is subject to compositor
            /// policies. The client must also acknowledge the configure when
            /// committing the new content (see ack_configure).
            ///
            /// The output passed by the request indicates the client's preference as
            /// to which display it should be set fullscreen on. If this value is NULL,
            /// it's up to the compositor to choose which display will be used to map
            /// this surface.
            ///
            /// If the surface doesn't cover the whole output, the compositor will
            /// position the surface in the center of the output and compensate with
            /// with border fill covering the rest of the output. The content of the
            /// border fill is undefined, but should be assumed to be in some way that
            /// attempts to blend into the surrounding area (e.g. solid black).
            ///
            /// If the fullscreened surface is not opaque, the compositor must make
            /// sure that other screen content not part of the same surface tree (made
            /// up of subsurfaces, popups or similarly coupled surfaces) are not
            /// visible below the fullscreened surface.
            ///
            const SetFullscreenMessage = struct {
                xdg_toplevel: XdgToplevel,
                output: ?WlOutput,
            };

            /// unset the window as fullscreen
            ///
            /// Make the surface no longer fullscreen.
            ///
            /// After requesting that the surface should be unfullscreened, the
            /// compositor will respond by emitting a configure event.
            /// Whether this actually removes the fullscreen state of the client is
            /// subject to compositor policies.
            ///
            /// Making a surface unfullscreen sets states for the surface based on the following:
            /// * the state(s) it may have had before becoming fullscreen
            /// * any state(s) decided by the compositor
            /// * any state(s) requested by the client while the surface was fullscreen
            ///
            /// The compositor may include the previous window geometry dimensions in
            /// the configure event, if applicable.
            ///
            /// The client must also acknowledge the configure when committing the new
            /// content (see ack_configure).
            ///
            const UnsetFullscreenMessage = struct {
                xdg_toplevel: XdgToplevel,
            };

            /// set the window as minimized
            ///
            /// Request that the compositor minimize your surface. There is no
            /// way to know if the surface is currently minimized, nor is there
            /// any way to unset minimization on this surface.
            ///
            /// If you are looking to throttle redrawing when minimized, please
            /// instead use the wl_surface.frame event for this, as this will
            /// also work with live previews on windows in Alt-Tab, Expose or
            /// similar compositor features.
            ///
            const SetMinimizedMessage = struct {
                xdg_toplevel: XdgToplevel,
            };

            //
            // This configure event asks the client to resize its toplevel surface or
            // to change its state. The configured state should not be applied
            // immediately. See xdg_surface.configure for details.
            //
            // The width and height arguments specify a hint to the window
            // about how its surface should be resized in window geometry
            // coordinates. See set_window_geometry.
            //
            // If the width or height arguments are zero, it means the client
            // should decide its own window dimension. This may happen when the
            // compositor needs to configure the state of the surface but doesn't
            // have any information about any previous or expected dimension.
            //
            // The states listed in the event specify how the width/height
            // arguments should be interpreted, and possibly how it should be
            // drawn.
            //
            // Clients must send an ack_configure in response to this event. See
            // xdg_surface.configure and xdg_surface.ack_configure for details.
            //
            pub fn sendConfigure(self: Self, width: i32, height: i32, states: []u8) !void {
                try self.wire.startWrite();
                try self.wire.putI32(width);
                try self.wire.putI32(height);
                try self.wire.putArray(states);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // The close event is sent by the compositor when the user
            // wants the surface to be closed. This should be equivalent to
            // the user clicking the close button in client-side decorations,
            // if your application has any.
            //
            // This is only a request that the user intends to close the
            // window. The client may choose to ignore this request, or show
            // a dialog to ask the user to save their data, etc.
            //
            pub fn sendClose(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 1);
            }

            //
            // The configure_bounds event may be sent prior to a xdg_toplevel.configure
            // event to communicate the bounds a window geometry size is recommended
            // to constrain to.
            //
            // The passed width and height are in surface coordinate space. If width
            // and height are 0, it means bounds is unknown and equivalent to as if no
            // configure_bounds event was ever sent for this surface.
            //
            // The bounds can for example correspond to the size of a monitor excluding
            // any panels or other shell components, so that a surface isn't created in
            // a way that it cannot fit.
            //
            // The bounds may change at any point, and in such a case, a new
            // xdg_toplevel.configure_bounds will be sent, followed by
            // xdg_toplevel.configure and xdg_surface.configure.
            //
            pub fn sendConfigureBounds(self: Self, width: i32, height: i32) !void {
                try self.wire.startWrite();
                try self.wire.putI32(width);
                try self.wire.putI32(height);
                try self.wire.finishWrite(self.id, 2);
            }
        };

        /// xdg_popup
        /// short-lived, popup surfaces for menus
        ///
        /// A popup surface is a short-lived, temporary surface. It can be used to
        /// implement for example menus, popovers, tooltips and other similar user
        /// interface concepts.
        ///
        /// A popup can be made to take an explicit grab. See xdg_popup.grab for
        /// details.
        ///
        /// When the popup is dismissed, a popup_done event will be sent out, and at
        /// the same time the surface will be unmapped. See the xdg_popup.popup_done
        /// event for details.
        ///
        /// Explicitly destroying the xdg_popup object will also dismiss the popup and
        /// unmap the surface. Clients that want to dismiss the popup when another
        /// surface of their own is clicked should dismiss the popup using the destroy
        /// request.
        ///
        /// A newly created xdg_popup will be stacked on top of all previously created
        /// xdg_popup surfaces associated with the same xdg_toplevel.
        ///
        /// The parent of an xdg_popup must be mapped (see the xdg_surface
        /// description) before the xdg_popup itself.
        ///
        /// The client must call wl_surface.commit on the corresponding wl_surface
        /// for the xdg_popup state to take effect.
        ///
        pub const XdgPopup = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.xdg_popup,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.xdg_popup) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                invalid_grab = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .xdg_popup = self.*,
                            },
                        };
                    },
                    // grab
                    1 => {
                        const seat: WlSeat = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_seat => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const serial: u32 = try self.wire.nextU32();
                        return Message{
                            .grab = GrabMessage{
                                .xdg_popup = self.*,
                                .seat = seat,
                                .serial = serial,
                            },
                        };
                    },
                    // reposition
                    2 => {
                        const positioner: XdgPositioner = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .xdg_positioner => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        const token: u32 = try self.wire.nextU32();
                        return Message{
                            .reposition = RepositionMessage{
                                .xdg_popup = self.*,
                                .positioner = positioner,
                                .token = token,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                grab,
                reposition,
            };

            pub const Message = union(MessageType) {
                /// remove xdg_popup interface
                ///
                /// This destroys the popup. Explicitly destroying the xdg_popup
                /// object will also dismiss the popup, and unmap the surface.
                ///
                /// If this xdg_popup is not the "topmost" popup, a protocol error
                /// will be sent.
                ///
                destroy: DestroyMessage,

                /// make the popup take an explicit grab
                ///
                /// This request makes the created popup take an explicit grab. An explicit
                /// grab will be dismissed when the user dismisses the popup, or when the
                /// client destroys the xdg_popup. This can be done by the user clicking
                /// outside the surface, using the keyboard, or even locking the screen
                /// through closing the lid or a timeout.
                ///
                /// If the compositor denies the grab, the popup will be immediately
                /// dismissed.
                ///
                /// This request must be used in response to some sort of user action like a
                /// button press, key press, or touch down event. The serial number of the
                /// event should be passed as 'serial'.
                ///
                /// The parent of a grabbing popup must either be an xdg_toplevel surface or
                /// another xdg_popup with an explicit grab. If the parent is another
                /// xdg_popup it means that the popups are nested, with this popup now being
                /// the topmost popup.
                ///
                /// Nested popups must be destroyed in the reverse order they were created
                /// in, e.g. the only popup you are allowed to destroy at all times is the
                /// topmost one.
                ///
                /// When compositors choose to dismiss a popup, they may dismiss every
                /// nested grabbing popup as well. When a compositor dismisses popups, it
                /// will follow the same dismissing order as required from the client.
                ///
                /// The parent of a grabbing popup must either be another xdg_popup with an
                /// active explicit grab, or an xdg_popup or xdg_toplevel, if there are no
                /// explicit grabs already taken.
                ///
                /// If the topmost grabbing popup is destroyed, the grab will be returned to
                /// the parent of the popup, if that parent previously had an explicit grab.
                ///
                /// If the parent is a grabbing popup which has already been dismissed, this
                /// popup will be immediately dismissed. If the parent is a popup that did
                /// not take an explicit grab, an error will be raised.
                ///
                /// During a popup grab, the client owning the grab will receive pointer
                /// and touch events for all their surfaces as normal (similar to an
                /// "owner-events" grab in X11 parlance), while the top most grabbing popup
                /// will always have keyboard focus.
                ///
                grab: GrabMessage,

                /// recalculate the popup's location
                ///
                /// Reposition an already-mapped popup. The popup will be placed given the
                /// details in the passed xdg_positioner object, and a
                /// xdg_popup.repositioned followed by xdg_popup.configure and
                /// xdg_surface.configure will be emitted in response. Any parameters set
                /// by the previous positioner will be discarded.
                ///
                /// The passed token will be sent in the corresponding
                /// xdg_popup.repositioned event. The new popup position will not take
                /// effect until the corresponding configure event is acknowledged by the
                /// client. See xdg_popup.repositioned for details. The token itself is
                /// opaque, and has no other special meaning.
                ///
                /// If multiple reposition requests are sent, the compositor may skip all
                /// but the last one.
                ///
                /// If the popup is repositioned in response to a configure event for its
                /// parent, the client should send an xdg_positioner.set_parent_configure
                /// and possibly an xdg_positioner.set_parent_size request to allow the
                /// compositor to properly constrain the popup.
                ///
                /// If the popup is repositioned together with a parent that is being
                /// resized, but not in response to a configure event, the client should
                /// send an xdg_positioner.set_parent_size request.
                ///
                reposition: RepositionMessage,
            };

            /// remove xdg_popup interface
            ///
            /// This destroys the popup. Explicitly destroying the xdg_popup
            /// object will also dismiss the popup, and unmap the surface.
            ///
            /// If this xdg_popup is not the "topmost" popup, a protocol error
            /// will be sent.
            ///
            const DestroyMessage = struct {
                xdg_popup: XdgPopup,
            };

            /// make the popup take an explicit grab
            ///
            /// This request makes the created popup take an explicit grab. An explicit
            /// grab will be dismissed when the user dismisses the popup, or when the
            /// client destroys the xdg_popup. This can be done by the user clicking
            /// outside the surface, using the keyboard, or even locking the screen
            /// through closing the lid or a timeout.
            ///
            /// If the compositor denies the grab, the popup will be immediately
            /// dismissed.
            ///
            /// This request must be used in response to some sort of user action like a
            /// button press, key press, or touch down event. The serial number of the
            /// event should be passed as 'serial'.
            ///
            /// The parent of a grabbing popup must either be an xdg_toplevel surface or
            /// another xdg_popup with an explicit grab. If the parent is another
            /// xdg_popup it means that the popups are nested, with this popup now being
            /// the topmost popup.
            ///
            /// Nested popups must be destroyed in the reverse order they were created
            /// in, e.g. the only popup you are allowed to destroy at all times is the
            /// topmost one.
            ///
            /// When compositors choose to dismiss a popup, they may dismiss every
            /// nested grabbing popup as well. When a compositor dismisses popups, it
            /// will follow the same dismissing order as required from the client.
            ///
            /// The parent of a grabbing popup must either be another xdg_popup with an
            /// active explicit grab, or an xdg_popup or xdg_toplevel, if there are no
            /// explicit grabs already taken.
            ///
            /// If the topmost grabbing popup is destroyed, the grab will be returned to
            /// the parent of the popup, if that parent previously had an explicit grab.
            ///
            /// If the parent is a grabbing popup which has already been dismissed, this
            /// popup will be immediately dismissed. If the parent is a popup that did
            /// not take an explicit grab, an error will be raised.
            ///
            /// During a popup grab, the client owning the grab will receive pointer
            /// and touch events for all their surfaces as normal (similar to an
            /// "owner-events" grab in X11 parlance), while the top most grabbing popup
            /// will always have keyboard focus.
            ///
            const GrabMessage = struct {
                xdg_popup: XdgPopup,
                /// the wl_seat of the user event
                seat: WlSeat,
                /// the serial of the user event
                serial: u32,
            };

            /// recalculate the popup's location
            ///
            /// Reposition an already-mapped popup. The popup will be placed given the
            /// details in the passed xdg_positioner object, and a
            /// xdg_popup.repositioned followed by xdg_popup.configure and
            /// xdg_surface.configure will be emitted in response. Any parameters set
            /// by the previous positioner will be discarded.
            ///
            /// The passed token will be sent in the corresponding
            /// xdg_popup.repositioned event. The new popup position will not take
            /// effect until the corresponding configure event is acknowledged by the
            /// client. See xdg_popup.repositioned for details. The token itself is
            /// opaque, and has no other special meaning.
            ///
            /// If multiple reposition requests are sent, the compositor may skip all
            /// but the last one.
            ///
            /// If the popup is repositioned in response to a configure event for its
            /// parent, the client should send an xdg_positioner.set_parent_configure
            /// and possibly an xdg_positioner.set_parent_size request to allow the
            /// compositor to properly constrain the popup.
            ///
            /// If the popup is repositioned together with a parent that is being
            /// resized, but not in response to a configure event, the client should
            /// send an xdg_positioner.set_parent_size request.
            ///
            const RepositionMessage = struct {
                xdg_popup: XdgPopup,
                positioner: XdgPositioner,
                /// reposition request token
                token: u32,
            };

            //
            // This event asks the popup surface to configure itself given the
            // configuration. The configured state should not be applied immediately.
            // See xdg_surface.configure for details.
            //
            // The x and y arguments represent the position the popup was placed at
            // given the xdg_positioner rule, relative to the upper left corner of the
            // window geometry of the parent surface.
            //
            // For version 2 or older, the configure event for an xdg_popup is only
            // ever sent once for the initial configuration. Starting with version 3,
            // it may be sent again if the popup is setup with an xdg_positioner with
            // set_reactive requested, or in response to xdg_popup.reposition requests.
            //
            pub fn sendConfigure(self: Self, x: i32, y: i32, width: i32, height: i32) !void {
                try self.wire.startWrite();
                try self.wire.putI32(x);
                try self.wire.putI32(y);
                try self.wire.putI32(width);
                try self.wire.putI32(height);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            // The popup_done event is sent out when a popup is dismissed by the
            // compositor. The client should destroy the xdg_popup object at this
            // point.
            //
            pub fn sendPopupDone(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 1);
            }

            //
            // The repositioned event is sent as part of a popup configuration
            // sequence, together with xdg_popup.configure and lastly
            // xdg_surface.configure to notify the completion of a reposition request.
            //
            // The repositioned event is to notify about the completion of a
            // xdg_popup.reposition request. The token argument is the token passed
            // in the xdg_popup.reposition request.
            //
            // Immediately after this event is emitted, xdg_popup.configure and
            // xdg_surface.configure will be sent with the updated size and position,
            // as well as a new configure serial.
            //
            // The client should optionally update the content of the popup, but must
            // acknowledge the new popup configuration for the new position to take
            // effect. See xdg_surface.ack_configure for details.
            //
            pub fn sendRepositioned(self: Self, token: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(token);
                try self.wire.finishWrite(self.id, 2);
            }
        };

        /// zwp_linux_dmabuf_v1
        /// factory for creating dmabuf-based wl_buffers
        ///
        /// Following the interfaces from:
        /// https://www.khronos.org/registry/egl/extensions/EXT/EGL_EXT_image_dma_buf_import.txt
        /// https://www.khronos.org/registry/EGL/extensions/EXT/EGL_EXT_image_dma_buf_import_modifiers.txt
        /// and the Linux DRM sub-system's AddFb2 ioctl.
        ///
        /// This interface offers ways to create generic dmabuf-based wl_buffers.
        ///
        /// Clients can use the get_surface_feedback request to get dmabuf feedback
        /// for a particular surface. If the client wants to retrieve feedback not
        /// tied to a surface, they can use the get_default_feedback request.
        ///
        /// The following are required from clients:
        ///
        /// - Clients must ensure that either all data in the dma-buf is
        /// coherent for all subsequent read access or that coherency is
        /// correctly handled by the underlying kernel-side dma-buf
        /// implementation.
        ///
        /// - Don't make any more attachments after sending the buffer to the
        /// compositor. Making more attachments later increases the risk of
        /// the compositor not being able to use (re-import) an existing
        /// dmabuf-based wl_buffer.
        ///
        /// The underlying graphics stack must ensure the following:
        ///
        /// - The dmabuf file descriptors relayed to the server will stay valid
        /// for the whole lifetime of the wl_buffer. This means the server may
        /// at any time use those fds to import the dmabuf into any kernel
        /// sub-system that might accept it.
        ///
        /// However, when the underlying graphics stack fails to deliver the
        /// promise, because of e.g. a device hot-unplug which raises internal
        /// errors, after the wl_buffer has been successfully created the
        /// compositor must not raise protocol errors to the client when dmabuf
        /// import later fails.
        ///
        /// To create a wl_buffer from one or more dmabufs, a client creates a
        /// zwp_linux_dmabuf_params_v1 object with a zwp_linux_dmabuf_v1.create_params
        /// request. All planes required by the intended format are added with
        /// the 'add' request. Finally, a 'create' or 'create_immed' request is
        /// issued, which has the following outcome depending on the import success.
        ///
        /// The 'create' request,
        /// - on success, triggers a 'created' event which provides the final
        /// wl_buffer to the client.
        /// - on failure, triggers a 'failed' event to convey that the server
        /// cannot use the dmabufs received from the client.
        ///
        /// For the 'create_immed' request,
        /// - on success, the server immediately imports the added dmabufs to
        /// create a wl_buffer. No event is sent from the server in this case.
        /// - on failure, the server can choose to either:
        /// - terminate the client by raising a fatal error.
        /// - mark the wl_buffer as failed, and send a 'failed' event to the
        /// client. If the client uses a failed wl_buffer as an argument to any
        /// request, the behaviour is compositor implementation-defined.
        ///
        /// For all DRM formats and unless specified in another protocol extension,
        /// pre-multiplied alpha is used for pixel values.
        ///
        /// Warning! The protocol described in this file is experimental and
        /// backward incompatible changes may be made. Backward compatible changes
        /// may be added together with the corresponding interface version bump.
        /// Backward incompatible changes are done by bumping the version number in
        /// the protocol and interface names and resetting the interface version.
        /// Once the protocol is to be declared stable, the 'z' prefix and the
        /// version number in the protocol and interface names are removed and the
        /// interface version number is reset.
        ///
        pub const ZwpLinuxDmabufV1 = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.zwp_linux_dmabuf_v1,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.zwp_linux_dmabuf_v1) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .zwp_linux_dmabuf_v1 = self.*,
                            },
                        };
                    },
                    // create_params
                    1 => {
                        const params_id: u32 = try self.wire.nextU32();
                        return Message{
                            .create_params = CreateParamsMessage{
                                .zwp_linux_dmabuf_v1 = self.*,
                                .params_id = params_id,
                            },
                        };
                    },
                    // get_default_feedback
                    2 => {
                        const id: u32 = try self.wire.nextU32();
                        return Message{
                            .get_default_feedback = GetDefaultFeedbackMessage{
                                .zwp_linux_dmabuf_v1 = self.*,
                                .id = id,
                            },
                        };
                    },
                    // get_surface_feedback
                    3 => {
                        const id: u32 = try self.wire.nextU32();
                        const surface: WlSurface = if (@call(.auto, @field(Client, field), .{ objects, try self.wire.nextU32() })) |obj| switch (obj) {
                            .wl_surface => |o| o,
                            else => return error.MismtachObjectTypes,
                        } else return error.ExpectedObject;
                        return Message{
                            .get_surface_feedback = GetSurfaceFeedbackMessage{
                                .zwp_linux_dmabuf_v1 = self.*,
                                .id = id,
                                .surface = surface,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                create_params,
                get_default_feedback,
                get_surface_feedback,
            };

            pub const Message = union(MessageType) {
                /// unbind the factory
                ///
                /// Objects created through this interface, especially wl_buffers, will
                /// remain valid.
                ///
                destroy: DestroyMessage,

                /// create a temporary object for buffer parameters
                ///
                /// This temporary object is used to collect multiple dmabuf handles into
                /// a single batch to create a wl_buffer. It can only be used once and
                /// should be destroyed after a 'created' or 'failed' event has been
                /// received.
                ///
                create_params: CreateParamsMessage,

                /// get default feedback
                ///
                /// This request creates a new wp_linux_dmabuf_feedback object not bound
                /// to a particular surface. This object will deliver feedback about dmabuf
                /// parameters to use if the client doesn't support per-surface feedback
                /// (see get_surface_feedback).
                ///
                get_default_feedback: GetDefaultFeedbackMessage,

                /// get feedback for a surface
                ///
                /// This request creates a new wp_linux_dmabuf_feedback object for the
                /// specified wl_surface. This object will deliver feedback about dmabuf
                /// parameters to use for buffers attached to this surface.
                ///
                /// If the surface is destroyed before the wp_linux_dmabuf_feedback object,
                /// the feedback object becomes inert.
                ///
                get_surface_feedback: GetSurfaceFeedbackMessage,
            };

            /// unbind the factory
            ///
            /// Objects created through this interface, especially wl_buffers, will
            /// remain valid.
            ///
            const DestroyMessage = struct {
                zwp_linux_dmabuf_v1: ZwpLinuxDmabufV1,
            };

            /// create a temporary object for buffer parameters
            ///
            /// This temporary object is used to collect multiple dmabuf handles into
            /// a single batch to create a wl_buffer. It can only be used once and
            /// should be destroyed after a 'created' or 'failed' event has been
            /// received.
            ///
            const CreateParamsMessage = struct {
                zwp_linux_dmabuf_v1: ZwpLinuxDmabufV1,
                /// the new temporary
                params_id: u32,
            };

            /// get default feedback
            ///
            /// This request creates a new wp_linux_dmabuf_feedback object not bound
            /// to a particular surface. This object will deliver feedback about dmabuf
            /// parameters to use if the client doesn't support per-surface feedback
            /// (see get_surface_feedback).
            ///
            const GetDefaultFeedbackMessage = struct {
                zwp_linux_dmabuf_v1: ZwpLinuxDmabufV1,
                id: u32,
            };

            /// get feedback for a surface
            ///
            /// This request creates a new wp_linux_dmabuf_feedback object for the
            /// specified wl_surface. This object will deliver feedback about dmabuf
            /// parameters to use for buffers attached to this surface.
            ///
            /// If the surface is destroyed before the wp_linux_dmabuf_feedback object,
            /// the feedback object becomes inert.
            ///
            const GetSurfaceFeedbackMessage = struct {
                zwp_linux_dmabuf_v1: ZwpLinuxDmabufV1,
                id: u32,
                surface: WlSurface,
            };

            //
            //         This event advertises one buffer format that the server supports.
            //         All the supported formats are advertised once when the client
            //         binds to this interface. A roundtrip after binding guarantees
            //         that the client has received all supported formats.
            //
            //         For the definition of the format codes, see the
            //         zwp_linux_buffer_params_v1::create request.
            //
            //         Starting version 4, the format event is deprecated and must not be
            //         sent by compositors. Instead, use get_default_feedback or
            //         get_surface_feedback.
            //
            pub fn sendFormat(self: Self, format: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(format);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            //         This event advertises the formats that the server supports, along with
            //         the modifiers supported for each format. All the supported modifiers
            //         for all the supported formats are advertised once when the client
            //         binds to this interface. A roundtrip after binding guarantees that
            //         the client has received all supported format-modifier pairs.
            //
            //         For legacy support, DRM_FORMAT_MOD_INVALID (that is, modifier_hi ==
            //         0x00ffffff and modifier_lo == 0xffffffff) is allowed in this event.
            //         It indicates that the server can support the format with an implicit
            //         modifier. When a plane has DRM_FORMAT_MOD_INVALID as its modifier, it
            //         is as if no explicit modifier is specified. The effective modifier
            //         will be derived from the dmabuf.
            //
            //         A compositor that sends valid modifiers and DRM_FORMAT_MOD_INVALID for
            //         a given format supports both explicit modifiers and implicit modifiers.
            //
            //         For the definition of the format and modifier codes, see the
            //         zwp_linux_buffer_params_v1::create and zwp_linux_buffer_params_v1::add
            //         requests.
            //
            //         Starting version 4, the modifier event is deprecated and must not be
            //         sent by compositors. Instead, use get_default_feedback or
            //         get_surface_feedback.
            //
            pub fn sendModifier(self: Self, format: u32, modifier_hi: u32, modifier_lo: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(format);
                try self.wire.putU32(modifier_hi);
                try self.wire.putU32(modifier_lo);
                try self.wire.finishWrite(self.id, 1);
            }
        };

        /// zwp_linux_buffer_params_v1
        /// parameters for creating a dmabuf-based wl_buffer
        ///
        /// This temporary object is a collection of dmabufs and other
        /// parameters that together form a single logical buffer. The temporary
        /// object may eventually create one wl_buffer unless cancelled by
        /// destroying it before requesting 'create'.
        ///
        /// Single-planar formats only require one dmabuf, however
        /// multi-planar formats may require more than one dmabuf. For all
        /// formats, an 'add' request must be called once per plane (even if the
        /// underlying dmabuf fd is identical).
        ///
        /// You must use consecutive plane indices ('plane_idx' argument for 'add')
        /// from zero to the number of planes used by the drm_fourcc format code.
        /// All planes required by the format must be given exactly once, but can
        /// be given in any order. Each plane index can be set only once.
        ///
        pub const ZwpLinuxBufferParamsV1 = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.zwp_linux_buffer_params_v1,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.zwp_linux_buffer_params_v1) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const Error = enum(u32) {
                already_used = 0,
                plane_idx = 1,
                plane_set = 2,
                incomplete = 3,
                invalid_format = 4,
                invalid_dimensions = 5,
                out_of_bounds = 6,
                invalid_wl_buffer = 7,
            };

            pub const Flags = packed struct(u32) { // bitfield
                y_invert: bool = false, // 1
                interlaced: bool = false, // 2
                bottom_first: bool = false, // 4
                _padding: u29 = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .zwp_linux_buffer_params_v1 = self.*,
                            },
                        };
                    },
                    // add
                    1 => {
                        const fd: i32 = try self.wire.nextFd();
                        const plane_idx: u32 = try self.wire.nextU32();
                        const offset: u32 = try self.wire.nextU32();
                        const stride: u32 = try self.wire.nextU32();
                        const modifier_hi: u32 = try self.wire.nextU32();
                        const modifier_lo: u32 = try self.wire.nextU32();
                        return Message{
                            .add = AddMessage{
                                .zwp_linux_buffer_params_v1 = self.*,
                                .fd = fd,
                                .plane_idx = plane_idx,
                                .offset = offset,
                                .stride = stride,
                                .modifier_hi = modifier_hi,
                                .modifier_lo = modifier_lo,
                            },
                        };
                    },
                    // create
                    2 => {
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        const format: u32 = try self.wire.nextU32();
                        const flags: Flags = @bitCast(try self.wire.nextU32()); // bitfield
                        return Message{
                            .create = CreateMessage{
                                .zwp_linux_buffer_params_v1 = self.*,
                                .width = width,
                                .height = height,
                                .format = format,
                                .flags = flags,
                            },
                        };
                    },
                    // create_immed
                    3 => {
                        const buffer_id: u32 = try self.wire.nextU32();
                        const width: i32 = try self.wire.nextI32();
                        const height: i32 = try self.wire.nextI32();
                        const format: u32 = try self.wire.nextU32();
                        const flags: Flags = @bitCast(try self.wire.nextU32()); // bitfield
                        return Message{
                            .create_immed = CreateImmedMessage{
                                .zwp_linux_buffer_params_v1 = self.*,
                                .buffer_id = buffer_id,
                                .width = width,
                                .height = height,
                                .format = format,
                                .flags = flags,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
                add,
                create,
                create_immed,
            };

            pub const Message = union(MessageType) {
                /// delete this object, used or not
                ///
                /// Cleans up the temporary data sent to the server for dmabuf-based
                /// wl_buffer creation.
                ///
                destroy: DestroyMessage,

                /// add a dmabuf to the temporary set
                ///
                /// This request adds one dmabuf to the set in this
                /// zwp_linux_buffer_params_v1.
                ///
                /// The 64-bit unsigned value combined from modifier_hi and modifier_lo
                /// is the dmabuf layout modifier. DRM AddFB2 ioctl calls this the
                /// fb modifier, which is defined in drm_mode.h of Linux UAPI.
                /// This is an opaque token. Drivers use this token to express tiling,
                /// compression, etc. driver-specific modifications to the base format
                /// defined by the DRM fourcc code.
                ///
                /// Starting from version 4, the invalid_format protocol error is sent if
                /// the format + modifier pair was not advertised as supported.
                ///
                /// This request raises the PLANE_IDX error if plane_idx is too large.
                /// The error PLANE_SET is raised if attempting to set a plane that
                /// was already set.
                ///
                add: AddMessage,

                /// create a wl_buffer from the given dmabufs
                ///
                /// This asks for creation of a wl_buffer from the added dmabuf
                /// buffers. The wl_buffer is not created immediately but returned via
                /// the 'created' event if the dmabuf sharing succeeds. The sharing
                /// may fail at runtime for reasons a client cannot predict, in
                /// which case the 'failed' event is triggered.
                ///
                /// The 'format' argument is a DRM_FORMAT code, as defined by the
                /// libdrm's drm_fourcc.h. The Linux kernel's DRM sub-system is the
                /// authoritative source on how the format codes should work.
                ///
                /// The 'flags' is a bitfield of the flags defined in enum "flags".
                /// 'y_invert' means the that the image needs to be y-flipped.
                ///
                /// Flag 'interlaced' means that the frame in the buffer is not
                /// progressive as usual, but interlaced. An interlaced buffer as
                /// supported here must always contain both top and bottom fields.
                /// The top field always begins on the first pixel row. The temporal
                /// ordering between the two fields is top field first, unless
                /// 'bottom_first' is specified. It is undefined whether 'bottom_first'
                /// is ignored if 'interlaced' is not set.
                ///
                /// This protocol does not convey any information about field rate,
                /// duration, or timing, other than the relative ordering between the
                /// two fields in one buffer. A compositor may have to estimate the
                /// intended field rate from the incoming buffer rate. It is undefined
                /// whether the time of receiving wl_surface.commit with a new buffer
                /// attached, applying the wl_surface state, wl_surface.frame callback
                /// trigger, presentation, or any other point in the compositor cycle
                /// is used to measure the frame or field times. There is no support
                /// for detecting missed or late frames/fields/buffers either, and
                /// there is no support whatsoever for cooperating with interlaced
                /// compositor output.
                ///
                /// The composited image quality resulting from the use of interlaced
                /// buffers is explicitly undefined. A compositor may use elaborate
                /// hardware features or software to deinterlace and create progressive
                /// output frames from a sequence of interlaced input buffers, or it
                /// may produce substandard image quality. However, compositors that
                /// cannot guarantee reasonable image quality in all cases are recommended
                /// to just reject all interlaced buffers.
                ///
                /// Any argument errors, including non-positive width or height,
                /// mismatch between the number of planes and the format, bad
                /// format, bad offset or stride, may be indicated by fatal protocol
                /// errors: INCOMPLETE, INVALID_FORMAT, INVALID_DIMENSIONS,
                /// OUT_OF_BOUNDS.
                ///
                /// Dmabuf import errors in the server that are not obvious client
                /// bugs are returned via the 'failed' event as non-fatal. This
                /// allows attempting dmabuf sharing and falling back in the client
                /// if it fails.
                ///
                /// This request can be sent only once in the object's lifetime, after
                /// which the only legal request is destroy. This object should be
                /// destroyed after issuing a 'create' request. Attempting to use this
                /// object after issuing 'create' raises ALREADY_USED protocol error.
                ///
                /// It is not mandatory to issue 'create'. If a client wants to
                /// cancel the buffer creation, it can just destroy this object.
                ///
                create: CreateMessage,

                /// immediately create a wl_buffer from the given                      dmabufs
                ///
                /// This asks for immediate creation of a wl_buffer by importing the
                /// added dmabufs.
                ///
                /// In case of import success, no event is sent from the server, and the
                /// wl_buffer is ready to be used by the client.
                ///
                /// Upon import failure, either of the following may happen, as seen fit
                /// by the implementation:
                /// - the client is terminated with one of the following fatal protocol
                /// errors:
                /// - INCOMPLETE, INVALID_FORMAT, INVALID_DIMENSIONS, OUT_OF_BOUNDS,
                /// in case of argument errors such as mismatch between the number
                /// of planes and the format, bad format, non-positive width or
                /// height, or bad offset or stride.
                /// - INVALID_WL_BUFFER, in case the cause for failure is unknown or
                /// plaform specific.
                /// - the server creates an invalid wl_buffer, marks it as failed and
                /// sends a 'failed' event to the client. The result of using this
                /// invalid wl_buffer as an argument in any request by the client is
                /// defined by the compositor implementation.
                ///
                /// This takes the same arguments as a 'create' request, and obeys the
                /// same restrictions.
                ///
                create_immed: CreateImmedMessage,
            };

            /// delete this object, used or not
            ///
            /// Cleans up the temporary data sent to the server for dmabuf-based
            /// wl_buffer creation.
            ///
            const DestroyMessage = struct {
                zwp_linux_buffer_params_v1: ZwpLinuxBufferParamsV1,
            };

            /// add a dmabuf to the temporary set
            ///
            /// This request adds one dmabuf to the set in this
            /// zwp_linux_buffer_params_v1.
            ///
            /// The 64-bit unsigned value combined from modifier_hi and modifier_lo
            /// is the dmabuf layout modifier. DRM AddFB2 ioctl calls this the
            /// fb modifier, which is defined in drm_mode.h of Linux UAPI.
            /// This is an opaque token. Drivers use this token to express tiling,
            /// compression, etc. driver-specific modifications to the base format
            /// defined by the DRM fourcc code.
            ///
            /// Starting from version 4, the invalid_format protocol error is sent if
            /// the format + modifier pair was not advertised as supported.
            ///
            /// This request raises the PLANE_IDX error if plane_idx is too large.
            /// The error PLANE_SET is raised if attempting to set a plane that
            /// was already set.
            ///
            const AddMessage = struct {
                zwp_linux_buffer_params_v1: ZwpLinuxBufferParamsV1,
                /// dmabuf fd
                fd: i32,
                /// plane index
                plane_idx: u32,
                /// offset in bytes
                offset: u32,
                /// stride in bytes
                stride: u32,
                /// high 32 bits of layout modifier
                modifier_hi: u32,
                /// low 32 bits of layout modifier
                modifier_lo: u32,
            };

            /// create a wl_buffer from the given dmabufs
            ///
            /// This asks for creation of a wl_buffer from the added dmabuf
            /// buffers. The wl_buffer is not created immediately but returned via
            /// the 'created' event if the dmabuf sharing succeeds. The sharing
            /// may fail at runtime for reasons a client cannot predict, in
            /// which case the 'failed' event is triggered.
            ///
            /// The 'format' argument is a DRM_FORMAT code, as defined by the
            /// libdrm's drm_fourcc.h. The Linux kernel's DRM sub-system is the
            /// authoritative source on how the format codes should work.
            ///
            /// The 'flags' is a bitfield of the flags defined in enum "flags".
            /// 'y_invert' means the that the image needs to be y-flipped.
            ///
            /// Flag 'interlaced' means that the frame in the buffer is not
            /// progressive as usual, but interlaced. An interlaced buffer as
            /// supported here must always contain both top and bottom fields.
            /// The top field always begins on the first pixel row. The temporal
            /// ordering between the two fields is top field first, unless
            /// 'bottom_first' is specified. It is undefined whether 'bottom_first'
            /// is ignored if 'interlaced' is not set.
            ///
            /// This protocol does not convey any information about field rate,
            /// duration, or timing, other than the relative ordering between the
            /// two fields in one buffer. A compositor may have to estimate the
            /// intended field rate from the incoming buffer rate. It is undefined
            /// whether the time of receiving wl_surface.commit with a new buffer
            /// attached, applying the wl_surface state, wl_surface.frame callback
            /// trigger, presentation, or any other point in the compositor cycle
            /// is used to measure the frame or field times. There is no support
            /// for detecting missed or late frames/fields/buffers either, and
            /// there is no support whatsoever for cooperating with interlaced
            /// compositor output.
            ///
            /// The composited image quality resulting from the use of interlaced
            /// buffers is explicitly undefined. A compositor may use elaborate
            /// hardware features or software to deinterlace and create progressive
            /// output frames from a sequence of interlaced input buffers, or it
            /// may produce substandard image quality. However, compositors that
            /// cannot guarantee reasonable image quality in all cases are recommended
            /// to just reject all interlaced buffers.
            ///
            /// Any argument errors, including non-positive width or height,
            /// mismatch between the number of planes and the format, bad
            /// format, bad offset or stride, may be indicated by fatal protocol
            /// errors: INCOMPLETE, INVALID_FORMAT, INVALID_DIMENSIONS,
            /// OUT_OF_BOUNDS.
            ///
            /// Dmabuf import errors in the server that are not obvious client
            /// bugs are returned via the 'failed' event as non-fatal. This
            /// allows attempting dmabuf sharing and falling back in the client
            /// if it fails.
            ///
            /// This request can be sent only once in the object's lifetime, after
            /// which the only legal request is destroy. This object should be
            /// destroyed after issuing a 'create' request. Attempting to use this
            /// object after issuing 'create' raises ALREADY_USED protocol error.
            ///
            /// It is not mandatory to issue 'create'. If a client wants to
            /// cancel the buffer creation, it can just destroy this object.
            ///
            const CreateMessage = struct {
                zwp_linux_buffer_params_v1: ZwpLinuxBufferParamsV1,
                /// base plane width in pixels
                width: i32,
                /// base plane height in pixels
                height: i32,
                /// DRM_FORMAT code
                format: u32,
                /// see enum flags
                flags: Flags,
            };

            /// immediately create a wl_buffer from the given                      dmabufs
            ///
            /// This asks for immediate creation of a wl_buffer by importing the
            /// added dmabufs.
            ///
            /// In case of import success, no event is sent from the server, and the
            /// wl_buffer is ready to be used by the client.
            ///
            /// Upon import failure, either of the following may happen, as seen fit
            /// by the implementation:
            /// - the client is terminated with one of the following fatal protocol
            /// errors:
            /// - INCOMPLETE, INVALID_FORMAT, INVALID_DIMENSIONS, OUT_OF_BOUNDS,
            /// in case of argument errors such as mismatch between the number
            /// of planes and the format, bad format, non-positive width or
            /// height, or bad offset or stride.
            /// - INVALID_WL_BUFFER, in case the cause for failure is unknown or
            /// plaform specific.
            /// - the server creates an invalid wl_buffer, marks it as failed and
            /// sends a 'failed' event to the client. The result of using this
            /// invalid wl_buffer as an argument in any request by the client is
            /// defined by the compositor implementation.
            ///
            /// This takes the same arguments as a 'create' request, and obeys the
            /// same restrictions.
            ///
            const CreateImmedMessage = struct {
                zwp_linux_buffer_params_v1: ZwpLinuxBufferParamsV1,
                /// id for the newly created wl_buffer
                buffer_id: u32,
                /// base plane width in pixels
                width: i32,
                /// base plane height in pixels
                height: i32,
                /// DRM_FORMAT code
                format: u32,
                /// see enum flags
                flags: Flags,
            };

            //
            //         This event indicates that the attempted buffer creation was
            //         successful. It provides the new wl_buffer referencing the dmabuf(s).
            //
            //         Upon receiving this event, the client should destroy the
            //         zlinux_dmabuf_params object.
            //
            pub fn sendCreated(self: Self, buffer: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(buffer);
                try self.wire.finishWrite(self.id, 0);
            }

            //
            //         This event indicates that the attempted buffer creation has
            //         failed. It usually means that one of the dmabuf constraints
            //         has not been fulfilled.
            //
            //         Upon receiving this event, the client should destroy the
            //         zlinux_buffer_params object.
            //
            pub fn sendFailed(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 1);
            }
        };

        /// zwp_linux_dmabuf_feedback_v1
        /// dmabuf feedback
        ///
        /// This object advertises dmabuf parameters feedback. This includes the
        /// preferred devices and the supported formats/modifiers.
        ///
        /// The parameters are sent once when this object is created and whenever they
        /// change. The done event is always sent once after all parameters have been
        /// sent. When a single parameter changes, all parameters are re-sent by the
        /// compositor.
        ///
        /// Compositors can re-send the parameters when the current client buffer
        /// allocations are sub-optimal. Compositors should not re-send the
        /// parameters if re-allocating the buffers would not result in a more optimal
        /// configuration. In particular, compositors should avoid sending the exact
        /// same parameters multiple times in a row.
        ///
        /// The tranche_target_device and tranche_modifier events are grouped by
        /// tranches of preference. For each tranche, a tranche_target_device, one
        /// tranche_flags and one or more tranche_modifier events are sent, followed
        /// by a tranche_done event finishing the list. The tranches are sent in
        /// descending order of preference. All formats and modifiers in the same
        /// tranche have the same preference.
        ///
        /// To send parameters, the compositor sends one main_device event, tranches
        /// (each consisting of one tranche_target_device event, one tranche_flags
        /// event, tranche_modifier events and then a tranche_done event), then one
        /// done event.
        ///
        pub const ZwpLinuxDmabufFeedbackV1 = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.zwp_linux_dmabuf_feedback_v1,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.zwp_linux_dmabuf_feedback_v1) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const TrancheFlags = packed struct(u32) { // bitfield
                scanout: bool = false, // 1
                _padding: u31 = 0,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // destroy
                    0 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .zwp_linux_dmabuf_feedback_v1 = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                destroy,
            };

            pub const Message = union(MessageType) {
                /// destroy the feedback object
                ///
                /// Using this request a client can tell the server that it is not going to
                /// use the wp_linux_dmabuf_feedback object anymore.
                ///
                destroy: DestroyMessage,
            };

            /// destroy the feedback object
            ///
            /// Using this request a client can tell the server that it is not going to
            /// use the wp_linux_dmabuf_feedback object anymore.
            ///
            const DestroyMessage = struct {
                zwp_linux_dmabuf_feedback_v1: ZwpLinuxDmabufFeedbackV1,
            };

            //
            //         This event is sent after all parameters of a wp_linux_dmabuf_feedback
            //         object have been sent.
            //
            //         This allows changes to the wp_linux_dmabuf_feedback parameters to be
            //         seen as atomic, even if they happen via multiple events.
            //
            pub fn sendDone(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 0);
            }

            //
            //         This event provides a file descriptor which can be memory-mapped to
            //         access the format and modifier table.
            //
            //         The table contains a tightly packed array of consecutive format +
            //         modifier pairs. Each pair is 16 bytes wide. It contains a format as a
            //         32-bit unsigned integer, followed by 4 bytes of unused padding, and a
            //         modifier as a 64-bit unsigned integer. The native endianness is used.
            //
            //         The client must map the file descriptor in read-only private mode.
            //
            //         Compositors are not allowed to mutate the table file contents once this
            //         event has been sent. Instead, compositors must create a new, separate
            //         table file and re-send feedback parameters. Compositors are allowed to
            //         store duplicate format + modifier pairs in the table.
            //
            pub fn sendFormatTable(self: Self, fd: i32, size: u32) !void {
                try self.wire.startWrite();
                try self.wire.putFd(fd);
                try self.wire.putU32(size);
                try self.wire.finishWrite(self.id, 1);
            }

            //
            //         This event advertises the main device that the server prefers to use
            //         when direct scan-out to the target device isn't possible. The
            //         advertised main device may be different for each
            //         wp_linux_dmabuf_feedback object, and may change over time.
            //
            //         There is exactly one main device. The compositor must send at least
            //         one preference tranche with tranche_target_device equal to main_device.
            //
            //         Clients need to create buffers that the main device can import and
            //         read from, otherwise creating the dmabuf wl_buffer will fail (see the
            //         wp_linux_buffer_params.create and create_immed requests for details).
            //         The main device will also likely be kept active by the compositor,
            //         so clients can use it instead of waking up another device for power
            //         savings.
            //
            //         In general the device is a DRM node. The DRM node type (primary vs.
            //         render) is unspecified. Clients must not rely on the compositor sending
            //         a particular node type. Clients cannot check two devices for equality
            //         by comparing the dev_t value.
            //
            //         If explicit modifiers are not supported and the client performs buffer
            //         allocations on a different device than the main device, then the client
            //         must force the buffer to have a linear layout.
            //
            pub fn sendMainDevice(self: Self, device: []u8) !void {
                try self.wire.startWrite();
                try self.wire.putArray(device);
                try self.wire.finishWrite(self.id, 2);
            }

            //
            //         This event splits tranche_target_device and tranche_modifier events in
            //         preference tranches. It is sent after a set of tranche_target_device
            //         and tranche_modifier events; it represents the end of a tranche. The
            //         next tranche will have a lower preference.
            //
            pub fn sendTrancheDone(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 3);
            }

            //
            //         This event advertises the target device that the server prefers to use
            //         for a buffer created given this tranche. The advertised target device
            //         may be different for each preference tranche, and may change over time.
            //
            //         There is exactly one target device per tranche.
            //
            //         The target device may be a scan-out device, for example if the
            //         compositor prefers to directly scan-out a buffer created given this
            //         tranche. The target device may be a rendering device, for example if
            //         the compositor prefers to texture from said buffer.
            //
            //         The client can use this hint to allocate the buffer in a way that makes
            //         it accessible from the target device, ideally directly. The buffer must
            //         still be accessible from the main device, either through direct import
            //         or through a potentially more expensive fallback path. If the buffer
            //         can't be directly imported from the main device then clients must be
            //         prepared for the compositor changing the tranche priority or making
            //         wl_buffer creation fail (see the wp_linux_buffer_params.create and
            //         create_immed requests for details).
            //
            //         If the device is a DRM node, the DRM node type (primary vs. render) is
            //         unspecified. Clients must not rely on the compositor sending a
            //         particular node type. Clients cannot check two devices for equality by
            //         comparing the dev_t value.
            //
            //         This event is tied to a preference tranche, see the tranche_done event.
            //
            pub fn sendTrancheTargetDevice(self: Self, device: []u8) !void {
                try self.wire.startWrite();
                try self.wire.putArray(device);
                try self.wire.finishWrite(self.id, 4);
            }

            //
            //         This event advertises the format + modifier combinations that the
            //         compositor supports.
            //
            //         It carries an array of indices, each referring to a format + modifier
            //         pair in the last received format table (see the format_table event).
            //         Each index is a 16-bit unsigned integer in native endianness.
            //
            //         For legacy support, DRM_FORMAT_MOD_INVALID is an allowed modifier.
            //         It indicates that the server can support the format with an implicit
            //         modifier. When a buffer has DRM_FORMAT_MOD_INVALID as its modifier, it
            //         is as if no explicit modifier is specified. The effective modifier
            //         will be derived from the dmabuf.
            //
            //         A compositor that sends valid modifiers and DRM_FORMAT_MOD_INVALID for
            //         a given format supports both explicit modifiers and implicit modifiers.
            //
            //         Compositors must not send duplicate format + modifier pairs within the
            //         same tranche or across two different tranches with the same target
            //         device and flags.
            //
            //         This event is tied to a preference tranche, see the tranche_done event.
            //
            //         For the definition of the format and modifier codes, see the
            //         wp_linux_buffer_params.create request.
            //
            pub fn sendTrancheFormats(self: Self, indices: []u8) !void {
                try self.wire.startWrite();
                try self.wire.putArray(indices);
                try self.wire.finishWrite(self.id, 5);
            }

            //
            //         This event sets tranche-specific flags.
            //
            //         The scanout flag is a hint that direct scan-out may be attempted by the
            //         compositor on the target device if the client appropriately allocates a
            //         buffer. How to allocate a buffer that can be scanned out on the target
            //         device is implementation-defined.
            //
            //         This event is tied to a preference tranche, see the tranche_done event.
            //
            pub fn sendTrancheFlags(self: Self, flags: TrancheFlags) !void {
                try self.wire.startWrite();
                try self.wire.putU32(@bitCast(flags)); // bitfield
                try self.wire.finishWrite(self.id, 6);
            }
        };

        /// fw_control
        /// protocol for querying and controlling foxwhale
        ///
        /// fw_control defines an interface for a a client to query and control
        /// foxwhale. It is intended to used primarily by foxwhalectl but there
        /// is no reason that arbitrary clients can't implement some or all of
        /// the protocol for whatever suits their needs.
        ///
        pub const FwControl = struct {
            wire: *Wire,
            id: u32,
            version: u32,
            resource: ResourceMap.fw_control,

            const Self = @This();

            pub fn init(id: u32, wire: *Wire, version: u32, resource: ResourceMap.fw_control) Self {
                return Self{
                    .id = id,
                    .wire = wire,
                    .version = version,
                    .resource = resource,
                };
            }

            pub const SurfaceType = enum(u32) {
                wl_surface = 0,
                wl_subsurface = 1,
                xdg_toplevel = 2,
                xdg_popup = 3,
            };

            pub fn readMessage(self: *Self, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !Message {
                if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info("{any}, {s} {s}", .{ &objects, &field, Client });
                switch (opcode) {
                    // get_clients
                    0 => {
                        return Message{
                            .get_clients = GetClientsMessage{
                                .fw_control = self.*,
                            },
                        };
                    },
                    // get_windows
                    1 => {
                        return Message{
                            .get_windows = GetWindowsMessage{
                                .fw_control = self.*,
                            },
                        };
                    },
                    // get_window_trees
                    2 => {
                        return Message{
                            .get_window_trees = GetWindowTreesMessage{
                                .fw_control = self.*,
                            },
                        };
                    },
                    // destroy
                    3 => {
                        return Message{
                            .destroy = DestroyMessage{
                                .fw_control = self.*,
                            },
                        };
                    },
                    else => {
                        std.log.info("{}", .{self});
                        return error.UnknownOpcode;
                    },
                }
            }

            const MessageType = enum(u8) {
                get_clients,
                get_windows,
                get_window_trees,
                destroy,
            };

            pub const Message = union(MessageType) {
                /// gets_clients gets current list of clients
                ///
                /// Gets metadata about all the clients currently connected to foxwhale.
                ///
                get_clients: GetClientsMessage,

                /// get_windows gets current list of windows
                ///
                /// Gets metadata about all the windows currently connected to foxwhale.
                ///
                get_windows: GetWindowsMessage,

                /// get_windows gets current list of windows
                ///
                /// Gets metadata about all the windows currently connected to foxwhale.
                ///
                get_window_trees: GetWindowTreesMessage,

                /// delete this object, used or not
                ///
                /// Cleans up fw_control object.
                ///
                destroy: DestroyMessage,
            };

            /// gets_clients gets current list of clients
            ///
            /// Gets metadata about all the clients currently connected to foxwhale.
            ///
            const GetClientsMessage = struct {
                fw_control: FwControl,
            };

            /// get_windows gets current list of windows
            ///
            /// Gets metadata about all the windows currently connected to foxwhale.
            ///
            const GetWindowsMessage = struct {
                fw_control: FwControl,
            };

            /// get_windows gets current list of windows
            ///
            /// Gets metadata about all the windows currently connected to foxwhale.
            ///
            const GetWindowTreesMessage = struct {
                fw_control: FwControl,
            };

            /// delete this object, used or not
            ///
            /// Cleans up fw_control object.
            ///
            const DestroyMessage = struct {
                fw_control: FwControl,
            };

            pub fn sendClient(self: Self, index: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(index);
                try self.wire.finishWrite(self.id, 0);
            }

            pub fn sendWindow(self: Self, index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, sibling_prev: i32, sibling_next: i32, children_prev: i32, children_next: i32, input_region_id: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(index);
                try self.wire.putI32(parent);
                try self.wire.putU32(wl_surface_id);
                try self.wire.putU32(surface_type);
                try self.wire.putI32(x);
                try self.wire.putI32(y);
                try self.wire.putI32(width);
                try self.wire.putI32(height);
                try self.wire.putI32(sibling_prev);
                try self.wire.putI32(sibling_next);
                try self.wire.putI32(children_prev);
                try self.wire.putI32(children_next);
                try self.wire.putU32(input_region_id);
                try self.wire.finishWrite(self.id, 1);
            }

            pub fn sendToplevelWindow(self: Self, index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, input_region_id: u32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(index);
                try self.wire.putI32(parent);
                try self.wire.putU32(wl_surface_id);
                try self.wire.putU32(surface_type);
                try self.wire.putI32(x);
                try self.wire.putI32(y);
                try self.wire.putI32(width);
                try self.wire.putI32(height);
                try self.wire.putU32(input_region_id);
                try self.wire.finishWrite(self.id, 2);
            }

            pub fn sendRegionRect(self: Self, index: u32, x: i32, y: i32, width: i32, height: i32, op: i32) !void {
                try self.wire.startWrite();
                try self.wire.putU32(index);
                try self.wire.putI32(x);
                try self.wire.putI32(y);
                try self.wire.putI32(width);
                try self.wire.putI32(height);
                try self.wire.putI32(op);
                try self.wire.finishWrite(self.id, 3);
            }

            pub fn sendDone(self: Self) !void {
                try self.wire.startWrite();
                try self.wire.finishWrite(self.id, 4);
            }
        };

        pub const WlInterfaceType = enum(u8) {
            wl_display,
            wl_registry,
            wl_callback,
            wl_compositor,
            wl_shm_pool,
            wl_shm,
            wl_buffer,
            wl_data_offer,
            wl_data_source,
            wl_data_device,
            wl_data_device_manager,
            wl_shell,
            wl_shell_surface,
            wl_surface,
            wl_seat,
            wl_pointer,
            wl_keyboard,
            wl_touch,
            wl_output,
            wl_region,
            wl_subcompositor,
            wl_subsurface,
            xdg_wm_base,
            xdg_positioner,
            xdg_surface,
            xdg_toplevel,
            xdg_popup,
            zwp_linux_dmabuf_v1,
            zwp_linux_buffer_params_v1,
            zwp_linux_dmabuf_feedback_v1,
            fw_control,
        };

        pub const WlMessage = union(WlInterfaceType) {
            wl_display: WlDisplay.Message,
            wl_registry: WlRegistry.Message,
            wl_callback: WlCallback.Message,
            wl_compositor: WlCompositor.Message,
            wl_shm_pool: WlShmPool.Message,
            wl_shm: WlShm.Message,
            wl_buffer: WlBuffer.Message,
            wl_data_offer: WlDataOffer.Message,
            wl_data_source: WlDataSource.Message,
            wl_data_device: WlDataDevice.Message,
            wl_data_device_manager: WlDataDeviceManager.Message,
            wl_shell: WlShell.Message,
            wl_shell_surface: WlShellSurface.Message,
            wl_surface: WlSurface.Message,
            wl_seat: WlSeat.Message,
            wl_pointer: WlPointer.Message,
            wl_keyboard: WlKeyboard.Message,
            wl_touch: WlTouch.Message,
            wl_output: WlOutput.Message,
            wl_region: WlRegion.Message,
            wl_subcompositor: WlSubcompositor.Message,
            wl_subsurface: WlSubsurface.Message,
            xdg_wm_base: XdgWmBase.Message,
            xdg_positioner: XdgPositioner.Message,
            xdg_surface: XdgSurface.Message,
            xdg_toplevel: XdgToplevel.Message,
            xdg_popup: XdgPopup.Message,
            zwp_linux_dmabuf_v1: ZwpLinuxDmabufV1.Message,
            zwp_linux_buffer_params_v1: ZwpLinuxBufferParamsV1.Message,
            zwp_linux_dmabuf_feedback_v1: ZwpLinuxDmabufFeedbackV1.Message,
            fw_control: FwControl.Message,
        };

        pub const WlObject = union(WlInterfaceType) {
            wl_display: WlDisplay,
            wl_registry: WlRegistry,
            wl_callback: WlCallback,
            wl_compositor: WlCompositor,
            wl_shm_pool: WlShmPool,
            wl_shm: WlShm,
            wl_buffer: WlBuffer,
            wl_data_offer: WlDataOffer,
            wl_data_source: WlDataSource,
            wl_data_device: WlDataDevice,
            wl_data_device_manager: WlDataDeviceManager,
            wl_shell: WlShell,
            wl_shell_surface: WlShellSurface,
            wl_surface: WlSurface,
            wl_seat: WlSeat,
            wl_pointer: WlPointer,
            wl_keyboard: WlKeyboard,
            wl_touch: WlTouch,
            wl_output: WlOutput,
            wl_region: WlRegion,
            wl_subcompositor: WlSubcompositor,
            wl_subsurface: WlSubsurface,
            xdg_wm_base: XdgWmBase,
            xdg_positioner: XdgPositioner,
            xdg_surface: XdgSurface,
            xdg_toplevel: XdgToplevel,
            xdg_popup: XdgPopup,
            zwp_linux_dmabuf_v1: ZwpLinuxDmabufV1,
            zwp_linux_buffer_params_v1: ZwpLinuxBufferParamsV1,
            zwp_linux_dmabuf_feedback_v1: ZwpLinuxDmabufFeedbackV1,
            fw_control: FwControl,

            pub fn readMessage(self: *WlObject, comptime Client: type, objects: anytype, comptime field: []const u8, opcode: u16) !WlMessage {
                return switch (self.*) {
                    .wl_display => |*o| WlMessage{ .wl_display = try o.readMessage(Client, objects, field, opcode) },
                    .wl_registry => |*o| WlMessage{ .wl_registry = try o.readMessage(Client, objects, field, opcode) },
                    .wl_callback => |*o| WlMessage{ .wl_callback = try o.readMessage(Client, objects, field, opcode) },
                    .wl_compositor => |*o| WlMessage{ .wl_compositor = try o.readMessage(Client, objects, field, opcode) },
                    .wl_shm_pool => |*o| WlMessage{ .wl_shm_pool = try o.readMessage(Client, objects, field, opcode) },
                    .wl_shm => |*o| WlMessage{ .wl_shm = try o.readMessage(Client, objects, field, opcode) },
                    .wl_buffer => |*o| WlMessage{ .wl_buffer = try o.readMessage(Client, objects, field, opcode) },
                    .wl_data_offer => |*o| WlMessage{ .wl_data_offer = try o.readMessage(Client, objects, field, opcode) },
                    .wl_data_source => |*o| WlMessage{ .wl_data_source = try o.readMessage(Client, objects, field, opcode) },
                    .wl_data_device => |*o| WlMessage{ .wl_data_device = try o.readMessage(Client, objects, field, opcode) },
                    .wl_data_device_manager => |*o| WlMessage{ .wl_data_device_manager = try o.readMessage(Client, objects, field, opcode) },
                    .wl_shell => |*o| WlMessage{ .wl_shell = try o.readMessage(Client, objects, field, opcode) },
                    .wl_shell_surface => |*o| WlMessage{ .wl_shell_surface = try o.readMessage(Client, objects, field, opcode) },
                    .wl_surface => |*o| WlMessage{ .wl_surface = try o.readMessage(Client, objects, field, opcode) },
                    .wl_seat => |*o| WlMessage{ .wl_seat = try o.readMessage(Client, objects, field, opcode) },
                    .wl_pointer => |*o| WlMessage{ .wl_pointer = try o.readMessage(Client, objects, field, opcode) },
                    .wl_keyboard => |*o| WlMessage{ .wl_keyboard = try o.readMessage(Client, objects, field, opcode) },
                    .wl_touch => |*o| WlMessage{ .wl_touch = try o.readMessage(Client, objects, field, opcode) },
                    .wl_output => |*o| WlMessage{ .wl_output = try o.readMessage(Client, objects, field, opcode) },
                    .wl_region => |*o| WlMessage{ .wl_region = try o.readMessage(Client, objects, field, opcode) },
                    .wl_subcompositor => |*o| WlMessage{ .wl_subcompositor = try o.readMessage(Client, objects, field, opcode) },
                    .wl_subsurface => |*o| WlMessage{ .wl_subsurface = try o.readMessage(Client, objects, field, opcode) },
                    .xdg_wm_base => |*o| WlMessage{ .xdg_wm_base = try o.readMessage(Client, objects, field, opcode) },
                    .xdg_positioner => |*o| WlMessage{ .xdg_positioner = try o.readMessage(Client, objects, field, opcode) },
                    .xdg_surface => |*o| WlMessage{ .xdg_surface = try o.readMessage(Client, objects, field, opcode) },
                    .xdg_toplevel => |*o| WlMessage{ .xdg_toplevel = try o.readMessage(Client, objects, field, opcode) },
                    .xdg_popup => |*o| WlMessage{ .xdg_popup = try o.readMessage(Client, objects, field, opcode) },
                    .zwp_linux_dmabuf_v1 => |*o| WlMessage{ .zwp_linux_dmabuf_v1 = try o.readMessage(Client, objects, field, opcode) },
                    .zwp_linux_buffer_params_v1 => |*o| WlMessage{ .zwp_linux_buffer_params_v1 = try o.readMessage(Client, objects, field, opcode) },
                    .zwp_linux_dmabuf_feedback_v1 => |*o| WlMessage{ .zwp_linux_dmabuf_feedback_v1 = try o.readMessage(Client, objects, field, opcode) },
                    .fw_control => |*o| WlMessage{ .fw_control = try o.readMessage(Client, objects, field, opcode) },
                };
            }
            // end of dispatch
            pub fn id(self: WlObject) u32 {
                return switch (self) {
                    .wl_display => |o| o.id,
                    .wl_registry => |o| o.id,
                    .wl_callback => |o| o.id,
                    .wl_compositor => |o| o.id,
                    .wl_shm_pool => |o| o.id,
                    .wl_shm => |o| o.id,
                    .wl_buffer => |o| o.id,
                    .wl_data_offer => |o| o.id,
                    .wl_data_source => |o| o.id,
                    .wl_data_device => |o| o.id,
                    .wl_data_device_manager => |o| o.id,
                    .wl_shell => |o| o.id,
                    .wl_shell_surface => |o| o.id,
                    .wl_surface => |o| o.id,
                    .wl_seat => |o| o.id,
                    .wl_pointer => |o| o.id,
                    .wl_keyboard => |o| o.id,
                    .wl_touch => |o| o.id,
                    .wl_output => |o| o.id,
                    .wl_region => |o| o.id,
                    .wl_subcompositor => |o| o.id,
                    .wl_subsurface => |o| o.id,
                    .xdg_wm_base => |o| o.id,
                    .xdg_positioner => |o| o.id,
                    .xdg_surface => |o| o.id,
                    .xdg_toplevel => |o| o.id,
                    .xdg_popup => |o| o.id,
                    .zwp_linux_dmabuf_v1 => |o| o.id,
                    .zwp_linux_buffer_params_v1 => |o| o.id,
                    .zwp_linux_dmabuf_feedback_v1 => |o| o.id,
                    .fw_control => |o| o.id,
                };
            }
            // end of id
        };
    };
}
