const std = @import("std");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer); // writer to stdout
    const stdout = &stdout_writer.interface;
    const alloc = std.heap.page_allocator;
    const args = try std.process.argsAlloc(alloc); // basic mem arrocator
    defer std.process.argsFree(alloc, args); // mem will be freed after fn return
    if (args.len < 2) return error.ExpectedArgument;
    // argsAlloc after unwrapping the error gives a slice.
    const f = try std.fmt.parseFloat(f32, args[1]);
    const c = (f - 32) * 5 / 9;
    try stdout.print("{d:.1} C\n", .{c}); // digit in string formatting
    try stdout.flush();
}
