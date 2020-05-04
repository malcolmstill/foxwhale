const std = @import("std");
const Context = @import("context.zig").Context;
const Object = @import("context.zig").Object;

// wl_display
pub const wl_display_interface = struct {
    // core global object
    sync: ?fn (u32) void,
    get_registry: ?fn (u32) void,
};

pub var WL_DISPLAY = wl_display_interface{
    .sync = null,
    .get_registry = null,
};

pub fn new_wl_display(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_display_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_display_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // sync
        0 => {
            var callback: u32 = context.next_u32();
            if (WL_DISPLAY.sync) |sync| {
                sync(callback);
            }
        },
        // get_registry
        1 => {
            var registry: u32 = context.next_u32();
            if (WL_DISPLAY.get_registry) |get_registry| {
                get_registry(registry);
            }
        },
        else => {},
    }
}

const wl_display_error = enum {
    invalid_object = 0,
    invalid_method = 1,
    no_memory = 2,
    implementation = 3,
};

// wl_registry
pub const wl_registry_interface = struct {
    // global registry object
    bind: ?fn (u32, u32) void,
};

pub var WL_REGISTRY = wl_registry_interface{
    .bind = null,
};

pub fn new_wl_registry(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_registry_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_registry_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // bind
        0 => {
            var name: u32 = context.next_u32();
            var id: u32 = context.next_u32();
            if (WL_REGISTRY.bind) |bind| {
                bind(name, id);
            }
        },
        else => {},
    }
}

// wl_callback
pub const wl_callback_interface = struct {
    // callback object
};

pub var WL_CALLBACK = wl_callback_interface{};

pub fn new_wl_callback(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_callback_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_callback_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        else => {},
    }
}

// wl_compositor
pub const wl_compositor_interface = struct {
    // the compositor singleton
    create_surface: ?fn (u32) void,
    create_region: ?fn (u32) void,
};

pub var WL_COMPOSITOR = wl_compositor_interface{
    .create_surface = null,
    .create_region = null,
};

pub fn new_wl_compositor(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_compositor_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_compositor_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // create_surface
        0 => {
            var id: u32 = context.next_u32();
            if (WL_COMPOSITOR.create_surface) |create_surface| {
                create_surface(id);
            }
        },
        // create_region
        1 => {
            var id: u32 = context.next_u32();
            if (WL_COMPOSITOR.create_region) |create_region| {
                create_region(id);
            }
        },
        else => {},
    }
}

// wl_shm_pool
pub const wl_shm_pool_interface = struct {
    // a shared memory pool
    create_buffer: ?fn (u32, i32, i32, i32, i32, u32) void,
    destroy: ?fn () void,
    resize: ?fn (i32) void,
};

pub var WL_SHM_POOL = wl_shm_pool_interface{
    .create_buffer = null,
    .destroy = null,
    .resize = null,
};

pub fn new_wl_shm_pool(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_shm_pool_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_shm_pool_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // create_buffer
        0 => {
            var id: u32 = context.next_u32();
            var offset: i32 = context.next_i32();
            var width: i32 = context.next_i32();
            var height: i32 = context.next_i32();
            var stride: i32 = context.next_i32();
            var format: u32 = context.next_u32();
            if (WL_SHM_POOL.create_buffer) |create_buffer| {
                create_buffer(id, offset, width, height, stride, format);
            }
        },
        // destroy
        1 => {
            if (WL_SHM_POOL.destroy) |destroy| {
                destroy();
            }
        },
        // resize
        2 => {
            var size: i32 = context.next_i32();
            if (WL_SHM_POOL.resize) |resize| {
                resize(size);
            }
        },
        else => {},
    }
}

// wl_shm
pub const wl_shm_interface = struct {
    // shared memory support
    create_pool: ?fn (u32, i32, i32) void,
};

pub var WL_SHM = wl_shm_interface{
    .create_pool = null,
};

