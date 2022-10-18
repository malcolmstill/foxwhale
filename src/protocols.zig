const std = @import("std");
const Client = @import("client.zig").Client;

// wl_display
pub const WlDisplay = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // sync
            0 => {
                var callback: u32 = try self.client.context.nextU32();
                return Message{
                    .sync = SyncMessage{
                        .callback = callback,
                    },
                };
            },
            // get_registry
            1 => {
                var registry: u32 = try self.client.context.nextU32();
                return Message{
                    .get_registry = GetRegistryMessage{
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
        sync: SyncMessage,
        get_registry: GetRegistryMessage,
    };

    const SyncMessage = struct {
        // TODO: should we include the interface's Object?
        callback: u32,
    };

    const GetRegistryMessage = struct {
        // TODO: should we include the interface's Object?
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
    pub fn sendError(self: Self, object_id: u32, code: u32, message: []const u8) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(object_id);
        self.client.context.putU32(code);
        self.client.context.putString(message);
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    // This event is used internally by the object ID management
    // logic.  When a client deletes an object, the server will send
    // this event to acknowledge that it has seen the delete request.
    // When the client receives this event, it will know that it can
    // safely reuse the object ID.
    //
    pub fn sendDeleteId(self: Self, id: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(id);
        try self.client.context.finishWrite(self.id, 1);
    }

    pub const Error = enum(u32) {
        invalid_object = 0,
        invalid_method = 1,
        no_memory = 2,
        implementation = 3,
    };
};

// wl_registry
pub const WlRegistry = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // bind
            0 => {
                var name: u32 = try self.client.context.nextU32();
                var name_string: []u8 = try self.client.context.nextString();
                var version: u32 = try self.client.context.nextU32();
                var id: u32 = try self.client.context.nextU32();
                return Message{
                    .bind = BindMessage{
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
        bind: BindMessage,
    };

    const BindMessage = struct {
        // TODO: should we include the interface's Object?
        name: u32,
        name_string: []u8,
        version: u32,
        id: u32,
    };

    //
    // Notify the client of global objects.
    //
    // The event notifies the client that a global object with
    // the given name is now available, and it implements the
    // given version of the given interface.
    //
    pub fn sendGlobal(self: Self, name: u32, interface: []const u8, version: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(name);
        self.client.context.putString(interface);
        self.client.context.putU32(version);
        try self.client.context.finishWrite(self.id, 0);
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
    pub fn sendGlobalRemove(self: Self, name: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(name);
        try self.client.context.finishWrite(self.id, 1);
    }
};

// wl_callback
pub const WlCallback = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
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
    pub fn sendDone(self: Self, callback_data: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(callback_data);
        try self.client.context.finishWrite(self.id, 0);
    }
};

// wl_compositor
pub const WlCompositor = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // create_surface
            0 => {
                var id: u32 = try self.client.context.nextU32();
                return Message{
                    .create_surface = CreateSurfaceMessage{
                        .id = id,
                    },
                };
            },
            // create_region
            1 => {
                var id: u32 = try self.client.context.nextU32();
                return Message{
                    .create_region = CreateRegionMessage{
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
        create_surface: CreateSurfaceMessage,
        create_region: CreateRegionMessage,
    };

    const CreateSurfaceMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
    };

    const CreateRegionMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
    };
};

// wl_shm_pool
pub const WlShmPool = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // create_buffer
            0 => {
                var id: u32 = try self.client.context.nextU32();
                var offset: i32 = try self.client.context.nextI32();
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                var stride: i32 = try self.client.context.nextI32();
                var format: u32 = try self.client.context.nextU32();
                return Message{
                    .create_buffer = CreateBufferMessage{
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
                    .destroy = DestroyMessage{},
                };
            },
            // resize
            2 => {
                var size: i32 = try self.client.context.nextI32();
                return Message{
                    .resize = ResizeMessage{
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
        create_buffer: CreateBufferMessage,
        destroy: DestroyMessage,
        resize: ResizeMessage,
    };

    const CreateBufferMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
        offset: i32,
        width: i32,
        height: i32,
        stride: i32,
        format: u32,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const ResizeMessage = struct {
        // TODO: should we include the interface's Object?
        size: i32,
    };
};

// wl_shm
pub const WlShm = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // create_pool
            0 => {
                var id: u32 = try self.client.context.nextU32();
                var fd: i32 = try self.client.context.nextFd();
                var size: i32 = try self.client.context.nextI32();
                return Message{
                    .create_pool = CreatePoolMessage{
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
        create_pool: CreatePoolMessage,
    };

    const CreatePoolMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
        fd: i32,
        size: i32,
    };

    //
    // Informs the client about a valid pixel format that
    // can be used for buffers. Known formats include
    // argb8888 and xrgb8888.
    //
    pub fn sendFormat(self: Self, format: Format) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(@enumToInt(format));
        try self.client.context.finishWrite(self.id, 0);
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
    };
};

// wl_buffer
pub const WlBuffer = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
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
        destroy: DestroyMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
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
    pub fn sendRelease(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 0);
    }
};

// wl_data_offer
pub const WlDataOffer = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // accept
            0 => {
                var serial: u32 = try self.client.context.nextU32();
                var mime_type: []u8 = try self.client.context.nextString();
                return Message{
                    .accept = AcceptMessage{
                        .serial = serial,
                        .mime_type = mime_type,
                    },
                };
            },
            // receive
            1 => {
                var mime_type: []u8 = try self.client.context.nextString();
                var fd: i32 = try self.client.context.nextFd();
                return Message{
                    .receive = ReceiveMessage{
                        .mime_type = mime_type,
                        .fd = fd,
                    },
                };
            },
            // destroy
            2 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // finish
            3 => {
                return Message{
                    .finish = FinishMessage{},
                };
            },
            // set_actions
            4 => {
                var dnd_actions: u32 = try self.client.context.nextU32();
                var preferred_action: u32 = try self.client.context.nextU32();
                return Message{
                    .set_actions = SetActionsMessage{
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
        accept: AcceptMessage,
        receive: ReceiveMessage,
        destroy: DestroyMessage,
        finish: FinishMessage,
        set_actions: SetActionsMessage,
    };

    const AcceptMessage = struct {
        // TODO: should we include the interface's Object?
        serial: u32,
        mime_type: []u8,
    };

    const ReceiveMessage = struct {
        // TODO: should we include the interface's Object?
        mime_type: []u8,
        fd: i32,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const FinishMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const SetActionsMessage = struct {
        // TODO: should we include the interface's Object?
        dnd_actions: u32,
        preferred_action: u32,
    };

    //
    // Sent immediately after creating the wl_data_offer object.  One
    // event per offered mime type.
    //
    pub fn sendOffer(self: Self, mime_type: []const u8) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putString(mime_type);
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    // This event indicates the actions offered by the data source. It
    // will be sent right after wl_data_device.enter, or anytime the source
    // side changes its offered actions through wl_data_source.set_actions.
    //
    pub fn sendSourceActions(self: Self, source_actions: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(source_actions);
        try self.client.context.finishWrite(self.id, 1);
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
    pub fn sendAction(self: Self, dnd_action: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(dnd_action);
        try self.client.context.finishWrite(self.id, 2);
    }

    pub const Error = enum(u32) {
        invalid_finish = 0,
        invalid_action_mask = 1,
        invalid_action = 2,
        invalid_offer = 3,
    };
};

// wl_data_source
pub const WlDataSource = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // offer
            0 => {
                var mime_type: []u8 = try self.client.context.nextString();
                return Message{
                    .offer = OfferMessage{
                        .mime_type = mime_type,
                    },
                };
            },
            // destroy
            1 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // set_actions
            2 => {
                var dnd_actions: u32 = try self.client.context.nextU32();
                return Message{
                    .set_actions = SetActionsMessage{
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
        offer: OfferMessage,
        destroy: DestroyMessage,
        set_actions: SetActionsMessage,
    };

    const OfferMessage = struct {
        // TODO: should we include the interface's Object?
        mime_type: []u8,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const SetActionsMessage = struct {
        // TODO: should we include the interface's Object?
        dnd_actions: u32,
    };

    //
    // Sent when a target accepts pointer_focus or motion events.  If
    // a target does not accept any of the offered types, type is NULL.
    //
    // Used for feedback during drag-and-drop.
    //
    pub fn sendTarget(self: Self, mime_type: []const u8) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putString(mime_type);
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    // Request for data from the client.  Send the data as the
    // specified mime type over the passed file descriptor, then
    // close it.
    //
    pub fn sendSend(self: Self, mime_type: []const u8, fd: i32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putString(mime_type);
        self.client.context.putFd(fd);
        try self.client.context.finishWrite(self.id, 1);
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
    pub fn sendCancelled(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 2);
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
    pub fn sendDndDropPerformed(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 3);
    }

    //
    // The drop destination finished interoperating with this data
    // source, so the client is now free to destroy this data source and
    // free all associated data.
    //
    // If the action used to perform the operation was "move", the
    // source can now delete the transferred data.
    //
    pub fn sendDndFinished(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 4);
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
    pub fn sendAction(self: Self, dnd_action: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(dnd_action);
        try self.client.context.finishWrite(self.id, 5);
    }

    pub const Error = enum(u32) {
        invalid_action_mask = 0,
        invalid_source = 1,
    };
};

// wl_data_device
pub const WlDataDevice = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // start_drag
            0 => {
                var source: ?WlDataSource = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_data_source => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                var origin: WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var icon: ?WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                var serial: u32 = try self.client.context.nextU32();
                return Message{
                    .start_drag = StartDragMessage{
                        .source = source,
                        .origin = origin,
                        .icon = icon,
                        .serial = serial,
                    },
                };
            },
            // set_selection
            1 => {
                var source: ?WlDataSource = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_data_source => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                var serial: u32 = try self.client.context.nextU32();
                return Message{
                    .set_selection = SetSelectionMessage{
                        .source = source,
                        .serial = serial,
                    },
                };
            },
            // release
            2 => {
                return Message{
                    .release = ReleaseMessage{},
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
        start_drag: StartDragMessage,
        set_selection: SetSelectionMessage,
        release: ReleaseMessage,
    };

    const StartDragMessage = struct {
        // TODO: should we include the interface's Object?
        source: ?WlDataSource,
        origin: WlSurface,
        icon: ?WlSurface,
        serial: u32,
    };

    const SetSelectionMessage = struct {
        // TODO: should we include the interface's Object?
        source: ?WlDataSource,
        serial: u32,
    };

    const ReleaseMessage = struct {
        // TODO: should we include the interface's Object?
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
    pub fn sendDataOffer(self: Self, id: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(id);
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    // This event is sent when an active drag-and-drop pointer enters
    // a surface owned by the client.  The position of the pointer at
    // enter time is provided by the x and y arguments, in surface-local
    // coordinates.
    //
    pub fn sendEnter(self: Self, serial: u32, surface: u32, x: f32, y: f32, id: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        self.client.context.putU32(surface);
        self.client.context.putFixed(x);
        self.client.context.putFixed(y);
        self.client.context.putU32(id);
        try self.client.context.finishWrite(self.id, 1);
    }

    //
    // This event is sent when the drag-and-drop pointer leaves the
    // surface and the session ends.  The client must destroy the
    // wl_data_offer introduced at enter time at this point.
    //
    pub fn sendLeave(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 2);
    }

    //
    // This event is sent when the drag-and-drop pointer moves within
    // the currently focused surface. The new position of the pointer
    // is provided by the x and y arguments, in surface-local
    // coordinates.
    //
    pub fn sendMotion(self: Self, time: u32, x: f32, y: f32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(time);
        self.client.context.putFixed(x);
        self.client.context.putFixed(y);
        try self.client.context.finishWrite(self.id, 3);
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
    pub fn sendDrop(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 4);
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
    // or until the client loses keyboard focus.  The client must
    // destroy the previous selection data_offer, if any, upon receiving
    // this event.
    //
    pub fn sendSelection(self: Self, id: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(id);
        try self.client.context.finishWrite(self.id, 5);
    }

    pub const Error = enum(u32) {
        role = 0,
    };
};

// wl_data_device_manager
pub const WlDataDeviceManager = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // create_data_source
            0 => {
                var id: u32 = try self.client.context.nextU32();
                return Message{
                    .create_data_source = CreateDataSourceMessage{
                        .id = id,
                    },
                };
            },
            // get_data_device
            1 => {
                var id: u32 = try self.client.context.nextU32();
                var seat: WlSeat = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_seat => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                return Message{
                    .get_data_device = GetDataDeviceMessage{
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
        create_data_source: CreateDataSourceMessage,
        get_data_device: GetDataDeviceMessage,
    };

    const CreateDataSourceMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
    };

    const GetDataDeviceMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
        seat: WlSeat,
    };

    pub const DndAction = enum(u32) {
        none = 0,
        copy = 1,
        move = 2,
        ask = 4,
    };
};

// wl_shell
pub const WlShell = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // get_shell_surface
            0 => {
                var id: u32 = try self.client.context.nextU32();
                var surface: WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                return Message{
                    .get_shell_surface = GetShellSurfaceMessage{
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
        get_shell_surface: GetShellSurfaceMessage,
    };

    const GetShellSurfaceMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
        surface: WlSurface,
    };

    pub const Error = enum(u32) {
        role = 0,
    };
};

// wl_shell_surface
pub const WlShellSurface = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // pong
            0 => {
                var serial: u32 = try self.client.context.nextU32();
                return Message{
                    .pong = PongMessage{
                        .serial = serial,
                    },
                };
            },
            // move
            1 => {
                var seat: WlSeat = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_seat => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var serial: u32 = try self.client.context.nextU32();
                return Message{
                    .move = MoveMessage{
                        .seat = seat,
                        .serial = serial,
                    },
                };
            },
            // resize
            2 => {
                var seat: WlSeat = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_seat => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var serial: u32 = try self.client.context.nextU32();
                var edges: u32 = try self.client.context.nextU32();
                return Message{
                    .resize = ResizeMessage{
                        .seat = seat,
                        .serial = serial,
                        .edges = edges,
                    },
                };
            },
            // set_toplevel
            3 => {
                return Message{
                    .set_toplevel = SetToplevelMessage{},
                };
            },
            // set_transient
            4 => {
                var parent: WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                var flags: u32 = try self.client.context.nextU32();
                return Message{
                    .set_transient = SetTransientMessage{
                        .parent = parent,
                        .x = x,
                        .y = y,
                        .flags = flags,
                    },
                };
            },
            // set_fullscreen
            5 => {
                var method: u32 = try self.client.context.nextU32();
                var framerate: u32 = try self.client.context.nextU32();
                var output: ?WlOutput = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_output => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                return Message{
                    .set_fullscreen = SetFullscreenMessage{
                        .method = method,
                        .framerate = framerate,
                        .output = output,
                    },
                };
            },
            // set_popup
            6 => {
                var seat: WlSeat = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_seat => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var serial: u32 = try self.client.context.nextU32();
                var parent: WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                var flags: u32 = try self.client.context.nextU32();
                return Message{
                    .set_popup = SetPopupMessage{
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
                var output: ?WlOutput = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_output => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                return Message{
                    .set_maximized = SetMaximizedMessage{
                        .output = output,
                    },
                };
            },
            // set_title
            8 => {
                var title: []u8 = try self.client.context.nextString();
                return Message{
                    .set_title = SetTitleMessage{
                        .title = title,
                    },
                };
            },
            // set_class
            9 => {
                var class_: []u8 = try self.client.context.nextString();
                return Message{
                    .set_class = SetClassMessage{
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
        pong: PongMessage,
        move: MoveMessage,
        resize: ResizeMessage,
        set_toplevel: SetToplevelMessage,
        set_transient: SetTransientMessage,
        set_fullscreen: SetFullscreenMessage,
        set_popup: SetPopupMessage,
        set_maximized: SetMaximizedMessage,
        set_title: SetTitleMessage,
        set_class: SetClassMessage,
    };

    const PongMessage = struct {
        // TODO: should we include the interface's Object?
        serial: u32,
    };

    const MoveMessage = struct {
        // TODO: should we include the interface's Object?
        seat: WlSeat,
        serial: u32,
    };

    const ResizeMessage = struct {
        // TODO: should we include the interface's Object?
        seat: WlSeat,
        serial: u32,
        edges: u32,
    };

    const SetToplevelMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const SetTransientMessage = struct {
        // TODO: should we include the interface's Object?
        parent: WlSurface,
        x: i32,
        y: i32,
        flags: u32,
    };

    const SetFullscreenMessage = struct {
        // TODO: should we include the interface's Object?
        method: u32,
        framerate: u32,
        output: ?WlOutput,
    };

    const SetPopupMessage = struct {
        // TODO: should we include the interface's Object?
        seat: WlSeat,
        serial: u32,
        parent: WlSurface,
        x: i32,
        y: i32,
        flags: u32,
    };

    const SetMaximizedMessage = struct {
        // TODO: should we include the interface's Object?
        output: ?WlOutput,
    };

    const SetTitleMessage = struct {
        // TODO: should we include the interface's Object?
        title: []u8,
    };

    const SetClassMessage = struct {
        // TODO: should we include the interface's Object?
        class_: []u8,
    };

    //
    // Ping a client to check if it is receiving events and sending
    // requests. A client is expected to reply with a pong request.
    //
    pub fn sendPing(self: Self, serial: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        try self.client.context.finishWrite(self.id, 0);
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
    pub fn sendConfigure(self: Self, edges: Resize, width: i32, height: i32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(@enumToInt(edges));
        self.client.context.putI32(width);
        self.client.context.putI32(height);
        try self.client.context.finishWrite(self.id, 1);
    }

    //
    // The popup_done event is sent out when a popup grab is broken,
    // that is, when the user clicks a surface that doesn't belong
    // to the client owning the popup surface.
    //
    pub fn sendPopupDone(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 2);
    }

    pub const Resize = enum(u32) {
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

    pub const Transient = enum(u32) {
        inactive = 0x1,
    };

    pub const FullscreenMethod = enum(u32) {
        default = 0,
        scale = 1,
        driver = 2,
        fill = 3,
    };
};

// wl_surface
pub const WlSurface = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // attach
            1 => {
                var buffer: ?WlBuffer = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_buffer => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                return Message{
                    .attach = AttachMessage{
                        .buffer = buffer,
                        .x = x,
                        .y = y,
                    },
                };
            },
            // damage
            2 => {
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                return Message{
                    .damage = DamageMessage{
                        .x = x,
                        .y = y,
                        .width = width,
                        .height = height,
                    },
                };
            },
            // frame
            3 => {
                var callback: u32 = try self.client.context.nextU32();
                return Message{
                    .frame = FrameMessage{
                        .callback = callback,
                    },
                };
            },
            // set_opaque_region
            4 => {
                var region: ?WlRegion = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_region => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                return Message{
                    .set_opaque_region = SetOpaqueRegionMessage{
                        .region = region,
                    },
                };
            },
            // set_input_region
            5 => {
                var region: ?WlRegion = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_region => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                return Message{
                    .set_input_region = SetInputRegionMessage{
                        .region = region,
                    },
                };
            },
            // commit
            6 => {
                return Message{
                    .commit = CommitMessage{},
                };
            },
            // set_buffer_transform
            7 => {
                var transform: i32 = try self.client.context.nextI32();
                return Message{
                    .set_buffer_transform = SetBufferTransformMessage{
                        .transform = transform,
                    },
                };
            },
            // set_buffer_scale
            8 => {
                var scale: i32 = try self.client.context.nextI32();
                return Message{
                    .set_buffer_scale = SetBufferScaleMessage{
                        .scale = scale,
                    },
                };
            },
            // damage_buffer
            9 => {
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                return Message{
                    .damage_buffer = DamageBufferMessage{
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
        attach,
        damage,
        frame,
        set_opaque_region,
        set_input_region,
        commit,
        set_buffer_transform,
        set_buffer_scale,
        damage_buffer,
    };

    pub const Message = union(MessageType) {
        destroy: DestroyMessage,
        attach: AttachMessage,
        damage: DamageMessage,
        frame: FrameMessage,
        set_opaque_region: SetOpaqueRegionMessage,
        set_input_region: SetInputRegionMessage,
        commit: CommitMessage,
        set_buffer_transform: SetBufferTransformMessage,
        set_buffer_scale: SetBufferScaleMessage,
        damage_buffer: DamageBufferMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const AttachMessage = struct {
        // TODO: should we include the interface's Object?
        buffer: ?WlBuffer,
        x: i32,
        y: i32,
    };

    const DamageMessage = struct {
        // TODO: should we include the interface's Object?
        x: i32,
        y: i32,
        width: i32,
        height: i32,
    };

    const FrameMessage = struct {
        // TODO: should we include the interface's Object?
        callback: u32,
    };

    const SetOpaqueRegionMessage = struct {
        // TODO: should we include the interface's Object?
        region: ?WlRegion,
    };

    const SetInputRegionMessage = struct {
        // TODO: should we include the interface's Object?
        region: ?WlRegion,
    };

    const CommitMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const SetBufferTransformMessage = struct {
        // TODO: should we include the interface's Object?
        transform: i32,
    };

    const SetBufferScaleMessage = struct {
        // TODO: should we include the interface's Object?
        scale: i32,
    };

    const DamageBufferMessage = struct {
        // TODO: should we include the interface's Object?
        x: i32,
        y: i32,
        width: i32,
        height: i32,
    };

    //
    // This is emitted whenever a surface's creation, movement, or resizing
    // results in some part of it being within the scanout region of an
    // output.
    //
    // Note that a surface may be overlapping with zero or more outputs.
    //
    pub fn sendEnter(self: Self, output: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(output);
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    // This is emitted whenever a surface's creation, movement, or resizing
    // results in it no longer having any part of it within the scanout region
    // of an output.
    //
    pub fn sendLeave(self: Self, output: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(output);
        try self.client.context.finishWrite(self.id, 1);
    }

    pub const Error = enum(u32) {
        invalid_scale = 0,
        invalid_transform = 1,
    };
};

// wl_seat
pub const WlSeat = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // get_pointer
            0 => {
                var id: u32 = try self.client.context.nextU32();
                return Message{
                    .get_pointer = GetPointerMessage{
                        .id = id,
                    },
                };
            },
            // get_keyboard
            1 => {
                var id: u32 = try self.client.context.nextU32();
                return Message{
                    .get_keyboard = GetKeyboardMessage{
                        .id = id,
                    },
                };
            },
            // get_touch
            2 => {
                var id: u32 = try self.client.context.nextU32();
                return Message{
                    .get_touch = GetTouchMessage{
                        .id = id,
                    },
                };
            },
            // release
            3 => {
                return Message{
                    .release = ReleaseMessage{},
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
        get_pointer: GetPointerMessage,
        get_keyboard: GetKeyboardMessage,
        get_touch: GetTouchMessage,
        release: ReleaseMessage,
    };

    const GetPointerMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
    };

    const GetKeyboardMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
    };

    const GetTouchMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
    };

    const ReleaseMessage = struct {
        // TODO: should we include the interface's Object?
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
    pub fn sendCapabilities(self: Self, capabilities: Capability) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(@enumToInt(capabilities));
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    // In a multiseat configuration this can be used by the client to help
    // identify which physical devices the seat represents. Based on
    // the seat configuration used by the compositor.
    //
    pub fn sendName(self: Self, name: []const u8) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putString(name);
        try self.client.context.finishWrite(self.id, 1);
    }

    pub const Capability = enum(u32) {
        pointer = 1,
        keyboard = 2,
        touch = 4,
    };
};

// wl_pointer
pub const WlPointer = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // set_cursor
            0 => {
                var serial: u32 = try self.client.context.nextU32();
                var surface: ?WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                var hotspot_x: i32 = try self.client.context.nextI32();
                var hotspot_y: i32 = try self.client.context.nextI32();
                return Message{
                    .set_cursor = SetCursorMessage{
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
                    .release = ReleaseMessage{},
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
        set_cursor: SetCursorMessage,
        release: ReleaseMessage,
    };

    const SetCursorMessage = struct {
        // TODO: should we include the interface's Object?
        serial: u32,
        surface: ?WlSurface,
        hotspot_x: i32,
        hotspot_y: i32,
    };

    const ReleaseMessage = struct {
        // TODO: should we include the interface's Object?
    };

    //
    // Notification that this seat's pointer is focused on a certain
    // surface.
    //
    // When a seat's focus enters a surface, the pointer image
    // is undefined and a client should respond to this event by setting
    // an appropriate pointer image with the set_cursor request.
    //
    pub fn sendEnter(self: Self, serial: u32, surface: u32, surface_x: f32, surface_y: f32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        self.client.context.putU32(surface);
        self.client.context.putFixed(surface_x);
        self.client.context.putFixed(surface_y);
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    // Notification that this seat's pointer is no longer focused on
    // a certain surface.
    //
    // The leave notification is sent before the enter notification
    // for the new focus.
    //
    pub fn sendLeave(self: Self, serial: u32, surface: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        self.client.context.putU32(surface);
        try self.client.context.finishWrite(self.id, 1);
    }

    //
    // Notification of pointer location change. The arguments
    // surface_x and surface_y are the location relative to the
    // focused surface.
    //
    pub fn sendMotion(self: Self, time: u32, surface_x: f32, surface_y: f32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(time);
        self.client.context.putFixed(surface_x);
        self.client.context.putFixed(surface_y);
        try self.client.context.finishWrite(self.id, 2);
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
    pub fn sendButton(self: Self, serial: u32, time: u32, button: u32, state: ButtonState) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        self.client.context.putU32(time);
        self.client.context.putU32(button);
        self.client.context.putU32(@enumToInt(state));
        try self.client.context.finishWrite(self.id, 3);
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
    pub fn sendAxis(self: Self, time: u32, axis: Axis, value: f32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(time);
        self.client.context.putU32(@enumToInt(axis));
        self.client.context.putFixed(value);
        try self.client.context.finishWrite(self.id, 4);
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
    pub fn sendFrame(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 5);
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
    pub fn sendAxisSource(self: Self, axis_source: AxisSource) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(@enumToInt(axis_source));
        try self.client.context.finishWrite(self.id, 6);
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
    pub fn sendAxisStop(self: Self, time: u32, axis: Axis) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(time);
        self.client.context.putU32(@enumToInt(axis));
        try self.client.context.finishWrite(self.id, 7);
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
    pub fn sendAxisDiscrete(self: Self, axis: Axis, discrete: i32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(@enumToInt(axis));
        self.client.context.putI32(discrete);
        try self.client.context.finishWrite(self.id, 8);
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
};

// wl_keyboard
pub const WlKeyboard = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // release
            0 => {
                return Message{
                    .release = ReleaseMessage{},
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
        release: ReleaseMessage,
    };

    const ReleaseMessage = struct {
        // TODO: should we include the interface's Object?
    };

    //
    // This event provides a file descriptor to the client which can be
    // memory-mapped to provide a keyboard mapping description.
    //
    // From version 7 onwards, the fd must be mapped with MAP_PRIVATE by
    // the recipient, as MAP_SHARED may fail.
    //
    pub fn sendKeymap(self: Self, format: KeymapFormat, fd: i32, size: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(@enumToInt(format));
        self.client.context.putFd(fd);
        self.client.context.putU32(size);
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    // Notification that this seat's keyboard focus is on a certain
    // surface.
    //
    pub fn sendEnter(self: Self, serial: u32, surface: u32, keys: []u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        self.client.context.putU32(surface);
        self.client.context.putArray(keys);
        try self.client.context.finishWrite(self.id, 1);
    }

    //
    // Notification that this seat's keyboard focus is no longer on
    // a certain surface.
    //
    // The leave notification is sent before the enter notification
    // for the new focus.
    //
    pub fn sendLeave(self: Self, serial: u32, surface: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        self.client.context.putU32(surface);
        try self.client.context.finishWrite(self.id, 2);
    }

    //
    // A key was pressed or released.
    // The time argument is a timestamp with millisecond
    // granularity, with an undefined base.
    //
    pub fn sendKey(self: Self, serial: u32, time: u32, key: u32, state: KeyState) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        self.client.context.putU32(time);
        self.client.context.putU32(key);
        self.client.context.putU32(@enumToInt(state));
        try self.client.context.finishWrite(self.id, 3);
    }

    //
    // Notifies clients that the modifier and/or group state has
    // changed, and it should update its local state.
    //
    pub fn sendModifiers(self: Self, serial: u32, mods_depressed: u32, mods_latched: u32, mods_locked: u32, group: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        self.client.context.putU32(mods_depressed);
        self.client.context.putU32(mods_latched);
        self.client.context.putU32(mods_locked);
        self.client.context.putU32(group);
        try self.client.context.finishWrite(self.id, 4);
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
    pub fn sendRepeatInfo(self: Self, rate: i32, delay: i32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putI32(rate);
        self.client.context.putI32(delay);
        try self.client.context.finishWrite(self.id, 5);
    }

    pub const KeymapFormat = enum(u32) {
        no_keymap = 0,
        xkb_v1 = 1,
    };

    pub const KeyState = enum(u32) {
        released = 0,
        pressed = 1,
    };
};

// wl_touch
pub const WlTouch = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // release
            0 => {
                return Message{
                    .release = ReleaseMessage{},
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
        release: ReleaseMessage,
    };

    const ReleaseMessage = struct {
        // TODO: should we include the interface's Object?
    };

    //
    // A new touch point has appeared on the surface. This touch point is
    // assigned a unique ID. Future events from this touch point reference
    // this ID. The ID ceases to be valid after a touch up event and may be
    // reused in the future.
    //
    pub fn sendDown(self: Self, serial: u32, time: u32, surface: u32, id: i32, x: f32, y: f32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        self.client.context.putU32(time);
        self.client.context.putU32(surface);
        self.client.context.putI32(id);
        self.client.context.putFixed(x);
        self.client.context.putFixed(y);
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    // The touch point has disappeared. No further events will be sent for
    // this touch point and the touch point's ID is released and may be
    // reused in a future touch down event.
    //
    pub fn sendUp(self: Self, serial: u32, time: u32, id: i32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        self.client.context.putU32(time);
        self.client.context.putI32(id);
        try self.client.context.finishWrite(self.id, 1);
    }

    //
    // A touch point has changed coordinates.
    //
    pub fn sendMotion(self: Self, time: u32, id: i32, x: f32, y: f32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(time);
        self.client.context.putI32(id);
        self.client.context.putFixed(x);
        self.client.context.putFixed(y);
        try self.client.context.finishWrite(self.id, 2);
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
    pub fn sendFrame(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 3);
    }

    //
    // Sent if the compositor decides the touch stream is a global
    // gesture. No further events are sent to the clients from that
    // particular gesture. Touch cancellation applies to all touch points
    // currently active on this client's surface. The client is
    // responsible for finalizing the touch points, future touch points on
    // this surface may reuse the touch point ID.
    //
    pub fn sendCancel(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 4);
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
    pub fn sendShape(self: Self, id: i32, major: f32, minor: f32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putI32(id);
        self.client.context.putFixed(major);
        self.client.context.putFixed(minor);
        try self.client.context.finishWrite(self.id, 5);
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
    pub fn sendOrientation(self: Self, id: i32, orientation: f32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putI32(id);
        self.client.context.putFixed(orientation);
        try self.client.context.finishWrite(self.id, 6);
    }
};

// wl_output
pub const WlOutput = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // release
            0 => {
                return Message{
                    .release = ReleaseMessage{},
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
        release: ReleaseMessage,
    };

    const ReleaseMessage = struct {
        // TODO: should we include the interface's Object?
    };

    //
    // The geometry event describes geometric properties of the output.
    // The event is sent when binding to the output object and whenever
    // any of the properties change.
    //
    // The physical size can be set to zero if it doesn't make sense for this
    // output (e.g. for projectors or virtual outputs).
    //
    // Note: wl_output only advertises partial information about the output
    // position and identification. Some compositors, for instance those not
    // implementing a desktop-style output layout or those exposing virtual
    // outputs, might fake this information. Instead of using x and y, clients
    // should use xdg_output.logical_position. Instead of using make and model,
    // clients should use xdg_output.name and xdg_output.description.
    //
    pub fn sendGeometry(self: Self, x: i32, y: i32, physical_width: i32, physical_height: i32, subpixel: Subpixel, make: []const u8, model: []const u8, transform: Transform) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putI32(x);
        self.client.context.putI32(y);
        self.client.context.putI32(physical_width);
        self.client.context.putI32(physical_height);
        self.client.context.putI32(@enumToInt(subpixel));
        self.client.context.putString(make);
        self.client.context.putString(model);
        self.client.context.putI32(@enumToInt(transform));
        try self.client.context.finishWrite(self.id, 0);
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
    // The size of a mode is given in physical hardware units of
    // the output device. This is not necessarily the same as
    // the output size in the global compositor space. For instance,
    // the output may be scaled, as described in wl_output.scale,
    // or transformed, as described in wl_output.transform. Clients
    // willing to retrieve the output size in the global compositor
    // space should use xdg_output.logical_size instead.
    //
    // Clients should not use the refresh rate to schedule frames. Instead,
    // they should use the wl_surface.frame event or the presentation-time
    // protocol.
    //
    // Note: this information is not always meaningful for all outputs. Some
    // compositors, such as those exposing virtual outputs, might fake the
    // refresh rate or the size.
    //
    pub fn sendMode(self: Self, flags: Mode, width: i32, height: i32, refresh: i32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(@enumToInt(flags));
        self.client.context.putI32(width);
        self.client.context.putI32(height);
        self.client.context.putI32(refresh);
        try self.client.context.finishWrite(self.id, 1);
    }

    //
    // This event is sent after all other properties have been
    // sent after binding to the output object and after any
    // other property changes done after that. This allows
    // changes to the output properties to be seen as
    // atomic, even if they happen via multiple events.
    //
    pub fn sendDone(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 2);
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
    pub fn sendScale(self: Self, factor: i32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putI32(factor);
        try self.client.context.finishWrite(self.id, 3);
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

    pub const Mode = enum(u32) {
        current = 0x1,
        preferred = 0x2,
    };
};

// wl_region
pub const WlRegion = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // add
            1 => {
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                return Message{
                    .add = AddMessage{
                        .x = x,
                        .y = y,
                        .width = width,
                        .height = height,
                    },
                };
            },
            // subtract
            2 => {
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                return Message{
                    .subtract = SubtractMessage{
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
        destroy: DestroyMessage,
        add: AddMessage,
        subtract: SubtractMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const AddMessage = struct {
        // TODO: should we include the interface's Object?
        x: i32,
        y: i32,
        width: i32,
        height: i32,
    };

    const SubtractMessage = struct {
        // TODO: should we include the interface's Object?
        x: i32,
        y: i32,
        width: i32,
        height: i32,
    };
};

// wl_subcompositor
pub const WlSubcompositor = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // get_subsurface
            1 => {
                var id: u32 = try self.client.context.nextU32();
                var surface: WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var parent: WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                return Message{
                    .get_subsurface = GetSubsurfaceMessage{
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
        destroy: DestroyMessage,
        get_subsurface: GetSubsurfaceMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const GetSubsurfaceMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
        surface: WlSurface,
        parent: WlSurface,
    };

    pub const Error = enum(u32) {
        bad_surface = 0,
    };
};

// wl_subsurface
pub const WlSubsurface = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // set_position
            1 => {
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                return Message{
                    .set_position = SetPositionMessage{
                        .x = x,
                        .y = y,
                    },
                };
            },
            // place_above
            2 => {
                var sibling: WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                return Message{
                    .place_above = PlaceAboveMessage{
                        .sibling = sibling,
                    },
                };
            },
            // place_below
            3 => {
                var sibling: WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                return Message{
                    .place_below = PlaceBelowMessage{
                        .sibling = sibling,
                    },
                };
            },
            // set_sync
            4 => {
                return Message{
                    .set_sync = SetSyncMessage{},
                };
            },
            // set_desync
            5 => {
                return Message{
                    .set_desync = SetDesyncMessage{},
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
        destroy: DestroyMessage,
        set_position: SetPositionMessage,
        place_above: PlaceAboveMessage,
        place_below: PlaceBelowMessage,
        set_sync: SetSyncMessage,
        set_desync: SetDesyncMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const SetPositionMessage = struct {
        // TODO: should we include the interface's Object?
        x: i32,
        y: i32,
    };

    const PlaceAboveMessage = struct {
        // TODO: should we include the interface's Object?
        sibling: WlSurface,
    };

    const PlaceBelowMessage = struct {
        // TODO: should we include the interface's Object?
        sibling: WlSurface,
    };

    const SetSyncMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const SetDesyncMessage = struct {
        // TODO: should we include the interface's Object?
    };

    pub const Error = enum(u32) {
        bad_surface = 0,
    };
};

// xdg_wm_base
pub const XdgWmBase = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // create_positioner
            1 => {
                var id: u32 = try self.client.context.nextU32();
                return Message{
                    .create_positioner = CreatePositionerMessage{
                        .id = id,
                    },
                };
            },
            // get_xdg_surface
            2 => {
                var id: u32 = try self.client.context.nextU32();
                var surface: WlSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                return Message{
                    .get_xdg_surface = GetXdgSurfaceMessage{
                        .id = id,
                        .surface = surface,
                    },
                };
            },
            // pong
            3 => {
                var serial: u32 = try self.client.context.nextU32();
                return Message{
                    .pong = PongMessage{
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
        destroy: DestroyMessage,
        create_positioner: CreatePositionerMessage,
        get_xdg_surface: GetXdgSurfaceMessage,
        pong: PongMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const CreatePositionerMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
    };

    const GetXdgSurfaceMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
        surface: WlSurface,
    };

    const PongMessage = struct {
        // TODO: should we include the interface's Object?
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
    pub fn sendPing(self: Self, serial: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        try self.client.context.finishWrite(self.id, 0);
    }

    pub const Error = enum(u32) {
        role = 0,
        defunct_surfaces = 1,
        not_the_topmost_popup = 2,
        invalid_popup_parent = 3,
        invalid_surface_state = 4,
        invalid_positioner = 5,
    };
};

// xdg_positioner
pub const XdgPositioner = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // set_size
            1 => {
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                return Message{
                    .set_size = SetSizeMessage{
                        .width = width,
                        .height = height,
                    },
                };
            },
            // set_anchor_rect
            2 => {
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                return Message{
                    .set_anchor_rect = SetAnchorRectMessage{
                        .x = x,
                        .y = y,
                        .width = width,
                        .height = height,
                    },
                };
            },
            // set_anchor
            3 => {
                var anchor: u32 = try self.client.context.nextU32();
                return Message{
                    .set_anchor = SetAnchorMessage{
                        .anchor = anchor,
                    },
                };
            },
            // set_gravity
            4 => {
                var gravity: u32 = try self.client.context.nextU32();
                return Message{
                    .set_gravity = SetGravityMessage{
                        .gravity = gravity,
                    },
                };
            },
            // set_constraint_adjustment
            5 => {
                var constraint_adjustment: u32 = try self.client.context.nextU32();
                return Message{
                    .set_constraint_adjustment = SetConstraintAdjustmentMessage{
                        .constraint_adjustment = constraint_adjustment,
                    },
                };
            },
            // set_offset
            6 => {
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                return Message{
                    .set_offset = SetOffsetMessage{
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
        set_size,
        set_anchor_rect,
        set_anchor,
        set_gravity,
        set_constraint_adjustment,
        set_offset,
    };

    pub const Message = union(MessageType) {
        destroy: DestroyMessage,
        set_size: SetSizeMessage,
        set_anchor_rect: SetAnchorRectMessage,
        set_anchor: SetAnchorMessage,
        set_gravity: SetGravityMessage,
        set_constraint_adjustment: SetConstraintAdjustmentMessage,
        set_offset: SetOffsetMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const SetSizeMessage = struct {
        // TODO: should we include the interface's Object?
        width: i32,
        height: i32,
    };

    const SetAnchorRectMessage = struct {
        // TODO: should we include the interface's Object?
        x: i32,
        y: i32,
        width: i32,
        height: i32,
    };

    const SetAnchorMessage = struct {
        // TODO: should we include the interface's Object?
        anchor: u32,
    };

    const SetGravityMessage = struct {
        // TODO: should we include the interface's Object?
        gravity: u32,
    };

    const SetConstraintAdjustmentMessage = struct {
        // TODO: should we include the interface's Object?
        constraint_adjustment: u32,
    };

    const SetOffsetMessage = struct {
        // TODO: should we include the interface's Object?
        x: i32,
        y: i32,
    };

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

    pub const ConstraintAdjustment = enum(u32) {
        none = 0,
        slide_x = 1,
        slide_y = 2,
        flip_x = 4,
        flip_y = 8,
        resize_x = 16,
        resize_y = 32,
    };
};

// xdg_surface
pub const XdgSurface = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // get_toplevel
            1 => {
                var id: u32 = try self.client.context.nextU32();
                return Message{
                    .get_toplevel = GetToplevelMessage{
                        .id = id,
                    },
                };
            },
            // get_popup
            2 => {
                var id: u32 = try self.client.context.nextU32();
                var parent: ?XdgSurface = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .xdg_surface => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                var positioner: XdgPositioner = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .xdg_positioner => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                return Message{
                    .get_popup = GetPopupMessage{
                        .id = id,
                        .parent = parent,
                        .positioner = positioner,
                    },
                };
            },
            // set_window_geometry
            3 => {
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                return Message{
                    .set_window_geometry = SetWindowGeometryMessage{
                        .x = x,
                        .y = y,
                        .width = width,
                        .height = height,
                    },
                };
            },
            // ack_configure
            4 => {
                var serial: u32 = try self.client.context.nextU32();
                return Message{
                    .ack_configure = AckConfigureMessage{
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
        destroy: DestroyMessage,
        get_toplevel: GetToplevelMessage,
        get_popup: GetPopupMessage,
        set_window_geometry: SetWindowGeometryMessage,
        ack_configure: AckConfigureMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const GetToplevelMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
    };

    const GetPopupMessage = struct {
        // TODO: should we include the interface's Object?
        id: u32,
        parent: ?XdgSurface,
        positioner: XdgPositioner,
    };

    const SetWindowGeometryMessage = struct {
        // TODO: should we include the interface's Object?
        x: i32,
        y: i32,
        width: i32,
        height: i32,
    };

    const AckConfigureMessage = struct {
        // TODO: should we include the interface's Object?
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
    pub fn sendConfigure(self: Self, serial: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(serial);
        try self.client.context.finishWrite(self.id, 0);
    }

    pub const Error = enum(u32) {
        not_constructed = 1,
        already_constructed = 2,
        unconfigured_buffer = 3,
    };
};

// xdg_toplevel
pub const XdgToplevel = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // set_parent
            1 => {
                var parent: ?XdgToplevel = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .xdg_toplevel => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                return Message{
                    .set_parent = SetParentMessage{
                        .parent = parent,
                    },
                };
            },
            // set_title
            2 => {
                var title: []u8 = try self.client.context.nextString();
                return Message{
                    .set_title = SetTitleMessage{
                        .title = title,
                    },
                };
            },
            // set_app_id
            3 => {
                var app_id: []u8 = try self.client.context.nextString();
                return Message{
                    .set_app_id = SetAppIdMessage{
                        .app_id = app_id,
                    },
                };
            },
            // show_window_menu
            4 => {
                var seat: WlSeat = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_seat => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var serial: u32 = try self.client.context.nextU32();
                var x: i32 = try self.client.context.nextI32();
                var y: i32 = try self.client.context.nextI32();
                return Message{
                    .show_window_menu = ShowWindowMenuMessage{
                        .seat = seat,
                        .serial = serial,
                        .x = x,
                        .y = y,
                    },
                };
            },
            // move
            5 => {
                var seat: WlSeat = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_seat => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var serial: u32 = try self.client.context.nextU32();
                return Message{
                    .move = MoveMessage{
                        .seat = seat,
                        .serial = serial,
                    },
                };
            },
            // resize
            6 => {
                var seat: WlSeat = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_seat => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var serial: u32 = try self.client.context.nextU32();
                var edges: u32 = try self.client.context.nextU32();
                return Message{
                    .resize = ResizeMessage{
                        .seat = seat,
                        .serial = serial,
                        .edges = edges,
                    },
                };
            },
            // set_max_size
            7 => {
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                return Message{
                    .set_max_size = SetMaxSizeMessage{
                        .width = width,
                        .height = height,
                    },
                };
            },
            // set_min_size
            8 => {
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                return Message{
                    .set_min_size = SetMinSizeMessage{
                        .width = width,
                        .height = height,
                    },
                };
            },
            // set_maximized
            9 => {
                return Message{
                    .set_maximized = SetMaximizedMessage{},
                };
            },
            // unset_maximized
            10 => {
                return Message{
                    .unset_maximized = UnsetMaximizedMessage{},
                };
            },
            // set_fullscreen
            11 => {
                var output: ?WlOutput = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_output => |o| o,
                    else => return error.MismtachObjectTypes,
                } else null;
                return Message{
                    .set_fullscreen = SetFullscreenMessage{
                        .output = output,
                    },
                };
            },
            // unset_fullscreen
            12 => {
                return Message{
                    .unset_fullscreen = UnsetFullscreenMessage{},
                };
            },
            // set_minimized
            13 => {
                return Message{
                    .set_minimized = SetMinimizedMessage{},
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
        destroy: DestroyMessage,
        set_parent: SetParentMessage,
        set_title: SetTitleMessage,
        set_app_id: SetAppIdMessage,
        show_window_menu: ShowWindowMenuMessage,
        move: MoveMessage,
        resize: ResizeMessage,
        set_max_size: SetMaxSizeMessage,
        set_min_size: SetMinSizeMessage,
        set_maximized: SetMaximizedMessage,
        unset_maximized: UnsetMaximizedMessage,
        set_fullscreen: SetFullscreenMessage,
        unset_fullscreen: UnsetFullscreenMessage,
        set_minimized: SetMinimizedMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const SetParentMessage = struct {
        // TODO: should we include the interface's Object?
        parent: ?XdgToplevel,
    };

    const SetTitleMessage = struct {
        // TODO: should we include the interface's Object?
        title: []u8,
    };

    const SetAppIdMessage = struct {
        // TODO: should we include the interface's Object?
        app_id: []u8,
    };

    const ShowWindowMenuMessage = struct {
        // TODO: should we include the interface's Object?
        seat: WlSeat,
        serial: u32,
        x: i32,
        y: i32,
    };

    const MoveMessage = struct {
        // TODO: should we include the interface's Object?
        seat: WlSeat,
        serial: u32,
    };

    const ResizeMessage = struct {
        // TODO: should we include the interface's Object?
        seat: WlSeat,
        serial: u32,
        edges: u32,
    };

    const SetMaxSizeMessage = struct {
        // TODO: should we include the interface's Object?
        width: i32,
        height: i32,
    };

    const SetMinSizeMessage = struct {
        // TODO: should we include the interface's Object?
        width: i32,
        height: i32,
    };

    const SetMaximizedMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const UnsetMaximizedMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const SetFullscreenMessage = struct {
        // TODO: should we include the interface's Object?
        output: ?WlOutput,
    };

    const UnsetFullscreenMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const SetMinimizedMessage = struct {
        // TODO: should we include the interface's Object?
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
    pub fn sendConfigure(self: Self, width: i32, height: i32, states: []u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putI32(width);
        self.client.context.putI32(height);
        self.client.context.putArray(states);
        try self.client.context.finishWrite(self.id, 0);
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
    pub fn sendClose(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 1);
    }

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
};

// xdg_popup
pub const XdgPopup = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // grab
            1 => {
                var seat: WlSeat = if (self.client.context.objects.get(try self.client.context.nextU32())) |obj| switch (obj) {
                    .wl_seat => |o| o,
                    else => return error.MismtachObjectTypes,
                } else return error.ExpectedObject;
                var serial: u32 = try self.client.context.nextU32();
                return Message{
                    .grab = GrabMessage{
                        .seat = seat,
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
        grab,
    };

    pub const Message = union(MessageType) {
        destroy: DestroyMessage,
        grab: GrabMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const GrabMessage = struct {
        // TODO: should we include the interface's Object?
        seat: WlSeat,
        serial: u32,
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
    pub fn sendConfigure(self: Self, x: i32, y: i32, width: i32, height: i32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putI32(x);
        self.client.context.putI32(y);
        self.client.context.putI32(width);
        self.client.context.putI32(height);
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    // The popup_done event is sent out when a popup is dismissed by the
    // compositor. The client should destroy the xdg_popup object at this
    // point.
    //
    pub fn sendPopupDone(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 1);
    }

    pub const Error = enum(u32) {
        invalid_grab = 0,
    };
};

// zwp_linux_dmabuf_v1
pub const ZwpLinuxDmabufV1 = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // create_params
            1 => {
                var params_id: u32 = try self.client.context.nextU32();
                return Message{
                    .create_params = CreateParamsMessage{
                        .params_id = params_id,
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
    };

    pub const Message = union(MessageType) {
        destroy: DestroyMessage,
        create_params: CreateParamsMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const CreateParamsMessage = struct {
        // TODO: should we include the interface's Object?
        params_id: u32,
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
    //         Warning: the 'format' event is likely to be deprecated and replaced
    //         with the 'modifier' event introduced in zwp_linux_dmabuf_v1
    //         version 3, described below. Please refrain from using the information
    //         received from this event.
    //
    pub fn sendFormat(self: Self, format: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(format);
        try self.client.context.finishWrite(self.id, 0);
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
    //         For the definition of the format and modifier codes, see the
    //         zwp_linux_buffer_params_v1::create and zwp_linux_buffer_params_v1::add
    //         requests.
    //
    pub fn sendModifier(self: Self, format: u32, modifier_hi: u32, modifier_lo: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(format);
        self.client.context.putU32(modifier_hi);
        self.client.context.putU32(modifier_lo);
        try self.client.context.finishWrite(self.id, 1);
    }
};

// zwp_linux_buffer_params_v1
pub const ZwpLinuxBufferParamsV1 = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // destroy
            0 => {
                return Message{
                    .destroy = DestroyMessage{},
                };
            },
            // add
            1 => {
                var fd: i32 = try self.client.context.nextFd();
                var plane_idx: u32 = try self.client.context.nextU32();
                var offset: u32 = try self.client.context.nextU32();
                var stride: u32 = try self.client.context.nextU32();
                var modifier_hi: u32 = try self.client.context.nextU32();
                var modifier_lo: u32 = try self.client.context.nextU32();
                return Message{
                    .add = AddMessage{
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
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                var format: u32 = try self.client.context.nextU32();
                var flags: u32 = try self.client.context.nextU32();
                return Message{
                    .create = CreateMessage{
                        .width = width,
                        .height = height,
                        .format = format,
                        .flags = flags,
                    },
                };
            },
            // create_immed
            3 => {
                var buffer_id: u32 = try self.client.context.nextU32();
                var width: i32 = try self.client.context.nextI32();
                var height: i32 = try self.client.context.nextI32();
                var format: u32 = try self.client.context.nextU32();
                var flags: u32 = try self.client.context.nextU32();
                return Message{
                    .create_immed = CreateImmedMessage{
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
        destroy: DestroyMessage,
        add: AddMessage,
        create: CreateMessage,
        create_immed: CreateImmedMessage,
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const AddMessage = struct {
        // TODO: should we include the interface's Object?
        fd: i32,
        plane_idx: u32,
        offset: u32,
        stride: u32,
        modifier_hi: u32,
        modifier_lo: u32,
    };

    const CreateMessage = struct {
        // TODO: should we include the interface's Object?
        width: i32,
        height: i32,
        format: u32,
        flags: u32,
    };

    const CreateImmedMessage = struct {
        // TODO: should we include the interface's Object?
        buffer_id: u32,
        width: i32,
        height: i32,
        format: u32,
        flags: u32,
    };

    //
    //         This event indicates that the attempted buffer creation was
    //         successful. It provides the new wl_buffer referencing the dmabuf(s).
    //
    //         Upon receiving this event, the client should destroy the
    //         zlinux_dmabuf_params object.
    //
    pub fn sendCreated(self: Self, buffer: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(buffer);
        try self.client.context.finishWrite(self.id, 0);
    }

    //
    //         This event indicates that the attempted buffer creation has
    //         failed. It usually means that one of the dmabuf constraints
    //         has not been fulfilled.
    //
    //         Upon receiving this event, the client should destroy the
    //         zlinux_buffer_params object.
    //
    pub fn sendFailed(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 1);
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

    pub const Flags = enum(u32) {
        y_invert = 1,
        interlaced = 2,
        bottom_first = 4,
    };
};

// fw_control
pub const FwControl = struct {
    id: u32,
    client: *Client,
    version: usize,
    container: usize,

    const Self = @This();

    pub fn init(id: u32, client: *Client, version: u32, container: usize) Self {
        return Self{
            .id = id,
            .client = client,
            .version = version,
            .container = container,
        };
    }

    pub fn dispatch(self: *Self, opcode: u16) anyerror!Message {
        switch (opcode) {
            // get_clients
            0 => {
                return Message{
                    .get_clients = GetClientsMessage{},
                };
            },
            // get_windows
            1 => {
                return Message{
                    .get_windows = GetWindowsMessage{},
                };
            },
            // get_window_trees
            2 => {
                return Message{
                    .get_window_trees = GetWindowTreesMessage{},
                };
            },
            // destroy
            3 => {
                return Message{
                    .destroy = DestroyMessage{},
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
        get_clients: GetClientsMessage,
        get_windows: GetWindowsMessage,
        get_window_trees: GetWindowTreesMessage,
        destroy: DestroyMessage,
    };

    const GetClientsMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const GetWindowsMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const GetWindowTreesMessage = struct {
        // TODO: should we include the interface's Object?
    };

    const DestroyMessage = struct {
        // TODO: should we include the interface's Object?
    };

    pub fn sendClient(self: Self, index: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(index);
        try self.client.context.finishWrite(self.id, 0);
    }

    pub fn sendWindow(self: Self, index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, sibling_prev: i32, sibling_next: i32, children_prev: i32, children_next: i32, input_region_id: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(index);
        self.client.context.putI32(parent);
        self.client.context.putU32(wl_surface_id);
        self.client.context.putU32(surface_type);
        self.client.context.putI32(x);
        self.client.context.putI32(y);
        self.client.context.putI32(width);
        self.client.context.putI32(height);
        self.client.context.putI32(sibling_prev);
        self.client.context.putI32(sibling_next);
        self.client.context.putI32(children_prev);
        self.client.context.putI32(children_next);
        self.client.context.putU32(input_region_id);
        try self.client.context.finishWrite(self.id, 1);
    }

    pub fn sendToplevelWindow(self: Self, index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, input_region_id: u32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(index);
        self.client.context.putI32(parent);
        self.client.context.putU32(wl_surface_id);
        self.client.context.putU32(surface_type);
        self.client.context.putI32(x);
        self.client.context.putI32(y);
        self.client.context.putI32(width);
        self.client.context.putI32(height);
        self.client.context.putU32(input_region_id);
        try self.client.context.finishWrite(self.id, 2);
    }

    pub fn sendRegionRect(self: Self, index: u32, x: i32, y: i32, width: i32, height: i32, op: i32) anyerror!void {
        self.client.context.startWrite();
        self.client.context.putU32(index);
        self.client.context.putI32(x);
        self.client.context.putI32(y);
        self.client.context.putI32(width);
        self.client.context.putI32(height);
        self.client.context.putI32(op);
        try self.client.context.finishWrite(self.id, 3);
    }

    pub fn sendDone(self: Self) anyerror!void {
        self.client.context.startWrite();
        try self.client.context.finishWrite(self.id, 4);
    }

    pub const SurfaceType = enum(u32) {
        wl_surface = 0,
        wl_subsurface = 1,
        xdg_toplevel = 2,
        xdg_popup = 3,
    };
};

pub const WlInterfaceType = enum {
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
    fw_control: FwControl,

    pub fn dispatch(self: *WlObject, opcode: u16) !WlMessage {
        return switch (self.*) {
            .wl_display => |*o| WlMessage{ .wl_display = try o.dispatch(opcode) },
            .wl_registry => |*o| WlMessage{ .wl_registry = try o.dispatch(opcode) },
            .wl_callback => |*o| WlMessage{ .wl_callback = try o.dispatch(opcode) },
            .wl_compositor => |*o| WlMessage{ .wl_compositor = try o.dispatch(opcode) },
            .wl_shm_pool => |*o| WlMessage{ .wl_shm_pool = try o.dispatch(opcode) },
            .wl_shm => |*o| WlMessage{ .wl_shm = try o.dispatch(opcode) },
            .wl_buffer => |*o| WlMessage{ .wl_buffer = try o.dispatch(opcode) },
            .wl_data_offer => |*o| WlMessage{ .wl_data_offer = try o.dispatch(opcode) },
            .wl_data_source => |*o| WlMessage{ .wl_data_source = try o.dispatch(opcode) },
            .wl_data_device => |*o| WlMessage{ .wl_data_device = try o.dispatch(opcode) },
            .wl_data_device_manager => |*o| WlMessage{ .wl_data_device_manager = try o.dispatch(opcode) },
            .wl_shell => |*o| WlMessage{ .wl_shell = try o.dispatch(opcode) },
            .wl_shell_surface => |*o| WlMessage{ .wl_shell_surface = try o.dispatch(opcode) },
            .wl_surface => |*o| WlMessage{ .wl_surface = try o.dispatch(opcode) },
            .wl_seat => |*o| WlMessage{ .wl_seat = try o.dispatch(opcode) },
            .wl_pointer => |*o| WlMessage{ .wl_pointer = try o.dispatch(opcode) },
            .wl_keyboard => |*o| WlMessage{ .wl_keyboard = try o.dispatch(opcode) },
            .wl_touch => |*o| WlMessage{ .wl_touch = try o.dispatch(opcode) },
            .wl_output => |*o| WlMessage{ .wl_output = try o.dispatch(opcode) },
            .wl_region => |*o| WlMessage{ .wl_region = try o.dispatch(opcode) },
            .wl_subcompositor => |*o| WlMessage{ .wl_subcompositor = try o.dispatch(opcode) },
            .wl_subsurface => |*o| WlMessage{ .wl_subsurface = try o.dispatch(opcode) },
            .xdg_wm_base => |*o| WlMessage{ .xdg_wm_base = try o.dispatch(opcode) },
            .xdg_positioner => |*o| WlMessage{ .xdg_positioner = try o.dispatch(opcode) },
            .xdg_surface => |*o| WlMessage{ .xdg_surface = try o.dispatch(opcode) },
            .xdg_toplevel => |*o| WlMessage{ .xdg_toplevel = try o.dispatch(opcode) },
            .xdg_popup => |*o| WlMessage{ .xdg_popup = try o.dispatch(opcode) },
            .zwp_linux_dmabuf_v1 => |*o| WlMessage{ .zwp_linux_dmabuf_v1 = try o.dispatch(opcode) },
            .zwp_linux_buffer_params_v1 => |*o| WlMessage{ .zwp_linux_buffer_params_v1 = try o.dispatch(opcode) },
            .fw_control => |*o| WlMessage{ .fw_control = try o.dispatch(opcode) },
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
            .fw_control => |o| o.id,
        };
    }
    // end of id
};
