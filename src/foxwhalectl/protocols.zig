const std = @import("std");
const Context = @import("connection.zig").Context;
const Object = @import("connection.zig").Object;

// wl_display
pub const wl_display_interface = struct {
    // core global object
    @"error": ?fn (*Context, Object, Object, u32, []u8) anyerror!void,
    delete_id: ?fn (*Context, Object, u32) anyerror!void,
};

fn wl_display_error_default(context: *Context, object: Object, object_id: Object, code: u32, message: []u8) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_display_delete_id_default(context: *Context, object: Object, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_DISPLAY = wl_display_interface{
    .@"error" = wl_display_error_default,
    .delete_id = wl_display_delete_id_default,
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
        // error
        0 => {
            var object_id: Object = object.context.objects.get(try object.context.next_u32()).?;
            var code: u32 = try object.context.next_u32();
            var message: []u8 = try object.context.next_string();
            if (WL_DISPLAY.@"error") |@"error"| {
                try @"error"(object.context, object, object_id, code, message);
            }
        },
        // delete_id
        1 => {
            var id: u32 = try object.context.next_u32();
            if (WL_DISPLAY.delete_id) |delete_id| {
                try delete_id(object.context, object, id);
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

//
// The sync request asks the server to emit the 'done' event
// on the returned wl_callback object.  Since requests are
// handled in-order and events are delivered in-order, this can
// be used as a barrier to ensure all previous requests and the
// resulting events have been handled.
//
// The object returned by this request will be destroyed by the
// compositor after the callback is fired and as such the client must not
// attempt to use it after that point.
//
// The callback_data passed in the callback is the event serial.
//
pub fn wl_display_send_sync(object: Object, callback: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(callback);
    object.context.finishWrite(object.id, 0);
}

//
// This request creates a registry object that allows the client
// to list and bind the global objects available from the
// compositor.
//
// It should be noted that the server side resources consumed in
// response to a get_registry request can only be released when the
// client disconnects, not when the client side proxy is destroyed.
// Therefore, clients should invoke get_registry as infrequently as
// possible to avoid wasting memory.
//
pub fn wl_display_send_get_registry(object: Object, registry: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(registry);
    object.context.finishWrite(object.id, 1);
}

// wl_registry
pub const wl_registry_interface = struct {
    // global registry object
    global: ?fn (*Context, Object, u32, []u8, u32) anyerror!void,
    global_remove: ?fn (*Context, Object, u32) anyerror!void,
};

fn wl_registry_global_default(context: *Context, object: Object, name: u32, interface: []u8, version: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_registry_global_remove_default(context: *Context, object: Object, name: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_REGISTRY = wl_registry_interface{
    .global = wl_registry_global_default,
    .global_remove = wl_registry_global_remove_default,
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
        // global
        0 => {
            var name: u32 = try object.context.next_u32();
            var interface: []u8 = try object.context.next_string();
            var version: u32 = try object.context.next_u32();
            if (WL_REGISTRY.global) |global| {
                try global(object.context, object, name, interface, version);
            }
        },
        // global_remove
        1 => {
            var name: u32 = try object.context.next_u32();
            if (WL_REGISTRY.global_remove) |global_remove| {
                try global_remove(object.context, object, name);
            }
        },
        else => {},
    }
}

//
// Binds a new, client-created object to the server using the
// specified name as the identifier.
//
pub fn wl_registry_send_bind(object: Object, name: u32, name_string: []const u8, version: u32, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(name);
    object.context.putString(name_string);
    object.context.putU32(version);
    object.context.putU32(id);
    object.context.finishWrite(object.id, 0);
}

// wl_callback
pub const wl_callback_interface = struct {
    // callback object
    done: ?fn (*Context, Object, u32) anyerror!void,
};

fn wl_callback_done_default(context: *Context, object: Object, callback_data: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_CALLBACK = wl_callback_interface{
    .done = wl_callback_done_default,
};

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
        // done
        0 => {
            var callback_data: u32 = try object.context.next_u32();
            if (WL_CALLBACK.done) |done| {
                try done(object.context, object, callback_data);
            }
        },
        else => {},
    }
}

// wl_compositor
pub const wl_compositor_interface = struct {
    // the compositor singleton
};

pub var WL_COMPOSITOR = wl_compositor_interface{};

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
        else => {},
    }
}

//
// Ask the compositor to create a new surface.
//
pub fn wl_compositor_send_create_surface(object: Object, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.finishWrite(object.id, 0);
}

//
// Ask the compositor to create a new region.
//
pub fn wl_compositor_send_create_region(object: Object, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.finishWrite(object.id, 1);
}

// wl_shm_pool
pub const wl_shm_pool_interface = struct {
    // a shared memory pool
};

pub var WL_SHM_POOL = wl_shm_pool_interface{};

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
        else => {},
    }
}

//
// Create a wl_buffer object from the pool.
//
// The buffer is created offset bytes into the pool and has
// width and height as specified.  The stride argument specifies
// the number of bytes from the beginning of one row to the beginning
// of the next.  The format is the pixel format of the buffer and
// must be one of those advertised through the wl_shm.format event.
//
// A buffer will keep a reference to the pool it was created from
// so it is valid to destroy the pool immediately after creating
// a buffer from it.
//
pub fn wl_shm_pool_send_create_buffer(object: Object, id: u32, offset: i32, width: i32, height: i32, stride: i32, format: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.putI32(offset);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.putI32(stride);
    object.context.putU32(format);
    object.context.finishWrite(object.id, 0);
}

//
// Destroy the shared memory pool.
//
// The mmapped memory will be released when all
// buffers that have been created from this pool
// are gone.
//
pub fn wl_shm_pool_send_destroy(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 1);
}

//
// This request will cause the server to remap the backing memory
// for the pool from the file descriptor passed when the pool was
// created, but using the new size.  This request can only be
// used to make the pool bigger.
//
pub fn wl_shm_pool_send_resize(object: Object, size: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(size);
    object.context.finishWrite(object.id, 2);
}

// wl_shm
pub const wl_shm_interface = struct {
    // shared memory support
    format: ?fn (*Context, Object, u32) anyerror!void,
};