pub fn new_wl_shm(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_shm_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_shm_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // create_pool
        0 => {
            var id: u32 = context.next_u32();
            var fd: i32 = context.next_i32();
            var size: i32 = context.next_i32();
            if (WL_SHM.create_pool) |create_pool| {
                create_pool(id, fd, size);
            }
        },
        else => {},
    }
}

const wl_shm_error = enum {
    invalid_format = 0,
    invalid_stride = 1,
    invalid_fd = 2,
};

const wl_shm_format = enum {
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

// wl_buffer
pub const wl_buffer_interface = struct {
    // content for a wl_surface
    destroy: ?fn () void,
};

pub var WL_BUFFER = wl_buffer_interface{
    .destroy = null,
};

pub fn new_wl_buffer(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_buffer_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_buffer_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // destroy
        0 => {
            if (WL_BUFFER.destroy) |destroy| {
                destroy();
            }
        },
        else => {},
    }
}

// wl_data_offer
pub const wl_data_offer_interface = struct {
    // offer to transfer data
    accept: ?fn (u32, []u8) void,
    receive: ?fn ([]u8, i32) void,
    destroy: ?fn () void,
    finish: ?fn () void,
    set_actions: ?fn (u32, u32) void,
};

pub var WL_DATA_OFFER = wl_data_offer_interface{
    .accept = null,
    .receive = null,
    .destroy = null,
    .finish = null,
    .set_actions = null,
};

pub fn new_wl_data_offer(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_data_offer_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_data_offer_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // accept
        0 => {
            var serial: u32 = context.next_u32();
            var mime_type: []u8 = context.next_string();
            if (WL_DATA_OFFER.accept) |accept| {
                accept(serial, mime_type);
            }
        },
        // receive
        1 => {
            var mime_type: []u8 = context.next_string();
            var fd: i32 = context.next_i32();
            if (WL_DATA_OFFER.receive) |receive| {
                receive(mime_type, fd);
            }
        },
        // destroy
        2 => {
            if (WL_DATA_OFFER.destroy) |destroy| {
                destroy();
            }
        },
        // finish
        3 => {
            if (WL_DATA_OFFER.finish) |finish| {
                finish();
            }
        },
        // set_actions
        4 => {
            var dnd_actions: u32 = context.next_u32();
            var preferred_action: u32 = context.next_u32();
            if (WL_DATA_OFFER.set_actions) |set_actions| {
                set_actions(dnd_actions, preferred_action);
            }
        },
        else => {},
    }
}

const wl_data_offer_error = enum {
    invalid_finish = 0,
    invalid_action_mask = 1,
    invalid_action = 2,
    invalid_offer = 3,
};

// wl_data_source
pub const wl_data_source_interface = struct {
    // offer to transfer data
    offer: ?fn ([]u8) void,
    destroy: ?fn () void,
    set_actions: ?fn (u32) void,
};

pub var WL_DATA_SOURCE = wl_data_source_interface{
    .offer = null,
    .destroy = null,
    .set_actions = null,
};

pub fn new_wl_data_source(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_data_source_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_data_source_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // offer
        0 => {
            var mime_type: []u8 = context.next_string();
            if (WL_DATA_SOURCE.offer) |offer| {
                offer(mime_type);
            }
        },
        // destroy
        1 => {
            if (WL_DATA_SOURCE.destroy) |destroy| {
                destroy();
            }
        },
        // set_actions
        2 => {
            var dnd_actions: u32 = context.next_u32();
            if (WL_DATA_SOURCE.set_actions) |set_actions| {
                set_actions(dnd_actions);
            }
        },
        else => {},
    }
}

const wl_data_source_error = enum {
    invalid_action_mask = 0,
    invalid_source = 1,
};

// wl_data_device
pub const wl_data_device_interface = struct {
    // data transfer device
    start_drag: ?fn (Object, Object, Object, u32) void,
    set_selection: ?fn (Object, u32) void,
    release: ?fn () void,
};

pub var WL_DATA_DEVICE = wl_data_device_interface{
    .start_drag = null,
    .set_selection = null,
    .release = null,
};

