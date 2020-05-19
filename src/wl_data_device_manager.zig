const std = @import("std");
const prot = @import("protocols.zig");
const Client = @import("client.zig").Client;
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;

fn create_data_source(context: *Context, object: Object, id: u32) anyerror!void {

}

fn get_data_device(context: *Context, object: Object, id: u32, seat: Object) anyerror!void {

}

pub fn init() void {    
    prot.WL_DATA_DEVICE_MANAGER = prot.wl_data_device_manager_interface{
        .create_data_source = create_data_source,
        .get_data_device = get_data_device,
    };
}