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
// std.heap.c_allocator - for high performance, but low safety. Requires linking Libc with -lc.
