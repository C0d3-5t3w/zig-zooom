const std = @import("std");
const game = @import("game.zig");
const ws = @import("ws.zig");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub const defaultConfig = struct {
    title: []const u8 = "Zooom",
    width: u32 = 800,
    height: u32 = 600,
    fullscreen: bool = false,
    vsync: bool = true,
    target_fps: u32 = 60,
};
