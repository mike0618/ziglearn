// Comments
//
// zig test -femit-docs main.zig - experimental generate documentation
//! Top-Level Doc Comment - documents the current module
/// Doc Comment
const std = @import("std");

pub fn main() void {
    // This is a comment
    std.debug.print("Hello, World!\n", .{}); // another comment
}
/// Doc Comments
/// A structure for storing a timestamp, with nanosecond precision
/// (this is a multiline doc comment)
const Timestamp = struct {
    /// The number of seconds since the epoch (doc comment)
    seconds: i64, // signed, so we can represent pre-1970 (not a doc comment)
    /// The number of nanoseconds past the second (doc comment)
    nanos: u32,
    /// Returns a 'Timestamp' struct representing the Unix epoch;
    /// this is the moment of 1970 Jan 1 00:00:00 UTC (doc comment)
    pub fn unixEpoch() Timestamp {
        return Timestamp{
            .seconds = 0,
            .nanos = 0,
        };
    }
};
