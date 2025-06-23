const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const UIState = struct {
    show_fps: bool,
    show_debug: bool,
    font_size: i32,

    pub fn init() UIState {
        return UIState{
            .show_fps = true,
            .show_debug = true,
            .font_size = 20,
        };
    }
};

pub fn drawScoreboard(lap: u32, checkpoint: u32, time: f32) void {
    // Draw semi-transparent background
    c.DrawRectangle(5, 5, 280, 120, c.Color{ .r = 0, .g = 0, .b = 0, .a = 120 });
    c.DrawRectangleLines(5, 5, 280, 120, c.WHITE);

    // Lap progress
    const lap_text = std.fmt.allocPrint(std.heap.page_allocator, "LAP: {d}/3", .{lap + 1}) catch return;
    defer std.heap.page_allocator.free(lap_text);
    c.DrawText(lap_text.ptr, 15, 15, 24, c.YELLOW);

    // Progress bar for current lap
    const progress_width = 200;
    const progress_height = 8;
    const progress_x = 15;
    const progress_y = 45;

    // Background bar
    c.DrawRectangle(progress_x, progress_y, progress_width, progress_height, c.DARKGRAY);

    // Progress fill (assuming 6 checkpoints per lap)
    const progress = @as(f32, @floatFromInt(checkpoint)) / 6.0;
    const fill_width = @as(i32, @intFromFloat(@as(f32, @floatFromInt(progress_width)) * progress));
    c.DrawRectangle(progress_x, progress_y, fill_width, progress_height, c.LIME);

    // Progress bar border
    c.DrawRectangleLines(progress_x, progress_y, progress_width, progress_height, c.WHITE);

    // Checkpoint indicator
    const cp_text = std.fmt.allocPrint(std.heap.page_allocator, "CHECKPOINT: {d}/6", .{checkpoint + 1}) catch return;
    defer std.heap.page_allocator.free(cp_text);
    c.DrawText(cp_text.ptr, 15, 60, 18, c.LIGHTGRAY);

    // Race time with better formatting
    const minutes = @as(u32, @intFromFloat(time / 60));
    const seconds = time - @as(f32, @floatFromInt(minutes)) * 60;
    const time_text = std.fmt.allocPrint(std.heap.page_allocator, "TIME: {d:0>2}:{d:0>5.2}", .{ minutes, seconds }) catch return;
    defer std.heap.page_allocator.free(time_text);
    c.DrawText(time_text.ptr, 15, 85, 18, c.WHITE);
}

pub fn drawFPS() void {
    // Custom FPS display with background
    const fps = c.GetFPS();
    const fps_text = std.fmt.allocPrint(std.heap.page_allocator, "FPS: {d}", .{fps}) catch return;
    defer std.heap.page_allocator.free(fps_text);

    const text_width = c.MeasureText(fps_text.ptr, 16);
    c.DrawRectangle(c.GetScreenWidth() - text_width - 15, 5, text_width + 10, 25, c.Color{ .r = 0, .g = 0, .b = 0, .a = 120 });

    const color = if (fps >= 60) c.LIME else if (fps >= 30) c.YELLOW else c.RED;
    c.DrawText(fps_text.ptr, c.GetScreenWidth() - text_width - 10, 10, 16, color);
}

pub fn drawDebugInfo(player_x: f32, player_y: f32, speed: f32) void {
    const debug_bg_height = 100;
    c.DrawRectangle(5, c.GetScreenHeight() - debug_bg_height - 5, 300, debug_bg_height, c.Color{ .r = 0, .g = 0, .b = 0, .a = 120 });
    c.DrawRectangleLines(5, c.GetScreenHeight() - debug_bg_height - 5, 300, debug_bg_height, c.GRAY);

    // Position
    const pos_text = std.fmt.allocPrint(std.heap.page_allocator, "POS: ({d:.1}, {d:.1})", .{ player_x, player_y }) catch return;
    defer std.heap.page_allocator.free(pos_text);
    c.DrawText(pos_text.ptr, 15, c.GetScreenHeight() - 90, 14, c.LIGHTGRAY);

    // Speed with visual bar
    const speed_text = std.fmt.allocPrint(std.heap.page_allocator, "SPEED: {d:.1}", .{speed}) catch return;
    defer std.heap.page_allocator.free(speed_text);
    c.DrawText(speed_text.ptr, 15, c.GetScreenHeight() - 70, 14, c.LIGHTGRAY);

    // Speed bar
    const max_display_speed = 250.0;
    const bar_width = 150;
    const bar_height = 6;
    const speed_ratio = @min(speed / max_display_speed, 1.0);
    const speed_bar_width = @as(i32, @intFromFloat(@as(f32, @floatFromInt(bar_width)) * speed_ratio));

    const bar_x = 15;
    const bar_y = c.GetScreenHeight() - 50;

    c.DrawRectangle(bar_x, bar_y, bar_width, bar_height, c.DARKGRAY);

    const speed_color = if (speed_ratio > 0.8) c.RED else if (speed_ratio > 0.5) c.YELLOW else c.LIME;
    c.DrawRectangle(bar_x, bar_y, speed_bar_width, bar_height, speed_color);
    c.DrawRectangleLines(bar_x, bar_y, bar_width, bar_height, c.WHITE);

    // Controls hint
    c.DrawText("WASD/ARROWS: Drive | ESC: Pause", 15, c.GetScreenHeight() - 25, 12, c.GRAY);
}

pub fn drawMiniMap(player_pos: c.Vector2, track_center: []const c.Vector2) void {
    _ = player_pos;
    _ = track_center;

    // Mini-map implementation
    const map_size = 150;
    const map_x = c.GetScreenWidth() - map_size - 10;
    const map_y = 140;

    // Map background
    c.DrawRectangle(map_x, map_y, map_size, map_size, c.Color{ .r = 0, .g = 0, .b = 0, .a = 180 });
    c.DrawRectangleLines(map_x, map_y, map_size, map_size, c.WHITE);

    // TODO: Draw track outline and player position on minimap
    c.DrawText("MINI MAP", map_x + 10, map_y + 10, 12, c.WHITE);
}
