const std = @import("std");
const vertex_shader_source = @embedFile("shaders/vertex.glsl");
const fragment_shader_source = @embedFile("shaders/fragment.glsl");
const c = @cImport({
    @cInclude("GLES2/gl2.h");
});

pub fn render() void {
    // std.debug.warn("vertex: {}\n", .{vertex_shader});
}

var PROGRAM: c_uint = undefined;

pub fn init() !void {
    PROGRAM = try initShaders();
}

fn initShaders() !c_uint{
    var vertex_shader = try compileShader(vertex_shader_source, c.GL_VERTEX_SHADER);
    var fragment_shader = try compileShader(fragment_shader_source, c.GL_FRAGMENT_SHADER);

    var program = c.glCreateProgram();
    c.glAttachShader(program, vertex_shader);
    c.glAttachShader(program, fragment_shader);

    return program;
}

fn compileShader(source: []const u8, shader_type: c_uint) !c_uint {
    var log: [256]u8 = undefined;
    var shader = c.glCreateShader(shader_type);
    c.glShaderSource(shader, 1, &source.ptr, null);
    c.glCompileShader(shader);

    var status: i32 = c.GL_TRUE;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &status);
    if (status == c.GL_FALSE) {
        var log_length: c_int = 0;
        c.glGetShaderiv(shader, c.GL_INFO_LOG_LENGTH, &log_length);
        c.glGetShaderInfoLog(shader, log_length, null, log[0..]);

        std.debug.warn("log: {}\n", .{log[0..std.math.min(log.len, @intCast(usize, log_length))]});

        return error.FailedToCompileShader;
    }

    return shader;
}