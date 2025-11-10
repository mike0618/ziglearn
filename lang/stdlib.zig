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
//
// New: std.fs.File.stdout().writer(&out_buf); std.fs.File.stdout().reader(&in_buf);
// Old: std.io.Writer and std.io.Reader - standard IO ways. std.ArrayList(u8) has a writer method.
//
// const ArrayList = std.ArrayList; // already defined above
// const test_alloc = std.testing.allocator;
test "io writer usage" {
    var list: ArrayList(u8) = .empty;
    defer list.deinit(test_alloc);
    const bytes_written = try list.writer(test_alloc).write("Hello World!");
    try expect(bytes_written == 12);
    try expect(eql(u8, list.items, "Hello World!"));
}
// removed in new version! readAllAlloc - max alloc size, if the file is larger -> error.StreamTooLong.
// new: std.Io.Reader / Writer.Allocating and streamRemaining
test "io reader usage" {
    const message = "Hello File";
    const file = try std.fs.cwd().createFile(
        "junk_file3.txt",
        .{ .read = true },
    );
    defer file.close();
    try file.writeAll(message);
    try file.seekTo(0);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(&buffer);
    var aw: std.Io.Writer.Allocating = .init(test_alloc);
    defer aw.deinit();
    _ = try reader.interface.streamRemaining(&aw.writer); // read all -> into aw
    const contents = try aw.toOwnedSlice(); // take ownership
    defer test_alloc.free(contents);
    try expect(eql(u8, contents, message));
}
// removed! std.io.getStdIn() - read until next line (for user input)
// new: std.fs.File.stdin().reader(&buffer) with interface
fn nextLine(reader: *std.Io.Reader) !?[]const u8 {
    // returns a slice into the reader's internal buffer
    const s = reader.takeDelimiterExclusive('\n') catch |e| switch (e) {
        error.EndOfStream => return null, // EOD no more data
        else => return e,
    };
    // trim windows-only carriage return char
    if (@import("builtin").os.tag == .windows) {
        return std.mem.trimRight(u8, s, "\r");
    } else {
        return s;
    }
}
// test "read until next line" {
pub fn userInput() !void {
    // stdout writer buffered
    var out_buf: [512]u8 = undefined;
    var outw = std.fs.File.stdout().writer(&out_buf);
    const out = &outw.interface;
    // stdout reader buffered
    var in_buf: [512]u8 = undefined;
    var inr = std.fs.File.stdin().reader(&in_buf);
    const in = &inr.interface;

    try out.print("Enter your name: ", .{});
    try out.flush();

    if (try nextLine(in)) |input| {
        try out.print("Your name is: \"{s}\"\n", .{input});
        try out.flush();
    }
}
// custom writer that behaves like new std.fs.File.stdout().writer(&buffer) instead of old std.io.Writer
const MyByteList = struct {
    data: [100]u8 = undefined,
    items: []u8 = &[_]u8{},
    const Writer = struct {
        context: *MyByteList,
        pub fn write(self: *const Writer, data: []const u8) !usize {
            return self.context.appendWrite(data);
        }
        pub fn writeAll(self: *const Writer, data: []const u8) !void {
            var written: usize = 0;
            while (written < data.len) {
                written += try self.write(data[written..]);
            }
        }
    };
    fn appendWrite(
        self: *MyByteList,
        data: []const u8,
    ) error{EndOfBuffer}!usize {
        if (self.items.len + data.len > self.data.len) {
            return error.EndOfBuffer;
        }
        @memcpy(
            self.data[self.items.len..][0..data.len],
            data,
        );
        self.items = self.data[0 .. self.items.len + data.len];
        return data.len;
    }
    fn writer(self: *MyByteList) Writer {
        return .{ .context = self };
    }
};
test "custom writer" {
    var bytes = MyByteList{};
    _ = try bytes.writer().write("Hello");
    _ = try bytes.writer().write(" Writer!");
    try expect(eql(u8, bytes.items, "Hello Writer!"));
}

