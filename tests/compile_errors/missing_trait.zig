const traits = @import("traits");

const OtherTrait = struct {
    value: i32,
};

const MyImplementation = struct {
    pub const unrelated = traits.impl(OtherTrait, struct {
        pub const value: i32 = 42;
    });
};

pub const run = blk: {
    _ = traits.getTrait(
        traits.Convert(i32, i64),
        MyImplementation,
    );

    break :blk {};
};
