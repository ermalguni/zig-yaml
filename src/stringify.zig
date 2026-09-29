const std = @import("std");

const Yaml = @import("Yaml.zig");

pub fn stringify(gpa: std.mem.Allocator, input: anytype, writer: *std.Io.Writer) Yaml.StringifyError!void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const value = try Yaml.Value.encode(arena.allocator(), input);
    try value.stringify(writer, .{});
}
