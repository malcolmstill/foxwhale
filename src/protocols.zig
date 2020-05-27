const std = @import("std");
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;

// wl_display
pub const wl_display_interface = struct {
    // core global object
    sync: ?fn (*Context, Object, u32) anyerror!void,
    get_registry: ?fn (*Context, Object, u32) anyerror!void,
};

fn wl_display_sync_default(context: *Context, object: Object, callback: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_display_get_registry_default(context: *Context, object: Object, registry: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_DISPLAY = wl_display_interface{
    .sync = wl_display_sync_default,
    .get_registry = wl_display_get_registry_default,
};

pub fn new_wl_display(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_display_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_display_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // sync
        0 => {
            var callback: u32 = try object.context.next_u32();
            if (WL_DISPLAY.sync) |sync| {
                try sync(object.context, object, callback);
            }
        },
        // get_registry
        1 => {
            var registry: u32 = try object.context.next_u32();
            if (WL_DISPLAY.get_registry) |get_registry| {
                try get_registry(object.context, object, registry);
            }
        },
        else => {},
    }
}

pub const wl_display_error = enum(u32) {
    invalid_object = 0,
    invalid_method = 1,
    no_memory = 2,
    implementation = 3,
};
// The error event is sent out when a fatal (non-recoverable)
// error has occurred.  The object_id argument is the object
// where the error occurred, most often in response to a request
// to that object.  The code identifies the error and is defined
// by the object interface.  As such, each interface defines its
// own set of error codes.  The message is a brief description
// of the error, for (debugging) convenience.
//
pub fn wl_display_send_error(object: Object, object_id: u32, code: u32, message: []const u8) anyerror!void {
    object.context.startWrite();
    object.context.putU32(object_id);
    object.context.putU32(code);
    object.context.putString(message);
    object.context.finishWrite(object.id, 0);
}
// This event is used internally by the object ID management
// logic.  When a client deletes an object, the server will send
// this event to acknowledge that it has seen the delete request.
// When the client receives this event, it will know that it can
// safely reuse the object ID.
//
pub fn wl_display_send_delete_id(object: Object, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.finishWrite(object.id, 1);
}

// wl_registry
pub const wl_registry_interface = struct {
    // global registry object
    bind: ?fn (*Context, Object, u32, []u8, u32, u32) anyerror!void,
};

fn wl_registry_bind_default(context: *Context, object: Object, name: u32, name_string: []u8, version: u32, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_REGISTRY = wl_registry_interface{
    .bind = wl_registry_bind_default,
};

pub fn new_wl_registry(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_registry_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_registry_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // bind
        0 => {
            var name: u32 = try object.context.next_u32();
            var name_string: []u8 = try object.context.next_string();
            var version: u32 = try object.context.next_u32();
            var id: u32 = try object.context.next_u32();
            if (WL_REGISTRY.bind) |bind| {
                try bind(object.context, object, name, name_string, version, id);
            }
        },
        else => {},
    }
}
// Notify the client of global objects.
//
// The event notifies the client that a global object with
// the given name is now available, and it implements the
// given version of the given interface.
//
pub fn wl_registry_send_global(object: Object, name: u32, interface: []const u8, version: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(name);
    object.context.putString(interface);
    object.context.putU32(version);
    object.context.finishWrite(object.id, 0);
}
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
pub fn wl_registry_send_global_remove(object: Object, name: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(name);
    object.context.finishWrite(object.id, 1);
}

// wl_callback
pub const wl_callback_interface = struct {
    // callback object
};

pub var WL_CALLBACK = wl_callback_interface{};

pub fn new_wl_callback(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_callback_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_callback_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        else => {},
    }
}
// Notify the client when the related request is done.
//
pub fn wl_callback_send_done(object: Object, callback_data: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(callback_data);
    object.context.finishWrite(object.id, 0);
}

// wl_compositor
pub const wl_compositor_interface = struct {
    // the compositor singleton
    create_surface: ?fn (*Context, Object, u32) anyerror!void,
    create_region: ?fn (*Context, Object, u32) anyerror!void,
};

