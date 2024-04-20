const std = @import("std");
const c = @cImport({
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("stdlib.h");
});

pub const Xkb = struct {
    context: *c.xkb_context,
    keymap: ?*c.xkb_keymap,
    state: ?*c.xkb_state,

    const Self = @This();

    pub const FdSize = struct {
        fd: i32,
        size: usize,
    };

    pub fn getKeymap(self: *Self) !FdSize {
        const xdg_runtime_dir = std.posix.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;

        var filename: [128]u8 = [_]u8{0} ** 128;
        const random = "/XXXXXX";
        std.mem.copyForwards(u8, filename[0..filename.len], xdg_runtime_dir);
        if (xdg_runtime_dir.len >= filename.len - 1) {
            return error.FilenameBufferTooSmall;
        }
        std.mem.copyForwards(u8, filename[xdg_runtime_dir.len..], random);

        if (self.keymap) |keymap| {
            const keymap_as_string = c.xkb_keymap_get_as_string(keymap, c.XKB_KEYMAP_FORMAT_TEXT_V1);
            if (keymap_as_string) |string| {
                defer c.free(string);
                const size = std.mem.len(string) + 1;
                var keymap_string: []u8 = undefined;
                keymap_string.ptr = string;
                keymap_string.len = size;

                const fd: i32 = c.mkstemp(&filename[0]); // O_CLOEXEC?
                try std.posix.ftruncate(fd, size);
                const data = try std.posix.mmap(null, @intCast(size), std.os.linux.PROT.READ | std.os.linux.PROT.WRITE, std.os.linux.MAP{ .TYPE = .SHARED }, fd, 0);

                std.mem.copyForwards(u8, data, keymap_string);

                std.posix.munmap(data);

                return FdSize{
                    .fd = fd,
                    .size = size,
                };
            }
            return error.FailedToGetKeymapAsString;
        }

        return error.NoKeymap;
    }

    pub fn updateKey(self: *Self, keycode: u32, state: u32) void {
        const direction = if (state == 1) c.XKB_KEY_DOWN else c.XKB_KEY_UP;
        _ = c.xkb_state_update_key(self.state, keycode + 8, @intCast(direction));
    }

    pub fn serializeDepressed(self: *Self) u32 {
        return c.xkb_state_serialize_mods(self.state, c.XKB_STATE_MODS_DEPRESSED);
    }

    pub fn serializeLatched(self: *Self) u32 {
        return c.xkb_state_serialize_mods(self.state, c.XKB_STATE_MODS_LATCHED);
    }

    pub fn serializeLocked(self: *Self) u32 {
        return c.xkb_state_serialize_mods(self.state, c.XKB_STATE_MODS_LOCKED);
    }

    pub fn serializeGroup(self: *Self) u32 {
        return c.xkb_state_serialize_mods(self.state, c.XKB_STATE_LAYOUT_EFFECTIVE);
    }
};

pub fn init() !Xkb {
    const flags = c.XKB_CONTEXT_NO_FLAGS;
    const context = try newContext(@intCast(flags));
    const keymap = try newKeymapFromNames(context, "evdev\x00", "apple\x00", "gb\x00", "\x00", "\x00");
    const state = try newState(keymap);

    return Xkb{
        .context = context,
        .keymap = keymap,
        .state = state,
    };
}

fn newContext(flags: c.enum_xkb_context_flags) !*c.xkb_context {
    return c.xkb_context_new(flags) orelse error.XkbContextCreationFailed;
}

fn newKeymapFromNames(context: *c.xkb_context, rules: []const u8, model: []const u8, layout: []const u8, variant: []const u8, options: []const u8) !*c.xkb_keymap {
    var names = c.xkb_rule_names{
        .rules = &rules[0],
        .model = &model[0],
        .layout = &layout[0],
        .variant = &variant[0],
        .options = &options[0],
    };

    const flags = c.XKB_KEYMAP_COMPILE_NO_FLAGS;

    return c.xkb_keymap_new_from_names(context, &names, @intCast(flags)) orelse error.XkbKeymapCreationFailed;
}

fn newState(keymap: *c.xkb_keymap) !*c.xkb_state {
    return c.xkb_state_new(keymap) orelse error.XkbStateCreationFailed;
}
