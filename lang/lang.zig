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
//
// If statement
//
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
//
// While loops
//
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
//
// For loops
//
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

//
//Functions
//
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

//
// Defer - to execute a statement upon exiting the current block
//
// useful to unsure that resources are cleaned up, add next to the statement that allocates the resource.
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
//
// Errors
//
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
    try expect(err == AllocationError.OutOfMemory);
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
//
// Payload capturing: func often return err unions. |err| receives the value of the error.
//
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
// errdefer works like defer, exec on error inside of the block
var problems: u32 = 98;
fn failFnCounter() error{Oops}!void {
    errdefer problems += 1;
    try failingFunction();
}
test "errdefer" {
    failFnCounter() catch |err| {
        try expect(err == error.Oops);
        try expect(problems == 99);
        return;
    };
}
// error unions return from a fn can have their own err sets
// inferred by not having an explicit err set
// with all possible errors that fn can return
fn createFile() !void {
    return error.AccessDenied;
}
test "inferred error set" {
    // type coercion successfully takes place
    const x: error{AccessDenied}!void = createFile();
    // Zig does not let us ignore err unions via _ = x;
    // way to unwrap it:
    _ = x catch {};
}
const A = error{ NotDir, PathNotFound };
const B = error{ OutOfMemory, PathNotFound };
const C = A || B; // merging of err sets
const D: anyerror = A.NotDir; // global error set can have an error from eny set coerced to it. Avoid it.
//
// Switch - works as statement and an expression.
//
// types of all branches must coerce to the type which is being switched upon.
// All possible vals must have an associated branch - vals cannot be left out.
// Cases cannot fal through to other branches.
test "switch statement" {
    var x: i8 = 10;
    switch (x) {
        -1...1 => {
            x = -x;
        },
        10, 100 => {
            x = @divExact(x, 10); // consideration when dividing signed ints
        },
        else => {}, // required for exhaustiveness, like case _ in python
    }
    try expect(x == 1);
}
//former as switch expression
test "switch expression" {
    var x: i8 = 10;
    x = switch (x) {
        -1...1 => -x,
        10, 100 => @divExact(x, 10),
        else => x,
    };
    try expect(x == 1);
}

