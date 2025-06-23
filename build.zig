const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zooom",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();

    const target_info = target.result;

    if (target_info.os.tag == .macos) {
        exe.addFrameworkPath(.{ .cwd_relative = "/System/Library/Frameworks" });
        exe.addFrameworkPath(.{ .cwd_relative = "/Library/Frameworks" });

        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        exe.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
        exe.addLibraryPath(.{ .cwd_relative = "/usr/lib" });

        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
        exe.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
        exe.addIncludePath(.{ .cwd_relative = "/usr/include" });

        exe.linkSystemLibrary("raylib");

        exe.linkFramework("OpenGL");
        exe.linkFramework("Cocoa");
        exe.linkFramework("IOKit");
        exe.linkFramework("CoreVideo");
        exe.linkFramework("CoreAudio");
        exe.linkFramework("AudioToolbox");

        exe.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
        exe.addIncludePath(.{ .cwd_relative = "/usr/include" });

        exe.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        exe.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
    } else if (target_info.os.tag == .linux) {
        exe.linkSystemLibrary("raylib");
        exe.linkSystemLibrary("GL");
        exe.linkSystemLibrary("m");
        exe.linkSystemLibrary("pthread");
        exe.linkSystemLibrary("dl");
        exe.linkSystemLibrary("rt");
        exe.linkSystemLibrary("X11");

        exe.addIncludePath(.{ .cwd_relative = "/usr/include" });
        exe.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
    } else if (target_info.os.tag == .windows) {
        exe.linkSystemLibrary("raylib");
        exe.linkSystemLibrary("winmm");
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("opengl32");
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