fn wl_compositor_create_surface_default(context: *Context, object: Object, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_compositor_create_region_default(context: *Context, object: Object, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_COMPOSITOR = wl_compositor_interface{
    .create_surface = wl_compositor_create_surface_default,
    .create_region = wl_compositor_create_region_default,
};

pub fn new_wl_compositor(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_compositor_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_compositor_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // create_surface
        0 => {
            var id: u32 = try object.context.next_u32();
            if (WL_COMPOSITOR.create_surface) |create_surface| {
                try create_surface(object.context, object, id);
            }
        },
        // create_region
        1 => {
            var id: u32 = try object.context.next_u32();
            if (WL_COMPOSITOR.create_region) |create_region| {
                try create_region(object.context, object, id);
            }
        },
        else => {},
    }
}

// wl_shm_pool
pub const wl_shm_pool_interface = struct {
    // a shared memory pool
    create_buffer: ?fn (*Context, Object, u32, i32, i32, i32, i32, u32) anyerror!void,
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    resize: ?fn (*Context, Object, i32) anyerror!void,
};

fn wl_shm_pool_create_buffer_default(context: *Context, object: Object, id: u32, offset: i32, width: i32, height: i32, stride: i32, format: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shm_pool_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shm_pool_resize_default(context: *Context, object: Object, size: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SHM_POOL = wl_shm_pool_interface{
    .create_buffer = wl_shm_pool_create_buffer_default,
    .destroy = wl_shm_pool_destroy_default,
    .resize = wl_shm_pool_resize_default,
};

pub fn new_wl_shm_pool(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_shm_pool_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_shm_pool_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // create_buffer
        0 => {
            var id: u32 = try object.context.next_u32();
            var offset: i32 = try object.context.next_i32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            var stride: i32 = try object.context.next_i32();
            var format: u32 = try object.context.next_u32();
            if (WL_SHM_POOL.create_buffer) |create_buffer| {
                try create_buffer(object.context, object, id, offset, width, height, stride, format);
            }
        },
        // destroy
        1 => {
            if (WL_SHM_POOL.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // resize
        2 => {
            var size: i32 = try object.context.next_i32();
            if (WL_SHM_POOL.resize) |resize| {
                try resize(object.context, object, size);
            }
        },
        else => {},
    }
}

// wl_shm
pub const wl_shm_interface = struct {
    // shared memory support
    create_pool: ?fn (*Context, Object, u32, i32, i32) anyerror!void,
};

fn wl_shm_create_pool_default(context: *Context, object: Object, id: u32, fd: i32, size: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SHM = wl_shm_interface{
    .create_pool = wl_shm_create_pool_default,
};

pub fn new_wl_shm(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_shm_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_shm_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // create_pool
        0 => {
            var id: u32 = try object.context.next_u32();
            var fd: i32 = try object.context.next_fd();
            var size: i32 = try object.context.next_i32();
            if (WL_SHM.create_pool) |create_pool| {
                try create_pool(object.context, object, id, fd, size);
            }
        },
        else => {},
    }
}

pub const wl_shm_error = enum(u32) {
    invalid_format = 0,
    invalid_stride = 1,
    invalid_fd = 2,
};

pub const wl_shm_format = enum(u32) {
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
// Informs the client about a valid pixel format that
// can be used for buffers. Known formats include
// argb8888 and xrgb8888.
//
pub fn wl_shm_send_format(object: Object, format: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(format);
    object.context.finishWrite(object.id, 0);
}

// wl_buffer
pub const wl_buffer_interface = struct {
    // content for a wl_surface
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn wl_buffer_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_BUFFER = wl_buffer_interface{
    .destroy = wl_buffer_destroy_default,
};

pub fn new_wl_buffer(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_buffer_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_buffer_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // destroy
        0 => {
            if (WL_BUFFER.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}
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
pub fn wl_buffer_send_release(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 0);
}

// wl_data_offer
pub const wl_data_offer_interface = struct {
    // offer to transfer data
    accept: ?fn (*Context, Object, u32, []u8) anyerror!void,
    receive: ?fn (*Context, Object, []u8, i32) anyerror!void,
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    finish: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    set_actions: ?fn (*Context, Object, u32, u32) anyerror!void,
};

fn wl_data_offer_accept_default(context: *Context, object: Object, serial: u32, mime_type: []u8) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_offer_receive_default(context: *Context, object: Object, mime_type: []u8, fd: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_offer_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_offer_finish_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_offer_set_actions_default(context: *Context, object: Object, dnd_actions: u32, preferred_action: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_DATA_OFFER = wl_data_offer_interface{
    .accept = wl_data_offer_accept_default,
    .receive = wl_data_offer_receive_default,
    .destroy = wl_data_offer_destroy_default,
    .finish = wl_data_offer_finish_default,
    .set_actions = wl_data_offer_set_actions_default,
};

pub fn new_wl_data_offer(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_data_offer_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_data_offer_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // accept
        0 => {
            var serial: u32 = try object.context.next_u32();
            var mime_type: []u8 = try object.context.next_string();
            if (WL_DATA_OFFER.accept) |accept| {
                try accept(object.context, object, serial, mime_type);
            }
        },
        // receive
        1 => {
            var mime_type: []u8 = try object.context.next_string();
            var fd: i32 = try object.context.next_fd();
            if (WL_DATA_OFFER.receive) |receive| {
                try receive(object.context, object, mime_type, fd);
            }
        },
        // destroy
        2 => {
            if (WL_DATA_OFFER.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // finish
        3 => {
            if (WL_DATA_OFFER.finish) |finish| {
                try finish(
                    object.context,
                    object,
                );
            }
        },
        // set_actions
        4 => {
            var dnd_actions: u32 = try object.context.next_u32();
            var preferred_action: u32 = try object.context.next_u32();
            if (WL_DATA_OFFER.set_actions) |set_actions| {
                try set_actions(object.context, object, dnd_actions, preferred_action);
            }
        },
        else => {},
    }
}

pub const wl_data_offer_error = enum(u32) {
    invalid_finish = 0,
    invalid_action_mask = 1,
    invalid_action = 2,
    invalid_offer = 3,
};
// Sent immediately after creating the wl_data_offer object.  One
// event per offered mime type.
//
pub fn wl_data_offer_send_offer(object: Object, mime_type: []const u8) anyerror!void {
    object.context.startWrite();
    object.context.putString(mime_type);
    object.context.finishWrite(object.id, 0);
}
// This event indicates the actions offered by the data source. It
// will be sent right after wl_data_device.enter, or anytime the source
// side changes its offered actions through wl_data_source.set_actions.
//
pub fn wl_data_offer_send_source_actions(object: Object, source_actions: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(source_actions);
    object.context.finishWrite(object.id, 1);
}
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
pub fn wl_data_offer_send_action(object: Object, dnd_action: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(dnd_action);
    object.context.finishWrite(object.id, 2);
}

// wl_data_source
pub const wl_data_source_interface = struct {
    // offer to transfer data
    offer: ?fn (*Context, Object, []u8) anyerror!void,
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    set_actions: ?fn (*Context, Object, u32) anyerror!void,
};

fn wl_data_source_offer_default(context: *Context, object: Object, mime_type: []u8) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_source_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_source_set_actions_default(context: *Context, object: Object, dnd_actions: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_DATA_SOURCE = wl_data_source_interface{
    .offer = wl_data_source_offer_default,
    .destroy = wl_data_source_destroy_default,
    .set_actions = wl_data_source_set_actions_default,
};

pub fn new_wl_data_source(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_data_source_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_data_source_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // offer
        0 => {
            var mime_type: []u8 = try object.context.next_string();
            if (WL_DATA_SOURCE.offer) |offer| {
                try offer(object.context, object, mime_type);
            }
        },
        // destroy
        1 => {
            if (WL_DATA_SOURCE.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // set_actions
        2 => {
            var dnd_actions: u32 = try object.context.next_u32();
            if (WL_DATA_SOURCE.set_actions) |set_actions| {
                try set_actions(object.context, object, dnd_actions);
            }
        },
        else => {},
    }
}

pub const wl_data_source_error = enum(u32) {
    invalid_action_mask = 0,
    invalid_source = 1,
};
// Sent when a target accepts pointer_focus or motion events.  If
// a target does not accept any of the offered types, type is NULL.
//
// Used for feedback during drag-and-drop.
//
pub fn wl_data_source_send_target(object: Object, mime_type: []const u8) anyerror!void {
    object.context.startWrite();
    object.context.putString(mime_type);
    object.context.finishWrite(object.id, 0);
}
// Request for data from the client.  Send the data as the
// specified mime type over the passed file descriptor, then
// close it.
//
pub fn wl_data_source_send_send(object: Object, mime_type: []const u8, fd: i32) anyerror!void {
    object.context.startWrite();
    object.context.putString(mime_type);
    object.context.putFd(fd);
    object.context.finishWrite(object.id, 1);
}
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
pub fn wl_data_source_send_cancelled(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 2);
}
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
pub fn wl_data_source_send_dnd_drop_performed(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 3);
}
// The drop destination finished interoperating with this data
// source, so the client is now free to destroy this data source and
// free all associated data.
//
// If the action used to perform the operation was "move", the
// source can now delete the transferred data.
//
pub fn wl_data_source_send_dnd_finished(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 4);
}
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
pub fn wl_data_source_send_action(object: Object, dnd_action: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(dnd_action);
    object.context.finishWrite(object.id, 5);
}

// wl_data_device
pub const wl_data_device_interface = struct {
    // data transfer device
    start_drag: ?fn (*Context, Object, ?Object, Object, ?Object, u32) anyerror!void,
    set_selection: ?fn (*Context, Object, ?Object, u32) anyerror!void,
    release: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn wl_data_device_start_drag_default(context: *Context, object: Object, source: ?Object, origin: Object, icon: ?Object, serial: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_device_set_selection_default(context: *Context, object: Object, source: ?Object, serial: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_device_release_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_DATA_DEVICE = wl_data_device_interface{
    .start_drag = wl_data_device_start_drag_default,
    .set_selection = wl_data_device_set_selection_default,
    .release = wl_data_device_release_default,
};

pub fn new_wl_data_device(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_data_device_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_data_device_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // start_drag
        0 => {
            var source: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (source != null) {
                if (source.?.dispatch != wl_data_source_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            var origin: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (origin.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            var icon: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (icon != null) {
                if (icon.?.dispatch != wl_surface_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            var serial: u32 = try object.context.next_u32();
            if (WL_DATA_DEVICE.start_drag) |start_drag| {
                try start_drag(object.context, object, source, origin, icon, serial);
            }
        },
        // set_selection
        1 => {
            var source: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (source != null) {
                if (source.?.dispatch != wl_data_source_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            var serial: u32 = try object.context.next_u32();
            if (WL_DATA_DEVICE.set_selection) |set_selection| {
                try set_selection(object.context, object, source, serial);
            }
        },
        // release
        2 => {
            if (WL_DATA_DEVICE.release) |release| {
                try release(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}

pub const wl_data_device_error = enum(u32) {
    role = 0,
};
// The data_offer event introduces a new wl_data_offer object,
// which will subsequently be used in either the
// data_device.enter event (for drag-and-drop) or the
// data_device.selection event (for selections).  Immediately
// following the data_device_data_offer event, the new data_offer
// object will send out data_offer.offer events to describe the
// mime types it offers.
//
pub fn wl_data_device_send_data_offer(object: Object, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.finishWrite(object.id, 0);
}
// This event is sent when an active drag-and-drop pointer enters
// a surface owned by the client.  The position of the pointer at
// enter time is provided by the x and y arguments, in surface-local
// coordinates.
//
pub fn wl_data_device_send_enter(object: Object, serial: u32, surface: u32, x: f32, y: f32, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(surface);
    object.context.putFixed(x);
    object.context.putFixed(y);
    object.context.putU32(id);
    object.context.finishWrite(object.id, 1);
}
// This event is sent when the drag-and-drop pointer leaves the
// surface and the session ends.  The client must destroy the
// wl_data_offer introduced at enter time at this point.
//
pub fn wl_data_device_send_leave(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 2);
}
// This event is sent when the drag-and-drop pointer moves within
// the currently focused surface. The new position of the pointer
// is provided by the x and y arguments, in surface-local
// coordinates.
//
pub fn wl_data_device_send_motion(object: Object, time: u32, x: f32, y: f32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(time);
    object.context.putFixed(x);
    object.context.putFixed(y);
    object.context.finishWrite(object.id, 3);
}
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
pub fn wl_data_device_send_drop(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 4);
}
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
pub fn wl_data_device_send_selection(object: Object, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.finishWrite(object.id, 5);
}

// wl_data_device_manager
pub const wl_data_device_manager_interface = struct {
    // data transfer interface
    create_data_source: ?fn (*Context, Object, u32) anyerror!void,
    get_data_device: ?fn (*Context, Object, u32, Object) anyerror!void,
};

fn wl_data_device_manager_create_data_source_default(context: *Context, object: Object, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_device_manager_get_data_device_default(context: *Context, object: Object, id: u32, seat: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_DATA_DEVICE_MANAGER = wl_data_device_manager_interface{
    .create_data_source = wl_data_device_manager_create_data_source_default,
    .get_data_device = wl_data_device_manager_get_data_device_default,
};

pub fn new_wl_data_device_manager(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_data_device_manager_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_data_device_manager_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // create_data_source
        0 => {
            var id: u32 = try object.context.next_u32();
            if (WL_DATA_DEVICE_MANAGER.create_data_source) |create_data_source| {
                try create_data_source(object.context, object, id);
            }
        },
        // get_data_device
        1 => {
            var id: u32 = try object.context.next_u32();
            var seat: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (seat.dispatch != wl_seat_dispatch) {
                return error.ObjectWrongType;
            }
            if (WL_DATA_DEVICE_MANAGER.get_data_device) |get_data_device| {
                try get_data_device(object.context, object, id, seat);
            }
        },
        else => {},
    }
}

pub const wl_data_device_manager_dnd_action = enum(u32) {
    none = 0,
    copy = 1,
    move = 2,
    ask = 4,
};

// wl_shell
pub const wl_shell_interface = struct {
    // create desktop-style surfaces
    get_shell_surface: ?fn (*Context, Object, u32, Object) anyerror!void,
};

fn wl_shell_get_shell_surface_default(context: *Context, object: Object, id: u32, surface: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SHELL = wl_shell_interface{
    .get_shell_surface = wl_shell_get_shell_surface_default,
};

pub fn new_wl_shell(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_shell_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_shell_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // get_shell_surface
        0 => {
            var id: u32 = try object.context.next_u32();
            var surface: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (surface.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            if (WL_SHELL.get_shell_surface) |get_shell_surface| {
                try get_shell_surface(object.context, object, id, surface);
            }
        },
        else => {},
    }
}

pub const wl_shell_error = enum(u32) {
    role = 0,
};

// wl_shell_surface
pub const wl_shell_surface_interface = struct {
    // desktop-style metadata interface
    pong: ?fn (*Context, Object, u32) anyerror!void,
    move: ?fn (*Context, Object, Object, u32) anyerror!void,
    resize: ?fn (*Context, Object, Object, u32, u32) anyerror!void,
    set_toplevel: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    set_transient: ?fn (*Context, Object, Object, i32, i32, u32) anyerror!void,
    set_fullscreen: ?fn (*Context, Object, u32, u32, ?Object) anyerror!void,
    set_popup: ?fn (*Context, Object, Object, u32, Object, i32, i32, u32) anyerror!void,
    set_maximized: ?fn (*Context, Object, ?Object) anyerror!void,
    set_title: ?fn (*Context, Object, []u8) anyerror!void,
    set_class: ?fn (*Context, Object, []u8) anyerror!void,
};

fn wl_shell_surface_pong_default(context: *Context, object: Object, serial: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_move_default(context: *Context, object: Object, seat: Object, serial: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_resize_default(context: *Context, object: Object, seat: Object, serial: u32, edges: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_set_toplevel_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_set_transient_default(context: *Context, object: Object, parent: Object, x: i32, y: i32, flags: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_set_fullscreen_default(context: *Context, object: Object, method: u32, framerate: u32, output: ?Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_set_popup_default(context: *Context, object: Object, seat: Object, serial: u32, parent: Object, x: i32, y: i32, flags: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_set_maximized_default(context: *Context, object: Object, output: ?Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_set_title_default(context: *Context, object: Object, title: []u8) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_set_class_default(context: *Context, object: Object, class_: []u8) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SHELL_SURFACE = wl_shell_surface_interface{
    .pong = wl_shell_surface_pong_default,
    .move = wl_shell_surface_move_default,
    .resize = wl_shell_surface_resize_default,
    .set_toplevel = wl_shell_surface_set_toplevel_default,
    .set_transient = wl_shell_surface_set_transient_default,
    .set_fullscreen = wl_shell_surface_set_fullscreen_default,
    .set_popup = wl_shell_surface_set_popup_default,
    .set_maximized = wl_shell_surface_set_maximized_default,
    .set_title = wl_shell_surface_set_title_default,
    .set_class = wl_shell_surface_set_class_default,
};

pub fn new_wl_shell_surface(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_shell_surface_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_shell_surface_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // pong
        0 => {
            var serial: u32 = try object.context.next_u32();
            if (WL_SHELL_SURFACE.pong) |pong| {
                try pong(object.context, object, serial);
            }
        },
        // move
        1 => {
            var seat: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (seat.dispatch != wl_seat_dispatch) {
                return error.ObjectWrongType;
            }
            var serial: u32 = try object.context.next_u32();
            if (WL_SHELL_SURFACE.move) |move| {
                try move(object.context, object, seat, serial);
            }
        },
        // resize
        2 => {
            var seat: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (seat.dispatch != wl_seat_dispatch) {
                return error.ObjectWrongType;
            }
            var serial: u32 = try object.context.next_u32();
            var edges: u32 = try object.context.next_u32();
            if (WL_SHELL_SURFACE.resize) |resize| {
                try resize(object.context, object, seat, serial, edges);
            }
        },
        // set_toplevel
        3 => {
            if (WL_SHELL_SURFACE.set_toplevel) |set_toplevel| {
                try set_toplevel(
                    object.context,
                    object,
                );
            }
        },
        // set_transient
        4 => {
            var parent: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (parent.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var flags: u32 = try object.context.next_u32();
            if (WL_SHELL_SURFACE.set_transient) |set_transient| {
                try set_transient(object.context, object, parent, x, y, flags);
            }
        },
        // set_fullscreen
        5 => {
            var method: u32 = try object.context.next_u32();
            var framerate: u32 = try object.context.next_u32();
            var output: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (output != null) {
                if (output.?.dispatch != wl_output_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            if (WL_SHELL_SURFACE.set_fullscreen) |set_fullscreen| {
                try set_fullscreen(object.context, object, method, framerate, output);
            }
        },
        // set_popup
        6 => {
            var seat: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (seat.dispatch != wl_seat_dispatch) {
                return error.ObjectWrongType;
            }
            var serial: u32 = try object.context.next_u32();
            var parent: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (parent.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var flags: u32 = try object.context.next_u32();
            if (WL_SHELL_SURFACE.set_popup) |set_popup| {
                try set_popup(object.context, object, seat, serial, parent, x, y, flags);
            }
        },
        // set_maximized
        7 => {
            var output: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (output != null) {
                if (output.?.dispatch != wl_output_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            if (WL_SHELL_SURFACE.set_maximized) |set_maximized| {
                try set_maximized(object.context, object, output);
            }
        },
        // set_title
        8 => {
            var title: []u8 = try object.context.next_string();
            if (WL_SHELL_SURFACE.set_title) |set_title| {
                try set_title(object.context, object, title);
            }
        },
        // set_class
        9 => {
            var class_: []u8 = try object.context.next_string();
            if (WL_SHELL_SURFACE.set_class) |set_class| {
                try set_class(object.context, object, class_);
            }
        },
        else => {},
    }
}

pub const wl_shell_surface_resize = enum(u32) {
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

pub const wl_shell_surface_transient = enum(u32) {
    inactive = 0x1,
};

pub const wl_shell_surface_fullscreen_method = enum(u32) {
    default = 0,
    scale = 1,
    driver = 2,
    fill = 3,
};
// Ping a client to check if it is receiving events and sending
// requests. A client is expected to reply with a pong request.
//
pub fn wl_shell_surface_send_ping(object: Object, serial: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.finishWrite(object.id, 0);
}
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
pub fn wl_shell_surface_send_configure(object: Object, edges: u32, width: i32, height: i32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(edges);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.finishWrite(object.id, 1);
}
// The popup_done event is sent out when a popup grab is broken,
// that is, when the user clicks a surface that doesn't belong
// to the client owning the popup surface.
//
pub fn wl_shell_surface_send_popup_done(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 2);
}

// wl_surface
pub const wl_surface_interface = struct {
    // an onscreen surface
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    attach: ?fn (*Context, Object, ?Object, i32, i32) anyerror!void,
    damage: ?fn (*Context, Object, i32, i32, i32, i32) anyerror!void,
    frame: ?fn (*Context, Object, u32) anyerror!void,
    set_opaque_region: ?fn (*Context, Object, ?Object) anyerror!void,
    set_input_region: ?fn (*Context, Object, ?Object) anyerror!void,
    commit: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    set_buffer_transform: ?fn (*Context, Object, i32) anyerror!void,
    set_buffer_scale: ?fn (*Context, Object, i32) anyerror!void,
    damage_buffer: ?fn (*Context, Object, i32, i32, i32, i32) anyerror!void,
};

fn wl_surface_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_surface_attach_default(context: *Context, object: Object, buffer: ?Object, x: i32, y: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_surface_damage_default(context: *Context, object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_surface_frame_default(context: *Context, object: Object, callback: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_surface_set_opaque_region_default(context: *Context, object: Object, region: ?Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_surface_set_input_region_default(context: *Context, object: Object, region: ?Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_surface_commit_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_surface_set_buffer_transform_default(context: *Context, object: Object, transform: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_surface_set_buffer_scale_default(context: *Context, object: Object, scale: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_surface_damage_buffer_default(context: *Context, object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SURFACE = wl_surface_interface{
    .destroy = wl_surface_destroy_default,
    .attach = wl_surface_attach_default,
    .damage = wl_surface_damage_default,
    .frame = wl_surface_frame_default,
    .set_opaque_region = wl_surface_set_opaque_region_default,
    .set_input_region = wl_surface_set_input_region_default,
    .commit = wl_surface_commit_default,
    .set_buffer_transform = wl_surface_set_buffer_transform_default,
    .set_buffer_scale = wl_surface_set_buffer_scale_default,
    .damage_buffer = wl_surface_damage_buffer_default,
};

pub fn new_wl_surface(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_surface_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_surface_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // destroy
        0 => {
            if (WL_SURFACE.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // attach
        1 => {
            var buffer: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (buffer != null) {
                if (buffer.?.dispatch != wl_buffer_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            if (WL_SURFACE.attach) |attach| {
                try attach(object.context, object, buffer, x, y);
            }
        },
        // damage
        2 => {
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            if (WL_SURFACE.damage) |damage| {
                try damage(object.context, object, x, y, width, height);
            }
        },
        // frame
        3 => {
            var callback: u32 = try object.context.next_u32();
            if (WL_SURFACE.frame) |frame| {
                try frame(object.context, object, callback);
            }
        },
        // set_opaque_region
        4 => {
            var region: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (region != null) {
                if (region.?.dispatch != wl_region_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            if (WL_SURFACE.set_opaque_region) |set_opaque_region| {
                try set_opaque_region(object.context, object, region);
            }
        },
        // set_input_region
        5 => {
            var region: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (region != null) {
                if (region.?.dispatch != wl_region_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            if (WL_SURFACE.set_input_region) |set_input_region| {
                try set_input_region(object.context, object, region);
            }
        },
        // commit
        6 => {
            if (WL_SURFACE.commit) |commit| {
                try commit(
                    object.context,
                    object,
                );
            }
        },
        // set_buffer_transform
        7 => {
            var transform: i32 = try object.context.next_i32();
            if (WL_SURFACE.set_buffer_transform) |set_buffer_transform| {
                try set_buffer_transform(object.context, object, transform);
            }
        },
        // set_buffer_scale
        8 => {
            var scale: i32 = try object.context.next_i32();
            if (WL_SURFACE.set_buffer_scale) |set_buffer_scale| {
                try set_buffer_scale(object.context, object, scale);
            }
        },
        // damage_buffer
        9 => {
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            if (WL_SURFACE.damage_buffer) |damage_buffer| {
                try damage_buffer(object.context, object, x, y, width, height);
            }
        },
        else => {},
    }
}

pub const wl_surface_error = enum(u32) {
    invalid_scale = 0,
    invalid_transform = 1,
};
// This is emitted whenever a surface's creation, movement, or resizing
// results in some part of it being within the scanout region of an
// output.
//
// Note that a surface may be overlapping with zero or more outputs.
//
pub fn wl_surface_send_enter(object: Object, output: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(output);
    object.context.finishWrite(object.id, 0);
}
// This is emitted whenever a surface's creation, movement, or resizing
// results in it no longer having any part of it within the scanout region
// of an output.
//
pub fn wl_surface_send_leave(object: Object, output: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(output);
    object.context.finishWrite(object.id, 1);
}

// wl_seat
pub const wl_seat_interface = struct {
    // group of input devices
    get_pointer: ?fn (*Context, Object, u32) anyerror!void,
    get_keyboard: ?fn (*Context, Object, u32) anyerror!void,
    get_touch: ?fn (*Context, Object, u32) anyerror!void,
    release: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn wl_seat_get_pointer_default(context: *Context, object: Object, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_seat_get_keyboard_default(context: *Context, object: Object, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_seat_get_touch_default(context: *Context, object: Object, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_seat_release_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SEAT = wl_seat_interface{
    .get_pointer = wl_seat_get_pointer_default,
    .get_keyboard = wl_seat_get_keyboard_default,
    .get_touch = wl_seat_get_touch_default,
    .release = wl_seat_release_default,
};

pub fn new_wl_seat(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_seat_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_seat_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // get_pointer
        0 => {
            var id: u32 = try object.context.next_u32();
            if (WL_SEAT.get_pointer) |get_pointer| {
                try get_pointer(object.context, object, id);
            }
        },
        // get_keyboard
        1 => {
            var id: u32 = try object.context.next_u32();
            if (WL_SEAT.get_keyboard) |get_keyboard| {
                try get_keyboard(object.context, object, id);
            }
        },
        // get_touch
        2 => {
            var id: u32 = try object.context.next_u32();
            if (WL_SEAT.get_touch) |get_touch| {
                try get_touch(object.context, object, id);
            }
        },
        // release
        3 => {
            if (WL_SEAT.release) |release| {
                try release(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}

pub const wl_seat_capability = enum(u32) {
    pointer = 1,
    keyboard = 2,
    touch = 4,
};
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
pub fn wl_seat_send_capabilities(object: Object, capabilities: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(capabilities);
    object.context.finishWrite(object.id, 0);
}
// In a multiseat configuration this can be used by the client to help
// identify which physical devices the seat represents. Based on
// the seat configuration used by the compositor.
//
pub fn wl_seat_send_name(object: Object, name: []const u8) anyerror!void {
    object.context.startWrite();
    object.context.putString(name);
    object.context.finishWrite(object.id, 1);
}

// wl_pointer
pub const wl_pointer_interface = struct {
    // pointer input device
    set_cursor: ?fn (*Context, Object, u32, ?Object, i32, i32) anyerror!void,
    release: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn wl_pointer_set_cursor_default(context: *Context, object: Object, serial: u32, surface: ?Object, hotspot_x: i32, hotspot_y: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_pointer_release_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_POINTER = wl_pointer_interface{
    .set_cursor = wl_pointer_set_cursor_default,
    .release = wl_pointer_release_default,
};

pub fn new_wl_pointer(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_pointer_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_pointer_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // set_cursor
        0 => {
            var serial: u32 = try object.context.next_u32();
            var surface: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (surface != null) {
                if (surface.?.dispatch != wl_surface_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            var hotspot_x: i32 = try object.context.next_i32();
            var hotspot_y: i32 = try object.context.next_i32();
            if (WL_POINTER.set_cursor) |set_cursor| {
                try set_cursor(object.context, object, serial, surface, hotspot_x, hotspot_y);
            }
        },
        // release
        1 => {
            if (WL_POINTER.release) |release| {
                try release(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}

pub const wl_pointer_error = enum(u32) {
    role = 0,
};

pub const wl_pointer_button_state = enum(u32) {
    released = 0,
    pressed = 1,
};

pub const wl_pointer_axis = enum(u32) {
    vertical_scroll = 0,
    horizontal_scroll = 1,
};

pub const wl_pointer_axis_source = enum(u32) {
    wheel = 0,
    finger = 1,
    continuous = 2,
    wheel_tilt = 3,
};
// Notification that this seat's pointer is focused on a certain
// surface.
//
// When a seat's focus enters a surface, the pointer image
// is undefined and a client should respond to this event by setting
// an appropriate pointer image with the set_cursor request.
//
pub fn wl_pointer_send_enter(object: Object, serial: u32, surface: u32, surface_x: f32, surface_y: f32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(surface);
    object.context.putFixed(surface_x);
    object.context.putFixed(surface_y);
    object.context.finishWrite(object.id, 0);
}
// Notification that this seat's pointer is no longer focused on
// a certain surface.
//
// The leave notification is sent before the enter notification
// for the new focus.
//
pub fn wl_pointer_send_leave(object: Object, serial: u32, surface: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(surface);
    object.context.finishWrite(object.id, 1);
}
// Notification of pointer location change. The arguments
// surface_x and surface_y are the location relative to the
// focused surface.
//
pub fn wl_pointer_send_motion(object: Object, time: u32, surface_x: f32, surface_y: f32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(time);
    object.context.putFixed(surface_x);
    object.context.putFixed(surface_y);
    object.context.finishWrite(object.id, 2);
}
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
pub fn wl_pointer_send_button(object: Object, serial: u32, time: u32, button: u32, state: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(time);
    object.context.putU32(button);
    object.context.putU32(state);
    object.context.finishWrite(object.id, 3);
}
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
pub fn wl_pointer_send_axis(object: Object, time: u32, axis: u32, value: f32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(time);
    object.context.putU32(axis);
    object.context.putFixed(value);
    object.context.finishWrite(object.id, 4);
}
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
pub fn wl_pointer_send_frame(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 5);
}
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
pub fn wl_pointer_send_axis_source(object: Object, axis_source: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(axis_source);
    object.context.finishWrite(object.id, 6);
}
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
pub fn wl_pointer_send_axis_stop(object: Object, time: u32, axis: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(time);
    object.context.putU32(axis);
    object.context.finishWrite(object.id, 7);
}
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
pub fn wl_pointer_send_axis_discrete(object: Object, axis: u32, discrete: i32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(axis);
    object.context.putI32(discrete);
    object.context.finishWrite(object.id, 8);
}

// wl_keyboard
pub const wl_keyboard_interface = struct {
    // keyboard input device
    release: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn wl_keyboard_release_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_KEYBOARD = wl_keyboard_interface{
    .release = wl_keyboard_release_default,
};

pub fn new_wl_keyboard(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_keyboard_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_keyboard_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // release
        0 => {
            if (WL_KEYBOARD.release) |release| {
                try release(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}

pub const wl_keyboard_keymap_format = enum(u32) {
    no_keymap = 0,
    xkb_v1 = 1,
};

pub const wl_keyboard_key_state = enum(u32) {
    released = 0,
    pressed = 1,
};
// This event provides a file descriptor to the client which can be
// memory-mapped to provide a keyboard mapping description.
//
// From version 7 onwards, the fd must be mapped with MAP_PRIVATE by
// the recipient, as MAP_SHARED may fail.
//
pub fn wl_keyboard_send_keymap(object: Object, format: u32, fd: i32, size: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(format);
    object.context.putFd(fd);
    object.context.putU32(size);
    object.context.finishWrite(object.id, 0);
}
// Notification that this seat's keyboard focus is on a certain
// surface.
//
pub fn wl_keyboard_send_enter(object: Object, serial: u32, surface: u32, keys: []u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(surface);
    object.context.putArray(keys);
    object.context.finishWrite(object.id, 1);
}
// Notification that this seat's keyboard focus is no longer on
// a certain surface.
//
// The leave notification is sent before the enter notification
// for the new focus.
//
pub fn wl_keyboard_send_leave(object: Object, serial: u32, surface: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(surface);
    object.context.finishWrite(object.id, 2);
}
// A key was pressed or released.
// The time argument is a timestamp with millisecond
// granularity, with an undefined base.
//
pub fn wl_keyboard_send_key(object: Object, serial: u32, time: u32, key: u32, state: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(time);
    object.context.putU32(key);
    object.context.putU32(state);
    object.context.finishWrite(object.id, 3);
}
// Notifies clients that the modifier and/or group state has
// changed, and it should update its local state.
//
pub fn wl_keyboard_send_modifiers(object: Object, serial: u32, mods_depressed: u32, mods_latched: u32, mods_locked: u32, group: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(mods_depressed);
    object.context.putU32(mods_latched);
    object.context.putU32(mods_locked);
    object.context.putU32(group);
    object.context.finishWrite(object.id, 4);
}
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
pub fn wl_keyboard_send_repeat_info(object: Object, rate: i32, delay: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(rate);
    object.context.putI32(delay);
    object.context.finishWrite(object.id, 5);
}

// wl_touch
pub const wl_touch_interface = struct {
    // touchscreen input device
    release: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn wl_touch_release_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_TOUCH = wl_touch_interface{
    .release = wl_touch_release_default,
};

pub fn new_wl_touch(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_touch_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_touch_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // release
        0 => {
            if (WL_TOUCH.release) |release| {
                try release(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}
// A new touch point has appeared on the surface. This touch point is
// assigned a unique ID. Future events from this touch point reference
// this ID. The ID ceases to be valid after a touch up event and may be
// reused in the future.
//
pub fn wl_touch_send_down(object: Object, serial: u32, time: u32, surface: u32, id: i32, x: f32, y: f32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(time);
    object.context.putU32(surface);
    object.context.putI32(id);
    object.context.putFixed(x);
    object.context.putFixed(y);
    object.context.finishWrite(object.id, 0);
}
// The touch point has disappeared. No further events will be sent for
// this touch point and the touch point's ID is released and may be
// reused in a future touch down event.
//
pub fn wl_touch_send_up(object: Object, serial: u32, time: u32, id: i32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(time);
    object.context.putI32(id);
    object.context.finishWrite(object.id, 1);
}
// A touch point has changed coordinates.
//
pub fn wl_touch_send_motion(object: Object, time: u32, id: i32, x: f32, y: f32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(time);
    object.context.putI32(id);
    object.context.putFixed(x);
    object.context.putFixed(y);
    object.context.finishWrite(object.id, 2);
}
// Indicates the end of a set of events that logically belong together.
// A client is expected to accumulate the data in all events within the
// frame before proceeding.
//
// A wl_touch.frame terminates at least one event but otherwise no
// guarantee is provided about the set of events within a frame. A client
// must assume that any state not updated in a frame is unchanged from the
// previously known state.
//
pub fn wl_touch_send_frame(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 3);
}
// Sent if the compositor decides the touch stream is a global
// gesture. No further events are sent to the clients from that
// particular gesture. Touch cancellation applies to all touch points
// currently active on this client's surface. The client is
// responsible for finalizing the touch points, future touch points on
// this surface may reuse the touch point ID.
//
pub fn wl_touch_send_cancel(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 4);
}
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
pub fn wl_touch_send_shape(object: Object, id: i32, major: f32, minor: f32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(id);
    object.context.putFixed(major);
    object.context.putFixed(minor);
    object.context.finishWrite(object.id, 5);
}
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
pub fn wl_touch_send_orientation(object: Object, id: i32, orientation: f32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(id);
    object.context.putFixed(orientation);
    object.context.finishWrite(object.id, 6);
}

// wl_output
pub const wl_output_interface = struct {
    // compositor output region
    release: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn wl_output_release_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_OUTPUT = wl_output_interface{
    .release = wl_output_release_default,
};

pub fn new_wl_output(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_output_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_output_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // release
        0 => {
            if (WL_OUTPUT.release) |release| {
                try release(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}

pub const wl_output_subpixel = enum(u32) {
    unknown = 0,
    none = 1,
    horizontal_rgb = 2,
    horizontal_bgr = 3,
    vertical_rgb = 4,
    vertical_bgr = 5,
};

pub const wl_output_transform = enum(u32) {
    normal = 0,
    @"90" = 1,
    @"180" = 2,
    @"270" = 3,
    flipped = 4,
    flipped_90 = 5,
    flipped_180 = 6,
    flipped_270 = 7,
};

pub const wl_output_mode = enum(u32) {
    current = 0x1,
    preferred = 0x2,
};
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
pub fn wl_output_send_geometry(object: Object, x: i32, y: i32, physical_width: i32, physical_height: i32, subpixel: i32, make: []const u8, model: []const u8, transform: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putI32(physical_width);
    object.context.putI32(physical_height);
    object.context.putI32(subpixel);
    object.context.putString(make);
    object.context.putString(model);
    object.context.putI32(transform);
    object.context.finishWrite(object.id, 0);
}
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
pub fn wl_output_send_mode(object: Object, flags: u32, width: i32, height: i32, refresh: i32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(flags);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.putI32(refresh);
    object.context.finishWrite(object.id, 1);
}
// This event is sent after all other properties have been
// sent after binding to the output object and after any
// other property changes done after that. This allows
// changes to the output properties to be seen as
// atomic, even if they happen via multiple events.
//
pub fn wl_output_send_done(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 2);
}
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
pub fn wl_output_send_scale(object: Object, factor: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(factor);
    object.context.finishWrite(object.id, 3);
}

// wl_region
pub const wl_region_interface = struct {
    // region interface
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    add: ?fn (*Context, Object, i32, i32, i32, i32) anyerror!void,
    subtract: ?fn (*Context, Object, i32, i32, i32, i32) anyerror!void,
};

fn wl_region_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_region_add_default(context: *Context, object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_region_subtract_default(context: *Context, object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_REGION = wl_region_interface{
    .destroy = wl_region_destroy_default,
    .add = wl_region_add_default,
    .subtract = wl_region_subtract_default,
};

pub fn new_wl_region(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_region_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_region_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // destroy
        0 => {
            if (WL_REGION.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // add
        1 => {
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            if (WL_REGION.add) |add| {
                try add(object.context, object, x, y, width, height);
            }
        },
        // subtract
        2 => {
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            if (WL_REGION.subtract) |subtract| {
                try subtract(object.context, object, x, y, width, height);
            }
        },
        else => {},
    }
}

// wl_subcompositor
pub const wl_subcompositor_interface = struct {
    // sub-surface compositing
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    get_subsurface: ?fn (*Context, Object, u32, Object, Object) anyerror!void,
};

fn wl_subcompositor_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_subcompositor_get_subsurface_default(context: *Context, object: Object, id: u32, surface: Object, parent: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SUBCOMPOSITOR = wl_subcompositor_interface{
    .destroy = wl_subcompositor_destroy_default,
    .get_subsurface = wl_subcompositor_get_subsurface_default,
};

pub fn new_wl_subcompositor(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_subcompositor_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_subcompositor_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // destroy
        0 => {
            if (WL_SUBCOMPOSITOR.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // get_subsurface
        1 => {
            var id: u32 = try object.context.next_u32();
            var surface: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (surface.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            var parent: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (parent.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            if (WL_SUBCOMPOSITOR.get_subsurface) |get_subsurface| {
                try get_subsurface(object.context, object, id, surface, parent);
            }
        },
        else => {},
    }
}

pub const wl_subcompositor_error = enum(u32) {
    bad_surface = 0,
};

// wl_subsurface
pub const wl_subsurface_interface = struct {
    // sub-surface interface to a wl_surface
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    set_position: ?fn (*Context, Object, i32, i32) anyerror!void,
    place_above: ?fn (*Context, Object, Object) anyerror!void,
    place_below: ?fn (*Context, Object, Object) anyerror!void,
    set_sync: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    set_desync: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn wl_subsurface_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_subsurface_set_position_default(context: *Context, object: Object, x: i32, y: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_subsurface_place_above_default(context: *Context, object: Object, sibling: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_subsurface_place_below_default(context: *Context, object: Object, sibling: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_subsurface_set_sync_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_subsurface_set_desync_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SUBSURFACE = wl_subsurface_interface{
    .destroy = wl_subsurface_destroy_default,
    .set_position = wl_subsurface_set_position_default,
    .place_above = wl_subsurface_place_above_default,
    .place_below = wl_subsurface_place_below_default,
    .set_sync = wl_subsurface_set_sync_default,
    .set_desync = wl_subsurface_set_desync_default,
};

pub fn new_wl_subsurface(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = wl_subsurface_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn wl_subsurface_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // destroy
        0 => {
            if (WL_SUBSURFACE.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // set_position
        1 => {
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            if (WL_SUBSURFACE.set_position) |set_position| {
                try set_position(object.context, object, x, y);
            }
        },
        // place_above
        2 => {
            var sibling: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (sibling.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            if (WL_SUBSURFACE.place_above) |place_above| {
                try place_above(object.context, object, sibling);
            }
        },
        // place_below
        3 => {
            var sibling: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (sibling.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            if (WL_SUBSURFACE.place_below) |place_below| {
                try place_below(object.context, object, sibling);
            }
        },
        // set_sync
        4 => {
            if (WL_SUBSURFACE.set_sync) |set_sync| {
                try set_sync(
                    object.context,
                    object,
                );
            }
        },
        // set_desync
        5 => {
            if (WL_SUBSURFACE.set_desync) |set_desync| {
                try set_desync(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}

pub const wl_subsurface_error = enum(u32) {
    bad_surface = 0,
};

// xdg_wm_base
pub const xdg_wm_base_interface = struct {
    // create desktop-style surfaces
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    create_positioner: ?fn (*Context, Object, u32) anyerror!void,
    get_xdg_surface: ?fn (*Context, Object, u32, Object) anyerror!void,
    pong: ?fn (*Context, Object, u32) anyerror!void,
};

fn xdg_wm_base_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_wm_base_create_positioner_default(context: *Context, object: Object, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_wm_base_get_xdg_surface_default(context: *Context, object: Object, id: u32, surface: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_wm_base_pong_default(context: *Context, object: Object, serial: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var XDG_WM_BASE = xdg_wm_base_interface{
    .destroy = xdg_wm_base_destroy_default,
    .create_positioner = xdg_wm_base_create_positioner_default,
    .get_xdg_surface = xdg_wm_base_get_xdg_surface_default,
    .pong = xdg_wm_base_pong_default,
};

pub fn new_xdg_wm_base(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = xdg_wm_base_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn xdg_wm_base_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // destroy
        0 => {
            if (XDG_WM_BASE.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // create_positioner
        1 => {
            var id: u32 = try object.context.next_u32();
            if (XDG_WM_BASE.create_positioner) |create_positioner| {
                try create_positioner(object.context, object, id);
            }
        },
        // get_xdg_surface
        2 => {
            var id: u32 = try object.context.next_u32();
            var surface: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (surface.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            if (XDG_WM_BASE.get_xdg_surface) |get_xdg_surface| {
                try get_xdg_surface(object.context, object, id, surface);
            }
        },
        // pong
        3 => {
            var serial: u32 = try object.context.next_u32();
            if (XDG_WM_BASE.pong) |pong| {
                try pong(object.context, object, serial);
            }
        },
        else => {},
    }
}

pub const xdg_wm_base_error = enum(u32) {
    role = 0,
    defunct_surfaces = 1,
    not_the_topmost_popup = 2,
    invalid_popup_parent = 3,
    invalid_surface_state = 4,
    invalid_positioner = 5,
};
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
pub fn xdg_wm_base_send_ping(object: Object, serial: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.finishWrite(object.id, 0);
}

// xdg_positioner
pub const xdg_positioner_interface = struct {
    // child surface positioner
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    set_size: ?fn (*Context, Object, i32, i32) anyerror!void,
    set_anchor_rect: ?fn (*Context, Object, i32, i32, i32, i32) anyerror!void,
    set_anchor: ?fn (*Context, Object, u32) anyerror!void,
    set_gravity: ?fn (*Context, Object, u32) anyerror!void,
    set_constraint_adjustment: ?fn (*Context, Object, u32) anyerror!void,
    set_offset: ?fn (*Context, Object, i32, i32) anyerror!void,
};

fn xdg_positioner_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_positioner_set_size_default(context: *Context, object: Object, width: i32, height: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_positioner_set_anchor_rect_default(context: *Context, object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_positioner_set_anchor_default(context: *Context, object: Object, anchor: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_positioner_set_gravity_default(context: *Context, object: Object, gravity: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_positioner_set_constraint_adjustment_default(context: *Context, object: Object, constraint_adjustment: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_positioner_set_offset_default(context: *Context, object: Object, x: i32, y: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var XDG_POSITIONER = xdg_positioner_interface{
    .destroy = xdg_positioner_destroy_default,
    .set_size = xdg_positioner_set_size_default,
    .set_anchor_rect = xdg_positioner_set_anchor_rect_default,
    .set_anchor = xdg_positioner_set_anchor_default,
    .set_gravity = xdg_positioner_set_gravity_default,
    .set_constraint_adjustment = xdg_positioner_set_constraint_adjustment_default,
    .set_offset = xdg_positioner_set_offset_default,
};

pub fn new_xdg_positioner(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = xdg_positioner_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn xdg_positioner_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // destroy
        0 => {
            if (XDG_POSITIONER.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // set_size
        1 => {
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            if (XDG_POSITIONER.set_size) |set_size| {
                try set_size(object.context, object, width, height);
            }
        },
        // set_anchor_rect
        2 => {
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            if (XDG_POSITIONER.set_anchor_rect) |set_anchor_rect| {
                try set_anchor_rect(object.context, object, x, y, width, height);
            }
        },
        // set_anchor
        3 => {
            var anchor: u32 = try object.context.next_u32();
            if (XDG_POSITIONER.set_anchor) |set_anchor| {
                try set_anchor(object.context, object, anchor);
            }
        },
        // set_gravity
        4 => {
            var gravity: u32 = try object.context.next_u32();
            if (XDG_POSITIONER.set_gravity) |set_gravity| {
                try set_gravity(object.context, object, gravity);
            }
        },
        // set_constraint_adjustment
        5 => {
            var constraint_adjustment: u32 = try object.context.next_u32();
            if (XDG_POSITIONER.set_constraint_adjustment) |set_constraint_adjustment| {
                try set_constraint_adjustment(object.context, object, constraint_adjustment);
            }
        },
        // set_offset
        6 => {
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            if (XDG_POSITIONER.set_offset) |set_offset| {
                try set_offset(object.context, object, x, y);
            }
        },
        else => {},
    }
}

pub const xdg_positioner_error = enum(u32) {
    invalid_input = 0,
};

pub const xdg_positioner_anchor = enum(u32) {
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

pub const xdg_positioner_gravity = enum(u32) {
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

pub const xdg_positioner_constraint_adjustment = enum(u32) {
    none = 0,
    slide_x = 1,
    slide_y = 2,
    flip_x = 4,
    flip_y = 8,
    resize_x = 16,
    resize_y = 32,
};

// xdg_surface
pub const xdg_surface_interface = struct {
    // desktop user interface surface base interface
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    get_toplevel: ?fn (*Context, Object, u32) anyerror!void,
    get_popup: ?fn (*Context, Object, u32, ?Object, Object) anyerror!void,
    set_window_geometry: ?fn (*Context, Object, i32, i32, i32, i32) anyerror!void,
    ack_configure: ?fn (*Context, Object, u32) anyerror!void,
};

fn xdg_surface_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_surface_get_toplevel_default(context: *Context, object: Object, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_surface_get_popup_default(context: *Context, object: Object, id: u32, parent: ?Object, positioner: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_surface_set_window_geometry_default(context: *Context, object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_surface_ack_configure_default(context: *Context, object: Object, serial: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var XDG_SURFACE = xdg_surface_interface{
    .destroy = xdg_surface_destroy_default,
    .get_toplevel = xdg_surface_get_toplevel_default,
    .get_popup = xdg_surface_get_popup_default,
    .set_window_geometry = xdg_surface_set_window_geometry_default,
    .ack_configure = xdg_surface_ack_configure_default,
};

pub fn new_xdg_surface(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = xdg_surface_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn xdg_surface_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // destroy
        0 => {
            if (XDG_SURFACE.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // get_toplevel
        1 => {
            var id: u32 = try object.context.next_u32();
            if (XDG_SURFACE.get_toplevel) |get_toplevel| {
                try get_toplevel(object.context, object, id);
            }
        },
        // get_popup
        2 => {
            var id: u32 = try object.context.next_u32();
            var parent: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (parent != null) {
                if (parent.?.dispatch != xdg_surface_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            var positioner: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (positioner.dispatch != xdg_positioner_dispatch) {
                return error.ObjectWrongType;
            }
            if (XDG_SURFACE.get_popup) |get_popup| {
                try get_popup(object.context, object, id, parent, positioner);
            }
        },
        // set_window_geometry
        3 => {
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            if (XDG_SURFACE.set_window_geometry) |set_window_geometry| {
                try set_window_geometry(object.context, object, x, y, width, height);
            }
        },
        // ack_configure
        4 => {
            var serial: u32 = try object.context.next_u32();
            if (XDG_SURFACE.ack_configure) |ack_configure| {
                try ack_configure(object.context, object, serial);
            }
        },
        else => {},
    }
}

pub const xdg_surface_error = enum(u32) {
    not_constructed = 1,
    already_constructed = 2,
    unconfigured_buffer = 3,
};
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
pub fn xdg_surface_send_configure(object: Object, serial: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.finishWrite(object.id, 0);
}

// xdg_toplevel
pub const xdg_toplevel_interface = struct {
    // toplevel surface
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    set_parent: ?fn (*Context, Object, ?Object) anyerror!void,
    set_title: ?fn (*Context, Object, []u8) anyerror!void,
    set_app_id: ?fn (*Context, Object, []u8) anyerror!void,
    show_window_menu: ?fn (*Context, Object, Object, u32, i32, i32) anyerror!void,
    move: ?fn (*Context, Object, Object, u32) anyerror!void,
    resize: ?fn (*Context, Object, Object, u32, u32) anyerror!void,
    set_max_size: ?fn (*Context, Object, i32, i32) anyerror!void,
    set_min_size: ?fn (*Context, Object, i32, i32) anyerror!void,
    set_maximized: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    unset_maximized: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    set_fullscreen: ?fn (*Context, Object, ?Object) anyerror!void,
    unset_fullscreen: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    set_minimized: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn xdg_toplevel_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_set_parent_default(context: *Context, object: Object, parent: ?Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_set_title_default(context: *Context, object: Object, title: []u8) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_set_app_id_default(context: *Context, object: Object, app_id: []u8) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_show_window_menu_default(context: *Context, object: Object, seat: Object, serial: u32, x: i32, y: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_move_default(context: *Context, object: Object, seat: Object, serial: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_resize_default(context: *Context, object: Object, seat: Object, serial: u32, edges: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_set_max_size_default(context: *Context, object: Object, width: i32, height: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_set_min_size_default(context: *Context, object: Object, width: i32, height: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_set_maximized_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_unset_maximized_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_set_fullscreen_default(context: *Context, object: Object, output: ?Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_unset_fullscreen_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_toplevel_set_minimized_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var XDG_TOPLEVEL = xdg_toplevel_interface{
    .destroy = xdg_toplevel_destroy_default,
    .set_parent = xdg_toplevel_set_parent_default,
    .set_title = xdg_toplevel_set_title_default,
    .set_app_id = xdg_toplevel_set_app_id_default,
    .show_window_menu = xdg_toplevel_show_window_menu_default,
    .move = xdg_toplevel_move_default,
    .resize = xdg_toplevel_resize_default,
    .set_max_size = xdg_toplevel_set_max_size_default,
    .set_min_size = xdg_toplevel_set_min_size_default,
    .set_maximized = xdg_toplevel_set_maximized_default,
    .unset_maximized = xdg_toplevel_unset_maximized_default,
    .set_fullscreen = xdg_toplevel_set_fullscreen_default,
    .unset_fullscreen = xdg_toplevel_unset_fullscreen_default,
    .set_minimized = xdg_toplevel_set_minimized_default,
};

pub fn new_xdg_toplevel(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = xdg_toplevel_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn xdg_toplevel_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // destroy
        0 => {
            if (XDG_TOPLEVEL.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // set_parent
        1 => {
            var parent: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (parent != null) {
                if (parent.?.dispatch != xdg_toplevel_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            if (XDG_TOPLEVEL.set_parent) |set_parent| {
                try set_parent(object.context, object, parent);
            }
        },
        // set_title
        2 => {
            var title: []u8 = try object.context.next_string();
            if (XDG_TOPLEVEL.set_title) |set_title| {
                try set_title(object.context, object, title);
            }
        },
        // set_app_id
        3 => {
            var app_id: []u8 = try object.context.next_string();
            if (XDG_TOPLEVEL.set_app_id) |set_app_id| {
                try set_app_id(object.context, object, app_id);
            }
        },
        // show_window_menu
        4 => {
            var seat: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (seat.dispatch != wl_seat_dispatch) {
                return error.ObjectWrongType;
            }
            var serial: u32 = try object.context.next_u32();
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            if (XDG_TOPLEVEL.show_window_menu) |show_window_menu| {
                try show_window_menu(object.context, object, seat, serial, x, y);
            }
        },
        // move
        5 => {
            var seat: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (seat.dispatch != wl_seat_dispatch) {
                return error.ObjectWrongType;
            }
            var serial: u32 = try object.context.next_u32();
            if (XDG_TOPLEVEL.move) |move| {
                try move(object.context, object, seat, serial);
            }
        },
        // resize
        6 => {
            var seat: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (seat.dispatch != wl_seat_dispatch) {
                return error.ObjectWrongType;
            }
            var serial: u32 = try object.context.next_u32();
            var edges: u32 = try object.context.next_u32();
            if (XDG_TOPLEVEL.resize) |resize| {
                try resize(object.context, object, seat, serial, edges);
            }
        },
        // set_max_size
        7 => {
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            if (XDG_TOPLEVEL.set_max_size) |set_max_size| {
                try set_max_size(object.context, object, width, height);
            }
        },
        // set_min_size
        8 => {
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            if (XDG_TOPLEVEL.set_min_size) |set_min_size| {
                try set_min_size(object.context, object, width, height);
            }
        },
        // set_maximized
        9 => {
            if (XDG_TOPLEVEL.set_maximized) |set_maximized| {
                try set_maximized(
                    object.context,
                    object,
                );
            }
        },
        // unset_maximized
        10 => {
            if (XDG_TOPLEVEL.unset_maximized) |unset_maximized| {
                try unset_maximized(
                    object.context,
                    object,
                );
            }
        },
        // set_fullscreen
        11 => {
            var output: ?Object = object.context.objects.getValue(try object.context.next_u32());
            if (output != null) {
                if (output.?.dispatch != wl_output_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            if (XDG_TOPLEVEL.set_fullscreen) |set_fullscreen| {
                try set_fullscreen(object.context, object, output);
            }
        },
        // unset_fullscreen
        12 => {
            if (XDG_TOPLEVEL.unset_fullscreen) |unset_fullscreen| {
                try unset_fullscreen(
                    object.context,
                    object,
                );
            }
        },
        // set_minimized
        13 => {
            if (XDG_TOPLEVEL.set_minimized) |set_minimized| {
                try set_minimized(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}

pub const xdg_toplevel_resize_edge = enum(u32) {
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

pub const xdg_toplevel_state = enum(u32) {
    maximized = 1,
    fullscreen = 2,
    resizing = 3,
    activated = 4,
    tiled_left = 5,
    tiled_right = 6,
    tiled_top = 7,
    tiled_bottom = 8,
};
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
pub fn xdg_toplevel_send_configure(object: Object, width: i32, height: i32, states: []u32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.putArray(states);
    object.context.finishWrite(object.id, 0);
}
// The close event is sent by the compositor when the user
// wants the surface to be closed. This should be equivalent to
// the user clicking the close button in client-side decorations,
// if your application has any.
//
// This is only a request that the user intends to close the
// window. The client may choose to ignore this request, or show
// a dialog to ask the user to save their data, etc.
//
pub fn xdg_toplevel_send_close(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 1);
}

// xdg_popup
pub const xdg_popup_interface = struct {
    // short-lived, popup surfaces for menus
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    grab: ?fn (*Context, Object, Object, u32) anyerror!void,
};

fn xdg_popup_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn xdg_popup_grab_default(context: *Context, object: Object, seat: Object, serial: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var XDG_POPUP = xdg_popup_interface{
    .destroy = xdg_popup_destroy_default,
    .grab = xdg_popup_grab_default,
};

pub fn new_xdg_popup(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = xdg_popup_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn xdg_popup_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // destroy
        0 => {
            if (XDG_POPUP.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        // grab
        1 => {
            var seat: Object = object.context.objects.getValue(try object.context.next_u32()).?;
            if (seat.dispatch != wl_seat_dispatch) {
                return error.ObjectWrongType;
            }
            var serial: u32 = try object.context.next_u32();
            if (XDG_POPUP.grab) |grab| {
                try grab(object.context, object, seat, serial);
            }
        },
        else => {},
    }
}

pub const xdg_popup_error = enum(u32) {
    invalid_grab = 0,
};
// This event asks the popup surface to configure itself given the
// configuration. The configured state should not be applied immediately.
// See xdg_surface.configure for details.
//
// The x and y arguments represent the position the popup was placed at
// given the xdg_positioner rule, relative to the upper left corner of the
// window geometry of the parent surface.
//
pub fn xdg_popup_send_configure(object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.finishWrite(object.id, 0);
}
// The popup_done event is sent out when a popup is dismissed by the
// compositor. The client should destroy the xdg_popup object at this
// point.
//
pub fn xdg_popup_send_popup_done(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 1);
}

// fw_control
pub const fw_control_interface = struct {
    // protocol for querying and controlling foxwhale
    get_clients: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    get_windows: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    get_window_trees: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    destroy: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn fw_control_get_clients_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn fw_control_get_windows_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn fw_control_get_window_trees_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn fw_control_destroy_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var FW_CONTROL = fw_control_interface{
    .get_clients = fw_control_get_clients_default,
    .get_windows = fw_control_get_windows_default,
    .get_window_trees = fw_control_get_window_trees_default,
    .destroy = fw_control_destroy_default,
};

pub fn new_fw_control(id: u32, context: *Context, container: usize) Object {
    return Object{
        .id = id,
        .dispatch = fw_control_dispatch,
        .context = context,
        .version = 0,
        .container = container,
    };
}

fn fw_control_dispatch(object: Object, opcode: u16) anyerror!void {
    switch (opcode) {
        // get_clients
        0 => {
            if (FW_CONTROL.get_clients) |get_clients| {
                try get_clients(
                    object.context,
                    object,
                );
            }
        },
        // get_windows
        1 => {
            if (FW_CONTROL.get_windows) |get_windows| {
                try get_windows(
                    object.context,
                    object,
                );
            }
        },
        // get_window_trees
        2 => {
            if (FW_CONTROL.get_window_trees) |get_window_trees| {
                try get_window_trees(
                    object.context,
                    object,
                );
            }
        },
        // destroy
        3 => {
            if (FW_CONTROL.destroy) |destroy| {
                try destroy(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}

pub const fw_control_surface_type = enum(u32) {
    wl_surface = 0,
    wl_subsurface = 1,
    xdg_toplevel = 2,
    xdg_popup = 3,
};
pub fn fw_control_send_client(object: Object, index: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(index);
    object.context.finishWrite(object.id, 0);
}
pub fn fw_control_send_window(object: Object, index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, sibling_prev: i32, sibling_next: i32, children_prev: i32, children_next: i32, input_region_id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(index);
    object.context.putI32(parent);
    object.context.putU32(wl_surface_id);
    object.context.putU32(surface_type);
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.putI32(sibling_prev);
    object.context.putI32(sibling_next);
    object.context.putI32(children_prev);
    object.context.putI32(children_next);
    object.context.putU32(input_region_id);
    object.context.finishWrite(object.id, 1);
}
pub fn fw_control_send_toplevel_window(object: Object, index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, input_region_id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(index);
    object.context.putI32(parent);
    object.context.putU32(wl_surface_id);
    object.context.putU32(surface_type);
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.putU32(input_region_id);
    object.context.finishWrite(object.id, 2);
}
pub fn fw_control_send_region_rect(object: Object, index: u32, x: i32, y: i32, width: i32, height: i32, op: i32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(index);
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.putI32(op);
    object.context.finishWrite(object.id, 3);
}
pub fn fw_control_send_done(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 4);
}
