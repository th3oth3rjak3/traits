const traits = @import("traits");

const MyTrait = struct {
    first: i32,
    second: i32,
};

const MyImplementation = struct {
    pub const first: i32 = 42;
};

pub const run = blk: {
    _ = traits.impl(MyTrait, MyImplementation);
    break :blk {};
};