pub fn new_wl_data_device(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_data_device_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_data_device_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // start_drag
        0 => {
            var source: Object = new_wl_data_source(context, context.next_u32());
            var origin: Object = new_wl_surface(context, context.next_u32());
            var icon: Object = new_wl_surface(context, context.next_u32());
            var serial: u32 = context.next_u32();
            if (WL_DATA_DEVICE.start_drag) |start_drag| {
                start_drag(source, origin, icon, serial);
            }
        },
        // set_selection
        1 => {
            var source: Object = new_wl_data_source(context, context.next_u32());
            var serial: u32 = context.next_u32();
            if (WL_DATA_DEVICE.set_selection) |set_selection| {
                set_selection(source, serial);
            }
        },
        // release
        2 => {
            if (WL_DATA_DEVICE.release) |release| {
                release();
            }
        },
        else => {},
    }
}

const wl_data_device_error = enum {
    role = 0,
};

// wl_data_device_manager
pub const wl_data_device_manager_interface = struct {
    // data transfer interface
    create_data_source: ?fn (u32) void,
    get_data_device: ?fn (u32, Object) void,
};

pub var WL_DATA_DEVICE_MANAGER = wl_data_device_manager_interface{
    .create_data_source = null,
    .get_data_device = null,
};

pub fn new_wl_data_device_manager(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_data_device_manager_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_data_device_manager_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // create_data_source
        0 => {
            var id: u32 = context.next_u32();
            if (WL_DATA_DEVICE_MANAGER.create_data_source) |create_data_source| {
                create_data_source(id);
            }
        },
        // get_data_device
        1 => {
            var id: u32 = context.next_u32();
            var seat: Object = new_wl_seat(context, context.next_u32());
            if (WL_DATA_DEVICE_MANAGER.get_data_device) |get_data_device| {
                get_data_device(id, seat);
            }
        },
        else => {},
    }
}

const wl_data_device_manager_dnd_action = enum {
    none = 0,
    copy = 1,
    move = 2,
    ask = 4,
};

// wl_shell
pub const wl_shell_interface = struct {
    // create desktop-style surfaces
    get_shell_surface: ?fn (u32, Object) void,
};

pub var WL_SHELL = wl_shell_interface{
    .get_shell_surface = null,
};

pub fn new_wl_shell(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_shell_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_shell_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // get_shell_surface
        0 => {
            var id: u32 = context.next_u32();
            var surface: Object = new_wl_surface(context, context.next_u32());
            if (WL_SHELL.get_shell_surface) |get_shell_surface| {
                get_shell_surface(id, surface);
            }
        },
        else => {},
    }
}

const wl_shell_error = enum {
    role = 0,
};

// wl_shell_surface
pub const wl_shell_surface_interface = struct {
    // desktop-style metadata interface
    pong: ?fn (u32) void,
    move: ?fn (Object, u32) void,
    resize: ?fn (Object, u32, u32) void,
    set_toplevel: ?fn () void,
    set_transient: ?fn (Object, i32, i32, u32) void,
    set_fullscreen: ?fn (u32, u32, Object) void,
    set_popup: ?fn (Object, u32, Object, i32, i32, u32) void,
    set_maximized: ?fn (Object) void,
    set_title: ?fn ([]u8) void,
    set_class: ?fn ([]u8) void,
};

pub var WL_SHELL_SURFACE = wl_shell_surface_interface{
    .pong = null,
    .move = null,
    .resize = null,
    .set_toplevel = null,
    .set_transient = null,
    .set_fullscreen = null,
    .set_popup = null,
    .set_maximized = null,
    .set_title = null,
    .set_class = null,
};

