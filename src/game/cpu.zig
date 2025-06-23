const std = @import("std");
const Player = @import("player.zig").Player;
const RaceTrack = @import("race_track.zig").RaceTrack;
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub const CPU = struct {
    player: Player,
    target_point_index: usize,
    ai_speed_modifier: f32,
    difficulty: f32,

    pub fn init() CPU {
        return CPU{
            .player = Player.init(),
            .target_point_index = 0,
            .ai_speed_modifier = 0.8,
            .difficulty = 1.0,
        };
    }

    pub fn update(self: *CPU, track: *RaceTrack) void {
        if (track.center_line.len == 0) return;

        const dt = c.GetFrameTime();

        // Simple AI: follow track center line
        const target_point = track.center_line[self.target_point_index];
        const direction = c.Vector2Subtract(target_point.position, self.player.position);
        const distance = c.Vector2Length(direction);

        // Check if we're close enough to move to next target
        if (distance < 50) {
            self.target_point_index = (self.target_point_index + 1) % track.center_line.len;
        }

        // Calculate desired angle
        const target_angle = std.math.atan2(direction.y, direction.x);
        var angle_diff = target_angle - self.player.angle;

        // Normalize angle difference
        while (angle_diff > std.math.pi) angle_diff -= 2 * std.math.pi;
        while (angle_diff < -std.math.pi) angle_diff += 2 * std.math.pi;

        // Apply turning
        if (@abs(angle_diff) > 0.1) {
            const turn_direction: f32 = if (angle_diff > 0) 1 else -1;
            self.player.angle += turn_direction * self.player.turn_speed * dt * self.difficulty;
        }

        // Apply acceleration
        const acceleration_input = self.player.acceleration * self.ai_speed_modifier * self.difficulty;
        self.player.speed += acceleration_input * dt;
        self.player.speed = std.math.clamp(self.player.speed, 0, self.player.max_speed);

        // Apply friction
        self.player.speed *= self.player.friction;

        // Update velocity and position
        self.player.velocity.x = @cos(self.player.angle) * self.player.speed;
        self.player.velocity.y = @sin(self.player.angle) * self.player.speed;

        self.player.position.x += self.player.velocity.x * dt;
        self.player.position.y += self.player.velocity.y * dt;

        // Check boundary collision and correct position
        const corrected_pos = track.checkBoundaryCollision(self.player.position, self.player.size);
        if (c.Vector2Distance(self.player.position, corrected_pos) > 0.1) {
            self.player.position = corrected_pos;
            self.player.speed *= 0.5; // AI slows down more on collision
        }
    }

    pub fn draw(self: *CPU) void {
        self.player.draw();
    }

    pub fn reset(self: *CPU) void {
        self.player.reset();
        self.target_point_index = 0;
    }
};
