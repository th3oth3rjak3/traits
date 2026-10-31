const traits = @import("traits");

const MyTrait = struct {
    value: i32,
};

const MyImplementation = struct {
    pub const first = traits.impl(MyTrait, struct {
        pub const value = 1;
    });

    pub const second = traits.impl(MyTrait, struct {
        pub const value = 2;
    });
};

pub const run = blk: {
    _ = traits.getTrait(MyTrait, MyImplementation);
    break :blk {};
};