//
// Runtime Safety
//
// To find problems during execution. Can be left on, or off.
// Detectable illegal behavior.
test "out of bounds" { // protection from out of bounds
    const a = [3]u8{ 1, 2, 3 };
    var index: u8 = 5;
    // const b = a[index];
    // _ = b;
    _ = a;
    index = index;
}
test "out of bounds, no safety" {
    @setRuntimeSafety(false);
    const a = [3]u8{ 1, 2, 3 };
    var index: u8 = 5;
    const b = a[index];
    _ = b;
    index = index;
}
// Unreachable - statement will not be reached, for advantage of optimizer.
// noreturn, compatible with all other types
test "unreachable" {
    const x: i32 = 1;
    // const y: u32 = if (x == 2) 5 else unreachable;
    // _ = y;
    _ = x;
}
fn asciiToUpper(x: u8) u8 {
    return switch (x) {
        'a'...'z' => x + 'A' - 'a',
        'A'...'Z' => x,
        else => unreachable,
    };
}
test "unreachable switch" {
    try expect(asciiToUpper('a') == 'A');
    try expect(asciiToUpper('A') == 'A');
}
//
// Pointers
//
// cannot have 0 or null val. Syntax *T, where T is the child type.
// referencing: &var, dereferencing: var.*
fn increment(num: *u8) void {
    num.* += 1;
}
test "pointers" {
    var x: u8 = 1;
    increment(&x);
    try expect(x == 2);
}
test "naughty pointer" {
    var x: u16 = 5;
    x -= 5;
    // var y: *u8 = @ptrFromInt(x);
    // y = y;
}
// referencing a const var will yield a const ptr
test "const pointer" {
    const x: u8 = 1;
    var y = &x; // *T coerces to *const T
    // y.* += 1;
    y = &x;
}
// usize and isize - unsigned and signed ints which are the same size as ptrs
test "usize" {
    try expect(@sizeOf(usize) == @sizeOf(*u8));
    try expect(@sizeOf(isize) == @sizeOf(*i8));
}
// Many-Item Pointers - to keep track of buffers which don't have compile-time lengths.
// Syntax: [*]T, not dereferenceable, but Indexable: ptr[0]
// Support Anithmetic: ptr + 1. Item size must be known. Coerces from an array ptr.
// Can be const as Single-Item ptrs
fn doubleAllManypointer(buffer: [*]u8, byte_count: usize) void {
    var i: usize = 0;
    while (i < byte_count) : (i += 1) buffer[i] *= 2;
}
test "many-item pointers" {
    var buffer: [100]u8 = [_]u8{1} ** 100;
    const buffer_ptr: *[100]u8 = &buffer; // single-item ptr to an array

    const buffer_many_ptr: [*]u8 = buffer_ptr; // single-item ptr to arr coerces no many-item ptr of bytes
    doubleAllManypointer(buffer_many_ptr, buffer.len);
    for (buffer) |byte| try expect(byte == 2);

    const first_elem_ptr: *u8 = &buffer_many_ptr[0];
    const first_elem_ptr_2: *u8 = @ptrCast(buffer_many_ptr); // conv to single-item ptr (only if len > 0)
    try expect(first_elem_ptr == first_elem_ptr_2);
}
// Slices - like many-item ptrs with len usize. Syntax []T. Easier to use safely, they store the valid len of the buffer within.
// "fat pointres" - double the size of ptr. For loops work with slices.
// x[n..m] to creat a slice from an array. n - included, m - excluded (like in Python)
fn total(values: []const u8) usize {
    var sum: usize = 0;
    for (values) |v| sum += v;
    return sum;
}
test "slices" {
    const array = [_]u8{ 1, 2, 3, 4, 5 };
    const slice = array[0..3]; // const because fn total doesn't write into it
    try expect(total(slice) == 6);
    // when n and m known at compile time, slicing produces a ptr to an array. *[N]T coerce to a slice []T
    try expect(@TypeOf(slice) == *const [3]u8);
    const slice_to_end = array[0..];
    _ = slice_to_end;
}
//
// Enums - types with a restricted set of names
//
const Direction = enum { north, south, east, west };
const Value = enum(u2) { zero, one, two }; // with an int tag
test "enum ordinal value" {
    try expect(@intFromEnum(Value.zero) == 0); // ordinal starts at 0
    try expect(@intFromEnum(Value.one) == 1);
    try expect(@intFromEnum(Value.two) == 2);
}
const Value2 = enum(u32) {
    hundred = 100, // val overwritten
    thousand = 1000,
    million = 1000000,
    next,
};
test "set enum ordinal value" {
    try expect(@intFromEnum(Value2.hundred) == 100);
    try expect(@intFromEnum(Value2.thousand) == 1000);
    try expect(@intFromEnum(Value2.million) == 1000000);
    try expect(@intFromEnum(Value2.next) == 1000001);
}
// Enum given methods, act as namespaced fn, called with dot syntax.
const Suit = enum {
    clubs,
    spades,
    diamonds,
    hearts,
    pub fn isClubs(self: Suit) bool {
        return self == Suit.clubs;
    }
};
test "enum method" {
    try expect(Suit.clubs.isClubs() == Suit.isClubs(.clubs)); // true/true
    try expect(Suit.spades.isClubs() == Suit.isClubs(.hearts)); // false/false
    try expect(Suit.spades.isClubs() != Suit.isClubs(.clubs)); // false/true
}
// Enum given var and const, act as namespaced globals, unrelated, unattached to instances of the enum type.
const Mode = enum {
    var count: u32 = 0;
    on,
    off,
};
test "hmm" {
    Mode.count += 1;
    try expect(Mode.count == 1);
}
//
// Structs - common composite data type, fixed set of named fields. T{} syntax
//
const Vec3 = struct { x: f32, y: f32, z: f32 };
test "struct usage" {
    const my_vector = Vec3{
        .x = 0,
        .y = 100,
        .z = 50,
    };
    _ = my_vector;
}
test "missing struct field" { // will cause error
    // const my_vector = Vec3{
    //     .x = 0,
    //     .y = 50, // .z is missing
    // };
    // _ = my_vector;
}
// fields with given defaults
const Vec4 = struct { x: f32 = 0, y: f32 = 0, z: f32 = 0, w: f32 = 0 };
test "struct defaults" {
    const my_vector = Vec4{
        .x = 25,
        .y = -50,
    };
    _ = my_vector;
}
// Struct with fn and vars
const Stuff = struct {
    x: i32,
    y: i32,
    fn swap(self: *Stuff) void { // pointer to a struct
        const tmp = self.x; // dereferencing is done automatically
        self.x = self.y;
        self.y = tmp;
    }
};
test "automatic dereference" {
    var thing = Stuff{ .x = 10, .y = 20 };
    thing.swap();
    try expect(thing.x == 20);
    try expect(thing.y == 10);
}
//
// Unions - type to store only one val of many possible typed fields. Cannot be used to reinterpret mem.
//
const Result = union {
    int: i64,
    float: f64,
    bool: bool,
};
test "simple union" {
    var result = Result{ .int = 1234 };
    // result.float = 12.34; // this will cause error, accessing not active field
    result.int = 4321;
}
// Tagged unions - use Enum to detect which field is active.
const Tag = enum { a, b, c };
const Tagged = union(Tag) { a: u8, b: f32, c: bool };
test "switch on tagged union" {
    var value = Tagged{ .b = 1.5 };
    switch (value) { // payload capture to switch on the Tag type
        .a => |*byte| byte.* += 1,
        .b => |*float| float.* *= 2, // pointer capture to mutate values
        .c => |*b| b.* = !b.*,
    }
    try expect(value.b == 3);
}
const Tagged2 = union(enum) { a: u8, b: f32, c: bool }; // tag type can be inferred
const Tagged3 = union(enum) { a: u8, b: f32, c: bool, none }; // void type can be omitted
//
// Integer Rules
//
// Dec, Hex, Octal, and Bin int literals
const dec_int: i32 = 98222;
const hex_int: u8 = 0xff;
const hex_int2: u8 = 0xFF;
const oct_int: u16 = 0o755;
const bin_int: u8 = 0b11110000;
// use underscore as a visual separator
const one_billion: u64 = 1_000_000_000;
const bin_mask: u64 = 0b1_1111_0000;
const permissions: u64 = 0o7_5_5;
const big_addr: u64 = 0xFF80_0000_0000_0000;
// int Widening. Int can coerce to int of another type
test "int widening" {
    const a: u8 = 250;
    const b: u16 = a;
    const c: u32 = b;
    try expect(c == a);
}
// explicit int type conversion
test "@intCast" {
    const x: u64 = 200; // if not out of range
    // const x: u64 = 300; // will cause error
    const y = @as(u8, @intCast(x));
    try expect(@TypeOf(y) == u8);
}
// int by default are not allowed to overflow.
// but Zig provides overflow operators
test "well defined overflow" {
    var a: u8 = 255;
    a +%= 1;
    try expect(a == 0);
}
//
// Floats - @setFloatMode(.Optimized) equivalent to GCC -ffast-math
// Coerces to larger float types.
//
test "float widening" {
    const a: f16 = 0;
    const b: f32 = a;
    const c: f64 = b;
    try expect(c == @as(f128, a));
}
// kinds of literals
const floating_point: f64 = 123.0E+77;
const another_float: f64 = 123.0;
const yet_another: f64 = 123.0e+77;

