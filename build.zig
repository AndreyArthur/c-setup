const std = @import("std");

fn getCFilesInDir(
    allocator: std.mem.Allocator,
    directory_path: []const u8,
) !std.ArrayList([]const u8) {
    var sources = std.ArrayList([]const u8).init(allocator);

    var dir = try std.fs.openDirAbsolute(directory_path, .{ .iterate = true });

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        const include_file = if (std.mem.eql(u8, ext, ".c")) true else false;
        if (include_file) {
            const source = try allocator.dupe(u8, entry.path);
            try sources.append(source);
        }
    }

    return sources;
}

const Files = struct {
    main: []const u8,
    main_target: []const u8,
    lib: [][]const u8,
    tests: [][]const u8,
    tests_targets: [][]const u8,
    tests_deps: [][]const u8,
};

pub fn getFiles(allocator: std.mem.Allocator) !Files {
    const src_path = try std.fs.cwd().realpathAlloc(allocator, "src");
    defer allocator.free(src_path);
    const tests_path = try std.fs.cwd().realpathAlloc(allocator, "tests");
    defer allocator.free(tests_path);
    const sources = try getCFilesInDir(
        allocator,
        src_path,
    );
    const test_files = try getCFilesInDir(
        allocator,
        tests_path,
    );

    var main: []const u8 = undefined;
    var main_target: []const u8 = undefined;
    var lib = std.ArrayList([]const u8).init(allocator);
    var tests = std.ArrayList([]const u8).init(allocator);
    var tests_targets = std.ArrayList([]const u8).init(allocator);
    var tests_deps = std.ArrayList([]const u8).init(allocator);

    for (sources.items) |file| {
        if (std.mem.containsAtLeast(u8, file, 1, "main.c")) {
            main = try allocator.dupe(u8, file);
            main_target = try allocator.dupe(u8, main[0 .. main.len - 2]);
        } else {
            try lib.append(try allocator.dupe(u8, file));
        }
    }

    for (test_files.items) |file| {
        if (std.mem.containsAtLeast(u8, file, 1, "deps")) {
            try tests_deps.append(try allocator.dupe(u8, file));
        } else {
            const test_file = try allocator.dupe(u8, file);
            try tests.append(test_file);
            try tests_targets.append(try allocator.dupe(
                u8,
                test_file[0 .. test_file.len - 2],
            ));
        }
    }

    return Files{
        .main = main,
        .main_target = main_target,
        .lib = try lib.toOwnedSlice(),
        .tests = try tests.toOwnedSlice(),
        .tests_targets = try tests_targets.toOwnedSlice(),
        .tests_deps = try tests_deps.toOwnedSlice(),
    };
}

pub fn build(b: *std.Build) !void {
    const files = try getFiles(b.allocator);

    // General config
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Run the executable
    const run_step = b.step("run", "Build and run the executable.");

    const exe = b.addExecutable(.{
        .name = files.main_target,
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.addCSourceFiles(std.Build.Module.AddCSourceFilesOptions{
        .root = std.Build.LazyPath{ .cwd_relative = "./src" },
        .files = files.lib,
    });
    exe.addCSourceFiles(std.Build.Module.AddCSourceFilesOptions{
        .root = std.Build.LazyPath{ .cwd_relative = "./src" },
        .files = &.{files.main},
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    run_step.dependOn(&run_exe.step);

    // Run the tests
    const test_step = b.step("test", "Run unit tests");

    for (files.tests_targets, 0..) |test_target, index| {
        const test_exe = b.addExecutable(.{
            .name = test_target,
            .target = target,
            .optimize = optimize,
        });
        test_exe.linkLibC();
        test_exe.addCSourceFiles(std.Build.Module.AddCSourceFilesOptions{
            .root = std.Build.LazyPath{ .cwd_relative = "./src" },
            .files = files.lib,
        });
        test_exe.addCSourceFiles(std.Build.Module.AddCSourceFilesOptions{
            .root = std.Build.LazyPath{ .cwd_relative = "./tests" },
            .files = &.{
                files.tests[index],
            },
        });
        test_exe.addCSourceFiles(std.Build.Module.AddCSourceFilesOptions{
            .root = std.Build.LazyPath{ .cwd_relative = "./tests" },
            .files = files.tests_deps,
        });
        b.installArtifact(test_exe);

        const run_test = b.addRunArtifact(test_exe);

        test_step.dependOn(&run_test.step);
    }
}
