const std = @import("std");
const traits = @import("traits.zig");
pub const impl = traits.impl;
pub const getTrait = traits.getTrait;
pub const Convert = traits.Convert;
pub const TryConvert = traits.TryConvert;

comptime {
    std.testing.refAllDecls(@This());
}
