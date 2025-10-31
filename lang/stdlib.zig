const std = @import("std");
const expect = std.testing.expect;
//
// Allocators - no alloc behind your back in stdlib
//
// std.heap.page_allocator - basic allocator, asks OS for pages of mem (a sys call, inefficient)
// alloc of byte will reserve kibibytes.
test "allocation" {
    const alloc = std.heap.page_allocator;
    const mem = try alloc.alloc(u8, 100); // alloc 100 bytes as []u8
    defer alloc.free(mem); // common pattern for mem mgmt
    try expect(mem.len == 100);
    try expect(@TypeOf(mem) == []u8);
}
// std.heap.FixedBufferAllocator - alloc mem into a fixed buffer w/o heap alloc.
// useful for performance when heap is not wanted, can run OutOfMemory
test "fixed buffer allocator" {
    var buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const alloc = fba.allocator();
    const mem = try alloc.alloc(u8, 100);
    defer alloc.free(mem);
    try expect(mem.len == 100);
    try expect(@TypeOf(mem) == []u8);
}
// std.heap.ArenaAllocator - takes a child alloc, allocate many times and free once.
// .deinit() frees all mem. alloc.free is no-op here.
test "arena allocator" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    _ = try alloc.alloc(u8, 1);
    _ = try alloc.alloc(u8, 10);
    _ = try alloc.alloc(u8, 100);
}
// alloc and free - for slices.
// create and destroy - for single items
test "allocator create/destroy" {
    const byte = try std.heap.page_allocator.create(u8);
    defer std.heap.page_allocator.destroy(byte);
    byte.* = 128;
}
// GeneralPurposeAllocator - prevents double-free, use-after-free, detects leaks.
// Safety can be turned off via its conf struct
// Designed for safety over performance, but still much faster than page_allocator.
// std.heap.c_allocator - for high performance, but low safety. Requires linking Libc with -lc.
test "GPA" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        // fail test; can't try in defer, it's executed after return
        if (deinit_status == .leak) expect(false) catch @panic("TEST FAIL");
    }
    const bytes = try alloc.alloc(u8, 100);
    defer alloc.free(bytes);
}
//
// std.ArrayList(T) - commonly used buffer that can change size. Similar to C++ std::vector<T> and Rust Vec<T>.
//
const eql = std.mem.eql;
const ArrayList = std.ArrayList;
const test_alloc = std.testing.allocator; // works only in tests to detect mem leaks
test "ArrayList" {
    var list: ArrayList(u8) = .empty;
    defer list.deinit(test_alloc);
    try list.append(test_alloc, 'H');
    try list.append(test_alloc, 'e');
    try list.append(test_alloc, 'l');
    try list.append(test_alloc, 'l');
    try list.append(test_alloc, 'o');
    try list.appendSlice(test_alloc, " World!");
    try expect(eql(u8, list.items, "Hello World!"));
}
//
// Filesystem
//
test "createFile, write, seekTo, read" {
    const file = try std.fs.cwd().createFile(
        "junk_file.txt",
        .{ .read = true },
    );
    defer file.close();
    try file.writeAll("Hello File!");
    var buffer: [100]u8 = undefined;
    try file.seekTo(0); // go back to start of the file
    const bytes_read = try file.readAll(&buffer);
    try expect(eql(u8, buffer[0..bytes_read], "Hello File!"));
}
// std.fs.openFileAbsolute fn also exist.
//
// .stat() to get file info, contains fields .inode .mode
test "file stat" {
    const file = try std.fs.cwd().createFile(
        "junk_file2.txt",
        .{ .read = true },
    );
    defer file.close();
    const stat = try file.stat();
    try expect(stat.size == 0);
    try expect(stat.kind == .file); // when enum type is known from context -> .file instead of Kind.file
    try expect(stat.ctime <= std.time.nanoTimestamp());
    try expect(stat.mtime <= std.time.nanoTimestamp());
    try expect(stat.atime <= std.time.nanoTimestamp());
}
// Make dirs, iterate over them, delete dirs. Iterator usage.
test "Make dir" {
    const dir: []const u8 = "test-tmp";
    try std.fs.cwd().makeDir(dir);
    var iter_dir = try std.fs.cwd().openDir(
        dir,
        .{ .iterate = true },
    );
    defer {
        iter_dir.close();
        std.fs.cwd().deleteTree(dir) catch unreachable;
    }
    _ = try iter_dir.createFile("x", .{});
    _ = try iter_dir.createFile("y", .{});
    _ = try iter_dir.createFile("z", .{});
    var file_count: usize = 0;
    var iter = iter_dir.iterate(); // iterator
    while (try iter.next()) |entry| {
        if (entry.kind == .file) file_count += 1;
    }
    try expect(file_count == 3);
}
