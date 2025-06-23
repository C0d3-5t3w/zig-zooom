# Zig Racing Game

Welcome to the Zig Racing Game! This project is a basic 2D racing game built using Zig and raylib, featuring both player-controlled and CPU racers. The game includes real-time multiplayer capabilities through WebSocket communication.

## Table of Contents

- [Zig Racing Game](#zig-racing-game)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Getting Started](#getting-started)
  - [Game Mechanics](#game-mechanics)
  - [Assets](#assets)
  - [Building the Project](#building-the-project)
  - [License](#license)

## Features

- Single-player mode against CPU racers.
- Multiplayer mode using WebSocket for real-time communication.
- Dynamic race track rendering.
- Smooth graphics using raylib.
- User interface for displaying game information.

## Getting Started

To get started with the Zig Racing Game, follow these steps:

1. **Clone the repository:**
   ```
   git clone https://github.com/yourusername/zig-racing-game.git
   cd zig-racing-game
   ```

2. **Install Zig:**
   Ensure you have Zig installed on your machine. You can download it from [ziglang.org](https://ziglang.org/download/).

3. **Install raylib:**
   Follow the instructions on the [raylib website](https://www.raylib.com/) to install the library.

4. **Build the project:**
   Run the build script:
   ```
   zig build
   ```

5. **Run the game:**
   After building, execute the game:
   ```
   ./zig-racing-game
   ```

## Game Mechanics

- **Player Controls:** Use the arrow keys to control your car's movement.
- **CPU Racers:** Compete against AI-controlled racers that simulate realistic driving behavior.
- **WebSocket Communication:** Connect with other players in real-time to race against them.

## Assets

The game includes various assets located in the `assets` directory:

- **Maps:** JSON files defining the race track layout.
- **Textures:** Images for the cars and tracks.
- **Fonts:** Custom fonts for rendering text in the game.

## Building the Project

The project uses a build script located in `build.zig`. You can customize the build configuration as needed.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.