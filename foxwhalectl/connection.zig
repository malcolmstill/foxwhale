const std = @import("std");
const epoll = @import("epoll");
const Dispatchable = @import("epoll").Dispatchable;
const WlContext = @import("wl").Context;

pub const Connection = struct {
    dispatchable: Dispatchable,
    context: WlContext(*Connection),

    pub fn init() Connection {
        return Connection {
            .dispatchable = epoll.Dispatchable {
                .impl = dispatch,
            },
            .context = context,
        };
    }    
};

pub const Context = WlContext(*Connection);
pub const Object = WlContext(*Connection).Object;

pub fn dispatch(dispatchable: *epoll.Dispatchable, event_type: usize) anyerror!void {
    if (event_type & std.os.linux.EPOLLHUP > 0) {
        std.os.exit(1);
    }

    var connection = @fieldParentPtr(Connection, "dispatchable", dispatchable);
    try connection.context.dispatch();
}