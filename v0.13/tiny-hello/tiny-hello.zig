const std = @import("std");
pub fn main() !void {
    var out_buf: [512]u8 = undefined;
    var outw = std.fs.File.stdout().writer(&out_buf);
    const out = &outw.interface;
    try out.print("Hello, World!\n", .{});
    try out.flush();
    std.debug.print("Hello, {s}!{s}{1s}\n", .{ "World", "1" });
}
