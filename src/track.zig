const std = @import("std");
const types = @import("types.zig");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub const Track = struct {
    name: [64]u8,
    center_line: []types.TrackPoint,
    checkpoints: []types.Checkpoint,
    start_position: types.Vector2,
    start_angle: f32,
    lap_length: f32,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Track {
        return Track{
            .name = std.mem.zeroes([64]u8),
            .center_line = &[_]types.TrackPoint{},
            .checkpoints = &[_]types.Checkpoint{},
            .start_position = types.Vector2{ .x = 100, .y = 300 },
            .start_angle = 0,
            .lap_length = 1000,
            .allocator = allocator,
        };
    }
    
    pub fn createDefaultTrack(self: *Track) !void {
        // Create an oval track
        const center_x: f32 = 400;
        const center_y: f32 = 300;
        const radius_x: f32 = 300;
        const radius_y: f32 = 150;
        const points = 64;
        
        self.center_line = try self.allocator.alloc(types.TrackPoint, points);
        self.checkpoints = try self.allocator.alloc(types.Checkpoint, 4);
        
        // Generate oval track points
        for (0..points) |i| {
            const angle = @as(f32, @floatFromInt(i)) * 2.0 * c.PI / @as(f32, @floatFromInt(points));
            const x = center_x + radius_x * @cos(angle);
            const y = center_y + radius_y * @sin(angle);
            
            self.center_line[i] = types.TrackPoint{
                .position = types.Vector2{ .x = x, .y = y },
                .width = 80,
            };
        }
        
        // Create checkpoints
        for (0..4) |i| {
            const checkpoint_index = i * (points / 4);
            self.checkpoints[i] = types.Checkpoint{
                .position = self.center_line[checkpoint_index].position,
                .radius = 30,
                .id = @intCast(i),
            };
        }
        
        std.mem.copy(u8, &self.name, "Default Oval Track");
        self.start_position = self.center_line[0].position;
    }
    
    pub fn draw(self: *Track) void {
        // Draw track surface
        for (0..self.center_line.len) |i| {
            const current = self.center_line[i];
            const next = self.center_line[(i + 1) % self.center_line.len];
            
            // Draw track segment
            c.DrawLineEx(current.position, next.position, current.width, c.DARKGRAY);
            c.DrawLineEx(current.position, next.position, current.width - 10, c.GRAY);
        }
        
        // Draw checkpoints
        for (self.checkpoints) |checkpoint| {
            c.DrawCircleLines(
                @intFromFloat(checkpoint.position.x),
                @intFromFloat(checkpoint.position.y),
                checkpoint.radius,
                c.YELLOW
            );
        }
        
        // Draw start/finish line
        const start_perpendicular = c.Vector2Rotate(
            types.Vector2{ .x = 0, .y = 40 },
            self.start_angle
        );
        const line_start = c.Vector2Add(self.start_position, start_perpendicular);
        const line_end = c.Vector2Subtract(self.start_position, start_perpendicular);
        
        c.DrawLineEx(line_start, line_end, 5, c.WHITE);
    }
    
    pub fn getClosestPoint(self: *Track, position: types.Vector2) ?types.TrackPoint {
        if (self.center_line.len == 0) return null;
        
        var closest_distance: f32 = std.math.floatMax(f32);
        var closest_point: types.TrackPoint = self.center_line[0];
        
        for (self.center_line) |point| {
            const distance = c.Vector2Distance(position, point.position);
            if (distance < closest_distance) {
                closest_distance = distance;
                closest_point = point;
            }
        }
        
        return closest_point;
    }
    
    pub fn deinit(self: *Track) void {
        if (self.center_line.len > 0) {
            self.allocator.free(self.center_line);
        }
        if (self.checkpoints.len > 0) {
            self.allocator.free(self.checkpoints);
        }
    }
};
