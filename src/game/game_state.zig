const std = @import("std");

pub const GameStateType = enum {
    menu,
    racing,
    paused,
    finished,
};

pub const GameState = struct {
    state: GameStateType,
    race_time: f32,
    target_laps: u32,
    race_started: bool,
    race_finished: bool,

    pub fn init() GameState {
        return GameState{
            .state = .menu,
            .race_time = 0.0,
            .target_laps = 3,
            .race_started = false,
            .race_finished = false,
        };
    }

    pub fn startRace(self: *GameState) void {
        self.state = .racing;
        self.race_time = 0.0;
        self.race_started = true;
        self.race_finished = false;
    }

    pub fn pauseRace(self: *GameState) void {
        if (self.state == .racing) {
            self.state = .paused;
        }
    }

    pub fn resumeRace(self: *GameState) void {
        if (self.state == .paused) {
            self.state = .racing;
        }
    }

    pub fn finishRace(self: *GameState) void {
        self.state = .finished;
        self.race_finished = true;
    }

    pub fn update(self: *GameState, dt: f32) void {
        if (self.state == .racing) {
            self.race_time += dt;
        }
    }

    pub fn resetRace(self: *GameState) void {
        self.state = .racing;
        self.race_time = 0.0;
        self.race_started = true;
        self.race_finished = false;
    }

    pub fn goToMenu(self: *GameState) void {
        self.state = .menu;
        self.race_started = false;
        self.race_finished = false;
        self.state = .racing;
        self.race_time = 0.0;
        self.race_started = true;
        self.race_finished = false;
    }

    pub fn updateGame(self: *GameState) void {
        self.player.update();
        for (self.cpus) |*cpu| {
            cpu.update();
        }
    }

    pub fn resetGame(self: *GameState) void {
        self.player.reset();
        for (self.cpus) |*cpu| {
            cpu.reset();
        }
        self.track.reset();
    }
};
