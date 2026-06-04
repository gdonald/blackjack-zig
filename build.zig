const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const bj_module = b.createModule(.{
        .root_source_file = b.path("src/bj.zig"),
        .target = target,
        .optimize = optimize,
    });

    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "bj", .module = bj_module }},
    });

    const exe = b.addExecutable(.{
        .name = "bj",
        .root_module = main_module,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the game");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/all.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "bj", .module = bj_module },
                .{ .name = "main", .module = main_module },
            },
        }),
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    const coverage_dir = b.pathJoin(&.{ b.install_path, "coverage" });
    const run_coverage = b.addSystemCommand(&.{
        "kcov",
        "--clean",
        "--include-pattern=src/",
        coverage_dir,
    });
    run_coverage.addArtifactArg(unit_tests);
    const coverage_step = b.step("coverage", "Generate test coverage with kcov");
    coverage_step.dependOn(&run_coverage.step);
}
