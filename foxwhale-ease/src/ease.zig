const std = @import("std");
const math = std.math;

pub fn InOutSine(x: f64) f64 {
    return -(math.cos(math.pi * x) - 1.0) / 2.0;
}

pub fn OutExpo(x: f64) f64 {
    return if (x == 1.0) 1.0 else 1.0 - math.pow(f64, 2, -10.0 * x);
}