fn wl_shm_format_default(context: *Context, object: Object, format: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SHM = wl_shm_interface{
    .format = wl_shm_format_default,
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
        // format
        0 => {
            var format: u32 = try object.context.next_u32();
            if (WL_SHM.format) |format| {
                try format(object.context, object, format);
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

//
// Create a new wl_shm_pool object.
//
// The pool can be used to create shared memory based buffer
// objects.  The server will mmap size bytes of the passed file
// descriptor, to use as backing memory for the pool.
//
pub fn wl_shm_send_create_pool(object: Object, id: u32, fd: i32, size: i32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.putFd(fd);
    object.context.putI32(size);
    object.context.finishWrite(object.id, 0);
}

// wl_buffer
pub const wl_buffer_interface = struct {
    // content for a wl_surface
    release: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn wl_buffer_release_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_BUFFER = wl_buffer_interface{
    .release = wl_buffer_release_default,
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
        // release
        0 => {
            if (WL_BUFFER.release) |release| {
                try release(
                    object.context,
                    object,
                );
            }
        },
        else => {},
    }
}

//
// Destroy a buffer. If and how you need to release the backing
// storage is defined by the buffer factory interface.
//
// For possible side-effects to a surface, see wl_surface.attach.
//
pub fn wl_buffer_send_destroy(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 0);
}

// wl_data_offer
pub const wl_data_offer_interface = struct {
    // offer to transfer data
    offer: ?fn (*Context, Object, []u8) anyerror!void,
    source_actions: ?fn (*Context, Object, u32) anyerror!void,
    action: ?fn (*Context, Object, u32) anyerror!void,
};

fn wl_data_offer_offer_default(context: *Context, object: Object, mime_type: []u8) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_offer_source_actions_default(context: *Context, object: Object, source_actions: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_offer_action_default(context: *Context, object: Object, dnd_action: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_DATA_OFFER = wl_data_offer_interface{
    .offer = wl_data_offer_offer_default,
    .source_actions = wl_data_offer_source_actions_default,
    .action = wl_data_offer_action_default,
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
        // offer
        0 => {
            var mime_type: []u8 = try object.context.next_string();
            if (WL_DATA_OFFER.offer) |offer| {
                try offer(object.context, object, mime_type);
            }
        },
        // source_actions
        1 => {
            var source_actions: u32 = try object.context.next_u32();
            if (WL_DATA_OFFER.source_actions) |source_actions| {
                try source_actions(object.context, object, source_actions);
            }
        },
        // action
        2 => {
            var dnd_action: u32 = try object.context.next_u32();
            if (WL_DATA_OFFER.action) |action| {
                try action(object.context, object, dnd_action);
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

//
// Indicate that the client can accept the given mime type, or
// NULL for not accepted.
//
// For objects of version 2 or older, this request is used by the
// client to give feedback whether the client can receive the given
// mime type, or NULL if none is accepted; the feedback does not
// determine whether the drag-and-drop operation succeeds or not.
//
// For objects of version 3 or newer, this request determines the
// final result of the drag-and-drop operation. If the end result
// is that no mime types were accepted, the drag-and-drop operation
// will be cancelled and the corresponding drag source will receive
// wl_data_source.cancelled. Clients may still use this event in
// conjunction with wl_data_source.action for feedback.
//
pub fn wl_data_offer_send_accept(object: Object, serial: u32, mime_type: []const u8) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putString(mime_type);
    object.context.finishWrite(object.id, 0);
}

//
// To transfer the offered data, the client issues this request
// and indicates the mime type it wants to receive.  The transfer
// happens through the passed file descriptor (typically created
// with the pipe system call).  The source client writes the data
// in the mime type representation requested and then closes the
// file descriptor.
//
// The receiving client reads from the read end of the pipe until
// EOF and then closes its end, at which point the transfer is
// complete.
//
// This request may happen multiple times for different mime types,
// both before and after wl_data_device.drop. Drag-and-drop destination
// clients may preemptively fetch data or examine it more closely to
// determine acceptance.
//
pub fn wl_data_offer_send_receive(object: Object, mime_type: []const u8, fd: i32) anyerror!void {
    object.context.startWrite();
    object.context.putString(mime_type);
    object.context.putFd(fd);
    object.context.finishWrite(object.id, 1);
}

//
// Destroy the data offer.
//
pub fn wl_data_offer_send_destroy(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 2);
}

//
// Notifies the compositor that the drag destination successfully
// finished the drag-and-drop operation.
//
// Upon receiving this request, the compositor will emit
// wl_data_source.dnd_finished on the drag source client.
//
// It is a client error to perform other requests than
// wl_data_offer.destroy after this one. It is also an error to perform
// this request after a NULL mime type has been set in
// wl_data_offer.accept or no action was received through
// wl_data_offer.action.
//
pub fn wl_data_offer_send_finish(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 3);
}

//
// Sets the actions that the destination side client supports for
// this operation. This request may trigger the emission of
// wl_data_source.action and wl_data_offer.action events if the compositor
// needs to change the selected action.
//
// This request can be called multiple times throughout the
// drag-and-drop operation, typically in response to wl_data_device.enter
// or wl_data_device.motion events.
//
// This request determines the final result of the drag-and-drop
// operation. If the end result is that no action is accepted,
// the drag source will receive wl_drag_source.cancelled.
//
// The dnd_actions argument must contain only values expressed in the
// wl_data_device_manager.dnd_actions enum, and the preferred_action
// argument must only contain one of those values set, otherwise it
// will result in a protocol error.
//
// While managing an "ask" action, the destination drag-and-drop client
// may perform further wl_data_offer.receive requests, and is expected
// to perform one last wl_data_offer.set_actions request with a preferred
// action other than "ask" (and optionally wl_data_offer.accept) before
// requesting wl_data_offer.finish, in order to convey the action selected
// by the user. If the preferred action is not in the
// wl_data_offer.source_actions mask, an error will be raised.
//
// If the "ask" action is dismissed (e.g. user cancellation), the client
// is expected to perform wl_data_offer.destroy right away.
//
// This request can only be made on drag-and-drop offers, a protocol error
// will be raised otherwise.
//
pub fn wl_data_offer_send_set_actions(object: Object, dnd_actions: u32, preferred_action: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(dnd_actions);
    object.context.putU32(preferred_action);
    object.context.finishWrite(object.id, 4);
}

// wl_data_source
pub const wl_data_source_interface = struct {
    // offer to transfer data
    target: ?fn (*Context, Object, []u8) anyerror!void,
    send: ?fn (*Context, Object, []u8, i32) anyerror!void,
    cancelled: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    dnd_drop_performed: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    dnd_finished: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    action: ?fn (*Context, Object, u32) anyerror!void,
};

fn wl_data_source_target_default(context: *Context, object: Object, mime_type: []u8) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_source_send_default(context: *Context, object: Object, mime_type: []u8, fd: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_source_cancelled_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_source_dnd_drop_performed_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_source_dnd_finished_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_source_action_default(context: *Context, object: Object, dnd_action: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_DATA_SOURCE = wl_data_source_interface{
    .target = wl_data_source_target_default,
    .send = wl_data_source_send_default,
    .cancelled = wl_data_source_cancelled_default,
    .dnd_drop_performed = wl_data_source_dnd_drop_performed_default,
    .dnd_finished = wl_data_source_dnd_finished_default,
    .action = wl_data_source_action_default,
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
        // target
        0 => {
            var mime_type: []u8 = try object.context.next_string();
            if (WL_DATA_SOURCE.target) |target| {
                try target(object.context, object, mime_type);
            }
        },
        // send
        1 => {
            var mime_type: []u8 = try object.context.next_string();
            var fd: i32 = try object.context.next_fd();
            if (WL_DATA_SOURCE.send) |send| {
                try send(object.context, object, mime_type, fd);
            }
        },
        // cancelled
        2 => {
            if (WL_DATA_SOURCE.cancelled) |cancelled| {
                try cancelled(
                    object.context,
                    object,
                );
            }
        },
        // dnd_drop_performed
        3 => {
            if (WL_DATA_SOURCE.dnd_drop_performed) |dnd_drop_performed| {
                try dnd_drop_performed(
                    object.context,
                    object,
                );
            }
        },
        // dnd_finished
        4 => {
            if (WL_DATA_SOURCE.dnd_finished) |dnd_finished| {
                try dnd_finished(
                    object.context,
                    object,
                );
            }
        },
        // action
        5 => {
            var dnd_action: u32 = try object.context.next_u32();
            if (WL_DATA_SOURCE.action) |action| {
                try action(object.context, object, dnd_action);
            }
        },
        else => {},
    }
}

pub const wl_data_source_error = enum(u32) {
    invalid_action_mask = 0,
    invalid_source = 1,
};

//
// This request adds a mime type to the set of mime types
// advertised to targets.  Can be called several times to offer
// multiple types.
//
pub fn wl_data_source_send_offer(object: Object, mime_type: []const u8) anyerror!void {
    object.context.startWrite();
    object.context.putString(mime_type);
    object.context.finishWrite(object.id, 0);
}

//
// Destroy the data source.
//
pub fn wl_data_source_send_destroy(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 1);
}

//
// Sets the actions that the source side client supports for this
// operation. This request may trigger wl_data_source.action and
// wl_data_offer.action events if the compositor needs to change the
// selected action.
//
// The dnd_actions argument must contain only values expressed in the
// wl_data_device_manager.dnd_actions enum, otherwise it will result
// in a protocol error.
//
// This request must be made once only, and can only be made on sources
// used in drag-and-drop, so it must be performed before
// wl_data_device.start_drag. Attempting to use the source other than
// for drag-and-drop will raise a protocol error.
//
pub fn wl_data_source_send_set_actions(object: Object, dnd_actions: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(dnd_actions);
    object.context.finishWrite(object.id, 2);
}

// wl_data_device
pub const wl_data_device_interface = struct {
    // data transfer device
    data_offer: ?fn (*Context, Object, u32) anyerror!void,
    enter: ?fn (*Context, Object, u32, Object, f32, f32, ?Object) anyerror!void,
    leave: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    motion: ?fn (*Context, Object, u32, f32, f32) anyerror!void,
    drop: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    selection: ?fn (*Context, Object, ?Object) anyerror!void,
};

fn wl_data_device_data_offer_default(context: *Context, object: Object, id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_device_enter_default(context: *Context, object: Object, serial: u32, surface: Object, x: f32, y: f32, id: ?Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_device_leave_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_device_motion_default(context: *Context, object: Object, time: u32, x: f32, y: f32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_device_drop_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_data_device_selection_default(context: *Context, object: Object, id: ?Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_DATA_DEVICE = wl_data_device_interface{
    .data_offer = wl_data_device_data_offer_default,
    .enter = wl_data_device_enter_default,
    .leave = wl_data_device_leave_default,
    .motion = wl_data_device_motion_default,
    .drop = wl_data_device_drop_default,
    .selection = wl_data_device_selection_default,
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
        // data_offer
        0 => {
            var id: u32 = try object.context.next_u32();
            if (WL_DATA_DEVICE.data_offer) |data_offer| {
                try data_offer(object.context, object, id);
            }
        },
        // enter
        1 => {
            var serial: u32 = try object.context.next_u32();
            var surface: Object = object.context.objects.get(try object.context.next_u32()).?;
            if (surface.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            var x: f32 = try object.context.next_fixed();
            var y: f32 = try object.context.next_fixed();
            var id: ?Object = object.context.objects.get(try object.context.next_u32());
            if (id != null) {
                if (id.?.dispatch != wl_data_offer_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            if (WL_DATA_DEVICE.enter) |enter| {
                try enter(object.context, object, serial, surface, x, y, id);
            }
        },
        // leave
        2 => {
            if (WL_DATA_DEVICE.leave) |leave| {
                try leave(
                    object.context,
                    object,
                );
            }
        },
        // motion
        3 => {
            var time: u32 = try object.context.next_u32();
            var x: f32 = try object.context.next_fixed();
            var y: f32 = try object.context.next_fixed();
            if (WL_DATA_DEVICE.motion) |motion| {
                try motion(object.context, object, time, x, y);
            }
        },
        // drop
        4 => {
            if (WL_DATA_DEVICE.drop) |drop| {
                try drop(
                    object.context,
                    object,
                );
            }
        },
        // selection
        5 => {
            var id: ?Object = object.context.objects.get(try object.context.next_u32());
            if (id != null) {
                if (id.?.dispatch != wl_data_offer_dispatch) {
                    return error.ObjectWrongType;
                }
            }
            if (WL_DATA_DEVICE.selection) |selection| {
                try selection(object.context, object, id);
            }
        },
        else => {},
    }
}

pub const wl_data_device_error = enum(u32) {
    role = 0,
};

//
// This request asks the compositor to start a drag-and-drop
// operation on behalf of the client.
//
// The source argument is the data source that provides the data
// for the eventual data transfer. If source is NULL, enter, leave
// and motion events are sent only to the client that initiated the
// drag and the client is expected to handle the data passing
// internally.
//
// The origin surface is the surface where the drag originates and
// the client must have an active implicit grab that matches the
// serial.
//
// The icon surface is an optional (can be NULL) surface that
// provides an icon to be moved around with the cursor.  Initially,
// the top-left corner of the icon surface is placed at the cursor
// hotspot, but subsequent wl_surface.attach request can move the
// relative position. Attach requests must be confirmed with
// wl_surface.commit as usual. The icon surface is given the role of
// a drag-and-drop icon. If the icon surface already has another role,
// it raises a protocol error.
//
// The current and pending input regions of the icon wl_surface are
// cleared, and wl_surface.set_input_region is ignored until the
// wl_surface is no longer used as the icon surface. When the use
// as an icon ends, the current and pending input regions become
// undefined, and the wl_surface is unmapped.
//
pub fn wl_data_device_send_start_drag(object: Object, source: u32, origin: u32, icon: u32, serial: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(source);
    object.context.putU32(origin);
    object.context.putU32(icon);
    object.context.putU32(serial);
    object.context.finishWrite(object.id, 0);
}

//
// This request asks the compositor to set the selection
// to the data from the source on behalf of the client.
//
// To unset the selection, set the source to NULL.
//
pub fn wl_data_device_send_set_selection(object: Object, source: u32, serial: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(source);
    object.context.putU32(serial);
    object.context.finishWrite(object.id, 1);
}

//
// This request destroys the data device.
//
pub fn wl_data_device_send_release(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 2);
}

// wl_data_device_manager
pub const wl_data_device_manager_interface = struct {
    // data transfer interface
};

pub var WL_DATA_DEVICE_MANAGER = wl_data_device_manager_interface{};

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
        else => {},
    }
}

pub const wl_data_device_manager_dnd_action = enum(u32) {
    none = 0,
    copy = 1,
    move = 2,
    ask = 4,
};

//
// Create a new data source.
//
pub fn wl_data_device_manager_send_create_data_source(object: Object, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.finishWrite(object.id, 0);
}

//
// Create a new data device for a given seat.
//
pub fn wl_data_device_manager_send_get_data_device(object: Object, id: u32, seat: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.putU32(seat);
    object.context.finishWrite(object.id, 1);
}

// wl_shell
pub const wl_shell_interface = struct {
    // create desktop-style surfaces
};

pub var WL_SHELL = wl_shell_interface{};

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
        else => {},
    }
}

pub const wl_shell_error = enum(u32) {
    role = 0,
};

//
// Create a shell surface for an existing surface. This gives
// the wl_surface the role of a shell surface. If the wl_surface
// already has another role, it raises a protocol error.
//
// Only one shell surface can be associated with a given surface.
//
pub fn wl_shell_send_get_shell_surface(object: Object, id: u32, surface: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.putU32(surface);
    object.context.finishWrite(object.id, 0);
}

// wl_shell_surface
pub const wl_shell_surface_interface = struct {
    // desktop-style metadata interface
    ping: ?fn (*Context, Object, u32) anyerror!void,
    configure: ?fn (*Context, Object, u32, i32, i32) anyerror!void,
    popup_done: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn wl_shell_surface_ping_default(context: *Context, object: Object, serial: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_configure_default(context: *Context, object: Object, edges: u32, width: i32, height: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_shell_surface_popup_done_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SHELL_SURFACE = wl_shell_surface_interface{
    .ping = wl_shell_surface_ping_default,
    .configure = wl_shell_surface_configure_default,
    .popup_done = wl_shell_surface_popup_done_default,
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
        // ping
        0 => {
            var serial: u32 = try object.context.next_u32();
            if (WL_SHELL_SURFACE.ping) |ping| {
                try ping(object.context, object, serial);
            }
        },
        // configure
        1 => {
            var edges: u32 = try object.context.next_u32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            if (WL_SHELL_SURFACE.configure) |configure| {
                try configure(object.context, object, edges, width, height);
            }
        },
        // popup_done
        2 => {
            if (WL_SHELL_SURFACE.popup_done) |popup_done| {
                try popup_done(
                    object.context,
                    object,
                );
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

//
// A client must respond to a ping event with a pong request or
// the client may be deemed unresponsive.
//
pub fn wl_shell_surface_send_pong(object: Object, serial: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.finishWrite(object.id, 0);
}

//
// Start a pointer-driven move of the surface.
//
// This request must be used in response to a button press event.
// The server may ignore move requests depending on the state of
// the surface (e.g. fullscreen or maximized).
//
pub fn wl_shell_surface_send_move(object: Object, seat: u32, serial: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(seat);
    object.context.putU32(serial);
    object.context.finishWrite(object.id, 1);
}

//
// Start a pointer-driven resizing of the surface.
//
// This request must be used in response to a button press event.
// The server may ignore resize requests depending on the state of
// the surface (e.g. fullscreen or maximized).
//
pub fn wl_shell_surface_send_resize(object: Object, seat: u32, serial: u32, edges: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(seat);
    object.context.putU32(serial);
    object.context.putU32(edges);
    object.context.finishWrite(object.id, 2);
}

//
// Map the surface as a toplevel surface.
//
// A toplevel surface is not fullscreen, maximized or transient.
//
pub fn wl_shell_surface_send_set_toplevel(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 3);
}

//
// Map the surface relative to an existing surface.
//
// The x and y arguments specify the location of the upper left
// corner of the surface relative to the upper left corner of the
// parent surface, in surface-local coordinates.
//
// The flags argument controls details of the transient behaviour.
//
pub fn wl_shell_surface_send_set_transient(object: Object, parent: u32, x: i32, y: i32, flags: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(parent);
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putU32(flags);
    object.context.finishWrite(object.id, 4);
}

//
// Map the surface as a fullscreen surface.
//
// If an output parameter is given then the surface will be made
// fullscreen on that output. If the client does not specify the
// output then the compositor will apply its policy - usually
// choosing the output on which the surface has the biggest surface
// area.
//
// The client may specify a method to resolve a size conflict
// between the output size and the surface size - this is provided
// through the method parameter.
//
// The framerate parameter is used only when the method is set
// to "driver", to indicate the preferred framerate. A value of 0
// indicates that the client does not care about framerate.  The
// framerate is specified in mHz, that is framerate of 60000 is 60Hz.
//
// A method of "scale" or "driver" implies a scaling operation of
// the surface, either via a direct scaling operation or a change of
// the output mode. This will override any kind of output scaling, so
// that mapping a surface with a buffer size equal to the mode can
// fill the screen independent of buffer_scale.
//
// A method of "fill" means we don't scale up the buffer, however
// any output scale is applied. This means that you may run into
// an edge case where the application maps a buffer with the same
// size of the output mode but buffer_scale 1 (thus making a
// surface larger than the output). In this case it is allowed to
// downscale the results to fit the screen.
//
// The compositor must reply to this request with a configure event
// with the dimensions for the output on which the surface will
// be made fullscreen.
//
pub fn wl_shell_surface_send_set_fullscreen(object: Object, method: u32, framerate: u32, output: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(method);
    object.context.putU32(framerate);
    object.context.putU32(output);
    object.context.finishWrite(object.id, 5);
}

//
// Map the surface as a popup.
//
// A popup surface is a transient surface with an added pointer
// grab.
//
// An existing implicit grab will be changed to owner-events mode,
// and the popup grab will continue after the implicit grab ends
// (i.e. releasing the mouse button does not cause the popup to
// be unmapped).
//
// The popup grab continues until the window is destroyed or a
// mouse button is pressed in any other client's window. A click
// in any of the client's surfaces is reported as normal, however,
// clicks in other clients' surfaces will be discarded and trigger
// the callback.
//
// The x and y arguments specify the location of the upper left
// corner of the surface relative to the upper left corner of the
// parent surface, in surface-local coordinates.
//
pub fn wl_shell_surface_send_set_popup(object: Object, seat: u32, serial: u32, parent: u32, x: i32, y: i32, flags: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(seat);
    object.context.putU32(serial);
    object.context.putU32(parent);
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putU32(flags);
    object.context.finishWrite(object.id, 6);
}

//
// Map the surface as a maximized surface.
//
// If an output parameter is given then the surface will be
// maximized on that output. If the client does not specify the
// output then the compositor will apply its policy - usually
// choosing the output on which the surface has the biggest surface
// area.
//
// The compositor will reply with a configure event telling
// the expected new surface size. The operation is completed
// on the next buffer attach to this surface.
//
// A maximized surface typically fills the entire output it is
// bound to, except for desktop elements such as panels. This is
// the main difference between a maximized shell surface and a
// fullscreen shell surface.
//
// The details depend on the compositor implementation.
//
pub fn wl_shell_surface_send_set_maximized(object: Object, output: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(output);
    object.context.finishWrite(object.id, 7);
}

//
// Set a short title for the surface.
//
// This string may be used to identify the surface in a task bar,
// window list, or other user interface elements provided by the
// compositor.
//
// The string must be encoded in UTF-8.
//
pub fn wl_shell_surface_send_set_title(object: Object, title: []const u8) anyerror!void {
    object.context.startWrite();
    object.context.putString(title);
    object.context.finishWrite(object.id, 8);
}

//
// Set a class for the surface.
//
// The surface class identifies the general class of applications
// to which the surface belongs. A common convention is to use the
// file name (or the full path if it is a non-standard location) of
// the application's .desktop file as the class.
//
pub fn wl_shell_surface_send_set_class(object: Object, class_: []const u8) anyerror!void {
    object.context.startWrite();
    object.context.putString(class_);
    object.context.finishWrite(object.id, 9);
}

// wl_surface
pub const wl_surface_interface = struct {
    // an onscreen surface
    enter: ?fn (*Context, Object, Object) anyerror!void,
    leave: ?fn (*Context, Object, Object) anyerror!void,
};

fn wl_surface_enter_default(context: *Context, object: Object, output: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_surface_leave_default(context: *Context, object: Object, output: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SURFACE = wl_surface_interface{
    .enter = wl_surface_enter_default,
    .leave = wl_surface_leave_default,
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
        // enter
        0 => {
            var output: Object = object.context.objects.get(try object.context.next_u32()).?;
            if (output.dispatch != wl_output_dispatch) {
                return error.ObjectWrongType;
            }
            if (WL_SURFACE.enter) |enter| {
                try enter(object.context, object, output);
            }
        },
        // leave
        1 => {
            var output: Object = object.context.objects.get(try object.context.next_u32()).?;
            if (output.dispatch != wl_output_dispatch) {
                return error.ObjectWrongType;
            }
            if (WL_SURFACE.leave) |leave| {
                try leave(object.context, object, output);
            }
        },
        else => {},
    }
}

pub const wl_surface_error = enum(u32) {
    invalid_scale = 0,
    invalid_transform = 1,
};

//
// Deletes the surface and invalidates its object ID.
//
pub fn wl_surface_send_destroy(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 0);
}

//
// Set a buffer as the content of this surface.
//
// The new size of the surface is calculated based on the buffer
// size transformed by the inverse buffer_transform and the
// inverse buffer_scale. This means that the supplied buffer
// must be an integer multiple of the buffer_scale.
//
// The x and y arguments specify the location of the new pending
// buffer's upper left corner, relative to the current buffer's upper
// left corner, in surface-local coordinates. In other words, the
// x and y, combined with the new surface size define in which
// directions the surface's size changes.
//
// Surface contents are double-buffered state, see wl_surface.commit.
//
// The initial surface contents are void; there is no content.
// wl_surface.attach assigns the given wl_buffer as the pending
// wl_buffer. wl_surface.commit makes the pending wl_buffer the new
// surface contents, and the size of the surface becomes the size
// calculated from the wl_buffer, as described above. After commit,
// there is no pending buffer until the next attach.
//
// Committing a pending wl_buffer allows the compositor to read the
// pixels in the wl_buffer. The compositor may access the pixels at
// any time after the wl_surface.commit request. When the compositor
// will not access the pixels anymore, it will send the
// wl_buffer.release event. Only after receiving wl_buffer.release,
// the client may reuse the wl_buffer. A wl_buffer that has been
// attached and then replaced by another attach instead of committed
// will not receive a release event, and is not used by the
// compositor.
//
// Destroying the wl_buffer after wl_buffer.release does not change
// the surface contents. However, if the client destroys the
// wl_buffer before receiving the wl_buffer.release event, the surface
// contents become undefined immediately.
//
// If wl_surface.attach is sent with a NULL wl_buffer, the
// following wl_surface.commit will remove the surface content.
//
pub fn wl_surface_send_attach(object: Object, buffer: u32, x: i32, y: i32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(buffer);
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.finishWrite(object.id, 1);
}

//
// This request is used to describe the regions where the pending
// buffer is different from the current surface contents, and where
// the surface therefore needs to be repainted. The compositor
// ignores the parts of the damage that fall outside of the surface.
//
// Damage is double-buffered state, see wl_surface.commit.
//
// The damage rectangle is specified in surface-local coordinates,
// where x and y specify the upper left corner of the damage rectangle.
//
// The initial value for pending damage is empty: no damage.
// wl_surface.damage adds pending damage: the new pending damage
// is the union of old pending damage and the given rectangle.
//
// wl_surface.commit assigns pending damage as the current damage,
// and clears pending damage. The server will clear the current
// damage as it repaints the surface.
//
// Note! New clients should not use this request. Instead damage can be
// posted with wl_surface.damage_buffer which uses buffer coordinates
// instead of surface coordinates.
//
pub fn wl_surface_send_damage(object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.finishWrite(object.id, 2);
}

//
// Request a notification when it is a good time to start drawing a new
// frame, by creating a frame callback. This is useful for throttling
// redrawing operations, and driving animations.
//
// When a client is animating on a wl_surface, it can use the 'frame'
// request to get notified when it is a good time to draw and commit the
// next frame of animation. If the client commits an update earlier than
// that, it is likely that some updates will not make it to the display,
// and the client is wasting resources by drawing too often.
//
// The frame request will take effect on the next wl_surface.commit.
// The notification will only be posted for one frame unless
// requested again. For a wl_surface, the notifications are posted in
// the order the frame requests were committed.
//
// The server must send the notifications so that a client
// will not send excessive updates, while still allowing
// the highest possible update rate for clients that wait for the reply
// before drawing again. The server should give some time for the client
// to draw and commit after sending the frame callback events to let it
// hit the next output refresh.
//
// A server should avoid signaling the frame callbacks if the
// surface is not visible in any way, e.g. the surface is off-screen,
// or completely obscured by other opaque surfaces.
//
// The object returned by this request will be destroyed by the
// compositor after the callback is fired and as such the client must not
// attempt to use it after that point.
//
// The callback_data passed in the callback is the current time, in
// milliseconds, with an undefined base.
//
pub fn wl_surface_send_frame(object: Object, callback: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(callback);
    object.context.finishWrite(object.id, 3);
}

//
// This request sets the region of the surface that contains
// opaque content.
//
// The opaque region is an optimization hint for the compositor
// that lets it optimize the redrawing of content behind opaque
// regions.  Setting an opaque region is not required for correct
// behaviour, but marking transparent content as opaque will result
// in repaint artifacts.
//
// The opaque region is specified in surface-local coordinates.
//
// The compositor ignores the parts of the opaque region that fall
// outside of the surface.
//
// Opaque region is double-buffered state, see wl_surface.commit.
//
// wl_surface.set_opaque_region changes the pending opaque region.
// wl_surface.commit copies the pending region to the current region.
// Otherwise, the pending and current regions are never changed.
//
// The initial value for an opaque region is empty. Setting the pending
// opaque region has copy semantics, and the wl_region object can be
// destroyed immediately. A NULL wl_region causes the pending opaque
// region to be set to empty.
//
pub fn wl_surface_send_set_opaque_region(object: Object, region: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(region);
    object.context.finishWrite(object.id, 4);
}

//
// This request sets the region of the surface that can receive
// pointer and touch events.
//
// Input events happening outside of this region will try the next
// surface in the server surface stack. The compositor ignores the
// parts of the input region that fall outside of the surface.
//
// The input region is specified in surface-local coordinates.
//
// Input region is double-buffered state, see wl_surface.commit.
//
// wl_surface.set_input_region changes the pending input region.
// wl_surface.commit copies the pending region to the current region.
// Otherwise the pending and current regions are never changed,
// except cursor and icon surfaces are special cases, see
// wl_pointer.set_cursor and wl_data_device.start_drag.
//
// The initial value for an input region is infinite. That means the
// whole surface will accept input. Setting the pending input region
// has copy semantics, and the wl_region object can be destroyed
// immediately. A NULL wl_region causes the input region to be set
// to infinite.
//
pub fn wl_surface_send_set_input_region(object: Object, region: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(region);
    object.context.finishWrite(object.id, 5);
}

//
// Surface state (input, opaque, and damage regions, attached buffers,
// etc.) is double-buffered. Protocol requests modify the pending state,
// as opposed to the current state in use by the compositor. A commit
// request atomically applies all pending state, replacing the current
// state. After commit, the new pending state is as documented for each
// related request.
//
// On commit, a pending wl_buffer is applied first, and all other state
// second. This means that all coordinates in double-buffered state are
// relative to the new wl_buffer coming into use, except for
// wl_surface.attach itself. If there is no pending wl_buffer, the
// coordinates are relative to the current surface contents.
//
// All requests that need a commit to become effective are documented
// to affect double-buffered state.
//
// Other interfaces may add further double-buffered surface state.
//
pub fn wl_surface_send_commit(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 6);
}

//
// This request sets an optional transformation on how the compositor
// interprets the contents of the buffer attached to the surface. The
// accepted values for the transform parameter are the values for
// wl_output.transform.
//
// Buffer transform is double-buffered state, see wl_surface.commit.
//
// A newly created surface has its buffer transformation set to normal.
//
// wl_surface.set_buffer_transform changes the pending buffer
// transformation. wl_surface.commit copies the pending buffer
// transformation to the current one. Otherwise, the pending and current
// values are never changed.
//
// The purpose of this request is to allow clients to render content
// according to the output transform, thus permitting the compositor to
// use certain optimizations even if the display is rotated. Using
// hardware overlays and scanning out a client buffer for fullscreen
// surfaces are examples of such optimizations. Those optimizations are
// highly dependent on the compositor implementation, so the use of this
// request should be considered on a case-by-case basis.
//
// Note that if the transform value includes 90 or 270 degree rotation,
// the width of the buffer will become the surface height and the height
// of the buffer will become the surface width.
//
// If transform is not one of the values from the
// wl_output.transform enum the invalid_transform protocol error
// is raised.
//
pub fn wl_surface_send_set_buffer_transform(object: Object, transform: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(transform);
    object.context.finishWrite(object.id, 7);
}

//
// This request sets an optional scaling factor on how the compositor
// interprets the contents of the buffer attached to the window.
//
// Buffer scale is double-buffered state, see wl_surface.commit.
//
// A newly created surface has its buffer scale set to 1.
//
// wl_surface.set_buffer_scale changes the pending buffer scale.
// wl_surface.commit copies the pending buffer scale to the current one.
// Otherwise, the pending and current values are never changed.
//
// The purpose of this request is to allow clients to supply higher
// resolution buffer data for use on high resolution outputs. It is
// intended that you pick the same buffer scale as the scale of the
// output that the surface is displayed on. This means the compositor
// can avoid scaling when rendering the surface on that output.
//
// Note that if the scale is larger than 1, then you have to attach
// a buffer that is larger (by a factor of scale in each dimension)
// than the desired surface size.
//
// If scale is not positive the invalid_scale protocol error is
// raised.
//
pub fn wl_surface_send_set_buffer_scale(object: Object, scale: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(scale);
    object.context.finishWrite(object.id, 8);
}

//
// This request is used to describe the regions where the pending
// buffer is different from the current surface contents, and where
// the surface therefore needs to be repainted. The compositor
// ignores the parts of the damage that fall outside of the surface.
//
// Damage is double-buffered state, see wl_surface.commit.
//
// The damage rectangle is specified in buffer coordinates,
// where x and y specify the upper left corner of the damage rectangle.
//
// The initial value for pending damage is empty: no damage.
// wl_surface.damage_buffer adds pending damage: the new pending
// damage is the union of old pending damage and the given rectangle.
//
// wl_surface.commit assigns pending damage as the current damage,
// and clears pending damage. The server will clear the current
// damage as it repaints the surface.
//
// This request differs from wl_surface.damage in only one way - it
// takes damage in buffer coordinates instead of surface-local
// coordinates. While this generally is more intuitive than surface
// coordinates, it is especially desirable when using wp_viewport
// or when a drawing library (like EGL) is unaware of buffer scale
// and buffer transform.
//
// Note: Because buffer transformation changes and damage requests may
// be interleaved in the protocol stream, it is impossible to determine
// the actual mapping between surface and buffer damage until
// wl_surface.commit time. Therefore, compositors wishing to take both
// kinds of damage into account will have to accumulate damage from the
// two requests separately and only transform from one to the other
// after receiving the wl_surface.commit.
//
pub fn wl_surface_send_damage_buffer(object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.finishWrite(object.id, 9);
}

// wl_seat
pub const wl_seat_interface = struct {
    // group of input devices
    capabilities: ?fn (*Context, Object, u32) anyerror!void,
    name: ?fn (*Context, Object, []u8) anyerror!void,
};

fn wl_seat_capabilities_default(context: *Context, object: Object, capabilities: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_seat_name_default(context: *Context, object: Object, name: []u8) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_SEAT = wl_seat_interface{
    .capabilities = wl_seat_capabilities_default,
    .name = wl_seat_name_default,
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
        // capabilities
        0 => {
            var capabilities: u32 = try object.context.next_u32();
            if (WL_SEAT.capabilities) |capabilities| {
                try capabilities(object.context, object, capabilities);
            }
        },
        // name
        1 => {
            var name: []u8 = try object.context.next_string();
            if (WL_SEAT.name) |name| {
                try name(object.context, object, name);
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

//
// The ID provided will be initialized to the wl_pointer interface
// for this seat.
//
// This request only takes effect if the seat has the pointer
// capability, or has had the pointer capability in the past.
// It is a protocol violation to issue this request on a seat that has
// never had the pointer capability.
//
pub fn wl_seat_send_get_pointer(object: Object, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.finishWrite(object.id, 0);
}

//
// The ID provided will be initialized to the wl_keyboard interface
// for this seat.
//
// This request only takes effect if the seat has the keyboard
// capability, or has had the keyboard capability in the past.
// It is a protocol violation to issue this request on a seat that has
// never had the keyboard capability.
//
pub fn wl_seat_send_get_keyboard(object: Object, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.finishWrite(object.id, 1);
}

//
// The ID provided will be initialized to the wl_touch interface
// for this seat.
//
// This request only takes effect if the seat has the touch
// capability, or has had the touch capability in the past.
// It is a protocol violation to issue this request on a seat that has
// never had the touch capability.
//
pub fn wl_seat_send_get_touch(object: Object, id: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.finishWrite(object.id, 2);
}

//
// Using this request a client can tell the server that it is not going to
// use the seat object anymore.
//
pub fn wl_seat_send_release(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 3);
}

// wl_pointer
pub const wl_pointer_interface = struct {
    // pointer input device
    enter: ?fn (*Context, Object, u32, Object, f32, f32) anyerror!void,
    leave: ?fn (*Context, Object, u32, Object) anyerror!void,
    motion: ?fn (*Context, Object, u32, f32, f32) anyerror!void,
    button: ?fn (*Context, Object, u32, u32, u32, u32) anyerror!void,
    axis: ?fn (*Context, Object, u32, u32, f32) anyerror!void,
    frame: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    axis_source: ?fn (*Context, Object, u32) anyerror!void,
    axis_stop: ?fn (*Context, Object, u32, u32) anyerror!void,
    axis_discrete: ?fn (*Context, Object, u32, i32) anyerror!void,
};

fn wl_pointer_enter_default(context: *Context, object: Object, serial: u32, surface: Object, surface_x: f32, surface_y: f32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_pointer_leave_default(context: *Context, object: Object, serial: u32, surface: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_pointer_motion_default(context: *Context, object: Object, time: u32, surface_x: f32, surface_y: f32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_pointer_button_default(context: *Context, object: Object, serial: u32, time: u32, button: u32, state: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_pointer_axis_default(context: *Context, object: Object, time: u32, axis: u32, value: f32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_pointer_frame_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_pointer_axis_source_default(context: *Context, object: Object, axis_source: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_pointer_axis_stop_default(context: *Context, object: Object, time: u32, axis: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_pointer_axis_discrete_default(context: *Context, object: Object, axis: u32, discrete: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_POINTER = wl_pointer_interface{
    .enter = wl_pointer_enter_default,
    .leave = wl_pointer_leave_default,
    .motion = wl_pointer_motion_default,
    .button = wl_pointer_button_default,
    .axis = wl_pointer_axis_default,
    .frame = wl_pointer_frame_default,
    .axis_source = wl_pointer_axis_source_default,
    .axis_stop = wl_pointer_axis_stop_default,
    .axis_discrete = wl_pointer_axis_discrete_default,
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
        // enter
        0 => {
            var serial: u32 = try object.context.next_u32();
            var surface: Object = object.context.objects.get(try object.context.next_u32()).?;
            if (surface.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            var surface_x: f32 = try object.context.next_fixed();
            var surface_y: f32 = try object.context.next_fixed();
            if (WL_POINTER.enter) |enter| {
                try enter(object.context, object, serial, surface, surface_x, surface_y);
            }
        },
        // leave
        1 => {
            var serial: u32 = try object.context.next_u32();
            var surface: Object = object.context.objects.get(try object.context.next_u32()).?;
            if (surface.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            if (WL_POINTER.leave) |leave| {
                try leave(object.context, object, serial, surface);
            }
        },
        // motion
        2 => {
            var time: u32 = try object.context.next_u32();
            var surface_x: f32 = try object.context.next_fixed();
            var surface_y: f32 = try object.context.next_fixed();
            if (WL_POINTER.motion) |motion| {
                try motion(object.context, object, time, surface_x, surface_y);
            }
        },
        // button
        3 => {
            var serial: u32 = try object.context.next_u32();
            var time: u32 = try object.context.next_u32();
            var button: u32 = try object.context.next_u32();
            var state: u32 = try object.context.next_u32();
            if (WL_POINTER.button) |button| {
                try button(object.context, object, serial, time, button, state);
            }
        },
        // axis
        4 => {
            var time: u32 = try object.context.next_u32();
            var axis: u32 = try object.context.next_u32();
            var value: f32 = try object.context.next_fixed();
            if (WL_POINTER.axis) |axis| {
                try axis(object.context, object, time, axis, value);
            }
        },
        // frame
        5 => {
            if (WL_POINTER.frame) |frame| {
                try frame(
                    object.context,
                    object,
                );
            }
        },
        // axis_source
        6 => {
            var axis_source: u32 = try object.context.next_u32();
            if (WL_POINTER.axis_source) |axis_source| {
                try axis_source(object.context, object, axis_source);
            }
        },
        // axis_stop
        7 => {
            var time: u32 = try object.context.next_u32();
            var axis: u32 = try object.context.next_u32();
            if (WL_POINTER.axis_stop) |axis_stop| {
                try axis_stop(object.context, object, time, axis);
            }
        },
        // axis_discrete
        8 => {
            var axis: u32 = try object.context.next_u32();
            var discrete: i32 = try object.context.next_i32();
            if (WL_POINTER.axis_discrete) |axis_discrete| {
                try axis_discrete(object.context, object, axis, discrete);
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

//
// Set the pointer surface, i.e., the surface that contains the
// pointer image (cursor). This request gives the surface the role
// of a cursor. If the surface already has another role, it raises
// a protocol error.
//
// The cursor actually changes only if the pointer
// focus for this device is one of the requesting client's surfaces
// or the surface parameter is the current pointer surface. If
// there was a previous surface set with this request it is
// replaced. If surface is NULL, the pointer image is hidden.
//
// The parameters hotspot_x and hotspot_y define the position of
// the pointer surface relative to the pointer location. Its
// top-left corner is always at (x, y) - (hotspot_x, hotspot_y),
// where (x, y) are the coordinates of the pointer location, in
// surface-local coordinates.
//
// On surface.attach requests to the pointer surface, hotspot_x
// and hotspot_y are decremented by the x and y parameters
// passed to the request. Attach must be confirmed by
// wl_surface.commit as usual.
//
// The hotspot can also be updated by passing the currently set
// pointer surface to this request with new values for hotspot_x
// and hotspot_y.
//
// The current and pending input regions of the wl_surface are
// cleared, and wl_surface.set_input_region is ignored until the
// wl_surface is no longer used as the cursor. When the use as a
// cursor ends, the current and pending input regions become
// undefined, and the wl_surface is unmapped.
//
pub fn wl_pointer_send_set_cursor(object: Object, serial: u32, surface: u32, hotspot_x: i32, hotspot_y: i32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(serial);
    object.context.putU32(surface);
    object.context.putI32(hotspot_x);
    object.context.putI32(hotspot_y);
    object.context.finishWrite(object.id, 0);
}

//
// Using this request a client can tell the server that it is not going to
// use the pointer object anymore.
//
// This request destroys the pointer proxy object, so clients must not call
// wl_pointer_destroy() after using this request.
//
pub fn wl_pointer_send_release(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 1);
}

// wl_keyboard
pub const wl_keyboard_interface = struct {
    // keyboard input device
    keymap: ?fn (*Context, Object, u32, i32, u32) anyerror!void,
    enter: ?fn (*Context, Object, u32, Object, []u32) anyerror!void,
    leave: ?fn (*Context, Object, u32, Object) anyerror!void,
    key: ?fn (*Context, Object, u32, u32, u32, u32) anyerror!void,
    modifiers: ?fn (*Context, Object, u32, u32, u32, u32, u32) anyerror!void,
    repeat_info: ?fn (*Context, Object, i32, i32) anyerror!void,
};

fn wl_keyboard_keymap_default(context: *Context, object: Object, format: u32, fd: i32, size: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_keyboard_enter_default(context: *Context, object: Object, serial: u32, surface: Object, keys: []u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_keyboard_leave_default(context: *Context, object: Object, serial: u32, surface: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_keyboard_key_default(context: *Context, object: Object, serial: u32, time: u32, key: u32, state: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_keyboard_modifiers_default(context: *Context, object: Object, serial: u32, mods_depressed: u32, mods_latched: u32, mods_locked: u32, group: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_keyboard_repeat_info_default(context: *Context, object: Object, rate: i32, delay: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_KEYBOARD = wl_keyboard_interface{
    .keymap = wl_keyboard_keymap_default,
    .enter = wl_keyboard_enter_default,
    .leave = wl_keyboard_leave_default,
    .key = wl_keyboard_key_default,
    .modifiers = wl_keyboard_modifiers_default,
    .repeat_info = wl_keyboard_repeat_info_default,
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
        // keymap
        0 => {
            var format: u32 = try object.context.next_u32();
            var fd: i32 = try object.context.next_fd();
            var size: u32 = try object.context.next_u32();
            if (WL_KEYBOARD.keymap) |keymap| {
                try keymap(object.context, object, format, fd, size);
            }
        },
        // enter
        1 => {
            var serial: u32 = try object.context.next_u32();
            var surface: Object = object.context.objects.get(try object.context.next_u32()).?;
            if (surface.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            var keys: []u32 = try object.context.next_array();
            if (WL_KEYBOARD.enter) |enter| {
                try enter(object.context, object, serial, surface, keys);
            }
        },
        // leave
        2 => {
            var serial: u32 = try object.context.next_u32();
            var surface: Object = object.context.objects.get(try object.context.next_u32()).?;
            if (surface.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            if (WL_KEYBOARD.leave) |leave| {
                try leave(object.context, object, serial, surface);
            }
        },
        // key
        3 => {
            var serial: u32 = try object.context.next_u32();
            var time: u32 = try object.context.next_u32();
            var key: u32 = try object.context.next_u32();
            var state: u32 = try object.context.next_u32();
            if (WL_KEYBOARD.key) |key| {
                try key(object.context, object, serial, time, key, state);
            }
        },
        // modifiers
        4 => {
            var serial: u32 = try object.context.next_u32();
            var mods_depressed: u32 = try object.context.next_u32();
            var mods_latched: u32 = try object.context.next_u32();
            var mods_locked: u32 = try object.context.next_u32();
            var group: u32 = try object.context.next_u32();
            if (WL_KEYBOARD.modifiers) |modifiers| {
                try modifiers(object.context, object, serial, mods_depressed, mods_latched, mods_locked, group);
            }
        },
        // repeat_info
        5 => {
            var rate: i32 = try object.context.next_i32();
            var delay: i32 = try object.context.next_i32();
            if (WL_KEYBOARD.repeat_info) |repeat_info| {
                try repeat_info(object.context, object, rate, delay);
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

pub fn wl_keyboard_send_release(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 0);
}

// wl_touch
pub const wl_touch_interface = struct {
    // touchscreen input device
    down: ?fn (*Context, Object, u32, u32, Object, i32, f32, f32) anyerror!void,
    up: ?fn (*Context, Object, u32, u32, i32) anyerror!void,
    motion: ?fn (*Context, Object, u32, i32, f32, f32) anyerror!void,
    frame: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    cancel: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    shape: ?fn (*Context, Object, i32, f32, f32) anyerror!void,
    orientation: ?fn (*Context, Object, i32, f32) anyerror!void,
};

fn wl_touch_down_default(context: *Context, object: Object, serial: u32, time: u32, surface: Object, id: i32, x: f32, y: f32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_touch_up_default(context: *Context, object: Object, serial: u32, time: u32, id: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_touch_motion_default(context: *Context, object: Object, time: u32, id: i32, x: f32, y: f32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_touch_frame_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_touch_cancel_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_touch_shape_default(context: *Context, object: Object, id: i32, major: f32, minor: f32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_touch_orientation_default(context: *Context, object: Object, id: i32, orientation: f32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_TOUCH = wl_touch_interface{
    .down = wl_touch_down_default,
    .up = wl_touch_up_default,
    .motion = wl_touch_motion_default,
    .frame = wl_touch_frame_default,
    .cancel = wl_touch_cancel_default,
    .shape = wl_touch_shape_default,
    .orientation = wl_touch_orientation_default,
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
        // down
        0 => {
            var serial: u32 = try object.context.next_u32();
            var time: u32 = try object.context.next_u32();
            var surface: Object = object.context.objects.get(try object.context.next_u32()).?;
            if (surface.dispatch != wl_surface_dispatch) {
                return error.ObjectWrongType;
            }
            var id: i32 = try object.context.next_i32();
            var x: f32 = try object.context.next_fixed();
            var y: f32 = try object.context.next_fixed();
            if (WL_TOUCH.down) |down| {
                try down(object.context, object, serial, time, surface, id, x, y);
            }
        },
        // up
        1 => {
            var serial: u32 = try object.context.next_u32();
            var time: u32 = try object.context.next_u32();
            var id: i32 = try object.context.next_i32();
            if (WL_TOUCH.up) |up| {
                try up(object.context, object, serial, time, id);
            }
        },
        // motion
        2 => {
            var time: u32 = try object.context.next_u32();
            var id: i32 = try object.context.next_i32();
            var x: f32 = try object.context.next_fixed();
            var y: f32 = try object.context.next_fixed();
            if (WL_TOUCH.motion) |motion| {
                try motion(object.context, object, time, id, x, y);
            }
        },
        // frame
        3 => {
            if (WL_TOUCH.frame) |frame| {
                try frame(
                    object.context,
                    object,
                );
            }
        },
        // cancel
        4 => {
            if (WL_TOUCH.cancel) |cancel| {
                try cancel(
                    object.context,
                    object,
                );
            }
        },
        // shape
        5 => {
            var id: i32 = try object.context.next_i32();
            var major: f32 = try object.context.next_fixed();
            var minor: f32 = try object.context.next_fixed();
            if (WL_TOUCH.shape) |shape| {
                try shape(object.context, object, id, major, minor);
            }
        },
        // orientation
        6 => {
            var id: i32 = try object.context.next_i32();
            var orientation: f32 = try object.context.next_fixed();
            if (WL_TOUCH.orientation) |orientation| {
                try orientation(object.context, object, id, orientation);
            }
        },
        else => {},
    }
}

pub fn wl_touch_send_release(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 0);
}

// wl_output
pub const wl_output_interface = struct {
    // compositor output region
    geometry: ?fn (*Context, Object, i32, i32, i32, i32, i32, []u8, []u8, i32) anyerror!void,
    mode: ?fn (*Context, Object, u32, i32, i32, i32) anyerror!void,
    done: ?fn (
        *Context,
        Object,
    ) anyerror!void,
    scale: ?fn (*Context, Object, i32) anyerror!void,
};

fn wl_output_geometry_default(context: *Context, object: Object, x: i32, y: i32, physical_width: i32, physical_height: i32, subpixel: i32, make: []u8, model: []u8, transform: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_output_mode_default(context: *Context, object: Object, flags: u32, width: i32, height: i32, refresh: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_output_done_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn wl_output_scale_default(context: *Context, object: Object, factor: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var WL_OUTPUT = wl_output_interface{
    .geometry = wl_output_geometry_default,
    .mode = wl_output_mode_default,
    .done = wl_output_done_default,
    .scale = wl_output_scale_default,
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
        // geometry
        0 => {
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var physical_width: i32 = try object.context.next_i32();
            var physical_height: i32 = try object.context.next_i32();
            var subpixel: i32 = try object.context.next_i32();
            var make: []u8 = try object.context.next_string();
            var model: []u8 = try object.context.next_string();
            var transform: i32 = try object.context.next_i32();
            if (WL_OUTPUT.geometry) |geometry| {
                try geometry(object.context, object, x, y, physical_width, physical_height, subpixel, make, model, transform);
            }
        },
        // mode
        1 => {
            var flags: u32 = try object.context.next_u32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            var refresh: i32 = try object.context.next_i32();
            if (WL_OUTPUT.mode) |mode| {
                try mode(object.context, object, flags, width, height, refresh);
            }
        },
        // done
        2 => {
            if (WL_OUTPUT.done) |done| {
                try done(
                    object.context,
                    object,
                );
            }
        },
        // scale
        3 => {
            var factor: i32 = try object.context.next_i32();
            if (WL_OUTPUT.scale) |scale| {
                try scale(object.context, object, factor);
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

//
// Using this request a client can tell the server that it is not going to
// use the output object anymore.
//
pub fn wl_output_send_release(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 0);
}

// wl_region
pub const wl_region_interface = struct {
    // region interface
};

pub var WL_REGION = wl_region_interface{};

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
        else => {},
    }
}

//
// Destroy the region.  This will invalidate the object ID.
//
pub fn wl_region_send_destroy(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 0);
}

//
// Add the specified rectangle to the region.
//
pub fn wl_region_send_add(object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.finishWrite(object.id, 1);
}

//
// Subtract the specified rectangle from the region.
//
pub fn wl_region_send_subtract(object: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.putI32(width);
    object.context.putI32(height);
    object.context.finishWrite(object.id, 2);
}

// wl_subcompositor
pub const wl_subcompositor_interface = struct {
    // sub-surface compositing
};

pub var WL_SUBCOMPOSITOR = wl_subcompositor_interface{};

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
        else => {},
    }
}

pub const wl_subcompositor_error = enum(u32) {
    bad_surface = 0,
};

//
// Informs the server that the client will not be using this
// protocol object anymore. This does not affect any other
// objects, wl_subsurface objects included.
//
pub fn wl_subcompositor_send_destroy(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 0);
}

//
// Create a sub-surface interface for the given surface, and
// associate it with the given parent surface. This turns a
// plain wl_surface into a sub-surface.
//
// The to-be sub-surface must not already have another role, and it
// must not have an existing wl_subsurface object. Otherwise a protocol
// error is raised.
//
// Adding sub-surfaces to a parent is a double-buffered operation on the
// parent (see wl_surface.commit). The effect of adding a sub-surface
// becomes visible on the next time the state of the parent surface is
// applied.
//
// This request modifies the behaviour of wl_surface.commit request on
// the sub-surface, see the documentation on wl_subsurface interface.
//
pub fn wl_subcompositor_send_get_subsurface(object: Object, id: u32, surface: u32, parent: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(id);
    object.context.putU32(surface);
    object.context.putU32(parent);
    object.context.finishWrite(object.id, 1);
}

// wl_subsurface
pub const wl_subsurface_interface = struct {
    // sub-surface interface to a wl_surface
};

pub var WL_SUBSURFACE = wl_subsurface_interface{};

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
        else => {},
    }
}

pub const wl_subsurface_error = enum(u32) {
    bad_surface = 0,
};

//
// The sub-surface interface is removed from the wl_surface object
// that was turned into a sub-surface with a
// wl_subcompositor.get_subsurface request. The wl_surface's association
// to the parent is deleted, and the wl_surface loses its role as
// a sub-surface. The wl_surface is unmapped immediately.
//
pub fn wl_subsurface_send_destroy(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 0);
}

//
// This schedules a sub-surface position change.
// The sub-surface will be moved so that its origin (top left
// corner pixel) will be at the location x, y of the parent surface
// coordinate system. The coordinates are not restricted to the parent
// surface area. Negative values are allowed.
//
// The scheduled coordinates will take effect whenever the state of the
// parent surface is applied. When this happens depends on whether the
// parent surface is in synchronized mode or not. See
// wl_subsurface.set_sync and wl_subsurface.set_desync for details.
//
// If more than one set_position request is invoked by the client before
// the commit of the parent surface, the position of a new request always
// replaces the scheduled position from any previous request.
//
// The initial position is 0, 0.
//
pub fn wl_subsurface_send_set_position(object: Object, x: i32, y: i32) anyerror!void {
    object.context.startWrite();
    object.context.putI32(x);
    object.context.putI32(y);
    object.context.finishWrite(object.id, 1);
}

//
// This sub-surface is taken from the stack, and put back just
// above the reference surface, changing the z-order of the sub-surfaces.
// The reference surface must be one of the sibling surfaces, or the
// parent surface. Using any other surface, including this sub-surface,
// will cause a protocol error.
//
// The z-order is double-buffered. Requests are handled in order and
// applied immediately to a pending state. The final pending state is
// copied to the active state the next time the state of the parent
// surface is applied. When this happens depends on whether the parent
// surface is in synchronized mode or not. See wl_subsurface.set_sync and
// wl_subsurface.set_desync for details.
//
// A new sub-surface is initially added as the top-most in the stack
// of its siblings and parent.
//
pub fn wl_subsurface_send_place_above(object: Object, sibling: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(sibling);
    object.context.finishWrite(object.id, 2);
}

//
// The sub-surface is placed just below the reference surface.
// See wl_subsurface.place_above.
//
pub fn wl_subsurface_send_place_below(object: Object, sibling: u32) anyerror!void {
    object.context.startWrite();
    object.context.putU32(sibling);
    object.context.finishWrite(object.id, 3);
}

//
// Change the commit behaviour of the sub-surface to synchronized
// mode, also described as the parent dependent mode.
//
// In synchronized mode, wl_surface.commit on a sub-surface will
// accumulate the committed state in a cache, but the state will
// not be applied and hence will not change the compositor output.
// The cached state is applied to the sub-surface immediately after
// the parent surface's state is applied. This ensures atomic
// updates of the parent and all its synchronized sub-surfaces.
// Applying the cached state will invalidate the cache, so further
// parent surface commits do not (re-)apply old state.
//
// See wl_subsurface for the recursive effect of this mode.
//
pub fn wl_subsurface_send_set_sync(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 4);
}

//
// Change the commit behaviour of the sub-surface to desynchronized
// mode, also described as independent or freely running mode.
//
// In desynchronized mode, wl_surface.commit on a sub-surface will
// apply the pending state directly, without caching, as happens
// normally with a wl_surface. Calling wl_surface.commit on the
// parent surface has no effect on the sub-surface's wl_surface
// state. This mode allows a sub-surface to be updated on its own.
//
// If cached state exists when wl_surface.commit is called in
// desynchronized mode, the pending state is added to the cached
// state, and applied as a whole. This invalidates the cache.
//
// Note: even if a sub-surface is set to desynchronized, a parent
// sub-surface may override it to behave as synchronized. For details,
// see wl_subsurface.
//
// If a surface's parent surface behaves as desynchronized, then
// the cached state is applied on set_desync.
//
pub fn wl_subsurface_send_set_desync(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 5);
}

// fw_control
pub const fw_control_interface = struct {
    // protocol for querying and controlling foxwhale
    client: ?fn (*Context, Object, u32) anyerror!void,
    window: ?fn (*Context, Object, u32, i32, u32, u32, i32, i32, i32, i32, i32, i32, i32, i32, u32) anyerror!void,
    toplevel_window: ?fn (*Context, Object, u32, i32, u32, u32, i32, i32, i32, i32, u32) anyerror!void,
    region_rect: ?fn (*Context, Object, u32, i32, i32, i32, i32, i32) anyerror!void,
    done: ?fn (
        *Context,
        Object,
    ) anyerror!void,
};

fn fw_control_client_default(context: *Context, object: Object, index: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn fw_control_window_default(context: *Context, object: Object, index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, sibling_prev: i32, sibling_next: i32, children_prev: i32, children_next: i32, input_region_id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn fw_control_toplevel_window_default(context: *Context, object: Object, index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, input_region_id: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn fw_control_region_rect_default(context: *Context, object: Object, index: u32, x: i32, y: i32, width: i32, height: i32, op: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn fw_control_done_default(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub var FW_CONTROL = fw_control_interface{
    .client = fw_control_client_default,
    .window = fw_control_window_default,
    .toplevel_window = fw_control_toplevel_window_default,
    .region_rect = fw_control_region_rect_default,
    .done = fw_control_done_default,
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
        // client
        0 => {
            var index: u32 = try object.context.next_u32();
            if (FW_CONTROL.client) |client| {
                try client(object.context, object, index);
            }
        },
        // window
        1 => {
            var index: u32 = try object.context.next_u32();
            var parent: i32 = try object.context.next_i32();
            var wl_surface_id: u32 = try object.context.next_u32();
            var surface_type: u32 = try object.context.next_u32();
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            var sibling_prev: i32 = try object.context.next_i32();
            var sibling_next: i32 = try object.context.next_i32();
            var children_prev: i32 = try object.context.next_i32();
            var children_next: i32 = try object.context.next_i32();
            var input_region_id: u32 = try object.context.next_u32();
            if (FW_CONTROL.window) |window| {
                try window(object.context, object, index, parent, wl_surface_id, surface_type, x, y, width, height, sibling_prev, sibling_next, children_prev, children_next, input_region_id);
            }
        },
        // toplevel_window
        2 => {
            var index: u32 = try object.context.next_u32();
            var parent: i32 = try object.context.next_i32();
            var wl_surface_id: u32 = try object.context.next_u32();
            var surface_type: u32 = try object.context.next_u32();
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            var input_region_id: u32 = try object.context.next_u32();
            if (FW_CONTROL.toplevel_window) |toplevel_window| {
                try toplevel_window(object.context, object, index, parent, wl_surface_id, surface_type, x, y, width, height, input_region_id);
            }
        },
        // region_rect
        3 => {
            var index: u32 = try object.context.next_u32();
            var x: i32 = try object.context.next_i32();
            var y: i32 = try object.context.next_i32();
            var width: i32 = try object.context.next_i32();
            var height: i32 = try object.context.next_i32();
            var op: i32 = try object.context.next_i32();
            if (FW_CONTROL.region_rect) |region_rect| {
                try region_rect(object.context, object, index, x, y, width, height, op);
            }
        },
        // done
        4 => {
            if (FW_CONTROL.done) |done| {
                try done(
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

//
//         Gets metadata about all the clients currently connected to foxwhale.
//
pub fn fw_control_send_get_clients(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 0);
}

//
//         Gets metadata about all the windows currently connected to foxwhale.
//
pub fn fw_control_send_get_windows(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 1);
}

//
//         Gets metadata about all the windows currently connected to foxwhale.
//
pub fn fw_control_send_get_window_trees(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 2);
}

//
//         Cleans up fw_control object.
//
pub fn fw_control_send_destroy(object: Object) anyerror!void {
    object.context.startWrite();
    object.context.finishWrite(object.id, 3);
}
