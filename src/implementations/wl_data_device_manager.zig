const std = @import("std");
const prot = @import("../protocols.zig");
const Client = @import("../client.zig").Client;
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;

fn create_data_source(context: *Context, wl_data_device_manager: Object, new_id: u32) anyerror!void {
    var wl_data_source = prot.new_wl_data_source(new_id, context, 0);
    try context.register(wl_data_source);
}

fn get_data_device(context: *Context, wl_data_device_manager: Object, new_id: u32, seat: Object) anyerror!void {
    var wl_data_device = prot.new_wl_data_device(new_id, context, 0);
    try context.register(wl_data_device);
}

pub fn init() void {    
    prot.WL_DATA_DEVICE_MANAGER = prot.wl_data_device_manager_interface{
        .create_data_source = create_data_source,
        .get_data_device = get_data_device,
    };
}