pub fn new_wl_shell_surface(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_shell_surface_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_shell_surface_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // pong
        0 => {
            var serial: u32 = context.next_u32();
            if (WL_SHELL_SURFACE.pong) |pong| {
                pong(serial);
            }
        },
        // move
        1 => {
            var seat: Object = new_wl_seat(context, context.next_u32());
            var serial: u32 = context.next_u32();
            if (WL_SHELL_SURFACE.move) |move| {
                move(seat, serial);
            }
        },
        // resize
        2 => {
            var seat: Object = new_wl_seat(context, context.next_u32());
            var serial: u32 = context.next_u32();
            var edges: u32 = context.next_u32();
            if (WL_SHELL_SURFACE.resize) |resize| {
                resize(seat, serial, edges);
            }
        },
        // set_toplevel
        3 => {
            if (WL_SHELL_SURFACE.set_toplevel) |set_toplevel| {
                set_toplevel();
            }
        },
        // set_transient
        4 => {
            var parent: Object = new_wl_surface(context, context.next_u32());
            var x: i32 = context.next_i32();
            var y: i32 = context.next_i32();
            var flags: u32 = context.next_u32();
            if (WL_SHELL_SURFACE.set_transient) |set_transient| {
                set_transient(parent, x, y, flags);
            }
        },
        // set_fullscreen
        5 => {
            var method: u32 = context.next_u32();
            var framerate: u32 = context.next_u32();
            var output: Object = new_wl_output(context, context.next_u32());
            if (WL_SHELL_SURFACE.set_fullscreen) |set_fullscreen| {
                set_fullscreen(method, framerate, output);
            }
        },
        // set_popup
        6 => {
            var seat: Object = new_wl_seat(context, context.next_u32());
            var serial: u32 = context.next_u32();
            var parent: Object = new_wl_surface(context, context.next_u32());
            var x: i32 = context.next_i32();
            var y: i32 = context.next_i32();
            var flags: u32 = context.next_u32();
            if (WL_SHELL_SURFACE.set_popup) |set_popup| {
                set_popup(seat, serial, parent, x, y, flags);
            }
        },
        // set_maximized
        7 => {
            var output: Object = new_wl_output(context, context.next_u32());
            if (WL_SHELL_SURFACE.set_maximized) |set_maximized| {
                set_maximized(output);
            }
        },
        // set_title
        8 => {
            var title: []u8 = context.next_string();
            if (WL_SHELL_SURFACE.set_title) |set_title| {
                set_title(title);
            }
        },
        // set_class
        9 => {
            var class_: []u8 = context.next_string();
            if (WL_SHELL_SURFACE.set_class) |set_class| {
                set_class(class_);
            }
        },
        else => {},
    }
}

const wl_shell_surface_resize = enum {
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

const wl_shell_surface_transient = enum {
    inactive = 0x1,
};

const wl_shell_surface_fullscreen_method = enum {
    default = 0,
    scale = 1,
    driver = 2,
    fill = 3,
};

// wl_surface
pub const wl_surface_interface = struct {
    // an onscreen surface
    destroy: ?fn () void,
    attach: ?fn (Object, i32, i32) void,
    damage: ?fn (i32, i32, i32, i32) void,
    frame: ?fn (u32) void,
    set_opaque_region: ?fn (Object) void,
    set_input_region: ?fn (Object) void,
    commit: ?fn () void,
    set_buffer_transform: ?fn (i32) void,
    set_buffer_scale: ?fn (i32) void,
    damage_buffer: ?fn (i32, i32, i32, i32) void,
};

pub var WL_SURFACE = wl_surface_interface{
    .destroy = null,
    .attach = null,
    .damage = null,
    .frame = null,
    .set_opaque_region = null,
    .set_input_region = null,
    .commit = null,
    .set_buffer_transform = null,
    .set_buffer_scale = null,
    .damage_buffer = null,
};

pub fn new_wl_surface(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_surface_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_surface_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // destroy
        0 => {
            if (WL_SURFACE.destroy) |destroy| {
                destroy();
            }
        },
        // attach
        1 => {
            var buffer: Object = new_wl_buffer(context, context.next_u32());
            var x: i32 = context.next_i32();
            var y: i32 = context.next_i32();
            if (WL_SURFACE.attach) |attach| {
                attach(buffer, x, y);
            }
        },
        // damage
        2 => {
            var x: i32 = context.next_i32();
            var y: i32 = context.next_i32();
            var width: i32 = context.next_i32();
            var height: i32 = context.next_i32();
            if (WL_SURFACE.damage) |damage| {
                damage(x, y, width, height);
            }
        },
        // frame
        3 => {
            var callback: u32 = context.next_u32();
            if (WL_SURFACE.frame) |frame| {
                frame(callback);
            }
        },
        // set_opaque_region
        4 => {
            var region: Object = new_wl_region(context, context.next_u32());
            if (WL_SURFACE.set_opaque_region) |set_opaque_region| {
                set_opaque_region(region);
            }
        },
        // set_input_region
        5 => {
            var region: Object = new_wl_region(context, context.next_u32());
            if (WL_SURFACE.set_input_region) |set_input_region| {
                set_input_region(region);
            }
        },
        // commit
        6 => {
            if (WL_SURFACE.commit) |commit| {
                commit();
            }
        },
        // set_buffer_transform
        7 => {
            var transform: i32 = context.next_i32();
            if (WL_SURFACE.set_buffer_transform) |set_buffer_transform| {
                set_buffer_transform(transform);
            }
        },
        // set_buffer_scale
        8 => {
            var scale: i32 = context.next_i32();
            if (WL_SURFACE.set_buffer_scale) |set_buffer_scale| {
                set_buffer_scale(scale);
            }
        },
        // damage_buffer
        9 => {
            var x: i32 = context.next_i32();
            var y: i32 = context.next_i32();
            var width: i32 = context.next_i32();
            var height: i32 = context.next_i32();
            if (WL_SURFACE.damage_buffer) |damage_buffer| {
                damage_buffer(x, y, width, height);
            }
        },
        else => {},
    }
}

