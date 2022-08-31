const std = @import("std");
const mem = std.mem;

pub fn Mat(comptime R: usize, comptime C: usize, comptime T: type) type {
    if (R != C) @compileError("Only square matrices currently supported");

    return struct {
        data: [R][C]T,

        const Self = @This();

        pub fn zeroes() Self {
            return Self{
                .data = mem.zeroes([R][C]T),
            };
        }

        pub fn identity() Self {
            var r = Self.zeroes();

            var i: usize = 0;
            while (i < R) : (i += 1) {
                r.data[i][i] = 1.0;
            }

            return r;
        }

        pub fn scale(scales: [R]T) Self {
            var r = Self.zeroes();

            var i: usize = 0;
            while (i < R) : (i += 1) {
                r.data[i][i] = scales[i];
            }

            return r;
        }

        pub fn translate(translations: [R]T) Self {
            var r = Self.identity();

            var i: usize = 0;
            while (i < R) : (i += 1) {
                r.data[i][C - 1] = translations[i];
            }

            return r;
        }

        pub fn mul(x: Self, y: Self) Self {
            var r = Self.zeroes();

            var i: usize = 0;
            while (i < R) : (i += 1) {
                var j: usize = 0;
                while (j < C) : (j += 1) {
                    var k: usize = 0;
                    while (k < C) : (k += 1) {
                        r.data[i][j] += x.data[i][k] * y.data[k][j];
                    }
                }
            }

            return r;
        }

        pub fn transpose(x: Self) [R * C]T {
            var m: [R * C]T = mem.zeroes([R * C]T);

            var i: usize = 0;
            while (i < R) : (i += 1) {
                var j: usize = 0;
                while (j < C) : (j += 1) {
                    m[R * i + j] = x.data[j][i];
                }
            }

            return m;
        }

        pub fn print(x: Self) void {
            var i: usize = 0;
            while (i < R) : (i += 1) {
                std.debug.print("| ", .{});
                var j: usize = 0;
                while (j < C) : (j += 1) {
                    std.debug.print("{any} ", .{x.data[i][j]});
                }
                std.debug.print("|\n", .{});
            }
        }
    };
}

pub fn Mat2x2(comptime T: type) type {
    return Mat(2, 2, T);
}

pub fn Mat3x3(comptime T: type) type {
    return Mat(3, 3, T);
}

pub fn Mat4x4(comptime T: type) type {
    return Mat(4, 4, T);
}

const testing = std.testing;

test "Comptime matrix" {
    const x = Mat2x2(f32).identity();

    try testing.expectEqual(x.data[0][0], 1.0);
    try testing.expectEqual(x.data[0][1], 0.0);
    try testing.expectEqual(x.data[1][0], 0.0);
    try testing.expectEqual(x.data[1][1], 1.0);

    // const y = Mat(4, 4, f32).identity();
    const y = Mat2x2(f32).identity();

    _ = x.mul(y);

    try testing.expectEqual(x.data[0][0], 1.0);
    try testing.expectEqual(x.data[0][1], 0.0);
    try testing.expectEqual(x.data[1][0], 0.0);
    try testing.expectEqual(x.data[1][1], 1.0);

    const w = Mat2x2(f32).scale([_]f32{ 2.0, 3.0 });
    try testing.expectEqual(w.data[0][0], 2.0);
    try testing.expectEqual(w.data[0][1], 0.0);
    try testing.expectEqual(w.data[1][0], 0.0);
    try testing.expectEqual(w.data[1][1], 3.0);

    const n = w.mul(x);
    n.print();
    try testing.expectEqual(n.data[0][0], 2.0);
    try testing.expectEqual(n.data[0][1], 0.0);
    try testing.expectEqual(n.data[1][0], 0.0);
    try testing.expectEqual(n.data[1][1], 3.0);
}
