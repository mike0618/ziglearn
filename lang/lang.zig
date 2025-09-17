const std = @import("std");
const expect = @import("std").testing.expect;

pub fn main() !void {
    // Assignment
    const constant: i32 = 5; // signed 32-bit constant
    var variable: u32 = 5000; // unsigned 32-bit variable
    variable = 8;

    // @as performs an explicit type coercion
    const inferred_constant = @as(i32, 5);
    var inferred_variable = @as(u32, 5000);
    inferred_variable = 13;

    const a: i32 = undefined; // no known value
    var b: u32 = undefined; // no known value
    b = 21;
    std.debug.print("{d},{d},{d},{d},{d},{d}\n", .{ constant, variable, inferred_constant, inferred_variable, a, b });

    // Arrays
    const arr1 = [5]u8{ 'h', 'e', 'l', 'l', 'o' }; // [size]type{elements}
    const arr2 = [_]u8{ 'w', 'o', 'r', 'l', 'd', '!' }; // _ to infer the size of the array
    std.debug.print("{d},{d}\n", .{ arr1.len, arr2.len }); // print the size of arrays

}
// If statement
test "if statement" {
    const a = true;
    var x: u16 = 0;
    if (a) {
        x += 1;
    } else {
        x += 2;
    }
    try expect(x == 1);
}
// If expression
test "if statement expression" {
    const a = true;
    var x: u16 = 0;
    x += if (a) 1 else 2;
    try expect(x == 1);
}
// While loops
test "while" {
    var i: u8 = 2;
    while (i < 100) {
        i *= 2;
    }
    try expect(i == 128);
}
// With a continue expression
test "while with a continue expression" {
    var sum: u8 = 0;
    var i: u8 = 1;
    while (i <= 10) : (i += 1) {
        sum += i;
    }
    try expect(sum == 55);
}
// With a continue
test "while with continue" {
    var sum: u8 = 0;
    var i: u8 = 0;
    while (i <= 3) : (i += 1) {
        if (i == 2) continue;
        sum += i;
    }
    try expect(sum == 4);
}
// With a break
test "while with break" {
    var sum: u8 = 0;
    var i: u8 = 0;
    while (i <= 3) : (i += 1) {
        if (i == 2) break;
        sum += i;
    }
    try expect(sum == 1);
}
// For loops
test "for" {
    // char literals are equivalent to int literals
    const string = [_]u8{ 'a', 'b', 'c' };
    for (string, 0..) |character, index| {
        _ = character;
        _ = index;
    }
    for (string) |character| {
        _ = character;
    }
    for (string, 0..) |_, index| {
        _ = index;
    }
    for (string) |_| {}
}

//Functions
// All arguments are IMMUTABLE. Var - snake_case, Fn - camelCase
// use _ to ignore vars inside functions
fn addFive(x: u32) u32 {
    return x + 5;
}
test "function" {
    const y = addFive(0);
    try expect(@TypeOf(y) == u32);
    try expect(y == 5);
}
fn fibonacci(n: u16) u16 {
    if (n == 0 or n == 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}
test "function recursion" {
    const x = fibonacci(10);
    try expect(x == 55);
}

// Defer - to execute a statement upon exiting the current block
// useful to unsure that resources are cleaned up, add next to the statement that allcates the resource.
test "defer" {
    var x: i16 = 5;
    {
        defer x += 2;
        try expect(x == 5);
    }
    try expect(x == 7);
}
// Multiple deferss in a single block execute in REVERSE order
test "multi defer" {
    var x: f32 = 5;
    {
        defer x += 2; // second
        defer x /= 2; // first
    }
    try expect(x == 4.5);
}
// Errors
// An error set is like an enum, each err is a value. There are no exceptions in Zig
const FileOpenError = error{
    AccessDenied,
    OutOfMemory,
    FileNotFound,
};
// Error sets coerce to their supersets
const AllocationError = error{OutOfMemory};
test "coerce error from a subset to a superset" {
    const err: FileOpenError = AllocationError.OutOfMemory;
    try expect(err == FileOpenError.OutOfMemory);
}
// use ! to combine err type with another type
// catch used to provide a fallback value, could be noreturn
test "error union" {
    const maybe_error: AllocationError!u16 = 10;
    const no_error = maybe_error catch 0;

    try expect(@TypeOf(no_error) == u16);
    try expect(no_error == 10);
}
// Payload copturing: func often return err unions. |err| receives the value of the error.
fn failingFunction() error{Oops}!void {
    return error.Oops;
}
test "returning an error" {
    failingFunction() catch |err| {
        try expect(err == error.Oops);
        return;
    };
}
// try x; is a shortcut for x catch |err| return err
fn failFn() error{Oops}!i32 {
    try failingFunction();
    return 12;
}
test "try" {
    const v: i32 = failFn() catch |err| {
        try expect(err == error.Oops);
        return;
    };
    try expect(v == 12); // is never reached
}