const wl_surface_error = enum {
    invalid_scale = 0,
    invalid_transform = 1,
};

// wl_seat
pub const wl_seat_interface = struct {
    // group of input devices
    get_pointer: ?fn (u32) void,
    get_keyboard: ?fn (u32) void,
    get_touch: ?fn (u32) void,
    release: ?fn () void,
};

pub var WL_SEAT = wl_seat_interface{
    .get_pointer = null,
    .get_keyboard = null,
    .get_touch = null,
    .release = null,
};

pub fn new_wl_seat(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_seat_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_seat_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // get_pointer
        0 => {
            var id: u32 = context.next_u32();
            if (WL_SEAT.get_pointer) |get_pointer| {
                get_pointer(id);
            }
        },
        // get_keyboard
        1 => {
            var id: u32 = context.next_u32();
            if (WL_SEAT.get_keyboard) |get_keyboard| {
                get_keyboard(id);
            }
        },
        // get_touch
        2 => {
            var id: u32 = context.next_u32();
            if (WL_SEAT.get_touch) |get_touch| {
                get_touch(id);
            }
        },
        // release
        3 => {
            if (WL_SEAT.release) |release| {
                release();
            }
        },
        else => {},
    }
}

const wl_seat_capability = enum {
    pointer = 1,
    keyboard = 2,
    touch = 4,
};

// wl_pointer
pub const wl_pointer_interface = struct {
    // pointer input device
    set_cursor: ?fn (u32, Object, i32, i32) void,
    release: ?fn () void,
};

pub var WL_POINTER = wl_pointer_interface{
    .set_cursor = null,
    .release = null,
};

pub fn new_wl_pointer(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_pointer_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_pointer_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // set_cursor
        0 => {
            var serial: u32 = context.next_u32();
            var surface: Object = new_wl_surface(context, context.next_u32());
            var hotspot_x: i32 = context.next_i32();
            var hotspot_y: i32 = context.next_i32();
            if (WL_POINTER.set_cursor) |set_cursor| {
                set_cursor(serial, surface, hotspot_x, hotspot_y);
            }
        },
        // release
        1 => {
            if (WL_POINTER.release) |release| {
                release();
            }
        },
        else => {},
    }
}

const wl_pointer_error = enum {
    role = 0,
};

const wl_pointer_button_state = enum {
    released = 0,
    pressed = 1,
};

const wl_pointer_axis = enum {
    vertical_scroll = 0,
    horizontal_scroll = 1,
};

