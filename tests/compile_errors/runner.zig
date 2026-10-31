const std = @import("std");

const Case = struct {
    name: []const u8,
    source: []const u8,
    expected_errors: []const []const u8,
    expected_location: []const u8,
};

const cases = [_]Case{
    .{
        .name = "missing_trait",
        .source = "tests/compile_errors/missing_trait.zig",
        .expected_errors = &.{
            "trait traits.Convert(i32,i64) not found on",
        },
        .expected_location = "src/traits.zig:",
    },
    .{
        .name = "ambiguous_trait",
        .source = "tests/compile_errors/ambiguous_trait.zig",
        .expected_errors = &.{
            "ambiguous trait ambiguous_trait.MyTrait on ambiguous_trait.MyImplementation",
            "Matching declarations:",
            "- first",
            "- second",
        },
        .expected_location = "src/traits.zig:",
    },
    .{
        .name = "missing_field",
        .source = "tests/compile_errors/missing_field.zig",
        .expected_errors = &.{
            "has no member named 'second'",
        },
        .expected_location = "src/traits.zig:",
    },
};

const Outcome = enum {
    passed,
    unexpected_success,
    unexpected_failure,
};

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn runCase(
    allocator: std.mem.Allocator,
    io: std.Io,
    zig_exe: []const u8,
    case: Case,
) !Outcome {
    const case_arg = try std.fmt.allocPrint(
        allocator,
        "-Mcase={s}",
        .{case.source},
    );

    const argv = [_][]const u8{
        zig_exe,
        "test",
        "--dep",
        "case",
        "-Mroot=tests/compile_errors/root.zig",
        "--dep",
        "traits",
        case_arg,
        "-Mtraits=src/root.zig",
    };

    const result = try std.process.run(allocator, io, .{
        .argv = &argv,
    });

    if (result.term.success()) {
        return .unexpected_success;
    }

    // Require every expected diagnostic fragment.
    for (case.expected_errors) |expected| {
        if (!contains(result.stderr, expected)) {
            return .unexpected_failure;
        }
    }

    // Require the diagnostic to reference the implementation.
    if (!contains(result.stderr, case.expected_location)) {
        return .unexpected_failure;
    }

    return .passed;
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    const zig_exe = init.environ_map.get("ZIG_EXE") orelse
        return error.ZigExecutableNotFound;

    var passed: usize = 0;
    var failed: usize = 0;

    std.debug.print("Compile-fail tests:\n\n", .{});

    for (cases) |case| {
        const case_arg = try std.fmt.allocPrint(
            allocator,
            "-Mcase={s}",
            .{case.source},
        );

        const argv = [_][]const u8{
            zig_exe,
            "test",
            "--dep",
            "case",
            "-Mroot=tests/compile_errors/root.zig",
            "--dep",
            "traits",
            case_arg,
            "-Mtraits=src/root.zig",
        };

        const result = try std.process.run(allocator, init.io, .{
            .argv = &argv,
        });

        const outcome: Outcome = if (result.term.success())
            .unexpected_success
        else blk: {
            var diagnostics_match = true;

            for (case.expected_errors) |expected| {
                if (!contains(result.stderr, expected)) {
                    diagnostics_match = false;
                    break;
                }
            }

            if (!diagnostics_match or
                !contains(result.stderr, case.expected_location))
            {
                break :blk .unexpected_failure;
            }

            break :blk .passed;
        };

        switch (outcome) {
            .passed => {
                std.debug.print("  PASS  {s}\n", .{case.name});
                passed += 1;
            },
            .unexpected_success => {
                std.debug.print(
                    "  FAIL  {s}: compilation unexpectedly succeeded\n",
                    .{case.name},
                );
                failed += 1;
            },
            .unexpected_failure => {
                std.debug.print(
                    "  FAIL  {s}: unexpected compilation failure\n",
                    .{case.name},
                );
                failed += 1;

                if (result.stderr.len > 0) {
                    std.debug.print("\n{s}\n", .{result.stderr});
                }

                if (result.stdout.len > 0) {
                    std.debug.print(
                        "\nCompiler stdout:\n{s}\n",
                        .{result.stdout},
                    );
                }
            },
        }
    }

    std.debug.print(
        "\n{d} passed, {d} failed\n",
        .{ passed, failed },
    );

    if (failed != 0) {
        return error.CompileFailTestsFailed;
    }
}
