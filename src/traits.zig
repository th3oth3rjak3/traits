const std = @import("std");

/// Constructs a trait value from an implementation type.
///
/// `Trait` is the trait type to construct. It is typically a struct type
/// containing the fields that define the trait's interface, such as function
/// pointers or associated values.
///
/// `Impl` is a type that provides declarations matching the fields of `Trait`.
/// Each field in `Trait` is populated using the declaration with the same name
/// in `Impl`.
///
/// The construction happens entirely at compile time. The resulting value
/// contains the implementation's declarations in the shape expected by `Trait`.
///
/// This function does not perform runtime interface dispatch or generate a
/// vtable. It simply assembles a value of the requested trait type.
pub fn impl(comptime Trait: type, comptime Impl: type) Trait {
    comptime {
        if (@typeInfo(Trait) != .@"struct") {
            @compileError("trait must be a struct type");
        }

        var result: Trait = undefined;
        for (@typeInfo(Trait).@"struct".field_names) |field_name| {
            @field(result, field_name) = @field(Impl, field_name);
        }
        return result;
    }
}

/// Retrieves a trait value explicitly declared on an implementation type.
///
/// `Trait` is the exact trait type to look for.
///
/// `Impl` is the type whose declarations will be searched. It is expected to
/// contain a declaration whose value has type `Trait`, typically a trait value
/// constructed with `impl`.
///
/// The search is performed at compile time and examines the declarations on
/// `Impl`. The first declaration whose type exactly matches `Trait` is returned.
///
/// If no matching declaration exists, compilation fails with an error
/// identifying the trait type and implementation type.
pub fn getTrait(Trait: type, Impl: type) Trait {
    comptime {
        const decl_names = @typeInfo(Impl).@"struct".decl_names;

        var matches: [decl_names.len][]const u8 = undefined;
        var match_count: usize = 0;
        var result: ?Trait = null;

        for (decl_names) |decl_name| {
            if (@TypeOf(@field(Impl, decl_name)) == Trait) {
                matches[match_count] = decl_name;
                match_count += 1;
                result = @field(Impl, decl_name);
            }
        }

        if (match_count == 0) {
            @compileError(
                "trait " ++ @typeName(Trait) ++
                    " not found on " ++ @typeName(Impl),
            );
        }

        if (match_count > 1) {
            var message: []const u8 =
                "ambiguous trait " ++ @typeName(Trait) ++
                " on " ++ @typeName(Impl) ++
                ". Matching declarations:";

            for (matches[0..match_count]) |name| {
                message = message ++ "\n  - " ++ name;
            }

            @compileError(message);
        }

        return result.?;
    }
}

/// Defines a trait for converting a value from `Input` to `Output`.
///
/// `Input` is the type of the value accepted by the conversion function.
///
/// `Output` is the type of the value produced by the conversion function.
///
/// The returned type describes the conversion interface. An implementation
/// must provide a `convert` function with the signature `fn (Input) Output`.
/// Since the function does not return an error union, this interface represents
/// conversions that do not report errors through their return value.
pub fn Convert(Input: type, Output: type) type {
    return struct {
        convert: fn (Input) Output,
    };
}

/// Defines a trait for converting a value from `Input` to `Output`,
/// where the conversion may fail with an error from `Error`.
///
/// `Input` is the type of the value accepted by the conversion function.
///
/// `Output` is the type of the value produced when the conversion succeeds.
///
/// `Error` is the error set that the conversion function is permitted to
/// return. It must be an error-set type. Use `anyerror` when the implementation
/// should not be restricted to a particular error set.
///
/// The returned type describes the conversion interface. An implementation
/// must provide a `tryConvert` function with the signature
/// `fn (Input) Error!Output`.
pub fn TryConvert(Input: type, Output: type, Error: type) type {
    return struct {
        tryConvert: fn (Input) Error!Output,
    };
}

/// Example custom trait:
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

test "custom Reducer trait supports sum and product implementations" {
    // Implement the trait for addition.
    const Sum = impl(Reducer(i32), struct {
        pub const empty: i32 = 0;

        pub fn combine(a: i32, b: i32) i32 {
            return a + b;
        }
    });

    // Implement the same trait for multiplication.
    const Product = impl(Reducer(i32), struct {
        pub const empty: i32 = 1;

        pub fn combine(a: i32, b: i32) i32 {
            return a * b;
        }
    });

    const values = [_]i32{ 1, 2, 3, 4 };

    try std.testing.expectEqual(10, Sum.reduce(&values));
    try std.testing.expectEqual(24, Product.reduce(&values));

    // Verify the identity values for empty input.
    try std.testing.expectEqual(0, Sum.reduce(&.{}));
    try std.testing.expectEqual(1, Product.reduce(&.{}));
}

fn convertToInt(
    value: anytype,
    comptime conversion: Convert(@TypeOf(value), i64),
) i64 {
    return conversion.convert(value);
}

fn parse(
    comptime T: type,
    value: []const u8,
    comptime conversion: TryConvert(
        []const u8,
        T,
        error{InvalidNumber},
    ),
) error{InvalidNumber}!T {
    return conversion.tryConvert(value);
}

test "Convert supports generic conversion implementations" {
    const I32ToI64 = impl(Convert(i32, i64), struct {
        pub fn convert(value: i32) i64 {
            return @intCast(value);
        }
    });

    const F64ToI64 = impl(Convert(f64, i64), struct {
        pub fn convert(value: f64) i64 {
            return @intFromFloat(value);
        }
    });

    try std.testing.expectEqual(
        @as(i64, 42),
        convertToInt(@as(i32, 42), I32ToI64),
    );

    try std.testing.expectEqual(
        @as(i64, 42),
        convertToInt(@as(f64, 42.75), F64ToI64),
    );
}

test "TryConvert supports successful and failed conversions" {
    const int_parser = impl(
        TryConvert(
            []const u8,
            i64,
            error{InvalidNumber},
        ),
        struct {
            pub fn tryConvert(
                value: []const u8,
            ) error{InvalidNumber}!i64 {
                return std.fmt.parseInt(i64, value, 10) catch
                    error.InvalidNumber;
            }
        },
    );

    try std.testing.expectEqual(
        42,
        try parse(i64, "42", int_parser),
    );

    try std.testing.expectError(
        error.InvalidNumber,
        parse(i64, "not a number", int_parser),
    );
}
