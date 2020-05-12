const std = @import("std");
const vertex_shader_source = @embedFile("shaders/vertex.glsl");
const fragment_shader_source = @embedFile("shaders/fragment.glsl");
const windows = @import("window.zig");
const Window = @import("window.zig").Window;
const Output = @import("output.zig").Output;
const c = @cImport({
    @cInclude("GLES3/gl3.h");
});

var ortho: [16]f32 = undefined;
var rectangle: [28]f32 = undefined;
var PROGRAM: c_uint = undefined;

pub fn render(output: *Output) !void {
    var width = output.getWidth();
    var height = output.getHeight();

    c.glClearColor(0.3, 0.3, 0.36, 0.0);
    try checkGLError();

    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
    try checkGLError();

    c.glUseProgram(PROGRAM);
    try checkGLError();

    c.glEnable(c.GL_BLEND);
    try checkGLError();

    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    try checkGLError();

    orthographicProjection(&ortho, 0.0, @intToFloat(f32, width), 0.0, @intToFloat(f32, height), -1.0, 1.0);

    // std.debug.warn("ortho: {}, {}, {}, {}\n", .{ortho[0], ortho[1], ortho[2], ortho[3]});

    try setUniformMatrix(PROGRAM, "ortho", ortho);
    try setUniformMatrix(PROGRAM, "scale", identity);
    try setUniformMatrix(PROGRAM, "translate", identity);
    try setUniformMatrix(PROGRAM, "origin", identity);
    try setUniformMatrix(PROGRAM, "originInverse", identity);
    try setUniformFloat(PROGRAM, "opacity", 1.0);

    for (windows.WINDOWS) |window| {
        if (!window.in_use) {
            continue;
        }

        if (window.texture) |texture| {
            setGeometry(window);
            try renderSurface(PROGRAM, texture);
        }
    }
}

fn renderSurface(program: c_uint, texture: u32) !void {
    var vbo: u32 = undefined;

    c.glGenBuffers(1, &vbo);
    try checkGLError();

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    try checkGLError();

    c.glBufferData(c.GL_ARRAY_BUFFER, 4*28, &rectangle[0], c.GL_STATIC_DRAW);
    try checkGLError();

    var vao: u32 = undefined;
    c.glGenVertexArrays(1, &vao);
    try checkGLError();

    c.glBindVertexArray(vao);
    try checkGLError();

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    try checkGLError();

    try setVertexAttrib(program, "position", 0);
    try setVertexAttrib(program, "texcoord", 8);

    c.glEnable(c.GL_BLEND);
    try checkGLError();

    c.glBindVertexArray(vao);
    try checkGLError();

    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    try checkGLError();

    c.glDrawArrays(c.GL_TRIANGLES, 0, 28/4);
    try checkGLError();

    c.glDeleteVertexArrays(1, &vao);
    try checkGLError();

    c.glDeleteBuffers(1, &vbo);
    try checkGLError();
}

pub fn init() !void {
    PROGRAM = try initShaders();
}

fn initShaders() !c_uint{
    var vertex_shader = try compileShader(vertex_shader_source, c.GL_VERTEX_SHADER);
    var fragment_shader = try compileShader(fragment_shader_source, c.GL_FRAGMENT_SHADER);

    var program = c.glCreateProgram();
    try checkGLError();

    c.glAttachShader(program, vertex_shader);
    try checkGLError();

    c.glAttachShader(program, fragment_shader);
    try checkGLError();

    c.glLinkProgram(program);
    try checkGLError();

    return program;
}

fn compileShader(source: []const u8, shader_type: c_uint) !c_uint {
    var log: [256]u8 = undefined;
    var shader = c.glCreateShader(shader_type);
    try checkGLError();
    c.glShaderSource(shader, 1, &source.ptr, null);
    try checkGLError();
    c.glCompileShader(shader);
    try checkGLError();

    var status: i32 = c.GL_TRUE;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &status);
    if (status == c.GL_FALSE) {
        var log_length: c_int = 0;
        c.glGetShaderiv(shader, c.GL_INFO_LOG_LENGTH, &log_length);
        try checkGLError();
        c.glGetShaderInfoLog(shader, log_length, null, log[0..]);
        try checkGLError();

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

fn setGeometry(window: Window) void {
    rectangle[0] = 0.0;
    rectangle[1] = 0.0;
    rectangle[2] = 0.0;
    rectangle[3] = 0.0;

    rectangle[4] = @intToFloat(f32, window.width);
    rectangle[5] = 0.0;
    rectangle[6] = 1.0;
    rectangle[7] = 0.0;

    rectangle[8] = 0.0;
    rectangle[9] = @intToFloat(f32, window.height);
    rectangle[10] = 0.0;
    rectangle[11] = 1.0;

    rectangle[12] = 0.0;
    rectangle[13] = @intToFloat(f32, window.height);
    rectangle[14] = 0.0;
    rectangle[15] = 1.0;

    rectangle[16] = @intToFloat(f32, window.width);
    rectangle[17] = 0.0;
    rectangle[18] = 1.0;
    rectangle[19] = 0.0;

    rectangle[20] = @intToFloat(f32, window.width);
    rectangle[21] = @intToFloat(f32, window.height);
    rectangle[22] = 1.0;
    rectangle[23] = 1.0;
}

var identity: [16]f32 = [_]f32{
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0,
};

fn setUniformMatrix(program: c_uint, location_string: []const u8, matrix: [16]f32) !void {
    var location = c.glGetUniformLocation(program, location_string.ptr);
    try checkGLError();
    if (location == -1) {
        return error.UniformNotFound;
    }
    c.glUniformMatrix4fv(location, 1, c.GL_TRUE, &matrix[0]);
    try checkGLError();
}

fn setUniformFloat(program: c_uint, location_string: []const u8, value: f32) !void {
    var location = c.glGetUniformLocation(program, location_string.ptr);
    try checkGLError();
    if (location == -1) {
        return error.UniformNotFound;
    }
    c.glUniform1f(location, value);
    try checkGLError();
}

fn setVertexAttrib(program: c_uint, attribute_string: []const u8, offset: c_uint) !void {
    var attribute = c.glGetAttribLocation(program, attribute_string.ptr);
    try checkGLError();
    if (attribute == -1) {
        return error.AttributeNotFound;
    }
    c.glEnableVertexAttribArray(@intCast(c_uint, attribute));
    try checkGLError();
    c.glVertexAttribPointer(@intCast(c_uint, attribute), 2, c.GL_FLOAT, c.GL_FALSE, 16, @intToPtr(*allowzero c_uint, offset));
    try checkGLError();
}

pub fn makeTexture(width: i32, height: i32, stride: i32, format: u32, data: []u8) !u32 {
    if (stride*height > data.len) {
        return error.NotEnoughTextureDataForDimensions;
    }

    var texture: u32 = undefined;
    var err: c_uint = undefined;

    c.glGenTextures(1, &texture);
    try checkGLError();

    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    try checkGLError();

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    try checkGLError();

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    try checkGLError();

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    try checkGLError();

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    try checkGLError();

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, width, height, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, data.ptr);
    try checkGLError();

    return texture;
}

pub fn releaseTexture(texture: u32) !void {
    c.glDeleteTextures(1, &texture);
    try checkGLError();
}

fn checkGLError() !void {
    var err = c.glGetError();
    if(err != c.GL_NO_ERROR) {
        std.debug.warn("error: {}\n", .{err});
        return error.GL_ERROR;
    }
}