const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub const Player = struct {
    position: c.Vector2,
    velocity: c.Vector2,
    angle: f32,
    speed: f32,
    max_speed: f32,
    acceleration: f32,
    brake_force: f32,
    turn_speed: f32,
    friction: f32,
    size: f32,
    color: c.Color,
    lap: u32,
    checkpoint: u32,

    // Visual effects
    engine_heat: f32,
    tire_smoke: [4]c.Vector2,
    last_positions: [10]c.Vector2,
    position_index: usize,

    pub fn init() Player {
        return Player{
            .position = c.Vector2{ .x = 100, .y = 300 },
            .velocity = c.Vector2{ .x = 0, .y = 0 },
            .angle = 0,
            .speed = 0,
            .max_speed = 250,
            .acceleration = 400,
            .brake_force = 500,
            .turn_speed = 3.5,
            .friction = 0.96,
            .size = 15,
            .color = c.RED,
            .lap = 0,
            .checkpoint = 0,
            .engine_heat = 0,
            .tire_smoke = [_]c.Vector2{c.Vector2{ .x = 0, .y = 0 }} ** 4,
            .last_positions = [_]c.Vector2{c.Vector2{ .x = 0, .y = 0 }} ** 10,
            .position_index = 0,
        };
    }

    pub fn update(self: *Player) void {
        const dt = c.GetFrameTime();

        var acceleration_input: f32 = 0;
        var turning: f32 = 0;
        var braking = false;

        // Input handling
        if (c.IsKeyDown(c.KEY_UP) or c.IsKeyDown(c.KEY_W)) {
            acceleration_input = self.acceleration;
            self.engine_heat = @min(self.engine_heat + dt * 2, 1.0);
        } else {
            self.engine_heat = @max(self.engine_heat - dt, 0);
        }

        if (c.IsKeyDown(c.KEY_DOWN) or c.IsKeyDown(c.KEY_S)) {
            acceleration_input = -self.brake_force;
            braking = true;
        }
        if (c.IsKeyDown(c.KEY_LEFT) or c.IsKeyDown(c.KEY_A)) {
            turning = -self.turn_speed;
        }
        if (c.IsKeyDown(c.KEY_RIGHT) or c.IsKeyDown(c.KEY_D)) {
            turning = self.turn_speed;
        }

        // Store position history for trail effect
        self.last_positions[self.position_index] = self.position;
        self.position_index = (self.position_index + 1) % self.last_positions.len;

        // Apply turning with speed-based sensitivity
        if (self.speed > 10) {
            const turn_factor = (self.speed / self.max_speed) * 0.8 + 0.2;
            self.angle += turning * dt * turn_factor;
        }

        // Apply acceleration
        self.speed += acceleration_input * dt;
        self.speed = std.math.clamp(self.speed, -self.max_speed * 0.6, self.max_speed);

        // Apply friction
        self.speed *= if (braking) 0.92 else self.friction;

        // Update velocity with some drift physics
        const desired_velocity = c.Vector2{
            .x = @cos(self.angle) * self.speed,
            .y = @sin(self.angle) * self.speed,
        };

        // Smooth velocity change for more realistic physics
        self.velocity = c.Vector2Lerp(self.velocity, desired_velocity, 0.8);

        // Update position
        self.position.x += self.velocity.x * dt;
        self.position.y += self.velocity.y * dt;
    }

    pub fn updateWithBoundaryCheck(self: *Player, track: *const @import("race_track.zig").RaceTrack) void {
        self.update();

        // Check boundary collision and correct position
        const corrected_pos = track.checkBoundaryCollision(self.position, self.size);

        // If position was corrected, reduce speed (collision impact)
        if (c.Vector2Distance(self.position, corrected_pos) > 0.1) {
            self.position = corrected_pos;
            self.speed *= 0.3; // Reduce speed on collision

            // Add collision visual feedback
            self.engine_heat = @min(self.engine_heat + 0.5, 1.0);
        }
    }

    pub fn draw(self: *Player) void {
        // Draw speed trail
        self.drawSpeedTrail();

        // Draw car body with enhanced visuals
        self.drawCarBody();

        // Draw engine effects
        if (self.engine_heat > 0.3) {
            self.drawEngineEffects();
        }
    }

    fn drawSpeedTrail(self: *Player) void {
        if (self.speed < 50) return;

        for (0..self.last_positions.len - 1) |i| {
            const alpha = @as(u8, @intFromFloat(50 * (@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(self.last_positions.len)))));
            const trail_color = c.Color{ .r = self.color.r, .g = self.color.g, .b = self.color.b, .a = alpha };

            const current_idx = (self.position_index + i) % self.last_positions.len;
            const next_idx = (self.position_index + i + 1) % self.last_positions.len;

            c.DrawLineEx(self.last_positions[current_idx], self.last_positions[next_idx], 3, trail_color);
        }
    }

    fn drawCarBody(self: *Player) void {
        // Calculate car dimensions
        const car_length = self.size * 1.2;
        const car_width = self.size * 0.8;

        // Car body corners
        const corners = [4]c.Vector2{
            c.Vector2{ .x = car_length * 0.5, .y = -car_width * 0.5 },
            c.Vector2{ .x = car_length * 0.5, .y = car_width * 0.5 },
            c.Vector2{ .x = -car_length * 0.5, .y = car_width * 0.5 },
            c.Vector2{ .x = -car_length * 0.5, .y = -car_width * 0.5 },
        };

        // Rotate and translate corners
        var world_corners: [4]c.Vector2 = undefined;
        for (corners, 0..) |corner, i| {
            const rotated = c.Vector2Rotate(corner, self.angle);
            world_corners[i] = c.Vector2Add(self.position, rotated);
        }

        // Draw car shadow
        for (0..4) |i| {
            world_corners[i].x += 2;
            world_corners[i].y += 2;
        }
        c.DrawTriangle(world_corners[0], world_corners[1], world_corners[2], c.Color{ .r = 0, .g = 0, .b = 0, .a = 100 });
        c.DrawTriangle(world_corners[0], world_corners[2], world_corners[3], c.Color{ .r = 0, .g = 0, .b = 0, .a = 100 });

        // Reset corners for actual car
        for (corners, 0..) |corner, i| {
            const rotated = c.Vector2Rotate(corner, self.angle);
            world_corners[i] = c.Vector2Add(self.position, rotated);
        }

        // Draw car body
        c.DrawTriangle(world_corners[0], world_corners[1], world_corners[2], self.color);
        c.DrawTriangle(world_corners[0], world_corners[2], world_corners[3], self.color);

        // Draw car details
        // Windshield
        const windshield_corners = [4]c.Vector2{
            c.Vector2{ .x = car_length * 0.3, .y = -car_width * 0.3 },
            c.Vector2{ .x = car_length * 0.3, .y = car_width * 0.3 },
            c.Vector2{ .x = car_length * 0.1, .y = car_width * 0.3 },
            c.Vector2{ .x = car_length * 0.1, .y = -car_width * 0.3 },
        };

        var windshield_world: [4]c.Vector2 = undefined;
        for (windshield_corners, 0..) |corner, i| {
            const rotated = c.Vector2Rotate(corner, self.angle);
            windshield_world[i] = c.Vector2Add(self.position, rotated);
        }

        c.DrawTriangle(windshield_world[0], windshield_world[1], windshield_world[2], c.Color{ .r = 100, .g = 150, .b = 255, .a = 180 });
        c.DrawTriangle(windshield_world[0], windshield_world[2], windshield_world[3], c.Color{ .r = 100, .g = 150, .b = 255, .a = 180 });

        // Car outline
        for (0..4) |i| {
            const next_i = (i + 1) % 4;
            c.DrawLineEx(world_corners[i], world_corners[next_i], 2.5, c.BLACK);
        }

        // Headlights
        const front_center = c.Vector2Add(self.position, c.Vector2Rotate(c.Vector2{ .x = car_length * 0.5, .y = 0 }, self.angle));
        const headlight_offset = c.Vector2Rotate(c.Vector2{ .x = 0, .y = car_width * 0.3 }, self.angle);

        c.DrawCircleV(c.Vector2Add(front_center, headlight_offset), 2, c.YELLOW);
        c.DrawCircleV(c.Vector2Subtract(front_center, headlight_offset), 2, c.YELLOW);
    }

    fn drawEngineEffects(self: *Player) void {
        // Draw exhaust smoke
        const exhaust_pos = c.Vector2Add(self.position, c.Vector2Rotate(c.Vector2{ .x = -self.size * 0.6, .y = 0 }, self.angle));

        var prng = std.Random.DefaultPrng.init(@as(u64, @intFromFloat(c.GetTime() * 1000)));
        const random = prng.random();

        for (0..3) |_| {
            const offset_x = random.float(f32) * 10.0 - 5.0; // Range: -5 to 5
            const offset_y = random.float(f32) * 10.0 - 5.0; // Range: -5 to 5
            const smoke_pos = c.Vector2{ .x = exhaust_pos.x + offset_x, .y = exhaust_pos.y + offset_y };

            const alpha = @as(u8, @intFromFloat(self.engine_heat * 100));
            c.DrawCircleV(smoke_pos, 3, c.Color{ .r = 100, .g = 100, .b = 100, .a = alpha });
        }
    }

    pub fn reset(self: *Player) void {
        self.position = c.Vector2{ .x = 100, .y = 300 };
        self.velocity = c.Vector2{ .x = 0, .y = 0 };
        self.speed = 0;
        self.angle = 0;
        self.lap = 0;
        self.checkpoint = 0;
    }
};