const wl_pointer_axis_source = enum {
    wheel = 0,
    finger = 1,
    continuous = 2,
    wheel_tilt = 3,
};

// wl_keyboard
pub const wl_keyboard_interface = struct {
    // keyboard input device
    release: ?fn () void,
};

pub var WL_KEYBOARD = wl_keyboard_interface{
    .release = null,
};

pub fn new_wl_keyboard(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_keyboard_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_keyboard_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // release
        0 => {
            if (WL_KEYBOARD.release) |release| {
                release();
            }
        },
        else => {},
    }
}

const wl_keyboard_keymap_format = enum {
    no_keymap = 0,
    xkb_v1 = 1,
};

const wl_keyboard_key_state = enum {
    released = 0,
    pressed = 1,
};

// wl_touch
pub const wl_touch_interface = struct {
    // touchscreen input device
    release: ?fn () void,
};

pub var WL_TOUCH = wl_touch_interface{
    .release = null,
};

pub fn new_wl_touch(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_touch_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_touch_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // release
        0 => {
            if (WL_TOUCH.release) |release| {
                release();
            }
        },
        else => {},
    }
}

// wl_output
pub const wl_output_interface = struct {
    // compositor output region
    release: ?fn () void,
};

pub var WL_OUTPUT = wl_output_interface{
    .release = null,
};

pub fn new_wl_output(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_output_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_output_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // release
        0 => {
            if (WL_OUTPUT.release) |release| {
                release();
            }
        },
        else => {},
    }
}

const wl_output_subpixel = enum {
    unknown = 0,
    none = 1,
    horizontal_rgb = 2,
    horizontal_bgr = 3,
    vertical_rgb = 4,
    vertical_bgr = 5,
};

const wl_output_transform = enum {
    normal = 0,
    @"90" = 1,
    @"180" = 2,
    @"270" = 3,
    flipped = 4,
    flipped_90 = 5,
    flipped_180 = 6,
    flipped_270 = 7,
};

const wl_output_mode = enum {
    current = 0x1,
    preferred = 0x2,
};

// wl_region
pub const wl_region_interface = struct {
    // region interface
    destroy: ?fn () void,
    add: ?fn (i32, i32, i32, i32) void,
    subtract: ?fn (i32, i32, i32, i32) void,
};

pub var WL_REGION = wl_region_interface{
    .destroy = null,
    .add = null,
    .subtract = null,
};

pub fn new_wl_region(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_region_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_region_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // destroy
        0 => {
            if (WL_REGION.destroy) |destroy| {
                destroy();
            }
        },
        // add
        1 => {
            var x: i32 = context.next_i32();
            var y: i32 = context.next_i32();
            var width: i32 = context.next_i32();
            var height: i32 = context.next_i32();
            if (WL_REGION.add) |add| {
                add(x, y, width, height);
            }
        },
        // subtract
        2 => {
            var x: i32 = context.next_i32();
            var y: i32 = context.next_i32();
            var width: i32 = context.next_i32();
            var height: i32 = context.next_i32();
            if (WL_REGION.subtract) |subtract| {
                subtract(x, y, width, height);
            }
        },
        else => {},
    }
}

// wl_subcompositor
pub const wl_subcompositor_interface = struct {
    // sub-surface compositing
    destroy: ?fn () void,
    get_subsurface: ?fn (u32, Object, Object) void,
};

pub var WL_SUBCOMPOSITOR = wl_subcompositor_interface{
    .destroy = null,
    .get_subsurface = null,
};

pub fn new_wl_subcompositor(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_subcompositor_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_subcompositor_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // destroy
        0 => {
            if (WL_SUBCOMPOSITOR.destroy) |destroy| {
                destroy();
            }
        },
        // get_subsurface
        1 => {
            var id: u32 = context.next_u32();
            var surface: Object = new_wl_surface(context, context.next_u32());
            var parent: Object = new_wl_surface(context, context.next_u32());
            if (WL_SUBCOMPOSITOR.get_subsurface) |get_subsurface| {
                get_subsurface(id, surface, parent);
            }
        },
        else => {},
    }
}

