const std = @import("std");
const traits = @import("traits");

/// T forms an index over Key and Value
fn Index(T: type, Key: type, Value: type) type {
    return struct {
        get: fn (T, Key) ?Value,
    };
}

const LookupTable = struct {
    entries: []const Entry,

    const Entry = struct {
        key: []const u8,
        value: i32,
    };
};

const LookupTableIndex = traits.impl(
    Index(LookupTable, []const u8, i32),
    struct {
        pub fn get(table: LookupTable, key: []const u8) ?i32 {
            for (table.entries) |entry| {
                if (std.mem.eql(u8, entry.key, key)) {
                    return entry.value;
                }
            }

            return null;
        }
    },
);

test "Index retrieves a value by key" {
    const entries = [_]LookupTable.Entry{
        .{ .key = "one", .value = 1 },
        .{ .key = "two", .value = 2 },
        .{ .key = "three", .value = 3 },
    };

    const table = LookupTable{
        .entries = &entries,
    };

    try std.testing.expectEqual(
        @as(?i32, 2),
        LookupTableIndex.get(table, "two"),
    );
}

test "Index returns null for a missing key" {
    const entries = [_]LookupTable.Entry{
        .{ .key = "one", .value = 1 },
    };

    const table = LookupTable{
        .entries = &entries,
    };

    try std.testing.expectEqual(
        @as(?i32, null),
        LookupTableIndex.get(table, "missing"),
    );
}
