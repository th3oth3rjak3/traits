
# traits

A small collection of compile-time trait utilities for Zig.

`traits` provides helpers for defining, implementing, and discovering trait-like interfaces using Zig's comptime capabilities.

The goal is to make compile-time abstractions more explicit and reusable, without introducing runtime polymorphism, virtual tables, or a large abstraction framework.

## Overview

Zig provides powerful compile-time programming facilities, including generic functions, type reflection, and compile-time evaluation. These facilities make it possible to express trait-like patterns directly in userland.

This library builds on that idea by providing a small set of reusable utilities:

- **`impl`** — Constructs a trait implementation from a struct containing the required declarations.
- **`getTrait`** — Discovers a trait implementation declared on a type or namespace.
- **`Convert`** — A reusable trait describing conversion between two types.
- **`TryConvert`** — A reusable trait describing a potentially failing conversion between two types, with an explicit error set.

Traits are ordinary Zig types and values. They are explicitly supplied to functions, allowing the compiler to specialize implementations at compile time.

## Example


### Convert

`Convert` describes a conversion from one type to another that does not report errors.

Define an implementation using `impl`:

```zig
const IntToFloat = traits.impl(
    traits.Convert(i32, f64),
    struct {
        pub fn convert(value: i32) f64 {
            return @floatFromInt(value);
        }
    },
);
```

Use the implementation:

```zig
const result = IntToFloat.convert(42);
```

A function can accept the trait as a compile-time parameter:

```zig
fn convertValue(
    value: i32,
    comptime conversion: traits.Convert(i32, f64),
) f64 {
    return conversion.convert(value);
}

const result = convertValue(42, IntToFloat);
```

### TryConvert

`TryConvert` describes a conversion from one type to another that may fail with an error from a specified error set.

Define an implementation using `impl`:

```zig
const ParseInt = traits.impl(
    traits.TryConvert(
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
```

Use the implementation:

```zig
const result = try ParseInt.tryConvert("42");
```

A function can also accept the trait as a compile-time parameter:

```zig
fn tryConvertValue(
    value: []const u8,
    comptime conversion: traits.TryConvert(
        []const u8,
        i64,
        error{InvalidNumber},
    ),
) error{InvalidNumber}!i64 {
    return conversion.tryConvert(value);
}

const result = try tryConvertValue("42", ParseInt);
```


### Trait discovery

Implementations can also be declared on a namespace and discovered with `getTrait`:

```zig
const Conversions = struct {
    pub const int_to_float = IntToFloat;
};

const conversion = traits.getTrait(
    traits.Convert(i32, f64),
    Conversions,
);

const result = conversion.convert(42);
```



### Using traits in generic functions

Traits can be used as compile-time parameters alongside generic types. This allows a function to operate on different input types while requiring an explicit conversion implementation for each type.

```zig
fn toInt(
    value: anytype,
    comptime conversion: traits.Convert(@TypeOf(value), i64),
) i64 {
    return conversion.convert(value);
}
```

For example, define a conversion from `f64` to `i64`:

```zig
const FloatToInt = traits.impl(
    traits.Convert(f64, i64),
    struct {
        pub fn convert(value: f64) i64 {
            return @intFromFloat(value);
        }
    },
);

const result = toInt(@as(f64, 42.0), FloatToInt);
```

The function accepts different input types as long as the caller supplies a matching conversion trait. The implementation is known at compile time, providing static dispatch without runtime interface machinery.



## Philosophy

Traits are an abstraction technique, not a requirement for writing Zig.

Use them when an explicit contract between a generic function and its implementation is useful. They can provide static dispatch and compile-time specialization while keeping implementation choices explicit.

They are not intended to replace ordinary Zig functions, generic programming, or runtime interfaces.

As with other comptime-heavy techniques, excessive specialization can increase compilation time and binary size. Use the abstraction where it provides value.

## Attribution

The ideas behind this library are inspired by **Axel Magnuson's** article:

[We Have Traits at Home](https://www.axelmagn.com/blog/202610-zig-traits/)

In particular, the `impl` and `getTrait` helper patterns and the broader approach to expressing compile-time trait contracts are adapted from his work.

This library is an independent implementation and exploration of those ideas, with additional utilities and experiments.

Thank you to Axel Magnuson for sharing the original work.

## Status

This library is experimental and evolving.

Its initial focus is intentionally small: provide useful compile-time trait utilities that can be reused across Zig projects without imposing a larger framework.

## Compile-fail tests

The compile-fail tests verify that invalid trait usage is rejected by the compiler at compile time. They protect behavior that ordinary successful tests cannot cover: cases where code is expected not to compile.

The current tests cover three invalid cases:

- **Missing trait:** `getTrait` reports an error when the requested trait is not declared on an implementation type.
- **Ambiguous trait:** `getTrait` reports an error when multiple declarations match the requested trait.
- **Missing field:** `impl` reports an error when the implementation is missing a required trait field.

These tests also check the compiler diagnostics, not just whether compilation fails. A test passes only when compilation fails and the expected diagnostic text and source location are present. This helps catch regressions that cause invalid code to fail for an unrelated reason or produce a different diagnostic.

To run the compile-fail tests:

```sh
zig build compile-errors
```

A successful run reports each case as `PASS` and finishes with a summary. If a case unexpectedly compiles, or fails with diagnostics that do not match its expectations, the test is reported as `FAIL`.

These tests complement the regular library tests; they do not replace them.
