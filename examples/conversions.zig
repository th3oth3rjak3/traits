const std = @import("std");
const traits = @import("traits");

/// T can be converted into Out
fn Into(T: type, Out: type) type {
    return struct {
        into: fn (T) Out,
    };
}

/// T can be derived from In
fn From(T: type, In: type) type {
    return struct {
        from: fn (In) T,
    };
}

const IntToFloat = traits.impl(Into(i32, f64), struct {
    pub fn into(value: i32) f64 {
        return @floatFromInt(value);
    }
});

const FloatFromInt = traits.impl(From(f64, i32), struct {
    pub fn from(value: i32) f64 {
        return @floatFromInt(value);
    }
});

test "Into converts an integer to a float" {
    const result = IntToFloat.into(42);

    try std.testing.expectEqual(@as(f64, 42.0), result);
}

test "From constructs a float from an integer" {
    const result = FloatFromInt.from(42);

    try std.testing.expectEqual(@as(f64, 42.0), result);
}

const Conversions = struct {
    pub const int_to_float = IntToFloat;
};

test "traits.getTrait discovers a conversion traits.implementation" {
    const conversion = traits.getTrait(Into(i32, f64), Conversions);

    try std.testing.expectEqual(
        @as(f64, 42.0),
        conversion.into(42),
    );
}
