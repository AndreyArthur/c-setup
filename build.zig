const std = @import("std");

fn getFilesInDir(
    allocator: std.mem.Allocator,
    directory_path: []const u8,
) !std.ArrayList([]const u8) {
    var sources = std.ArrayList([]const u8).init(allocator);

    var dir = try std.fs.openDirAbsolute(directory_path, .{ .iterate = true });

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    const allowed_exts = [_][]const u8{ ".c", ".cpp", ".cxx", ".c++", ".cc" };
    while (try walker.next()) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        const include_file = for (allowed_exts) |e| {
            if (std.mem.eql(u8, ext, e))
                break true;
        } else false;
        if (include_file) {
            const source = try allocator.dupe(u8, entry.path);
            try sources.append(source);
        }
    }

    return sources;
}

pub fn build(b: *std.Build) !void {
    // General config
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build and run the executable
    const sources = try getFilesInDir(
        b.allocator,
        b.path("./src").getPath(b),
    );

    const exe = b.addExecutable(.{
        .name = "main",
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.addCSourceFiles(std.Build.Module.AddCSourceFilesOptions{
        .root = std.Build.LazyPath{ .cwd_relative = "./src" },
        .files = sources.items,
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Build and run the executable.");
    run_step.dependOn(&run_exe.step);

    // Build and run the tests
    var lib = std.ArrayList([]const u8).init(b.allocator);
    for (sources.items) |source| {
        if (std.mem.eql(u8, source, "main.c")) {
            continue;
        }
        try lib.append(source);
    }
    var test_lib = std.ArrayList([]const u8).init(b.allocator);

    const test_dir_files = try getFilesInDir(
        b.allocator,
        b.path("./tests").getPath(b),
    );
    var test_sources = std.ArrayList([]const u8).init(b.allocator);
    for (test_dir_files.items) |test_dir_file| {
        if (std.mem.containsAtLeast(u8, test_dir_file, 1, "deps")) {
            try test_lib.append(test_dir_file);
            continue;
        }
        try test_sources.append(test_dir_file);
    }
    var test_targets = std.ArrayList([]const u8).init(b.allocator);
    for (test_sources.items) |test_source| {
        const index = std.mem.indexOf(u8, test_source, ".").?;
        try test_targets.append(test_source[0..index]);
    }

    const test_step = b.step("test", "Run unit tests");

    for (test_targets.items, 0..) |test_target, index| {
        const test_exe = b.addExecutable(.{
            .name = test_target,
            .target = target,
            .optimize = optimize,
        });
        test_exe.linkLibC();
        test_exe.addCSourceFiles(std.Build.Module.AddCSourceFilesOptions{
            .root = std.Build.LazyPath{ .cwd_relative = "./src" },
            .files = lib.items,
        });
        test_exe.addCSourceFiles(std.Build.Module.AddCSourceFilesOptions{
            .root = std.Build.LazyPath{ .cwd_relative = "./tests" },
            .files = &.{
                test_sources.items[index],
            },
        });
        test_exe.addCSourceFiles(std.Build.Module.AddCSourceFilesOptions{
            .root = std.Build.LazyPath{ .cwd_relative = "./tests" },
            .files = test_lib.items,
        });
        b.installArtifact(test_exe);

        const run_test = b.addRunArtifact(test_exe);

        test_step.dependOn(&run_test.step);
    }
}
