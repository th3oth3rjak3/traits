const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const mod = b.addModule("traits", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const tests = b.addTest(.{
        .root_module = mod,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    const runner = b.addExecutable(.{
        .name = "compile_error_runner",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/compile_errors/runner.zig"),
            .target = b.graph.host,
        }),
    });

    const run_runner = b.addRunArtifact(runner);
    run_runner.setCwd(b.path("."));
    run_runner.setEnvironmentVariable("ZIG_EXE", b.graph.zig_exe);

    const compile_errors_step = b.step(
        "compile-errors",
        "Run compile-fail tests",
    );

    compile_errors_step.dependOn(&run_runner.step);
}
