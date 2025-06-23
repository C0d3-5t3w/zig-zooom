const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const Player = @import("game/player.zig").Player;
const CPU = @import("game/cpu.zig").CPU;
const RaceTrack = @import("game/race_track.zig").RaceTrack;
const GameState = @import("game/game_state.zig").GameState;
const Renderer = @import("graphics/renderer.zig").Renderer;
const ui = @import("graphics/ui.zig");

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize Raylib
    const screen_width = 800;
    const screen_height = 600;

    c.InitWindow(screen_width, screen_height, "Zig Racing Championship - Zooom!");
    defer c.CloseWindow();

    c.SetTargetFPS(60);

    // Initialize game components
    var game_state = GameState.init();
    var player = Player.init();
    const cpu_racers = try allocator.alloc(CPU, 3);
    defer allocator.free(cpu_racers);

    for (cpu_racers, 0..) |*cpu, i| {
        cpu.* = CPU.init();
        cpu.player.color = switch (i) {
            0 => c.BLUE,
            1 => c.GREEN,
            2 => c.ORANGE,
            else => c.PURPLE,
        };
        cpu.player.position.x += @as(f32, @floatFromInt(i)) * 25;
        cpu.player.position.y += @as(f32, @floatFromInt(i)) * 15;
    }

    var track = RaceTrack.init(allocator);
    defer track.deinit();
    try track.createDefaultTrack();

    var renderer = Renderer.init();
    const ui_state = ui.UIState.init();

    std.log.info("Game initialized successfully!", .{});
    std.log.info("Controls: WASD/Arrow Keys to drive, ESC to pause, ENTER to start", .{});

    // Main game loop
    while (!c.WindowShouldClose()) {
        const dt = c.GetFrameTime();

        // Handle input based on game state
        switch (game_state.state) {
            .menu => {
                if (c.IsKeyPressed(c.KEY_ENTER)) {
                    game_state.startRace();
                    player.reset();
                    for (cpu_racers) |*cpu| {
                        cpu.reset();
                    }
                }
            },
            .racing => {
                if (c.IsKeyPressed(c.KEY_ESCAPE)) {
                    game_state.pauseRace();
                } else {
                    // Update game
                    game_state.update(dt);
                    player.updateWithBoundaryCheck(&track);

                    // Check checkpoint collisions for player
                    track.checkCheckpointCollision(player.position, &player.checkpoint, &player.lap);

                    for (cpu_racers) |*cpu| {
                        cpu.update(&track);
                        // Check checkpoint collisions for CPU players
                        track.checkCheckpointCollision(cpu.player.position, &cpu.player.checkpoint, &cpu.player.lap);
                    }

                    // Update camera to follow player
                    renderer.setTarget(player.position.x, player.position.y);

                    // Check for race completion
                    if (player.lap >= game_state.target_laps) {
                        game_state.finishRace();
                    }
                }
            },
            .paused => {
                if (c.IsKeyPressed(c.KEY_ESCAPE)) {
                    game_state.resumeRace();
                } else if (c.IsKeyPressed(c.KEY_R)) {
                    game_state.resetRace();
                    player.reset();
                    for (cpu_racers) |*cpu| {
                        cpu.reset();
                    }
                }
            },
            .finished => {
                if (c.IsKeyPressed(c.KEY_R)) {
                    game_state.resetRace();
                    player.reset();
                    for (cpu_racers) |*cpu| {
                        cpu.reset();
                    }
                } else if (c.IsKeyPressed(c.KEY_M)) {
                    game_state.goToMenu();
                }
            },
        }

        // Render
        renderer.beginFrame();

        switch (game_state.state) {
            .menu => {
                drawMenu();
            },
            .racing, .paused => {
                renderer.begin2D();

                // Draw game objects
                track.draw();
                player.draw();
                for (cpu_racers) |*cpu| {
                    cpu.draw();
                }

                renderer.end2D();

                // Draw UI
                if (ui_state.show_fps) {
                    ui.drawFPS();
                }
                ui.drawScoreboard(player.lap, player.checkpoint, game_state.race_time);
                ui.drawDebugInfo(player.position.x, player.position.y, player.speed);

                if (game_state.state == .paused) {
                    drawPauseMenu();
                }
            },
            .finished => {
                renderer.begin2D();
                track.draw();
                player.draw();
                for (cpu_racers) |*cpu| {
                    cpu.draw();
                }
                renderer.end2D();

                drawFinishScreen(game_state.race_time);
            },
        }

        renderer.endFrame();
    }

    std.log.info("Game shutting down...", .{});
}

fn drawMenu() void {
    const title = "ZIG RACING CHAMPIONSHIP";
    const title_size = 40;
    const title_width = c.MeasureText(title, title_size);

    c.DrawText(title, @divTrunc(800 - title_width, 2), 200, title_size, c.WHITE);

    c.DrawText("ENTER - Start Race", 300, 300, 20, c.LIGHTGRAY);
    c.DrawText("WASD/Arrow Keys - Drive", 300, 330, 20, c.LIGHTGRAY);
    c.DrawText("ESC - Pause", 300, 360, 20, c.LIGHTGRAY);
}

fn drawPauseMenu() void {
    c.DrawRectangle(0, 0, 800, 600, c.Color{ .r = 0, .g = 0, .b = 0, .a = 128 });

    const pause_text = "PAUSED";
    const pause_size = 48;
    const pause_width = c.MeasureText(pause_text, pause_size);

    c.DrawText(pause_text, @divTrunc(800 - pause_width, 2), 250, pause_size, c.WHITE);

    c.DrawText("ESC - Resume  R - Restart", 250, 350, 20, c.LIGHTGRAY);
}

fn drawFinishScreen(race_time: f32) void {
    c.DrawRectangle(0, 0, 800, 600, c.Color{ .r = 0, .g = 0, .b = 0, .a = 128 });

    const finish_text = "RACE FINISHED!";
    const finish_size = 48;
    const finish_width = c.MeasureText(finish_text, finish_size);

    c.DrawText(finish_text, @divTrunc(800 - finish_width, 2), 250, finish_size, c.GOLD);

    const time_text = std.fmt.allocPrint(std.heap.page_allocator, "Final Time: {d:.2}s", .{race_time}) catch return;
    defer std.heap.page_allocator.free(time_text);

    const time_width = c.MeasureText(time_text.ptr, 24);
    c.DrawText(time_text.ptr, @divTrunc(800 - time_width, 2), 320, 24, c.WHITE);

    c.DrawText("R - Restart  M - Menu", 300, 400, 20, c.LIGHTGRAY);
}
