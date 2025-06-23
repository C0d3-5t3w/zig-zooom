const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub const Renderer = struct {
    camera: c.Camera2D,
    background_color: c.Color,

    pub fn init() Renderer {
        return Renderer{
            .camera = c.Camera2D{
                .offset = c.Vector2{ .x = 400, .y = 300 },
                .target = c.Vector2{ .x = 0, .y = 0 },
                .rotation = 0,
                .zoom = 1.0,
            },
            .background_color = c.Color{ .r = 34, .g = 139, .b = 34, .a = 255 },
        };
    }

    pub fn beginFrame(self: *Renderer) void {
        c.BeginDrawing();
        c.ClearBackground(self.background_color);
    }

    pub fn endFrame(self: *Renderer) void {
        _ = self;
        c.EndDrawing();
    }

    pub fn begin2D(self: *Renderer) void {
        c.BeginMode2D(self.camera);
    }

    pub fn end2D(self: *Renderer) void {
        _ = self;
        c.EndMode2D();
    }

    pub fn setTarget(self: *Renderer, x: f32, y: f32) void {
        self.camera.target.x = x;
        self.camera.target.y = y;
    }

    pub fn setZoom(self: *Renderer, zoom: f32) void {
        self.camera.zoom = zoom;
    }
};
