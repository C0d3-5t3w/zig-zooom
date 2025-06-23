const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub const TrackPoint = struct {
    position: c.Vector2,
    width: f32,
    banking: f32,
    inner_bound: c.Vector2,
    outer_bound: c.Vector2,
};

pub const Checkpoint = struct {
    position: c.Vector2,
    radius: f32,
    id: u32,
    passed: bool,
};

pub const StadiumSeat = struct {
    position: c.Vector2,
    color: c.Color,
    occupied: bool,
};

pub const RaceTrack = struct {
    allocator: std.mem.Allocator,
    center_line: []TrackPoint,
    checkpoints: []Checkpoint,
    start_position: c.Vector2,
    start_angle: f32,
    track_texture_id: u32,

    // Stadium elements
    stadium_seats: []StadiumSeat,
    crowd_animation_time: f32,

    pub fn init(allocator: std.mem.Allocator) RaceTrack {
        return RaceTrack{
            .allocator = allocator,
            .center_line = &[_]TrackPoint{},
            .checkpoints = &[_]Checkpoint{},
            .start_position = c.Vector2{ .x = 100, .y = 300 },
            .start_angle = 0,
            .track_texture_id = 0,
            .stadium_seats = &[_]StadiumSeat{},
            .crowd_animation_time = 0,
        };
    }

    pub fn createDefaultTrack(self: *RaceTrack) !void {
        // Create a more complex track shape
        const center_x: f32 = 400;
        const center_y: f32 = 300;
        const radius_x: f32 = 280;
        const radius_y: f32 = 140;
        const points = 80;

        self.center_line = try self.allocator.alloc(TrackPoint, points);
        self.checkpoints = try self.allocator.alloc(Checkpoint, 6);

        // Generate oval track points with variations and boundaries
        for (0..points) |i| {
            const angle = @as(f32, @floatFromInt(i)) * 2.0 * std.math.pi / @as(f32, @floatFromInt(points));

            // Add some variation to make the track more interesting
            const variation = @sin(angle * 3) * 20;
            const x = center_x + (radius_x + variation) * @cos(angle);
            const y = center_y + (radius_y + variation * 0.3) * @sin(angle);

            // Calculate banking based on track curvature
            const banking = @sin(angle * 2) * 0.2;

            // Calculate track width
            const track_width = 90 + @sin(angle) * 10;

            // Calculate boundary points
            const next_angle = @as(f32, @floatFromInt((i + 1) % points)) * 2.0 * std.math.pi / @as(f32, @floatFromInt(points));
            const next_x = center_x + (radius_x + @sin(next_angle * 3) * 20) * @cos(next_angle);
            const next_y = center_y + (radius_y + @sin(next_angle * 3) * 20 * 0.3) * @sin(next_angle);

            const direction = c.Vector2Normalize(c.Vector2{ .x = next_x - x, .y = next_y - y });
            const perpendicular = c.Vector2{ .x = -direction.y, .y = direction.x };

            const half_width = track_width * 0.5;
            const inner_bound = c.Vector2Add(c.Vector2{ .x = x, .y = y }, c.Vector2Scale(perpendicular, -half_width));
            const outer_bound = c.Vector2Add(c.Vector2{ .x = x, .y = y }, c.Vector2Scale(perpendicular, half_width));

            self.center_line[i] = TrackPoint{
                .position = c.Vector2{ .x = x, .y = y },
                .width = track_width,
                .banking = banking,
                .inner_bound = inner_bound,
                .outer_bound = outer_bound,
            };
        }

        // Create checkpoints
        for (0..6) |i| {
            const checkpoint_index = i * (points / 6);
            self.checkpoints[i] = Checkpoint{
                .position = self.center_line[checkpoint_index].position,
                .radius = 35,
                .id = @intCast(i),
                .passed = false,
            };
        }

        // Create stadium seating
        try self.createStadiumSeating();

        self.start_position = self.center_line[0].position;
    }

    fn createStadiumSeating(self: *RaceTrack) !void {
        const seats_per_section = 200;
        const total_seats = seats_per_section * 8; // 8 sections around the track

        self.stadium_seats = try self.allocator.alloc(StadiumSeat, total_seats);

        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();

        var seat_index: usize = 0;

        // Create seating in multiple tiers around the track
        for (0..8) |section| {
            const section_angle = @as(f32, @floatFromInt(section)) * std.math.pi / 4.0;

            for (0..seats_per_section) |seat| {
                if (seat_index >= total_seats) break;

                const tier = seat / 40; // 40 seats per tier
                const seat_in_tier = seat % 40;

                const radius = 400 + @as(f32, @floatFromInt(tier)) * 15; // Distance from track center
                const angle_offset = (@as(f32, @floatFromInt(seat_in_tier)) - 20) * 0.02; // Spread seats
                const final_angle = section_angle + angle_offset;

                const x = 400 + radius * @cos(final_angle);
                const y = 300 + radius * 0.7 * @sin(final_angle); // Slightly oval stadium

                // Random colors for crowd diversity
                const crowd_colors = [_]c.Color{
                    c.Color{ .r = 255, .g = 100, .b = 100, .a = 255 }, // Red shirts
                    c.Color{ .r = 100, .g = 100, .b = 255, .a = 255 }, // Blue shirts
                    c.Color{ .r = 100, .g = 255, .b = 100, .a = 255 }, // Green shirts
                    c.Color{ .r = 255, .g = 255, .b = 100, .a = 255 }, // Yellow shirts
                    c.Color{ .r = 200, .g = 200, .b = 200, .a = 255 }, // Gray shirts
                    c.Color{ .r = 255, .g = 150, .b = 0, .a = 255 }, // Orange shirts
                };

                self.stadium_seats[seat_index] = StadiumSeat{
                    .position = c.Vector2{ .x = x, .y = y },
                    .color = crowd_colors[random.intRangeAtMost(usize, 0, crowd_colors.len - 1)],
                    .occupied = random.float(f32) > 0.15, // 85% occupancy rate
                };

                seat_index += 1;
            }
        }
    }

    pub fn draw(self: *RaceTrack) void {
        // Update crowd animation
        self.crowd_animation_time += c.GetFrameTime();

        // Draw stadium structure
        self.drawStadium();

        // Draw crowd
        self.drawCrowd();

        // Draw grass background around track
        self.drawBackground();

        // Draw track surface with enhanced visuals
        self.drawTrackSurface();

        // Draw track borders
        self.drawTrackBorders();

        // Draw start/finish line
        self.drawStartFinishLine();

        // Draw checkpoints
        self.drawCheckpoints();
    }

    fn drawStadium(self: *RaceTrack) void {
        _ = self;

        // Draw stadium structure
        const stadium_center = c.Vector2{ .x = 400, .y = 300 };
        const stadium_radius = 500;

        // Draw stadium walls
        for (0..32) |i| {
            const angle1 = @as(f32, @floatFromInt(i)) * 2.0 * std.math.pi / 32.0;
            const angle2 = @as(f32, @floatFromInt(i + 1)) * 2.0 * std.math.pi / 32.0;

            const p1 = c.Vector2{
                .x = stadium_center.x + stadium_radius * @cos(angle1),
                .y = stadium_center.y + stadium_radius * 0.7 * @sin(angle1),
            };
            const p2 = c.Vector2{
                .x = stadium_center.x + stadium_radius * @cos(angle2),
                .y = stadium_center.y + stadium_radius * 0.7 * @sin(angle2),
            };

            // Stadium wall
            c.DrawLineEx(p1, p2, 8, c.Color{ .r = 180, .g = 180, .b = 180, .a = 255 });

            // Stadium roof structure
            const roof_p1 = c.Vector2{ .x = p1.x, .y = p1.y - 30 };
            const roof_p2 = c.Vector2{ .x = p2.x, .y = p2.y - 30 };
            c.DrawLineEx(roof_p1, roof_p2, 4, c.Color{ .r = 100, .g = 100, .b = 100, .a = 255 });
        }

        // Draw support pillars
        for (0..16) |i| {
            const angle = @as(f32, @floatFromInt(i)) * 2.0 * std.math.pi / 16.0;
            const pillar_pos = c.Vector2{
                .x = stadium_center.x + stadium_radius * @cos(angle),
                .y = stadium_center.y + stadium_radius * 0.7 * @sin(angle),
            };
            const pillar_top = c.Vector2{ .x = pillar_pos.x, .y = pillar_pos.y - 40 };

            c.DrawLineEx(pillar_pos, pillar_top, 6, c.Color{ .r = 150, .g = 150, .b = 150, .a = 255 });
        }
    }

    fn drawCrowd(self: *RaceTrack) void {
        // Draw crowd with animation
        for (self.stadium_seats, 0..) |seat, i| {
            if (!seat.occupied) continue;

            // Add some crowd animation (waving, cheering)
            const wave_offset = @sin(self.crowd_animation_time * 2 + @as(f32, @floatFromInt(i)) * 0.1) * 2;
            const cheer_scale = 1.0 + @sin(self.crowd_animation_time * 3 + @as(f32, @floatFromInt(i)) * 0.05) * 0.2;

            const animated_pos = c.Vector2{
                .x = seat.position.x,
                .y = seat.position.y + wave_offset,
            };

            // Draw person as small circle with some variation
            const person_size = 2 * cheer_scale;
            c.DrawCircleV(animated_pos, person_size, seat.color);

            // Occasionally draw raised hands (cheering)
            if (@mod(i, 10) == 0 and @sin(self.crowd_animation_time + @as(f32, @floatFromInt(i))) > 0.7) {
                c.DrawCircleV(c.Vector2{ .x = animated_pos.x - 1, .y = animated_pos.y - 2 }, 0.5, seat.color);
                c.DrawCircleV(c.Vector2{ .x = animated_pos.x + 1, .y = animated_pos.y - 2 }, 0.5, seat.color);
            }
        }
    }

    fn drawBackground(self: *RaceTrack) void {
        _ = self;
        // Draw a large grass area
        c.DrawRectangle(-200, -200, 1200, 800, c.Color{ .r = 34, .g = 139, .b = 34, .a = 255 });

        // Add some texture with random grass patches
        var prng = std.Random.DefaultPrng.init(12345);
        const random = prng.random();

        for (0..50) |_| {
            const x = random.intRangeAtMost(i32, -200, 1000);
            const y = random.intRangeAtMost(i32, -200, 600);
            const shade = random.intRangeAtMost(u8, 20, 40);
            c.DrawCircle(x, y, 8, c.Color{ .r = shade, .g = 120 + shade, .b = shade, .a = 100 });
        }
    }

    fn drawTrackSurface(self: *RaceTrack) void {
        // Draw track surface with multiple layers for depth
        for (0..self.center_line.len) |i| {
            const current = self.center_line[i];
            const next = self.center_line[(i + 1) % self.center_line.len];

            // Base track surface (asphalt)
            c.DrawLineEx(current.position, next.position, current.width, c.Color{ .r = 50, .g = 50, .b = 50, .a = 255 });

            // Track surface detail
            c.DrawLineEx(current.position, next.position, current.width - 5, c.Color{ .r = 60, .g = 60, .b = 60, .a = 255 });

            // Center line
            c.DrawLineEx(current.position, next.position, 3, c.Color{ .r = 255, .g = 255, .b = 255, .a = 180 });
        }
    }

    fn drawTrackBorders(self: *RaceTrack) void {
        // Draw track borders with barriers
        for (0..self.center_line.len) |i| {
            const current = self.center_line[i];
            const next = self.center_line[(i + 1) % self.center_line.len];

            // Calculate perpendicular vector for border offset
            const direction = c.Vector2Normalize(c.Vector2Subtract(next.position, current.position));
            const perpendicular = c.Vector2{ .x = -direction.y, .y = direction.x };

            const half_width = current.width * 0.5;
            const border_width = 8.0;

            // Outer borders
            const outer_left = c.Vector2Add(current.position, c.Vector2Scale(perpendicular, half_width + border_width));
            const outer_right = c.Vector2Add(current.position, c.Vector2Scale(perpendicular, -(half_width + border_width)));

            const next_outer_left = c.Vector2Add(next.position, c.Vector2Scale(perpendicular, half_width + border_width));
            const next_outer_right = c.Vector2Add(next.position, c.Vector2Scale(perpendicular, -(half_width + border_width)));

            // Draw barriers
            c.DrawLineEx(outer_left, next_outer_left, border_width, c.Color{ .r = 200, .g = 50, .b = 50, .a = 255 });
            c.DrawLineEx(outer_right, next_outer_right, border_width, c.Color{ .r = 200, .g = 50, .b = 50, .a = 255 });
        }
    }

    fn drawStartFinishLine(self: *RaceTrack) void {
        if (self.center_line.len == 0) return;

        const start_point = self.center_line[0];
        const next_point = self.center_line[1];

        // Calculate perpendicular for finish line
        const direction = c.Vector2Normalize(c.Vector2Subtract(next_point.position, start_point.position));
        const perpendicular = c.Vector2{ .x = -direction.y, .y = direction.x };

        const half_width = start_point.width * 0.5;
        const line_start = c.Vector2Add(start_point.position, c.Vector2Scale(perpendicular, half_width - 10));
        const line_end = c.Vector2Add(start_point.position, c.Vector2Scale(perpendicular, -(half_width - 10)));

        // Draw checkered pattern
        const segments = 8;

        for (0..segments) |i| {
            const t1 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments));
            const t2 = @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(segments));

            const p1 = c.Vector2Lerp(line_start, line_end, t1);
            const p2 = c.Vector2Lerp(line_start, line_end, t2);

            const color = if (i % 2 == 0) c.WHITE else c.BLACK;
            c.DrawLineEx(p1, p2, 8, color);
        }
    }

    fn drawCheckpoints(self: *RaceTrack) void {
        for (self.checkpoints, 0..) |checkpoint, i| {
            // Animate checkpoint colors
            const time = c.GetTime();
            const alpha = @as(u8, @intFromFloat(128 + 60 * @sin(time * 2 + @as(f32, @floatFromInt(i)))));

            const color = if (checkpoint.passed)
                c.Color{ .r = 0, .g = 255, .b = 0, .a = alpha }
            else
                c.Color{ .r = 255, .g = 255, .b = 0, .a = alpha };

            // Draw checkpoint ring
            c.DrawCircleLines(@as(i32, @intFromFloat(checkpoint.position.x)), @as(i32, @intFromFloat(checkpoint.position.y)), checkpoint.radius, color);
            c.DrawCircleLines(@as(i32, @intFromFloat(checkpoint.position.x)), @as(i32, @intFromFloat(checkpoint.position.y)), checkpoint.radius - 3, color);

            // Draw checkpoint number
            const num_text = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{checkpoint.id + 1}) catch continue;
            defer std.heap.page_allocator.free(num_text);

            const text_width = c.MeasureText(num_text.ptr, 16);
            c.DrawText(num_text.ptr, @as(i32, @intFromFloat(checkpoint.position.x)) - @divTrunc(text_width, 2), @as(i32, @intFromFloat(checkpoint.position.y)) - 8, 16, c.WHITE);
        }
    }

    pub fn checkCheckpointCollision(self: *RaceTrack, player_pos: c.Vector2, player_checkpoint: *u32, player_lap: *u32) void {
        for (self.checkpoints) |*checkpoint| {
            if (checkpoint.passed) continue;

            const distance = c.Vector2Distance(player_pos, checkpoint.position);
            if (distance <= checkpoint.radius) {
                // Check if this is the next expected checkpoint
                if (checkpoint.id == player_checkpoint.*) {
                    checkpoint.passed = true;
                    player_checkpoint.* += 1;

                    // Check if we completed a lap
                    if (player_checkpoint.* >= self.checkpoints.len) {
                        player_checkpoint.* = 0;
                        player_lap.* += 1;

                        // Reset all checkpoints for next lap
                        for (self.checkpoints) |*cp| {
                            cp.passed = false;
                        }
                    }
                    break;
                }
            }
        }
    }

    pub fn checkBoundaryCollision(self: *const RaceTrack, player_pos: c.Vector2, player_radius: f32) c.Vector2 {
        var corrected_pos = player_pos;
        var min_distance = std.math.inf(f32);
        var closest_boundary_point = player_pos;
        var is_colliding = false;

        // Check collision with all track boundary segments
        for (0..self.center_line.len) |i| {
            const current = self.center_line[i];
            const next = self.center_line[(i + 1) % self.center_line.len];

            // Check collision with inner boundary
            const inner_dist = self.distanceToLineSegment(player_pos, current.inner_bound, next.inner_bound);
            if (inner_dist < player_radius + 5) { // 5 pixel buffer
                const closest_point = self.closestPointOnLineSegment(player_pos, current.inner_bound, next.inner_bound);
                if (inner_dist < min_distance) {
                    min_distance = inner_dist;
                    closest_boundary_point = closest_point;
                    is_colliding = true;
                }
            }

            // Check collision with outer boundary
            const outer_dist = self.distanceToLineSegment(player_pos, current.outer_bound, next.outer_bound);
            if (outer_dist < player_radius + 5) {
                const closest_point = self.closestPointOnLineSegment(player_pos, current.outer_bound, next.outer_bound);
                if (outer_dist < min_distance) {
                    min_distance = outer_dist;
                    closest_boundary_point = closest_point;
                    is_colliding = true;
                }
            }
        }

        // If colliding, push the player back to a safe position
        if (is_colliding) {
            const push_direction = c.Vector2Normalize(c.Vector2Subtract(player_pos, closest_boundary_point));
            corrected_pos = c.Vector2Add(closest_boundary_point, c.Vector2Scale(push_direction, player_radius + 5));
        }

        return corrected_pos;
    }

    fn distanceToLineSegment(self: *const RaceTrack, point: c.Vector2, line_start: c.Vector2, line_end: c.Vector2) f32 {
        _ = self;
        const line_vec = c.Vector2Subtract(line_end, line_start);
        const point_vec = c.Vector2Subtract(point, line_start);
        const line_len_sq = c.Vector2DotProduct(line_vec, line_vec);

        if (line_len_sq == 0) {
            return c.Vector2Distance(point, line_start);
        }

        const t = @max(0, @min(1, c.Vector2DotProduct(point_vec, line_vec) / line_len_sq));
        const projection = c.Vector2Add(line_start, c.Vector2Scale(line_vec, t));

        return c.Vector2Distance(point, projection);
    }

    fn closestPointOnLineSegment(self: *const RaceTrack, point: c.Vector2, line_start: c.Vector2, line_end: c.Vector2) c.Vector2 {
        _ = self;
        const line_vec = c.Vector2Subtract(line_end, line_start);
        const point_vec = c.Vector2Subtract(point, line_start);
        const line_len_sq = c.Vector2DotProduct(line_vec, line_vec);

        if (line_len_sq == 0) {
            return line_start;
        }

        const t = @max(0, @min(1, c.Vector2DotProduct(point_vec, line_vec) / line_len_sq));
        return c.Vector2Add(line_start, c.Vector2Scale(line_vec, t));
    }

    pub fn deinit(self: *RaceTrack) void {
        if (self.center_line.len > 0) {
            self.allocator.free(self.center_line);
        }
        if (self.checkpoints.len > 0) {
            self.allocator.free(self.checkpoints);
        }
        if (self.stadium_seats.len > 0) {
            self.allocator.free(self.stadium_seats);
        }
    }
};