pub fn main() !void {
    try userInput();
}
//
// Formatting. std.fmt - format data to and from strings
//
// const test_alloc = std.testing.allocator; // defined above
test "fmt" {
    const string = try std.fmt.allocPrint(
        test_alloc,
        "{d} + {d} = {d}", // d - digit
        .{ 9, 10, 19 },
    );
    defer test_alloc.free(string);
    try expect(eql(u8, string, "9 + 10 = 19"));
}
// conveniently used similar print method
test "print" {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(test_alloc);
    try list.writer(test_alloc).print(
        "{} + {} = {}",
        .{ 9, 10, 19 },
    );
    try expect(eql(u8, list.items, "9 + 10 = 19"));
}
// std.debug.print works the same, except it writes to stderr and is protected by a mutex
test "hello world" {
    var out_buf: [512]u8 = undefined;
    var outw = std.fs.File.stdout().writer(&out_buf);
    const out = &outw.interface;
    try out.print(
        "Hello, {s}!\n",
        .{"World"},
    );
    // std.debug.print(
    //     "Hello, {s}!\n",
    //     .{"Debug"},
    // );
}
// using {any} for default formatting
test "aray printing" {
    const string = try std.fmt.allocPrint(
        test_alloc,
        "{any} + {any} = {any}",
        .{
            @as([]const u8, &[_]u8{ 1, 4 }),
            @as([]const u8, &[_]u8{ 2, 5 }),
            @as([]const u8, &[_]u8{ 3, 9 }),
        },
    );
    defer test_alloc.free(string);
    try expect(eql(
        u8,
        string,
        "{ 1, 4 } + { 2, 5 } = { 3, 9 }",
    ));
}
// A type with custom formatting. std.fmt can access pub fn. {s} - string format specifier, {} - for array
const Person = struct {
    name: []const u8,
    birth_year: i32,
    death_year: ?i32,
    pub fn format(
        self: Person,
        // comptime fmt: []const u8, // for 0.15.1
        // options: std.fmt.FormatOptions, // for 0.15.1
        writer: anytype,
    ) !void {
        // _ = fmt; // for 0.15.1
        // _ = options; // for 0.15.1
        try writer.print("{s} ({}-", .{
            self.name,
            self.birth_year,
        });
        if (self.death_year) |year| {
            try writer.print("{}", .{year});
        }
        try writer.writeAll(")");
    }
};
test "custom fmt" {
    const john = Person{
        .name = "John Carmack",
        .birth_year = 1970,
        .death_year = null,
    };
    const john_string = try std.fmt.allocPrint(
        test_alloc,
        "{f}", // for 0.15.1
        .{john},
    );
    defer test_alloc.free(john_string);
    // std.debug.print(
    //     "{f}",
    //     .{john},
    // );
    try expect(eql(
        u8,
        john_string,
        "John Carmack (1970-)",
    ));
    const claude = Person{
        .name = "Claude Shannon",
        .birth_year = 1916,
        .death_year = 2001,
    };
    const claude_string = try std.fmt.allocPrint(
        test_alloc,
        "{f}",
        .{claude},
    );
    defer test_alloc.free(claude_string);
    try expect(eql(
        u8,
        claude_string,
        "Claude Shannon (1916-2001)",
    ));
}
//
// JSON
//
// Parse JSON into a Struct
const Place = struct { lat: f32, long: f32 };
test "json parse" {
    const parsed = try std.json.parseFromSlice(
        Place,
        test_alloc,
        \\{ "lat": 40.684540, "long": -74.401422 }
    ,
        .{},
    );
    defer parsed.deinit();
    const place = parsed.value;
    try expect(place.lat == 40.684540);
    try expect(place.long == -74.401422);
}
//using stringify to turn arbitrary data into a string.
// test "json stringify" {
//     const x = Place{
//         .lat = 51.997664,
//         .long = -0.740687,
//     };
//     var buf: [100]u8 = undefined;
//     var fba = std.heap.FixedBufferAllocator.init(&buf);
//     const alloc = fba.allocator();
//     const s = std.json.stringifyAlloc(alloc, x, .{});
//     defer alloc.free(s);
//     try expect(eql(u8, s,
//         \\{"lat":5.199766540527344e1,"long":-7.406870126724243e-1}
//     ));
// }
// JSON parser requires an allocater for JavaScript's string, array, and map types.
test "json parse with strings" {
    const User = struct { name: []u8, age: u16 };
    const parsed = try std.json.parseFromSlice(User, test_alloc,
        \\{ "name": "Joe", "age": 25 }
    , .{});
    defer parsed.deinit();
    const user = parsed.value;
    try expect(eql(u8, user.name, "Joe"));
    try expect(user.age == 25);
}
//
// Random Numbers
//
test "random numbers" {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    const a = rand.float(f32);
    const b = rand.boolean();
    const c = rand.int(u8);
    const d = rand.intRangeAtMost(u8, 0, 255);
    std.debug.print(
        "{any} {any} {any} {any}\n",
        .{ a, b, c, d },
    );
    // _ = .{ a, b, c, d }; // suppress unused constants
}
// cryptographically secure random
test "crypto random numbers" {
    const rand = std.crypto.random;
    const a = rand.float(f32);
    const b = rand.boolean();
    const c = rand.int(u8);
    const d = rand.intRangeAtMost(u8, 0, 255);
    std.debug.print(
        "{any} {any} {any} {any}\n",
        .{ a, b, c, d },
    );
    // _ = .{ a, b, c, d }; // suppress unused constants
}
// std.crypto includes many cryptographic utilities: AES128, AES256, Diffie-Hellman x25519,
// Elliptic curve25519, edwards25519, ristretto25519
// Crypto secure hashing blake2, blake3, Gimli, MD5, sha1, sha2, sha3
// MAC functions: Ghash, Poly1305
// Stream ciphers: ChaCha20IETF, ChaCha20With64BitNonce, XChaCha20IETF, Salsa20, XSalsa20)
//
