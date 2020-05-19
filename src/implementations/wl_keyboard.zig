fn release(context: *Context, object: Object) anyerror!void {

}

pub fn init() {
    prot.WL_KEYBOARD = prot.wl_keyboard_interface{
        .release = release,
    };
}