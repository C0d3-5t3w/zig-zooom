const std = @import("std");
const types = @import("types.zig");
const racer_mod = @import("racer.zig");
const track_mod = @import("track.zig");
const websocket = @import("websocket.zig");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub const Game = struct {
    allocator: std.mem.Allocator,
    state: types.GameState,
    track: track_mod.Track,
    player: racer_mod.Racer,
    cpu_racers: []racer_mod.Racer,
    camera: c.Camera2D,
    websocket_client: ?*websocket.WebSocketClient,
    race_time: f32,
    target_fps: i32,
    
    pub fn init(allocator: std.mem.Allocator) !Game {
        var game = Game{
            .allocator = allocator,
            .state = .menu,
            .track = track_mod.Track.init(allocator),
            .player = racer_mod.Racer.init(0, .player, types.Vector2{ .x = 100, .y = 300 }),
            .cpu_racers = try allocator.alloc(racer_mod.Racer, 5),
            .camera = c.Camera2D{
                .offset = types.Vector2{ .x = 400, .y = 300 },
                .target = types.Vector2{ .x = 100, .y = 300 },
                .rotation = 0,
                .zoom = 1.0,
            },
            .websocket_client = null,
            .race_time = 0,
            .target_fps = 60,
        };
        
        // Initialize track
        try game.track.createDefaultTrack();
        
        // Initialize CPU racers
        for (game.cpu_racers, 0..) |*cpu, i| {
            const start_offset = types.Vector2{
                .x = @as(f32, @floatFromInt(i)) * 25,
                .y = @as(f32, @floatFromInt(i)) * 15,
            };
            cpu.* = racer_mod.Racer.init(
                @intCast(i + 1),
                .cpu,
                c.Vector2Add(game.track.start_position, start_offset)
            );
        }
        
        return game;
    }
    
    pub fn update(self: *Game, dt: f32) void {
        switch (self.state) {
            .menu => self.updateMenu(),
            .racing => self.updateRacing(dt),
            .paused => self.updatePaused(),
            .finished => self.updateFinished(),
        }
    }
    
    fn updateMenu(self: *Game) void {
        if (c.IsKeyPressed(c.KEY_ENTER)) {
            self.startRace();
        }
        if (c.IsKeyPressed(c.KEY_C)) {
            self.connectToWebSocket();
        }
    }
    
    fn updateRacing(self: *Game, dt: f32) void {
        if (c.IsKeyPressed(c.KEY_ESCAPE)) {
            self.state = .paused;
            return;
        }
        
        self.race_time += dt;
        
        // Update player
        self.player.updatePlayer(dt);
        self.player.checkCheckpoints(&self.track);
        
        // Update CPU racers
        for (self.cpu_racers) |*cpu| {
            cpu.updateCPU(&self.track, dt);
            cpu.checkCheckpoints(&self.track);
        }
        
        // Update camera to follow player
        self.camera.target = self.player.state.position;
        
        // Check for race completion
        if (self.player.state.lap >= 3) {
            self.state = .finished;
        }
        
        // Send position updates via WebSocket
        if (self.websocket_client) |client| {
            self.sendPositionUpdate(client);
        }
    }
    
    fn updatePaused(self: *Game) void {
        if (c.IsKeyPressed(c.KEY_ESCAPE)) {
            self.state = .racing;
        }
        if (c.IsKeyPressed(c.KEY_R)) {
            self.resetRace();
        }
    }
    
    fn updateFinished(self: *Game) void {
        if (c.IsKeyPressed(c.KEY_R)) {
            self.resetRace();
        }
        if (c.IsKeyPressed(c.KEY_M)) {
            self.state = .menu;
        }
    }
    
    pub fn draw(self: *Game) void {
        c.BeginDrawing();
        defer c.EndDrawing();
        
        c.ClearBackground(c.Color{ .r = 34, .g = 139, .b = 34, .a = 255 }); // Forest green background
        
        switch (self.state) {
            .menu => self.drawMenu(),
            .racing, .paused => self.drawRacing(),
            .finished => self.drawFinished(),
        }
        
        // Draw FPS
        c.DrawFPS(10, 10);
    }
    
    fn drawMenu(self: *Game) void {
        const title = "ZIG RACING CHAMPIONSHIP";
        const title_size = 40;
        const title_width = c.MeasureText(title, title_size);
        
        c.DrawText(
            title,
            @divTrunc(800 - title_width, 2),
            200,
            title_size,
            c.WHITE
        );
        
        const instructions = [_][]const u8{
            "ENTER - Start Race",
            "C - Connect to WebSocket",
            "",
            "Controls:",
            "WASD or Arrow Keys - Drive",
            "ESC - Pause",
        };
        
        for (instructions, 0..) |instruction, i| {
            c.DrawText(
                instruction.ptr,
                300,
                300 + @as(i32, @intCast(i)) * 30,
                20,
                c.LIGHTGRAY
            );
        }
    }
    
    fn drawRacing(self: *Game) void {
        c.BeginMode2D(self.camera);
        
        // Draw track
        self.track.draw();
        
        // Draw racers
        self.player.draw();
        for (self.cpu_racers) |*cpu| {
            cpu.draw();
        }
        
        c.EndMode2D();
        
        // Draw UI
        self.drawUI();
        
        if (self.state == .paused) {
            self.drawPauseMenu();
        }
    }
    
    fn drawFinished(self: *Game) void {
        self.drawRacing(); // Draw the race scene in background
        
        // Draw finish overlay
        c.DrawRectangle(0, 0, 800, 600, c.Color{ .r = 0, .g = 0, .b = 0, .a = 128 });
        
        const finish_text = "RACE FINISHED!";
        const finish_size = 48;
        const finish_width = c.MeasureText(finish_text, finish_size);
        
        c.DrawText(
            finish_text,
            @divTrunc(800 - finish_width, 2),
            250,
            finish_size,
            c.GOLD
        );
        
        const time_text = std.fmt.allocPrint(
            std.heap.page_allocator,
            "Final Time: {d:.2}s",
            .{self.race_time}
        ) catch return;
        defer std.heap.page_allocator.free(time_text);
        
        const time_width = c.MeasureText(time_text.ptr, 24);
        c.DrawText(
            time_text.ptr,
            @divTrunc(800 - time_width, 2),
            320,
            24,
            c.WHITE
        );
        
        c.DrawText("R - Restart  M - Menu", 300, 400, 20, c.LIGHTGRAY);
    }
    
    fn drawUI(self: *Game) void {
        // Draw lap counter
        const lap_text = std.fmt.allocPrint(
            std.heap.page_allocator,
            "Lap: {d}/3",
            .{self.player.state.lap + 1}
        ) catch return;
        defer std.heap.page_allocator.free(lap_text);
        
        c.DrawText(lap_text.ptr, 10, 50, 24, c.WHITE);
        
        // Draw checkpoint progress
        const cp_text = std.fmt.allocPrint(
            std.heap.page_allocator,
            "Checkpoint: {d}/{d}",
            .{ self.player.state.checkpoint + 1, self.track.checkpoints.len }
        ) catch return;
        defer std.heap.page_allocator.free(cp_text);
        
        c.DrawText(cp_text.ptr, 10, 80, 20, c.WHITE);
        
        // Draw race time
        const time_text = std.fmt.allocPrint(
            std.heap.page_allocator,
            "Time: {d:.1}s",
            .{self.race_time}
        ) catch return;
        defer std.heap.page_allocator.free(time_text);
        
        c.DrawText(time_text.ptr, 10, 110, 20, c.WHITE);
        
        // Draw speed
        const speed_text = std.fmt.allocPrint(
            std.heap.page_allocator,
            "Speed: {d:.0} km/h",
            .{@abs(self.player.state.speed) * 3.6}
        ) catch return;
        defer std.heap.page_allocator.free(speed_text);
        
        c.DrawText(speed_text.ptr, 10, 140, 20, c.WHITE);
        
        // Draw minimap
        self.drawMinimap();
    }
    
    fn drawMinimap(self: *Game) void {
        const minimap_size = 150;
        const minimap_x = 800 - minimap_size - 10;
        const minimap_y = 10;
        
        // Draw minimap background
        c.DrawRectangle(minimap_x, minimap_y, minimap_size, minimap_size, c.Color{ .r = 0, .g = 0, .b = 0, .a = 128 });
        c.DrawRectangleLines(minimap_x, minimap_y, minimap_size, minimap_size, c.WHITE);
        
        // Draw track on minimap
        const scale = 0.15;
        const offset_x = minimap_x + minimap_size / 2 - 400 * scale;
        const offset_y = minimap_y + minimap_size / 2 - 300 * scale;
        
        for (0..self.track.center_line.len) |i| {
            const current = self.track.center_line[i];
            const next = self.track.center_line[(i + 1) % self.track.center_line.len];
            
            const start = types.Vector2{
                .x = offset_x + current.position.x * scale,
                .y = offset_y + current.position.y * scale,
            };
            const end = types.Vector2{
                .x = offset_x + next.position.x * scale,
                .y = offset_y + next.position.y * scale,
            };
            
            c.DrawLineEx(start, end, 2, c.GRAY);
        }
        
        // Draw player on minimap
        const player_pos = types.Vector2{
            .x = offset_x + self.player.state.position.x * scale,
            .y = offset_y + self.player.state.position.y * scale,
        };
        c.DrawCircle(@intFromFloat(player_pos.x), @intFromFloat(player_pos.y), 3, c.RED);
        
        // Draw CPU racers on minimap
        for (self.cpu_racers) |cpu| {
            const cpu_pos = types.Vector2{
                .x = offset_x + cpu.state.position.x * scale,
                .y = offset_y + cpu.state.position.y * scale,
            };
            c.DrawCircle(@intFromFloat(cpu_pos.x), @intFromFloat(cpu_pos.y), 2, cpu.state.color);
        }
    }
    
    fn drawPauseMenu(self: *Game) void {
        _ = self;
        c.DrawRectangle(0, 0, 800, 600, c.Color{ .r = 0, .g = 0, .b = 0, .a = 128 });
        
        const pause_text = "PAUSED";
        const pause_size = 48;
        const pause_width = c.MeasureText(pause_text, pause_size);
        
        c.DrawText(
            pause_text,
            @divTrunc(800 - pause_width, 2),
            250,
            pause_size,
            c.WHITE
        );
        
        c.DrawText("ESC - Resume  R - Restart", 250, 350, 20, c.LIGHTGRAY);
    }
    
    fn startRace(self: *Game) void {
        self.state = .racing;
        self.race_time = 0;
        self.resetRace();
    }
    
    fn resetRace(self: *Game) void {
        // Reset player
        self.player.state.position = self.track.start_position;
        self.player.state.velocity = types.Vector2{ .x = 0, .y = 0 };
        self.player.state.speed = 0;
        self.player.state.lap = 0;
        self.player.state.checkpoint = 0;
        self.player.state.angle = 0;
        
        // Reset CPU racers
        for (self.cpu_racers, 0..) |*cpu, i| {
            const start_offset = types.Vector2{
                .x = @as(f32, @floatFromInt(i)) * 25,
                .y = @as(f32, @floatFromInt(i)) * 15,
            };
            cpu.state.position = c.Vector2Add(self.track.start_position, start_offset);
            cpu.state.velocity = types.Vector2{ .x = 0, .y = 0 };
            cpu.state.speed = 0;
            cpu.state.lap = 0;
            cpu.state.checkpoint = 0;
            cpu.state.angle = 0;
            cpu.target_point_index = 0;
        }
        
        self.race_time = 0;
        self.state = .racing;
    }
    
    fn connectToWebSocket(self: *Game) void {
        self.websocket_client = websocket.WebSocketClient.connect("ws://localhost:8080") catch |err| {
            std.log.err("Failed to connect to WebSocket: {}", .{err});
            return;
        };
        std.log.info("Connected to WebSocket server");
    }
    
    fn sendPositionUpdate(self: *Game, client: *websocket.WebSocketClient) void {
        const message = types.NetworkMessage{
            .message_type = .position_update,
            .player_id = self.player.state.id,
            .data = std.mem.asBytes(&self.player.state),
        };
        
        client.sendMessage(std.mem.asBytes(&message)) catch |err| {
            std.log.err("Failed to send position update: {}", .{err});
        };
    }
    
    pub fn deinit(self: *Game) void {
        self.track.deinit();
        self.allocator.free(self.cpu_racers);
        
        if (self.websocket_client) |client| {
            client.deinit();
        }
    }
};