const wl_subcompositor_error = enum {
    bad_surface = 0,
};

// wl_subsurface
pub const wl_subsurface_interface = struct {
    // sub-surface interface to a wl_surface
    destroy: ?fn () void,
    set_position: ?fn (i32, i32) void,
    place_above: ?fn (Object) void,
    place_below: ?fn (Object) void,
    set_sync: ?fn () void,
    set_desync: ?fn () void,
};

pub var WL_SUBSURFACE = wl_subsurface_interface{
    .destroy = null,
    .set_position = null,
    .place_above = null,
    .place_below = null,
    .set_sync = null,
    .set_desync = null,
};

pub fn new_wl_subsurface(context: *Context, id: u32) Object {
    var object = Object{
        .id = id,
        .dispatch = wl_subsurface_dispatch,
    };
    context.register(object) catch |err| {
        std.debug.warn("Couldn't register id: {}\n", .{id});
    };
    return object;
}

fn wl_subsurface_dispatch(context: *Context, opcode: u16) void {
    switch (opcode) {
        // destroy
        0 => {
            if (WL_SUBSURFACE.destroy) |destroy| {
                destroy();
            }
        },
        // set_position
        1 => {
            var x: i32 = context.next_i32();
            var y: i32 = context.next_i32();
            if (WL_SUBSURFACE.set_position) |set_position| {
                set_position(x, y);
            }
        },
        // place_above
        2 => {
            var sibling: Object = new_wl_surface(context, context.next_u32());
            if (WL_SUBSURFACE.place_above) |place_above| {
                place_above(sibling);
            }
        },
        // place_below
        3 => {
            var sibling: Object = new_wl_surface(context, context.next_u32());
            if (WL_SUBSURFACE.place_below) |place_below| {
                place_below(sibling);
            }
        },
        // set_sync
        4 => {
            if (WL_SUBSURFACE.set_sync) |set_sync| {
                set_sync();
            }
        },
        // set_desync
        5 => {
            if (WL_SUBSURFACE.set_desync) |set_desync| {
                set_desync();
            }
        },
        else => {},
    }
}

const wl_subsurface_error = enum {
    bad_surface = 0,
};
const TypeTag = enum {
    wl_display_tag,
    wl_registry_tag,
    wl_callback_tag,
    wl_compositor_tag,
    wl_shm_pool_tag,
    wl_shm_tag,
    wl_buffer_tag,
    wl_data_offer_tag,
    wl_data_source_tag,
    wl_data_device_tag,
    wl_data_device_manager_tag,
    wl_shell_tag,
    wl_shell_surface_tag,
    wl_surface_tag,
    wl_seat_tag,
    wl_pointer_tag,
    wl_keyboard_tag,
    wl_touch_tag,
    wl_output_tag,
    wl_region_tag,
    wl_subcompositor_tag,
    wl_subsurface_tag,
};
const WlResource = union(TypeTag) {
    wl_display_tag: wl_display,
    wl_registry_tag: wl_registry,
    wl_callback_tag: wl_callback,
    wl_compositor_tag: wl_compositor,
    wl_shm_pool_tag: wl_shm_pool,
    wl_shm_tag: wl_shm,
    wl_buffer_tag: wl_buffer,
    wl_data_offer_tag: wl_data_offer,
    wl_data_source_tag: wl_data_source,
    wl_data_device_tag: wl_data_device,
    wl_data_device_manager_tag: wl_data_device_manager,
    wl_shell_tag: wl_shell,
    wl_shell_surface_tag: wl_shell_surface,
    wl_surface_tag: wl_surface,
    wl_seat_tag: wl_seat,
    wl_pointer_tag: wl_pointer,
    wl_keyboard_tag: wl_keyboard,
    wl_touch_tag: wl_touch,
    wl_output_tag: wl_output,
    wl_region_tag: wl_region,
    wl_subcompositor_tag: wl_subcompositor,
    wl_subsurface_tag: wl_subsurface,
};
