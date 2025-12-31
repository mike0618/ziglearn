const std = @import("std");

test "expect addOne adds one to 41" {
    // expect verifies its argument is true
    // try returns an error to notify that the test failed
    try std.testing.expect(addOne(41) == 42);
}
test addOne {
    // a test can be written using an identifier
    // this is a doctest, serves as documentation for addOne
    try std.testing.expect(addOne(41) == 42);
}

fn addOne(number: i32) i32 {
    return number + 1;
}
