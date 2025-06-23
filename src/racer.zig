const std = @import("std");
const types = @import("types.zig");
const track_mod = @import("track.zig");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub const Racer = struct {
    state: types.RacerState,
    max_speed: f32,
    acceleration: f32,
    brake_force: f32,
    turn_speed: f32,
    friction: f32,
    size: f32,
    
    // AI specific
    target_point_index: usize,
    ai_speed_modifier: f32,
    
    pub fn init(id: u32, racer_type: types.RacerType, position: types.Vector2) Racer {
        const colors = [_]types.Color{ c.RED, c.BLUE, c.GREEN, c.ORANGE, c.PURPLE, c.PINK };
        
        return Racer{
            .state = types.RacerState{
                .id = id,
                .position = position,
                .velocity = types.Vector2{ .x = 0, .y = 0 },
                .angle = 0,
                .speed = 0,
                .lap = 0,
                .checkpoint = 0,
                .racer_type = racer_type,
                .color = colors[id % colors.len],
                .name = std.mem.zeroes([32]u8),
            },
            .max_speed = switch (racer_type) {
                .player => 200,
                .cpu => 180 + @as(f32, @floatFromInt(id)) * 10,
                .remote_player => 200,
            },
            .acceleration = 300,
            .brake_force = 400,
            .turn_speed = 3.0,
            .friction = 0.95,
            .size = 12,
            .target_point_index = 0,
            .ai_speed_modifier = 0.8 + (@as(f32, @floatFromInt(id)) * 0.1),
        };
    }
    
    pub fn updatePlayer(self: *Racer, dt: f32) void {
        var acceleration: f32 = 0;
        var turning: f32 = 0;
        
        // Input handling
        if (c.IsKeyDown(c.KEY_UP) or c.IsKeyDown(c.KEY_W)) {
            acceleration = self.acceleration;
        }
        if (c.IsKeyDown(c.KEY_DOWN) or c.IsKeyDown(c.KEY_S)) {
            acceleration = -self.brake_force;
        }
        if (c.IsKeyDown(c.KEY_LEFT) or c.IsKeyDown(c.KEY_A)) {
            turning = -self.turn_speed;
        }
        if (c.IsKeyDown(c.KEY_RIGHT) or c.IsKeyDown(c.KEY_D)) {
            turning = self.turn_speed;
        }
        
        self.updatePhysics(acceleration, turning, dt);
    }
    
    pub fn updateCPU(self: *Racer, track: *track_mod.Track, dt: f32) void {
        if (track.center_line.len == 0) return;
        
        // Simple AI: follow track center line
        const target_point = track.center_line[self.target_point_index];
        const direction = c.Vector2Subtract(target_point.position, self.state.position);
        const distance = c.Vector2Length(direction);
        
        // Check if we're close enough to move to next target
        if (distance < 50) {
            self.target_point_index = (self.target_point_index + 1) % track.center_line.len;
        }
        
        // Calculate desired angle
        const target_angle = std.math.atan2(direction.y, direction.x);
        var angle_diff = target_angle - self.state.angle;
        
        // Normalize angle difference
        while (angle_diff > c.PI) angle_diff -= 2 * c.PI;
        while (angle_diff < -c.PI) angle_diff += 2 * c.PI;
        
        // Determine acceleration and turning
        var acceleration = self.acceleration * self.ai_speed_modifier;
        var turning: f32 = 0;
        
        if (@abs(angle_diff) > 0.1) {
            turning = if (angle_diff > 0) self.turn_speed else -self.turn_speed;
            acceleration *= 0.7; // Slow down when turning
        }
        
        self.updatePhysics(acceleration, turning, dt);
    }
    
    fn updatePhysics(self: *Racer, acceleration: f32, turning: f32, dt: f32) void {
        // Apply turning
        if (self.state.speed > 10) { // Only turn when moving
            self.state.angle += turning * dt * (self.state.speed / self.max_speed);
        }
        
        // Apply acceleration
        self.state.speed += acceleration * dt;
        self.state.speed = std.math.clamp(self.state.speed, -self.max_speed * 0.5, self.max_speed);
        
        // Apply friction
        self.state.speed *= self.friction;
        
        // Update velocity based on angle and speed
        self.state.velocity = types.Vector2{
            .x = @cos(self.state.angle) * self.state.speed,
            .y = @sin(self.state.angle) * self.state.speed,
        };
        
        // Update position
        self.state.position = c.Vector2Add(
            self.state.position,
            c.Vector2Scale(self.state.velocity, dt)
        );
    }
    
    pub fn checkCheckpoints(self: *Racer, track: *track_mod.Track) void {
        for (track.checkpoints) |checkpoint| {
            if (checkpoint.id == self.state.checkpoint) {
                const distance = c.Vector2Distance(self.state.position, checkpoint.position);
                if (distance < checkpoint.radius) {
                    self.state.checkpoint += 1;
                    
                    // Check for lap completion
                    if (self.state.checkpoint >= track.checkpoints.len) {
                        self.state.checkpoint = 0;
                        self.state.lap += 1;
                    }
                    break;
                }
            }
        }
    }
    
    pub fn draw(self: *Racer) void {
        // Calculate racer corners for realistic car shape
        const half_width = self.size * 0.6;
        const half_length = self.size;
        
        const corners = [4]types.Vector2{
            types.Vector2{ .x = half_length, .y = -half_width },
            types.Vector2{ .x = half_length, .y = half_width },
            types.Vector2{ .x = -half_length, .y = half_width },
            types.Vector2{ .x = -half_length, .y = -half_width },
        };
        
        // Rotate and translate corners
        var world_corners: [4]types.Vector2 = undefined;
        for (corners, 0..) |corner, i| {
            const rotated = c.Vector2Rotate(corner, self.state.angle);
            world_corners[i] = c.Vector2Add(self.state.position, rotated);
        }
        
        // Draw car body
        c.DrawTriangle(world_corners[0], world_corners[1], world_corners[2], self.state.color);
        c.DrawTriangle(world_corners[0], world_corners[2], world_corners[3], self.state.color);
        
        // Draw car outline
        for (0..4) |i| {
            const next_i = (i + 1) % 4;
            c.DrawLineEx(world_corners[i], world_corners[next_i], 2, c.BLACK);
        }
        
        // Draw direction indicator
        const front_point = c.Vector2Add(
            self.state.position,
            c.Vector2Scale(types.Vector2{ .x = @cos(self.state.angle), .y = @sin(self.state.angle) }, self.size + 5)
        );
        c.DrawLineEx(self.state.position, front_point, 3, c.WHITE);
        
        // Draw racer info
        const info_text = std.fmt.allocPrint(
            std.heap.page_allocator,
            "L:{d} CP:{d}",
            .{ self.state.lap, self.state.checkpoint }
        ) catch return;
        defer std.heap.page_allocator.free(info_text);
        
        c.DrawText(
            info_text.ptr,
            @intFromFloat(self.state.position.x - 20),
            @intFromFloat(self.state.position.y - 30),
            10,
            c.WHITE
        );
    }
};
