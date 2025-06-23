const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub const Vector2 = c.Vector2;
pub const Color = c.Color;
pub const Texture2D = c.Texture2D;
pub const Rectangle = c.Rectangle;

pub const RacerType = enum {
    player,
    cpu,
    remote_player,
};

pub const RacerState = struct {
    id: u32,
    position: Vector2,
    velocity: Vector2,
    angle: f32,
    speed: f32,
    lap: u32,
    checkpoint: u32,
    racer_type: RacerType,
    color: Color,
    name: [32]u8,
};

pub const GameState = enum {
    menu,
    racing,
    paused,
    finished,
};

pub const TrackPoint = struct {
    position: Vector2,
    width: f32,
};

pub const Checkpoint = struct {
    position: Vector2,
    radius: f32,
    id: u32,
};

pub const NetworkMessage = struct {
    message_type: MessageType,
    player_id: u32,
    data: []const u8,
    
    pub const MessageType = enum {
        player_join,
        player_leave,
        position_update,
        race_start,
        race_end,
        lap_complete,
    };
};
