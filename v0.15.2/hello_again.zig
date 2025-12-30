const std = @import("std");

pub fn main() void { // ! can be omitted, no errors are returned
    std.debug.print("Hello, {s}!\n", .{"World"});
}
