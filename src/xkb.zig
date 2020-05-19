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
        var xdg_runtime_dir = std.os.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;

        var filename: [128]u8 = [_]u8{0} ** 128;
        var random = "/XXXXXX";
        std.mem.copy(u8, filename[0..filename.len], xdg_runtime_dir);
        if (xdg_runtime_dir.len >= filename.len-1) {
            return error.FilenameBufferTooSmall;
        }
        std.mem.copy(u8, filename[xdg_runtime_dir.len..], random);

        if (self.keymap) |keymap| {
            var keymap_as_string = c.xkb_keymap_get_as_string(keymap, c.enum_xkb_keymap_format.XKB_KEYMAP_FORMAT_TEXT_V1);
            if (keymap_as_string) |string| {
                defer c.free(string);
                var size = std.mem.len(string) + 1;
                var keymap_string: []u8 = undefined;
                keymap_string.ptr = string;
                keymap_string.len = size;

                var fd: i32 = c.mkstemp(&filename[0]); // O_CLOEXEC?
                try std.os.ftruncate(fd, size);
                var data = try std.os.mmap(null, @intCast(usize, size), std.os.linux.PROT_READ|std.os.linux.PROT_WRITE, std.os.linux.MAP_SHARED, fd, 0);

                std.mem.copy(u8, data, keymap_string);

                std.os.munmap(data);

                return FdSize {
                    .fd = fd,
                    .size = size,
                };
            }
            return error.FailedToGetKeymapAsString;
        }

        return error.NoKeymap;
    }

    pub fn serializeDepressed(self: *Self) u32 {
        return c.xkb_state_serialize_mods(self.state, c.enum_xkb_state_component.XKB_STATE_MODS_DEPRESSED);
    }

    pub fn serializeLatched(self: *Self) u32 {
        return c.xkb_state_serialize_mods(self.state, c.enum_xkb_state_component.XKB_STATE_MODS_LATCHED);
    }

    pub fn serializeLocked(self: *Self) u32 {
        return c.xkb_state_serialize_mods(self.state, c.enum_xkb_state_component.XKB_STATE_MODS_LOCKED);
    }

    pub fn serializeGroup(self: *Self) u32 {
        return c.xkb_state_serialize_mods(self.state, c.enum_xkb_state_component.XKB_STATE_LAYOUT_EFFECTIVE);
    }
};

pub fn init() !Xkb {
    var flags = c.enum_xkb_context_flags.XKB_CONTEXT_NO_FLAGS;
    var context = try newContext(flags);
    var keymap = try newKeymapFromNames(context, "evdev\x00", "apple\x00", "gb\x00", "\x00", "\x00");
    var state = try newState(keymap);

    return Xkb {
        .context = context,
        .keymap = keymap,
        .state = state,
    };
}

fn newContext(flags: c.enum_xkb_context_flags) !*c.xkb_context {
    return c.xkb_context_new(flags) orelse error.XkbContextCreationFailed;
}

fn newKeymapFromNames(context: *c.xkb_context, rules: []const u8, model: []const u8, layout: []const u8, variant: []const u8, options: []const u8) !*c.xkb_keymap {
    var names = c.xkb_rule_names {
        .rules = &rules[0],
        .model = &model[0],
        .layout = &layout[0],
        .variant = &variant[0],
        .options = &options[0],
    };

    var flags = c.enum_xkb_keymap_compile_flags.XKB_KEYMAP_COMPILE_NO_FLAGS;

    return c.xkb_keymap_new_from_names(context, &names, flags) orelse error.XkbKeymapCreationFailed;
}

fn newState(keymap: *c.xkb_keymap) !*c.xkb_state {
    return c.xkb_state_new(keymap) orelse error.XkbStateCreationFailed;
}