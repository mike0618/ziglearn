// Top-level declaration are order-independent
const print = std.debug.print;
const std = @import("std");
const os = std.os;
const assert = std.debug.assert;
const mem = std.mem;

pub fn main() void {
    // integers
    const one_plus_one: i32 = 1 + 1;
    print("1 + 1 = {}\n", .{one_plus_one});
    // floats
    const seven_div_three: f32 = 7.0 / 3.0;
    print("7.0 / 3.0 = {}\n", .{seven_div_three});
    // boolean
    print("{}\n{}\n{}\n", .{
        true and false,
        true or false,
        !true,
    });
    // optional
    var optional_value: ?[]const u8 = null;
    assert(optional_value == null);
    print("\noptional 1\ntype: {}\nvalue: {?s}\n", .{ @TypeOf(optional_value), optional_value });
    optional_value = "hi";
    assert(optional_value != null);
    print("\noptional 2\ntype: {}\nvalue: {?s}\n", .{ @TypeOf(optional_value), optional_value });
    // error union
    var number_or_error: anyerror!i32 = error.ArgNotFound;
    print("\nerror union 1\ntype: {}\nvalue: {!}\n", .{ @TypeOf(number_or_error), number_or_error });
    number_or_error = 1234;
    print("\nerror union 2\ntype: {}\nvalue: {!}\n", .{ @TypeOf(number_or_error), number_or_error });

    // String Literals and Unicode Code Point Literals
    // single-item Pointers to null-terminated byte arrays.
    // Coerced to Slices and Null-Terminated Pointers
    // Dereferencing converts them to Arrays.
    const bytes = "Hello";
    print("{}\n", .{@TypeOf(bytes)}); // *const [5:0]u8
    print("{d}\n", .{bytes.len}); // 5
    print("{c}\n", .{bytes[1]}); // 'e'
    print("{d}\n", .{bytes[5]}); // 0
    print("{}\n", .{'e' == '\x65'}); // true
    print("{d}\n", .{'\u{1f4a9}'}); // 128169
    print("{u}\n", .{'⚡'});
    print("{}\n", .{mem.eql(u8, "hello", "h\x65llo")}); // true
    const invalid_utf8 = "\xff\xfe"; // non-UTF-8 strings are possible with \xNN notation
    print("0x{x}\n", .{invalid_utf8[1]}); // indexing them returns individual bytes
    // Multiline string literal:
    const hello_world_in_c =
        \\#include <stdio.h>
        \\
        \\int main(int argc, char **argv) {
        \\  printf("herro world\n");
        \\  return 0;
        \\}
    ;
    print("{s}\n", .{hello_world_in_c});
    assignment();
}
// Assignment
const x = 1234; // use const to assign a value to an identifier
fn assignment() void {
    //It works at file scope as well as iside functions
    const y = 5678;
    //Once assigned an identifier cannot be changed.
    // y += 1; // error: cannot assign to const
    var z: i32 = 789; // use var to create a variable, it must be initialized
    z += 1;
    var u: i32 = undefined; // leave a var uninitialized
    u = 1; // undefined can be coerced to any type, could be anything, not a meaningful value.
    print("x={d} y={d} z={d} u={d}\n", .{ x, y, z, u });

    // Destructuring assignment can separate elements of indexable aggregate types (Tuples, Arrays, Vectors)
    var xx: u32 = undefined;
    var yy: u32 = undefined;
    var zz: u32 = undefined;
    const tuple = .{ 1, 2, 3 };
    xx, yy, zz = tuple;
    print("tuple: xx = {}, yy = {}, zz = {}\n", .{ xx, yy, zz });
    const array = [_]u32{ 4, 5, 6 };
    xx, yy, zz = array;
    print("array: xx = {}, yy = {}, zz = {}\n", .{ xx, yy, zz });
    const vector: @Vector(3, u32) = .{ 7, 8, 9 };
    xx, yy, zz = vector;
    print("vector: xx = {}, yy = {}, zz = {}\n", .{ xx, yy, zz });
    // Mixed destructuring
    var xxx: u32 = undefined;
    xxx, var yyy: u32, const zzz = tuple;
    print("tuple: xxx = {}, yyy = {}, zzz = {}\n", .{ xxx, yyy, zzz });
    // yyy is mutable
    yyy = 100;
    print("yyy = {}\n", .{yyy});
    // use _ to throw away unwanted values
    _, xxx, _ = tuple;
    print("xxx = {}\n", .{xxx});
    // A destructure may be prefixed with the comptime -> entire destructure is evaluated at comptime
    // all its vars and expressions are evaluated at comptime
}
