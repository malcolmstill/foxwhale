const std = @import("std");
const mem = std.mem;
const Mat4x4 = @import("math.zig").Mat4x4;
const StringHashMap = std.hash_map.StringHashMap;
// const vertex_shader_source = ;
const fragment_shader_source = @embedFile("shaders/fragment.glsl");
const windows = @import("window.zig");
const Window = @import("window.zig").Window;
const CompositorOutput = @import("output.zig").CompositorOutput;
const main = @import("main.zig");
const c = @cImport({
    @cInclude("GLES3/gl3.h");
    @cInclude("EGL/egl.h");
    @cInclude("GLES2/gl2ext.h");
});
const egl = @import("backend/drm/egl.zig");

pub const Renderer = struct {
    shaders: StringHashMap(c_uint),

    pub fn init(allocator: *mem.Allocator) Renderer {
        return Renderer{
            .shaders = StringHashMap(c_uint).init(allocator),
        };
    }

    pub fn initShaders(self: *Renderer) !void {
        try self.shaders.put("window", try createProgram(
            @embedFile("shaders/window/vertex.glsl"),
            @embedFile("shaders/window/fragment.glsl"),
        ));

        try self.shaders.put("checker", try createProgram(
            @embedFile("shaders/checker/vertex.glsl"),
            @embedFile("shaders/checker/fragment.glsl"),
        ));
    }

    pub fn deinit(self: *Renderer) void {
        var it = self.shaders.iterator();
        while (it.next()) |kv| {
            c.glDeleteProgram(kv.value_ptr.*);
        }
    }

    pub fn useProgram(self: *Renderer, name: []const u8) !c_uint {
        const program = self.shaders.get(name) orelse return error.NoSuchProgram;

        c.glUseProgram(program);
        try checkGLError();

        return program;
    }

    pub fn clear(self: *Renderer) !void {
        c.glClearColor(0.3, 0.3, 0.36, 0.0);
        try checkGLError();

        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        try checkGLError();
    }

    pub fn render(self: *Renderer, output: *CompositorOutput) !void {
        var width = output.getWidth();
        var height = output.getHeight();

        c.glEnable(c.GL_BLEND);
        try checkGLError();

        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
        try checkGLError();
    }

    pub fn renderBackground(self: *Renderer, output_width: i32, output_height: i32) !void {
        const program = try self.useProgram("checker");
        try Renderer.setUniformFloat(program, "size", 30.0);

        const rectangle = setGeometry(output_width, output_height);

        const ortho = orthographicProjection(
            0.0,
            @intToFloat(f32, output_width),
            @intToFloat(f32, output_height),
            0.0,
            -1.0,
            1.0,
        );

        try setUniformMatrix(program, "ortho", ortho.data);

        var vbo: u32 = undefined;

        c.glGenBuffers(1, &vbo);
        try checkGLError();

        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        try checkGLError();

        c.glBufferData(c.GL_ARRAY_BUFFER, 4 * rectangle.len, &rectangle[0], c.GL_STATIC_DRAW);
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

        c.glDrawArrays(c.GL_TRIANGLES, 0, rectangle.len / 4);
        try checkGLError();

        c.glDeleteVertexArrays(1, &vao);
        try checkGLError();

        c.glDeleteBuffers(1, &vbo);
        try checkGLError();
    }

    pub fn renderSurface(self: *Renderer, output_width: i32, output_height: i32, program: c_uint, texture: u32, width: i32, height: i32) !void {
        const rectangle = setGeometry(width, height);

        const ortho = orthographicProjection(
            0.0,
            @intToFloat(f32, output_width),
            @intToFloat(f32, output_height),
            0.0,
            -1.0,
            1.0,
        );

        try setUniformMatrix(program, "ortho", ortho.data);

        var vbo: u32 = undefined;

        c.glGenBuffers(1, &vbo);
        try checkGLError();

        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        try checkGLError();

        c.glBufferData(c.GL_ARRAY_BUFFER, 4 * rectangle.len, &rectangle[0], c.GL_STATIC_DRAW);
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

        c.glDrawArrays(c.GL_TRIANGLES, 0, rectangle.len / 4);
        try checkGLError();

        c.glDeleteVertexArrays(1, &vao);
        try checkGLError();

        c.glDeleteBuffers(1, &vbo);
        try checkGLError();
    }

    pub fn setUniformMatrix(program: c_uint, location_string: []const u8, matrix: [4][4]f32) !void {
        var location = c.glGetUniformLocation(program, location_string.ptr);
        try checkGLError();
        if (location == -1) {
            return error.UniformNotFound;
        }

        c.glUniformMatrix4fv(location, 1, c.GL_TRUE, &matrix[0]);
        try checkGLError();
    }

    pub fn setUniformFloat(program: c_uint, location_string: []const u8, value: f32) !void {
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

    pub fn makeTexture(width: i32, height: i32, stride: i32, format: u32, data: []const u8) !u32 {
        if (stride * height > data.len) {
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

    pub fn makeDmaTexture(image: *c_void, width: i32, height: i32, format: u32) !u32 {
        switch (main.OUTPUT.backend) {
            .DRM => |drm| {
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

                if (egl.glEGLImageTargetTexture2DOES) |glEGLImageTargetTexture2DOES| {
                    glEGLImageTargetTexture2DOES(c.GL_TEXTURE_2D, image);
                } else {
                    return error.EGLImageTargetTexture2DOESNotAvailable;
                }
                try checkGLError();

                return texture;
            },
            else => {
                return error.AttemptedToMakeDmaTextureWithNoEGLContext;
            },
        }
    }

    pub fn releaseTexture(texture: u32) !void {
        c.glDeleteTextures(1, &texture);
        try checkGLError();
    }
};

fn createProgram(vertex_source: []const u8, fragment_source: []const u8) !c_uint {
    var vertex_shader = try compileShader(vertex_source, c.GL_VERTEX_SHADER);
    var fragment_shader = try compileShader(fragment_source, c.GL_FRAGMENT_SHADER);

    var program = c.glCreateProgram();
    try checkGLError();

    c.glAttachShader(program, vertex_shader);
    try checkGLError();

    c.glAttachShader(program, fragment_shader);
    try checkGLError();

    c.glLinkProgram(program);
    try checkGLError();

    c.glDeleteShader(vertex_shader);
    try checkGLError();

    c.glDeleteShader(fragment_shader);
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

        std.debug.warn("log: {s}\n", .{log[0..std.math.min(log.len, @intCast(usize, log_length))]});

        return error.FailedToCompileShader;
    }

    return shader;
}

// TODO: This looks column-major, but transpose is set to true?
fn orthographicProjection(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4x4(f32) {
    var r = Mat4x4(f32).zeroes();

    r.data[0][0] = 2.0 / (right - left);
    r.data[0][1] = 0.0;
    r.data[0][2] = 0.0;
    r.data[0][3] = -((right + left) / (right - left));
    r.data[1][0] = 0.0;
    r.data[1][1] = 2.0 / (top - bottom);
    r.data[1][2] = 0.0;
    r.data[1][3] = -((top + bottom) / (top - bottom));
    r.data[2][0] = 0.0;
    r.data[2][1] = 0.0;
    r.data[2][2] = -2.0 / (far - near);
    r.data[2][3] = -((far + near) / (far - near));
    r.data[3][0] = 0.0;
    r.data[3][1] = 0.0;
    r.data[3][2] = 0.0;
    r.data[3][3] = 1.0;

    return r;
}

pub fn setGeometry(width: i32, height: i32) [28]f32 {
    var rectangle: [28]f32 = mem.zeroes([28]f32);

    rectangle[0] = 0.0;
    rectangle[1] = 0.0;
    rectangle[2] = 0.0;
    rectangle[3] = 0.0;

    rectangle[4] = @intToFloat(f32, width);
    rectangle[5] = 0.0;
    rectangle[6] = 1.0;
    rectangle[7] = 0.0;

    rectangle[8] = 0.0;
    rectangle[9] = @intToFloat(f32, height);
    rectangle[10] = 0.0;
    rectangle[11] = 1.0;

    rectangle[12] = 0.0;
    rectangle[13] = @intToFloat(f32, height);
    rectangle[14] = 0.0;
    rectangle[15] = 1.0;

    rectangle[16] = @intToFloat(f32, width);
    rectangle[17] = 0.0;
    rectangle[18] = 1.0;
    rectangle[19] = 0.0;

    rectangle[20] = @intToFloat(f32, width);
    rectangle[21] = @intToFloat(f32, height);
    rectangle[22] = 1.0;
    rectangle[23] = 1.0;

    return rectangle;
}

fn checkGLError() !void {
    var err = c.glGetError();
    if (err != c.GL_NO_ERROR) {
        std.debug.warn("error: {}\n", .{err});
        return error.GL_ERROR;
    }
}
