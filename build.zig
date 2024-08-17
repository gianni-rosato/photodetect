const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the executable
    const bin = b.addExecutable(.{
        .name = "photodetect",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    bin.addIncludePath(b.path("src"));

    // Add C source files
    bin.addCSourceFiles(.{
        .files = &.{
            "src/stb_image_impl.c",
        },
        .flags = &.{
            "-std=c17",
            "-static",
            "-O3",
        },
    });

    // Link libc
    bin.linkLibC();
    b.installArtifact(bin);
}
