const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const mod = b.addModule("traits", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // Library tests
    const tests = b.addTest(.{
        .root_module = mod,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    // Compile-fail tests
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

    // Example tests
    const examples_step = b.step(
        "examples",
        "Run all example tests",
    );

    const example_files = [_][]const u8{
        "examples/conversions.zig",
        "examples/indexing.zig",
        "examples/iteration.zig",
        "examples/reducers.zig",
    };

    for (example_files) |example_file| {
        const example_mod = b.createModule(.{
            .root_source_file = b.path(example_file),
            .target = target,
            .imports = &.{
                .{ .name = "traits", .module = mod },
            },
        });

        const example_tests = b.addTest(.{
            .root_module = example_mod,
        });

        const run_example_tests = b.addRunArtifact(example_tests);
        examples_step.dependOn(&run_example_tests.step);
    }
}
