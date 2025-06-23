const std = @import("std");

pub fn Vector2(x: f32, y: f32) struct { x: f32, y: f32 } {
    return .{ .x = x, .y = y };
}

pub fn add(v1: Vector2, v2: Vector2) Vector2 {
    return Vector2(v1.x + v2.x, v1.y + v2.y);
}

pub fn subtract(v1: Vector2, v2: Vector2) Vector2 {
    return Vector2(v1.x - v2.x, v1.y - v2.y);
}

pub fn multiply(v: Vector2, scalar: f32) Vector2 {
    return Vector2(v.x * scalar, v.y * scalar);
}

pub fn dot(v1: Vector2, v2: Vector2) f32 {
    return v1.x * v2.x + v1.y * v2.y;
}

pub fn length(v: Vector2) f32 {
    return std.math.sqrt(dot(v, v));
}

pub fn normalize(v: Vector2) Vector2 {
    const len = length(v);
    if (len == 0) {
        return Vector2(0, 0);
    }
    return multiply(v, 1.0 / len);
}

pub fn distance(v1: Vector2, v2: Vector2) f32 {
    return length(subtract(v1, v2));
}

pub fn collideCircleCircle(pos1: Vector2, radius1: f32, pos2: Vector2, radius2: f32) bool {
    const dist = distance(pos1, pos2);
    return dist <= (radius1 + radius2);
}

pub fn clamp(value: f32, min_val: f32, max_val: f32) f32 {
    return @max(min_val, @min(max_val, value));
}

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn distanceXY(x1: f32, y1: f32, x2: f32, y2: f32) f32 {
    const dx = x2 - x1;
    const dy = y2 - y1;
    return @sqrt(dx * dx + dy * dy);
}

pub fn normalizeAngle(angle: f32) f32 {
    var result = angle;
    while (result > std.math.pi) result -= 2 * std.math.pi;
    while (result < -std.math.pi) result += 2 * std.math.pi;
    return result;
}
