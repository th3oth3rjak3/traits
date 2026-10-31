const std = @import("std");
const traits = @import("traits");

/// T can be used to iterate over Elem elements of type
fn Iterator(T: type, Elem: type) type {
    return struct {
        next: fn (*T) ?Elem,
    };
}

/// T can return an Iter iterator over Elem elements
fn Iterable(T: type, Elem: type, Iter: type) type {
    return struct {
        iter: fn (T) IterPair,
        pub const IterPair = struct { impl: Iter, trait: Iterator(Iter, Elem) };
    };
}

const NumberIterator = struct {
    items: []const i32,
    index: usize = 0,
};

const NumberIteratorTrait = traits.impl(
    Iterator(NumberIterator, i32),
    struct {
        pub fn next(iterator: *NumberIterator) ?i32 {
            if (iterator.index >= iterator.items.len) {
                return null;
            }

            const value = iterator.items[iterator.index];
            iterator.index += 1;

            return value;
        }
    },
);

test "Iterator returns elements in sequence" {
    const items = [_]i32{ 10, 20, 30 };

    var iterator = NumberIterator{
        .items = &items,
    };

    try std.testing.expectEqual(
        @as(?i32, 10),
        NumberIteratorTrait.next(&iterator),
    );

    try std.testing.expectEqual(
        @as(?i32, 20),
        NumberIteratorTrait.next(&iterator),
    );

    try std.testing.expectEqual(
        @as(?i32, 30),
        NumberIteratorTrait.next(&iterator),
    );

    try std.testing.expectEqual(
        @as(?i32, null),
        NumberIteratorTrait.next(&iterator),
    );
}

const NumberList = struct {
    items: []const i32,
};

const NumberListIterable = traits.impl(
    Iterable(NumberList, i32, NumberIterator),
    struct {
        pub fn iter(
            list: NumberList,
        ) Iterable(NumberList, i32, NumberIterator).IterPair {
            return .{
                .impl = .{
                    .items = list.items,
                },
                .trait = NumberIteratorTrait,
            };
        }
    },
);
test "Iterable produces an iterator over its elements" {
    const items = [_]i32{ 10, 20, 30 };

    const list = NumberList{
        .items = &items,
    };

    const pair = NumberListIterable.iter(list);
    var iterator = pair.impl;

    for (items) |expected| {
        try std.testing.expectEqual(
            @as(?i32, expected),
            pair.trait.next(&iterator),
        );
    }

    try std.testing.expectEqual(
        @as(?i32, null),
        pair.trait.next(&iterator),
    );
}
