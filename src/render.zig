const std = @import("std");
const vertex_shader_source = @embedFile("shaders/vertex.glsl");
const fragment_shader_source = @embedFile("shaders/fragment.glsl");
const c = @cImport({
    @cInclude("GLES2/gl2.h");
});

var ortho: [16]f32 = undefined;

pub fn render() void {
    c.glClearColor(0.0, 0.6, 0.0, 0.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
    c.glUseProgram(PROGRAM);

    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    orthographicProjection(&ortho, 0.0, 1600.0, 0.0, 1200.0, -1.0, 1.0);
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

fn orthographicProjection(m: *[16]f32, left: f32, right: f32, top: f32, bottom: f32, near: f32, far: f32) void {
    m[0] = 2.0/(right-left);  m[1] = 0.0;               m[2] = 0.0;              m[3] = -((right + left)/(right-left));
    m[4] = 0.0;               m[5] = 2.0/(top-bottom);  m[6] = 0.0;              m[7] = -((top + bottom)/(top-bottom));
    m[8] = 0.0;               m[9] = 0.0;               m[10] = -2.0/(far-near); m[11] = -((far + near)/(far-near));
    m[12] = 0.0;              m[13] = 0.0;              m[14] = 0.0;             m[15] = 1.0;
}