const hex_floating_point: f64 = 0x103.70p-5;
const another_hex_float: f64 = 0x103.70;
const yet_another_hex_float: f64 = 0x103.70P-5;
// with underscore separators
const lightspeed: f64 = 299_792_458.000_000;
const nanosecond: f64 = 0.000_000_001;
const more_hex: f64 = 0x1234_5678.9ABC_CDEFp-10;
// conv functions: @floatFromInt is safe, @intFromFloat must fit dest type
test "int-float conv" {
    const a: i32 = 500;
    const b = @as(f32, @floatFromInt(a));
    // const c = @as(i8, @intFromFloat(b)); // will cause error
    const c = @as(i32, @intFromFloat(b));
    try expect(c == a);
}
//
// Labelled Blocks - used to yeild values. {} is a val of type void.
//
test "labelled blocks" {
    const count = blk: {
        var sum: u32 = 0;
        var i: u32 = 0;
        while (i < 10) : (i += 1) sum += i;
        break :blk sum;
    };
    try expect(count == 45);
    try expect(@TypeOf(count) == u32);
}
// Labelled Loops - to break and continue to outer loops.
test "nested continue" {
    var count: usize = 0;
    outer: for ([_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 }) |_| {
        for ([_]i32{ 1, 2, 3, 4, 5 }) |_| {
            count += 1;
            continue :outer;
        }
    }
    try expect(count == 8);
}
// Loops as Expressions - like return, break accepts value to yeild from a loop. Else can be used if not break
fn rangeHasNumber(begin: usize, end: usize, number: usize) bool {
    var i = begin;
    return while (i < end) : (i += 1) {
        if (i == number) {
            break true;
        }
    } else false;
}
test "while loop expression" {
    try expect(rangeHasNumber(0, 10, 3));
    // try expect(rangeHasNumber(0, 10, 33)); // this will cause error
}
