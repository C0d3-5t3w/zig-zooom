const std = @import("std");

pub const MessageType = enum {
    player_join,
    player_leave,
    position_update,
    race_start,
    race_end,
    lap_complete,
};

pub const PlayerState = struct {
    id: u32,
    x: f32,
    y: f32,
    angle: f32,
    speed: f32,
    lap: u32,
    checkpoint: u32,
};

pub const GameStateType = enum {
    waiting,
    racing,
    finished,
};

pub const NetworkMessage = struct {
    message_type: MessageType,
    player_id: u32,
    timestamp: u64,
    data: []const u8,

    pub fn serialize(self: *const NetworkMessage, allocator: std.mem.Allocator) ![]u8 {
        // TODO: Implement proper serialization
        _ = allocator;
        return std.mem.asBytes(self);
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !NetworkMessage {
        // TODO: Implement proper deserialization
        _ = allocator;
        _ = data;
        return NetworkMessage{
            .message_type = .position_update,
            .player_id = 0,
            .timestamp = 0,
            .data = &[_]u8{},
        };
    }
};
