const std = @import("std");
const traits = @import("traits");

fn Reducer(T: type) type {
    return struct {
        empty: T,
        combine: fn (T, T) T,

        fn reduce(self: @This(), xs: []const T) T {
            var accum = self.empty;
            for (xs) |x| {
                accum = self.combine(accum, x);
            }

            return accum;
        }
    };
}

fn Finalizer(T: type) type {
    return struct {
        finalize: fn (*T, bool) void,
    };
}

const ReducerAllocationContext = struct {
    allocator: std.mem.Allocator,
    allocations: std.ArrayList([]u8),

    pub fn init(allocator: std.mem.Allocator) ReducerAllocationContext {
        return .{
            .allocator = allocator,
            .allocations = .empty,
        };
    }

    pub fn retainLast(self: *ReducerAllocationContext) void {
        const items = self.allocations.items;

        if (items.len == 0) return;

        const last = items[items.len - 1];

        for (items[0 .. items.len - 1]) |allocation| {
            self.allocator.free(allocation);
        }

        items[0] = last;
        self.allocations.shrinkRetainingCapacity(1);
    }

    /// Intentionally leak the last element, caller cleans it up.
    /// This should only be called when the reduction was successful.
    pub fn leakLast(self: *ReducerAllocationContext) void {
        self.retainLast();
        self.allocations.deinit(self.allocator);
    }

    pub fn deinit(self: *ReducerAllocationContext) void {
        for (self.allocations.items) |item| {
            self.allocator.free(item);
        }

        self.allocations.deinit(self.allocator);
    }
};

fn AllocatingReducer(T: type, State: type) type {
    return struct {
        init: fn (std.mem.Allocator) anyerror!State,
        empty: T,
        combine: fn (*State, T, T) anyerror!T,
        finalizer: Finalizer(State),

        fn reduce(
            self: @This(),
            allocator: std.mem.Allocator,
            items: []const T,
        ) !T {
            var state = try self.init(allocator);
            var succeeded = false;
            var accum = self.empty;
            defer self.finalizer.finalize(&state, succeeded);

            for (items) |item| {
                accum = try self.combine(&state, accum, item);
            }

            succeeded = true;
            return accum;
        }
    };
}

pub fn reduce(
    comptime T: type,
    comptime reducer: Reducer(T),
    items: []const T,
) T {
    return reducer.reduce(items);
}

const SumReducer = traits.impl(Reducer(i32), struct {
    pub const empty = 0;
    pub fn combine(a: i32, b: i32) i32 {
        return a + b;
    }
});

const ProductReducer = traits.impl(Reducer(i32), struct {
    pub const empty = 1;
    pub fn combine(a: i32, b: i32) i32 {
        return a * b;
    }
});

const ReducerContextFinalizer = traits.impl(Finalizer(ReducerAllocationContext), struct {
    pub fn finalize(self: *ReducerAllocationContext, succeeded: bool) void {
        if (succeeded) {
            self.leakLast();
        } else {
            self.deinit();
        }
    }
});

const StringReducer = traits.impl(AllocatingReducer([]const u8, ReducerAllocationContext), struct {
    pub const empty: []const u8 = "";
    pub fn init(allocator: std.mem.Allocator) !ReducerAllocationContext {
        return ReducerAllocationContext.init(allocator);
    }
    pub const finalizer = ReducerContextFinalizer;
    pub fn combine(context: *ReducerAllocationContext, a: []const u8, b: []const u8) ![]const u8 {
        var allocator = context.allocator;
        var allocations = &context.allocations;
        var buffer = try allocator.alloc(u8, a.len + b.len);
        errdefer allocator.free(buffer);
        @memcpy(buffer[0..a.len], a);
        @memcpy(buffer[a.len..], b);
        const new_value = try allocations.addOne(allocator);
        new_value.* = buffer;
        return buffer;
    }
});

test "SumReducer combines multiple values" {
    const result = SumReducer.reduce(&.{ 1, 2, 3, 4 });
    try std.testing.expectEqual(10, result);
}

test "ProductReducer combines multiple values" {
    const result = ProductReducer.reduce(&.{ 2, 3 });
    try std.testing.expectEqual(6, result);
}

test "reduce function takes either reducer" {
    const sum = reduce(i32, SumReducer, &.{ 1, 2, 3, 4 });
    const product = reduce(i32, ProductReducer, &.{ 1, 2, 3 });
    try std.testing.expectEqual(10, sum);
    try std.testing.expectEqual(6, product);
}

test "StringReducer concatenates strings using an allocation context" {
    const allocator = std.testing.allocator;
    var context = ReducerAllocationContext.init(allocator);
    defer context.deinit();

    const result = try StringReducer.combine(
        &context,
        "hello",
        " world",
    );

    try std.testing.expectEqualStrings("hello world", result);
    try std.testing.expectEqual(@as(usize, 1), context.allocations.items.len);
}

test "AllocationContext retainLast frees intermediate allocations" {
    const allocator = std.testing.allocator;
    var context = ReducerAllocationContext.init(allocator);
    defer context.deinit();

    _ = try StringReducer.combine(&context, "a", "b");
    const result = try StringReducer.combine(&context, "ab", "c");

    try std.testing.expectEqual(@as(usize, 2), context.allocations.items.len);

    context.retainLast();

    try std.testing.expectEqual(@as(usize, 1), context.allocations.items.len);
    try std.testing.expectEqualStrings("abc", result);
}

test "StringReducer reduces multiple strings using an allocation context" {
    const allocator = std.testing.allocator;

    const result = try StringReducer.reduce(
        allocator,
        &.{ "hello", " ", "world" },
    );

    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "StringReducer cleans up when allocation fails" {
    var failing_allocator = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{
            .fail_index = 0,
        },
    );

    const allocator = failing_allocator.allocator();

    var context = ReducerAllocationContext.init(allocator);
    defer context.deinit();

    const result = StringReducer.combine(
        &context,
        "hello",
        " world",
    );

    try std.testing.expectError(error.OutOfMemory, result);
}

test "StringReducer cleans up when allocation tracking fails" {
    var failing_allocator = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{
            .fail_index = 1,
        },
    );

    const allocator = failing_allocator.allocator();

    var context = ReducerAllocationContext.init(allocator);
    defer context.deinit();

    const result = StringReducer.combine(
        &context,
        "hello",
        " world",
    );

    try std.testing.expectError(error.OutOfMemory, result);
}

test "StringReducer cleans up when allocation fails during reduction" {
    var failing_allocator = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{
            .fail_index = 3,
        },
    );

    const result = StringReducer.reduce(
        failing_allocator.allocator(),
        &.{ "hello", " ", "world" },
    );

    try std.testing.expectError(error.OutOfMemory, result);
}
