const std = @import("std");
const vertex_shader = @embedFile("shaders/vertex.glsl");
const fragment_shader = @embedFile("shaders/fragment.glsl");

pub fn render() void {
    // std.debug.warn("vertex: {}\n", .{vertex_shader});
}