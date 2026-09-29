const std = @import("std");
const mem = std.mem;
const stringify = @import("../stringify.zig").stringify;
const testing = std.testing;

const Arena = std.heap.ArenaAllocator;
const Yaml = @import("../Yaml.zig");

test "simple list" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const list = yaml.docs.items[0].list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].scalar);
    try testing.expectEqualStrings("b", list[1].scalar);
    try testing.expectEqualStrings("c", list[2].scalar);
}

test "simple list parsed as booleans" {
    const source =
        \\- true
        \\- false
        \\- true
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const parsed = try yaml.parse(arena.allocator(), []const bool);
    try testing.expectEqual(parsed.len, 3);

    try testing.expect(parsed[0]);
    try testing.expect(!parsed[1]);
    try testing.expect(parsed[2]);
}

test "simple list typed as array of strings" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3][]const u8);
    try testing.expectEqual(3, arr.len);
    try testing.expectEqualStrings("a", arr[0]);
    try testing.expectEqualStrings("b", arr[1]);
    try testing.expectEqualStrings("c", arr[2]);
}

test "simple list typed as array of ints" {
    const source =
        \\- 0
        \\- 1
        \\- 2
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3]u8);
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 1, 2 }, &arr);
}

test "list of mixed sign integer" {
    const source =
        \\- 0
        \\- -1
        \\- 2
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3]i8);
    try testing.expectEqualSlices(i8, &[_]i8{ 0, -1, 2 }, &arr);
}

test "several integer bases" {
    const source =
        \\- 10
        \\- -10
        \\- 0x10
        \\- -0X10
        \\- 0o10
        \\- -0O10
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [6]i8);
    try testing.expectEqualSlices(i8, &[_]i8{ 10, -10, 16, -16, 8, -8 }, &arr);
}

test "simple flow sequence / bracket list" {
    const source =
        \\a_key: [a, b, c]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;

    const list = map.get("a_key").?.list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].scalar);
    try testing.expectEqualStrings("b", list[1].scalar);
    try testing.expectEqualStrings("c", list[2].scalar);
}

test "simple flow sequence / bracket list with trailing comma" {
    const source =
        \\a_key: [a, b, c,]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;

    const list = map.get("a_key").?.list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].scalar);
    try testing.expectEqualStrings("b", list[1].scalar);
    try testing.expectEqualStrings("c", list[2].scalar);
}

test "simple flow sequence / bracket list with invalid comment" {
    const source =
        \\a_key: [a, b, c]#invalid
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    const err = yaml.load(testing.allocator);

    try std.testing.expectError(error.ParseFailure, err);
}

test "simple flow sequence / bracket list with double trailing commas" {
    const source =
        \\a_key: [a, b, c,,]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    const err = yaml.load(testing.allocator);

    try std.testing.expectError(error.ParseFailure, err);
}

test "more bools" {
    const source =
        \\- false
        \\- true
        \\- off
        \\- on
        \\- no
        \\- yes
        \\- n
        \\- y
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [8]bool);
    try testing.expectEqualSlices(bool, &[_]bool{
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
    }, &arr);
}

test "invalid enum" {
    const TestEnum = enum {
        alpha,
        bravo,
        charlie,
    };

    const source =
        \\- delta
        \\- echo
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const result = yaml.parse(arena.allocator(), [2]TestEnum);
    try testing.expectError(Yaml.Error.InvalidEnum, result);
}

test "simple map untyped" {
    const source =
        \\a: 0
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
}

test "simple map untyped with a list of maps" {
    const source =
        \\a: 0
        \\b:
        \\  - foo: 1
        \\    bar: 2
        \\  - foo: 3
        \\    bar: 4
        \\c: 1
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
    try testing.expectEqualStrings("2", map.get("b").?.list[0].map.get("bar").?.scalar);
    try testing.expectEqualStrings("3", map.get("b").?.list[1].map.get("foo").?.scalar);
    try testing.expectEqualStrings("4", map.get("b").?.list[1].map.get("bar").?.scalar);
}

test "simple map untyped with a list of maps. no indent" {
    const source =
        \\b:
        \\- foo: 1
        \\c: 1
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
}

test "simple map untyped with a list of maps. no indent 2" {
    const source =
        \\a: 0
        \\b:
        \\- foo: 1
        \\  bar: 2
        \\- foo: 3
        \\  bar: 4
        \\c: 1
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
    try testing.expectEqualStrings("2", map.get("b").?.list[0].map.get("bar").?.scalar);
    try testing.expectEqualStrings("3", map.get("b").?.list[1].map.get("foo").?.scalar);
    try testing.expectEqualStrings("4", map.get("b").?.list[1].map.get("bar").?.scalar);
}

test "simple map typed" {
    const source =
        \\a: 0
        \\b: hello there
        \\c: 'wait, what?'
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct { a: usize, b: []const u8, c: []const u8 });
    try testing.expectEqual(@as(usize, 0), simple.a);
    try testing.expectEqualStrings("hello there", simple.b);
    try testing.expectEqualStrings("wait, what?", simple.c);
}

test "typed nested structs" {
    const source =
        \\a:
        \\  b: hello there
        \\  c: 'wait, what?'
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        a: struct {
            b: []const u8,
            c: []const u8,
        },
    });
    try testing.expectEqualStrings("hello there", simple.a.b);
    try testing.expectEqualStrings("wait, what?", simple.a.c);
}

test "typed union with nested struct" {
    const source =
        \\a:
        \\  b: hello there
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), union(enum) {
        tag_a: struct {
            a: struct {
                b: []const u8,
            },
        },
        tag_c: struct {
            c: struct {
                d: []const u8,
            },
        },
    });
    try testing.expectEqualStrings("hello there", simple.tag_a.a.b);
}

test "typed union with nested struct 2" {
    const source =
        \\c:
        \\  d: hello there
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), union(enum) {
        tag_a: struct {
            a: struct {
                b: []const u8,
            },
        },
        tag_c: struct {
            c: struct {
                d: []const u8,
            },
        },
    });
    try testing.expectEqualStrings("hello there", simple.tag_c.c.d);
}

test "single quoted string" {
    const source =
        \\- 'hello'
        \\- 'here''s an escaped quote'
        \\- 'newlines and tabs\nare not\tsupported'
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3][]const u8);
    try testing.expectEqual(arr.len, 3);
    try testing.expectEqualStrings("hello", arr[0]);
    try testing.expectEqualStrings("here's an escaped quote", arr[1]);
    try testing.expectEqualStrings("newlines and tabs\\nare not\\tsupported", arr[2]);
}

test "double quoted string" {
    const source =
        \\- "hello"
        \\- "\"here\" are some escaped quotes"
        \\- "newlines and tabs\nare\tsupported"
        \\- "let's have
        \\some fun!"
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [4][]const u8);
    try testing.expectEqual(arr.len, 4);
    try testing.expectEqualStrings("hello", arr[0]);
    try testing.expectEqualStrings(
        \\"here" are some escaped quotes
    , arr[1]);
    try testing.expectEqualStrings("newlines and tabs\nare\tsupported", arr[2]);
    try testing.expectEqualStrings(
        \\let's have
        \\some fun!
    , arr[3]);
}

test "commas in string" {
    const source =
        \\a: 900,50,50
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        a: []const u8,
    });
    try testing.expectEqualStrings("900,50,50", simple.a);
}

test "multidoc typed as a slice of structs" {
    const source =
        \\---
        \\a: 0
        \\---
        \\a: 1
        \\...
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    {
        const result = try yaml.parse(arena.allocator(), [2]struct { a: usize });
        try testing.expectEqual(result.len, 2);
        try testing.expectEqual(result[0].a, 0);
        try testing.expectEqual(result[1].a, 1);
    }

    {
        const result = try yaml.parse(arena.allocator(), []struct { a: usize });
        try testing.expectEqual(result.len, 2);
        try testing.expectEqual(result[0].a, 0);
        try testing.expectEqual(result[1].a, 1);
    }
}

test "multidoc typed as a struct is an error" {
    const source =
        \\---
        \\a: 0
        \\---
        \\b: 1
        \\...
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), struct { a: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), struct { b: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), struct { a: usize, b: usize }));
}

test "multidoc typed as a slice of structs with optionals" {
    const source =
        \\---
        \\a: 0
        \\c: 1.0
        \\---
        \\a: 1
        \\b: different field
        \\...
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const result = try yaml.parse(arena.allocator(), []struct { a: usize, b: ?[]const u8, c: ?f16 });
    try testing.expectEqual(result.len, 2);

    try testing.expectEqual(result[0].a, 0);
    try testing.expect(result[0].b == null);
    try testing.expect(result[0].c != null);
    try testing.expectEqual(result[0].c.?, 1.0);

    try testing.expectEqual(result[1].a, 1);
    try testing.expect(result[1].b != null);
    try testing.expectEqualStrings("different field", result[1].b.?);
    try testing.expect(result[1].c == null);
}

test "empty yaml can be represented as void" {
    const source = "";

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const result = try yaml.parse(arena.allocator(), void);
    try testing.expect(@TypeOf(result) == void);
}

test "nonempty yaml cannot be represented as void" {
    const source =
        \\a: b
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), void));
}

test "typed array size mismatch" {
    const source =
        \\- 0
        \\- 0
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse(arena.allocator(), [1]usize));
    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse(arena.allocator(), [5]usize));
}

test "comments" {
    const source =
        \\
        \\key: # this is the key
        \\# first value
        \\
        \\- val1
        \\
        \\# second value
        \\- val2
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        key: []const []const u8,
    });
    try testing.expect(simple.key.len == 2);
    try testing.expectEqualStrings("val1", simple.key[0]);
    try testing.expectEqualStrings("val2", simple.key[1]);
}

test "promote ints to floats in a list mixed numeric types" {
    const source =
        \\a_list: [0, 1.0]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        a_list: []const f64,
    });
    try testing.expectEqualSlices(f64, &[_]f64{ 0.0, 1.0 }, simple.a_list);
}

test "demoting floats to ints in a list is an error" {
    const source =
        \\a_list: [0, 1.0]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(error.InvalidCharacter, yaml.parse(arena.allocator(), struct {
        a_list: []const u64,
    }));
}

test "duplicate map keys" {
    const source =
        \\a: b
        \\a: c
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try testing.expectError(error.DuplicateMapKey, yaml.load(testing.allocator));
}

fn testStringify(expected: []const u8, input: anytype) !void {
    var writer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer writer.deinit();

    try stringify(testing.allocator, input, &writer.writer);
    try testing.expectEqualStrings(expected, writer.written());
}

test "stringify an int" {
    try testStringify("128", @as(u32, 128));
}

test "stringify a simple struct" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , struct { a: i64, b: f64, c: f64 }{ .a = 1, .b = 2.0, .c = 2.5 });
}

test "stringify a struct with an optional" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , struct { a: i64, b: ?f64, c: f64 }{ .a = 1, .b = 2.0, .c = 2.5 });

    try testStringify(
        \\a: 1
        \\b: null
        \\c: 2.5
    , struct { a: i64, b: ?f64, c: f64 }{ .a = 1, .b = null, .c = 2.5 });
}

test "stringify a struct with all optionals" {
    try testStringify(
        \\a: null
        \\b: null
    , struct { a: ?i64, b: ?f64 }{ .a = null, .b = null });
}

test "stringify an optional" {
    try testStringify("null", null);
    try testStringify("null", @as(?u64, null));
}

test "stringify a union" {
    const Dummy = union(enum) {
        x: u64,
        y: f64,
    };
    try testStringify("a: 1", struct { a: Dummy }{ .a = .{ .x = 1 } });
    try testStringify("a: 2.1", struct { a: Dummy }{ .a = .{ .y = 2.1 } });
}

test "stringify a string" {
    try testStringify("a: name", struct { a: []const u8 }{ .a = "name" });
    try testStringify("name", "name");
}

test "stringify a list" {
    try testStringify("[ 1, 2, 3 ]", @as([]const u64, &.{ 1, 2, 3 }));
    try testStringify("[ 1, 2, 3 ]", .{ @as(i64, 1), 2, 3 });
    try testStringify("[ 1, name, 3 ]", .{ 1, "name", 3 });

    const arr: [3]i64 = .{ 1, 2, 3 };
    try testStringify("[ 1, 2, 3 ]", arr);
}

test "pointer of a value" {
    const TestStruct = struct {
        a: usize,
        b: i64,
        c: u12,
        d: ?*const @This() = null,
    };

    const source =
        \\a: 1
        \\b: 2
        \\c: 3
        \\d:
        \\  a: 4
        \\  b: 5
        \\  c: 6
    ;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var yaml = Yaml{ .source = source };
    try yaml.load(arena.allocator());

    const parsed = try yaml.parse(arena.allocator(), *TestStruct);
    try testing.expectEqual(1, parsed.a);
    try testing.expectEqual(2, parsed.b);
    try testing.expectEqual(3, parsed.c);
    try testing.expectEqual(4, parsed.d.?.a);
    try testing.expectEqual(5, parsed.d.?.b);
    try testing.expectEqual(6, parsed.d.?.c);
    try testing.expectEqual(@as(?*const TestStruct, null), parsed.d.?.d);
}

test "struct default value test" {
    const TestStruct = struct {
        a: i32,
        b: ?[]const u8 = "test",
        c: ?u8 = 5,
        d: u8 = 12,
    };

    const TestCase = struct {
        yaml: []const u8,
        container: TestStruct,
    };

    const tcs = [_]TestCase{
        .{
            .yaml =
            \\---
            \\a: 1
            \\b: "asd"
            \\c: 3
            \\d: 1
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "asd",
                .c = 3,
                .d = 1,
            },
        },
        .{
            .yaml =
            \\---
            \\a: 1
            \\c: 3
            \\d: 1
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "test",
                .c = 3,
                .d = 1,
            },
        },
        .{
            .yaml =
            \\---
            \\a: 1
            \\b: "asd"
            \\d: 1
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "asd",
                .c = 5,
                .d = 1,
            },
        },
        .{
            .yaml =
            \\---
            \\a: 1
            \\b: "asd"
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "asd",
                .c = 5,
                .d = 12,
            },
        },
    };

    for (&tcs) |tc| {
        var arena = std.heap.ArenaAllocator.init(testing.allocator);
        defer arena.deinit();
        var yamlParser = Yaml{ .source = tc.yaml };
        try yamlParser.load(arena.allocator());
        const parsed = try yamlParser.parse(arena.allocator(), TestStruct);
        try testing.expectEqual(tc.container.a, parsed.a);
        try testing.expectEqualDeep(tc.container.b, parsed.b);
        try testing.expectEqual(tc.container.c, parsed.c);
        try testing.expectEqual(tc.container.d, parsed.d);
    }
}

test "enums" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    const Enum = enum { a, b, c };

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const parsed = try yaml.parse(arena.allocator(), []const Enum);
    try testing.expectEqualDeep(&[_]Enum{
        .a,
        .b,
        .c,
    }, parsed);
}

test "stringify a bool" {
    try testStringify("false", false);
    try testStringify("true", true);
}

test "stringify an enum" {
    const TestEnum = enum {
        alpha,
        bravo,
        charlie,
    };

    try testStringify("alpha", TestEnum.alpha);
    try testStringify("bravo", TestEnum.bravo);
    try testStringify("charlie", TestEnum.charlie);
}

test "parse struct as list of structs" {
    const source =
        \\a: 1
    ;

    const Struct = struct { a: u32 };

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const result = yaml.parse(arena.allocator(), []Struct);
    try testing.expectError(error.TypeMismatch, result);

    const parsed = try yaml.parse(arena.allocator(), Struct);
    try testing.expectEqualDeep(Struct{ .a = 1 }, parsed);
}

test "unsupported YAML references and merge keys" {
    const cases = [_]struct {
        source: []const u8,
        expected: anyerror,
    }{
        .{
            .source = "image: &image nginx:alpine\n",
            .expected = error.UnsupportedAnchor,
        },
        .{
            .source = "command: [*command]\n",
            .expected = error.UnsupportedAlias,
        },
        .{
            .source = "first: value\n&key second: value\n",
            .expected = error.UnsupportedAnchor,
        },
        .{
            .source = "first: value\n*key: value\n",
            .expected = error.UnsupportedAlias,
        },
        .{
            .source = "service:\n  <<:\n    image: nginx:alpine\n",
            .expected = error.UnsupportedMergeKey,
        },
    };

    for (cases) |case| {
        var yaml: Yaml = .{ .source = case.source };
        defer yaml.deinit(testing.allocator);

        try testing.expectError(
            case.expected,
            yaml.load(testing.allocator),
        );
    }
}

test "reference punctuation remains scalar content" {
    const source =
        \\# &anchor *alias <<:
        \\anchor: "&literal"
        \\alias: '*literal'
        \\merge: <<
        \\command: echo &literal *literal
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    const map = yaml.docs.items[0].map;

    try testing.expectEqualStrings(
        "&literal",
        map.get("anchor").?.scalar,
    );
    try testing.expectEqualStrings(
        "*literal",
        map.get("alias").?.scalar,
    );
    try testing.expectEqualStrings(
        "<<",
        map.get("merge").?.scalar,
    );
    try testing.expectEqualStrings(
        "echo &literal *literal",
        map.get("command").?.scalar,
    );
}

test "block scalar preserves interpolation braces" {
    var document: Yaml = .{
        .source = "image: nginx:${TAG}\ncommand: [echo, hello]\n",
    };
    defer document.deinit(testing.allocator);
    try document.load(testing.allocator);

    const map = document.docs.items[0].map;
    try testing.expectEqualStrings(
        "nginx:${TAG}",
        map.get("image").?.scalar,
    );

    const command = map.get("command").?.list;
    try testing.expectEqual(@as(usize, 2), command.len);
    try testing.expectEqualStrings("hello", command[1].scalar);
}

test "empty mapping values preserve sibling and ancestor keys" {
    const source =
        \\outer:
        \\  first:
        \\  second: value
        \\  last:
        \\items:
        \\- one
        \\- two
        \\next: sibling
    ;

    var document: Yaml = .{ .source = source };
    defer document.deinit(testing.allocator);
    try document.load(testing.allocator);

    const root = document.docs.items[0].map;
    const outer = root.get("outer").?.map;

    try testing.expect(outer.get("first").? == .null);
    try testing.expectEqualStrings("value", outer.get("second").?.scalar);
    try testing.expect(outer.get("last").? == .null);
    try testing.expectEqualStrings("sibling", root.get("next").?.scalar);

    const items = root.get("items").?.list;
    try testing.expectEqual(@as(usize, 2), items.len);
    try testing.expectEqualStrings("one", items[0].scalar);
    try testing.expectEqualStrings("two", items[1].scalar);
}

test "unindented scalar is not a mapping value" {
    var document: Yaml = .{ .source = "a:\nb\n" };
    defer document.deinit(testing.allocator);

    try testing.expectError(
        error.ParseFailure,
        document.load(testing.allocator),
    );
}

test "null spellings resolve at the root and in collections" {
    for ([_][]const u8{ "null", "Null", "NULL", "~" }) |source| {
        var yaml: Yaml = .{ .source = source };
        defer yaml.deinit(testing.allocator);
        try yaml.load(testing.allocator);
        try testing.expectEqual(@as(usize, 1), yaml.docs.items.len);
        try testing.expect(yaml.docs.items[0] == .null);
        try testing.expectEqual(@as(?i32, null), try yaml.parse(testing.allocator, ?i32));
    }

    var yaml: Yaml = .{ .source =
        \\lower: null
        \\title: Null
        \\upper: NULL
        \\tilde: ~
        \\list: [null, Null, NULL, ~]
    };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    const map = yaml.docs.items[0].map;
    for ([_][]const u8{ "lower", "title", "upper", "tilde" }) |key| {
        try testing.expect(map.get(key).? == .null);
    }
    const list = map.get("list").?.list;
    try testing.expectEqual(@as(usize, 4), list.len);
    for (list) |item| try testing.expect(item == .null);
}

test "quoted null spellings empty strings and mixed case remain strings" {
    const cases = [_]struct { source: []const u8, expected: []const u8 }{
        .{ .source = "'null'", .expected = "null" },
        .{ .source = "\"null\"", .expected = "null" },
        .{ .source = "'Null'", .expected = "Null" },
        .{ .source = "\"Null\"", .expected = "Null" },
        .{ .source = "'NULL'", .expected = "NULL" },
        .{ .source = "\"NULL\"", .expected = "NULL" },
        .{ .source = "'~'", .expected = "~" },
        .{ .source = "\"~\"", .expected = "~" },
        .{ .source = "''", .expected = "" },
        .{ .source = "\"\"", .expected = "" },
        .{ .source = "nUlL", .expected = "nUlL" },
        .{ .source = "nullish", .expected = "nullish" },
    };
    for (cases) |case| {
        var yaml: Yaml = .{ .source = case.source };
        defer yaml.deinit(testing.allocator);
        try yaml.load(testing.allocator);
        try testing.expectEqualStrings(case.expected, yaml.docs.items[0].scalar);
        var arena = Arena.init(testing.allocator);
        defer arena.deinit();
        const parsed = try yaml.parse(arena.allocator(), ?[]const u8);
        try testing.expect(parsed != null);
        try testing.expectEqualStrings(case.expected, parsed.?);
    }
}

test "null decodes to every optional type and rejects nonoptional destinations" {
    const Choice = enum { selected };
    const Record = struct { value: i32 };
    var yaml: Yaml = .{ .source = "null" };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    inline for (.{ i32, u32, f64, bool, []const u8, Choice, Record, [2]i32, []const i32, *i32, *const Record, ?i32 }) |T| {
        try testing.expectEqual(@as(?T, null), try yaml.parse(arena.allocator(), ?T));
        if (@typeInfo(T) != .optional) {
            try testing.expectError(error.TypeMismatch, yaml.parse(arena.allocator(), T));
        }
    }
    try testing.expectError(error.TypeMismatch, yaml.parse(arena.allocator(), void));
}

test "non-null optionals retain scalar and compound values" {
    const Choice = enum { selected };
    const Record = struct { value: i32 };
    const Config = struct {
        signed: ?i32,
        unsigned: ?u32,
        float: ?f64,
        boolean: ?bool,
        string: ?[]const u8,
        choice: ?Choice,
        record: ?Record,
        array: ?[2]i32,
        slice: ?[]const i32,
        pointer: ?*i32,
        record_pointer: ?*const Record,
        nested: ??i32,
    };
    var yaml: Yaml = .{ .source =
        \\signed: -7
        \\unsigned: 7
        \\float: 1.25
        \\boolean: false
        \\string: "null"
        \\choice: selected
        \\record:
        \\  value: 8
        \\array: [1, 2]
        \\slice: [3, 4]
        \\pointer: 9
        \\record_pointer:
        \\  value: 10
        \\nested: 11
    };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    var arena = Arena.init(testing.allocator);
    defer arena.deinit();
    const parsed = try yaml.parse(arena.allocator(), Config);
    try testing.expectEqual(@as(i32, -7), parsed.signed.?);
    try testing.expectEqual(@as(u32, 7), parsed.unsigned.?);
    try testing.expectEqual(@as(f64, 1.25), parsed.float.?);
    try testing.expectEqual(false, parsed.boolean.?);
    try testing.expectEqualStrings("null", parsed.string.?);
    try testing.expectEqual(Choice.selected, parsed.choice.?);
    try testing.expectEqual(@as(i32, 8), parsed.record.?.value);
    try testing.expectEqualSlices(i32, &.{ 1, 2 }, &parsed.array.?);
    try testing.expectEqualSlices(i32, &.{ 3, 4 }, parsed.slice.?);
    try testing.expectEqual(@as(i32, 9), parsed.pointer.?.*);
    try testing.expectEqual(@as(i32, 10), parsed.record_pointer.?.value);
    try testing.expectEqual(@as(i32, 11), parsed.nested.?.?);
}

test "missing fields use defaults but explicit and omitted null values override them" {
    const Config = struct {
        missing: ?i32 = 12,
        explicit: ?i32 = 13,
        omitted: ?i32 = 14,
        absent: ?i32,
        text: ?[]const u8 = "default",
        required: i32 = 15,
    };
    var yaml: Yaml = .{ .source =
        \\explicit: null
        \\omitted:
        \\text: ~
    };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    var arena = Arena.init(testing.allocator);
    defer arena.deinit();
    const parsed = try yaml.parse(arena.allocator(), Config);
    try testing.expectEqual(@as(?i32, 12), parsed.missing);
    try testing.expect(parsed.explicit == null);
    try testing.expect(parsed.omitted == null);
    try testing.expect(parsed.absent == null);
    try testing.expect(parsed.text == null);
    try testing.expectEqual(@as(i32, 15), parsed.required);

    var nonoptional: Yaml = .{ .source = "required: null" };
    defer nonoptional.deinit(testing.allocator);
    try nonoptional.load(testing.allocator);
    try testing.expectError(error.TypeMismatch, nonoptional.parse(arena.allocator(), Config));
}

test "explicit empty documents are null while empty streams have no documents" {
    for ([_][]const u8{ "", " \n# comment\n" }) |source| {
        var yaml: Yaml = .{ .source = source };
        defer yaml.deinit(testing.allocator);
        try yaml.load(testing.allocator);
        try testing.expectEqual(@as(usize, 0), yaml.docs.items.len);
        try testing.expectError(error.TypeMismatch, yaml.parse(testing.allocator, ?i32));
    }
    for ([_][]const u8{ "---", "---\n", "---\n# empty\n", "---\n...\n" }) |source| {
        var yaml: Yaml = .{ .source = source };
        defer yaml.deinit(testing.allocator);
        try yaml.load(testing.allocator);
        try testing.expectEqual(@as(usize, 1), yaml.docs.items.len);
        try testing.expect(yaml.docs.items[0] == .null);
        try testing.expectEqual(@as(?i32, null), try yaml.parse(testing.allocator, ?i32));
    }
}

test "empty documents and mapping values stop at document boundaries" {
    var yaml: Yaml = .{ .source =
        \\---
        \\---
        \\value:
        \\---
        \\...
        \\---
        \\value: 7
        \\...
    };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    try testing.expectEqual(@as(usize, 4), yaml.docs.items.len);
    try testing.expect(yaml.docs.items[0] == .null);
    try testing.expect(yaml.docs.items[1].map.get("value").? == .null);
    try testing.expect(yaml.docs.items[2] == .null);
    try testing.expectEqualStrings("7", yaml.docs.items[3].map.get("value").?.scalar);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();
    const parsed = try yaml.parse(arena.allocator(), []const ?struct { value: ?i32 });
    try testing.expectEqual(@as(usize, 4), parsed.len);
    try testing.expect(parsed[0] == null);
    try testing.expect(parsed[1].?.value == null);
    try testing.expect(parsed[2] == null);
    try testing.expectEqual(@as(?i32, 7), parsed[3].?.value);
}

test "empty block items preserve positions across nesting and indentless sequences" {
    var yaml: Yaml = .{ .source =
        \\items:
        \\- # first empty item
        \\- 2
        \\-
        \\nested:
        \\  -
        \\  - value:
        \\    next: 3
        \\  -
        \\    - null
        \\    -
        \\after:
    };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    const map = yaml.docs.items[0].map;
    const items = map.get("items").?.list;
    try testing.expectEqual(@as(usize, 3), items.len);
    try testing.expect(items[0] == .null);
    try testing.expectEqualStrings("2", items[1].scalar);
    try testing.expect(items[2] == .null);
    const nested = map.get("nested").?.list;
    try testing.expectEqual(@as(usize, 3), nested.len);
    try testing.expect(nested[0] == .null);
    try testing.expect(nested[1].map.get("value").? == .null);
    try testing.expectEqualStrings("3", nested[1].map.get("next").?.scalar);
    try testing.expectEqual(@as(usize, 2), nested[2].list.len);
    for (nested[2].list) |item| try testing.expect(item == .null);
    try testing.expect(map.get("after").? == .null);
}

test "empty final block items stop at document markers and end of input" {
    for ([_][]const u8{ "-", "-\n", "- # empty\n", "---\n-\n...\n" }) |source| {
        var yaml: Yaml = .{ .source = source };
        defer yaml.deinit(testing.allocator);
        try yaml.load(testing.allocator);
        const list = yaml.docs.items[0].list;
        try testing.expectEqual(@as(usize, 1), list.len);
        try testing.expect(list[0] == .null);
    }
    var yaml: Yaml = .{ .source = "---\n-\n---\n- 4\n" };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    try testing.expectEqual(@as(usize, 2), yaml.docs.items.len);
    try testing.expectEqual(@as(usize, 1), yaml.docs.items[0].list.len);
    try testing.expect(yaml.docs.items[0].list[0] == .null);
    try testing.expectEqualStrings("4", yaml.docs.items[1].list[0].scalar);
}

test "mixed null list positions survive typed arrays slices and serialization" {
    const expected = [_]?i32{ null, 1, null, -2, null };
    for ([_][]const u8{ "[null, 1, ~, -2, NULL]", "-\n- 1\n- Null\n- -2\n-" }) |source| {
        var yaml: Yaml = .{ .source = source };
        defer yaml.deinit(testing.allocator);
        try yaml.load(testing.allocator);
        var arena = Arena.init(testing.allocator);
        defer arena.deinit();
        const array = try yaml.parse(arena.allocator(), [5]?i32);
        try testing.expectEqualSlices(?i32, &expected, &array);
        const slice = try yaml.parse(arena.allocator(), []const ?i32);
        try testing.expectEqualSlices(?i32, &expected, slice);
        try testing.expectError(error.TypeMismatch, yaml.parse(arena.allocator(), []const i32));
        try testing.expectError(error.TypeMismatch, yaml.parse(arena.allocator(), [5]i32));
    }
    try testStringify("[ null, 1, null, -2, null ]", expected);
    try testStringify("[ null, 1, null, -2, null ]", @as([]const ?i32, &expected));
}

test "encode preserves null roots fields and tuple array slice positions" {
    var arena = Arena.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try testing.expect(try Yaml.Value.encode(allocator, null) == .null);
    try testing.expect(try Yaml.Value.encode(allocator, @as(?i32, null)) == .null);
    const nested_null: ?i32 = null;
    const present_null: ??i32 = nested_null;
    try testing.expect(present_null != null);
    try testing.expect(try Yaml.Value.encode(allocator, present_null) == .null);
    try testStringify("null", present_null);

    const array = [_]?i32{ null, 2, null };
    inline for (.{ .{ null, @as(?i32, 2), @as(?i32, null) }, array, @as([]const ?i32, &array) }) |input| {
        const encoded = try Yaml.Value.encode(allocator, input);
        try testing.expectEqual(@as(usize, 3), encoded.list.len);
        try testing.expect(encoded.list[0] == .null);
        try testing.expectEqualStrings("2", encoded.list[1].scalar);
        try testing.expect(encoded.list[2] == .null);
    }
    const encoded = try Yaml.Value.encode(allocator, struct { a: ?i32, b: ?i32 }{ .a = null, .b = 3 });
    try testing.expectEqual(@as(usize, 2), encoded.map.count());
    try testing.expect(encoded.map.get("a").? == .null);
    try testing.expectEqualStrings("3", encoded.map.get("b").?.scalar);
    try testStringify("[ null, 2, null ]", .{ null, @as(?i32, 2), @as(?i32, null) });
}

test "raw serializer roundtrip preserves nulls and null-looking strings" {
    var yaml: Yaml = .{ .source =
        \\actual: null
        \\omitted:
        \\strings: ["null", 'Null', "NULL", '~', "", nUlL]
        \\mixed: [null, "null", "", ~]
    };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    var writer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer writer.deinit();
    try yaml.stringify(&writer.writer);
    var reloaded: Yaml = .{ .source = writer.written() };
    defer reloaded.deinit(testing.allocator);
    try reloaded.load(testing.allocator);
    try testing.expectEqual(@as(usize, 1), reloaded.docs.items.len);
    const map = reloaded.docs.items[0].map;
    try testing.expect(map.get("actual").? == .null);
    try testing.expect(map.get("omitted").? == .null);
    const strings = map.get("strings").?.list;
    const expected = [_][]const u8{ "null", "Null", "NULL", "~", "", "nUlL" };
    try testing.expectEqual(expected.len, strings.len);
    for (expected, strings) |text, value| try testing.expectEqualStrings(text, value.scalar);
    const mixed = map.get("mixed").?.list;
    try testing.expectEqual(@as(usize, 4), mixed.len);
    try testing.expect(mixed[0] == .null);
    try testing.expectEqualStrings("null", mixed[1].scalar);
    try testing.expectEqualStrings("", mixed[2].scalar);
    try testing.expect(mixed[3] == .null);
}

test "typed serializer roundtrip preserves explicit null overriding defaults and strings" {
    const Config = struct {
        absent: ?i32 = 99,
        strings: []const ?[]const u8,
    };
    const input: Config = .{
        .absent = null,
        .strings = &.{ null, "null", "Null", "NULL", "~", "", "nUlL", null },
    };
    var writer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer writer.deinit();
    try stringify(testing.allocator, input, &writer.writer);
    var yaml: Yaml = .{ .source = writer.written() };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    var arena = Arena.init(testing.allocator);
    defer arena.deinit();
    const parsed = try yaml.parse(arena.allocator(), Config);
    try testing.expect(parsed.absent == null);
    try testing.expectEqual(input.strings.len, parsed.strings.len);
    for (input.strings, parsed.strings) |expected, actual| {
        if (expected) |text| {
            try testing.expect(actual != null);
            try testing.expectEqualStrings(text, actual.?);
        } else {
            try testing.expect(actual == null);
        }
    }
}

test "stringify non-null optional scalar and compound values" {
    const Choice = enum { selected };
    const Record = struct { value: ?i32 };
    const integer: i32 = -7;
    const record: Record = .{ .value = null };
    try testStringify("-7", @as(?i32, integer));
    try testStringify("7", @as(?u32, 7));
    try testStringify("1.25", @as(?f64, 1.25));
    try testStringify("false", @as(?bool, false));
    try testStringify("text", @as(?[]const u8, "text"));
    try testStringify("selected", @as(?Choice, .selected));
    try testStringify("value: null", @as(?Record, record));
    try testStringify("[ 1, 2 ]", @as(?[2]i32, .{ 1, 2 }));
    try testStringify("[ 3, 4 ]", @as(?[]const i32, &.{ 3, 4 }));
    try testStringify("-7", @as(?*const i32, &integer));
    try testStringify("value: null", @as(?*const Record, &record));
    try testStringify("11", @as(??i32, @as(?i32, 11)));
}

test "serializer roundtrip preserves compound list values between nulls" {
    const Record = struct { value: ?i32 };
    const Config = struct {
        records: []const ?Record,
        lists: []const ?[]const ?i32,
    };
    const input: Config = .{
        .records = &.{ null, .{ .value = 1 }, null, .{ .value = null }, null },
        .lists = &.{ null, &.{ null, 2 }, null, &.{ 3, null }, null },
    };
    var writer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer writer.deinit();
    try stringify(testing.allocator, input, &writer.writer);
    var yaml: Yaml = .{ .source = writer.written() };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    var arena = Arena.init(testing.allocator);
    defer arena.deinit();
    const parsed = try yaml.parse(arena.allocator(), Config);
    try testing.expectEqual(input.records.len, parsed.records.len);
    for (input.records, parsed.records) |expected, actual| {
        if (expected) |record| {
            try testing.expect(actual != null);
            try testing.expectEqual(record.value, actual.?.value);
        } else {
            try testing.expect(actual == null);
        }
    }
    try testing.expectEqual(input.lists.len, parsed.lists.len);
    for (input.lists, parsed.lists) |expected, actual| {
        if (expected) |list| {
            try testing.expect(actual != null);
            try testing.expectEqualSlices(?i32, list, actual.?);
        } else {
            try testing.expect(actual == null);
        }
    }
}

test "null and empty-string root documents survive raw and typed serialization" {
    for ([_]?[]const u8{ null, "", "null", "Null", "NULL", "~" }) |input| {
        var writer: std.Io.Writer.Allocating = .init(testing.allocator);
        defer writer.deinit();
        try stringify(testing.allocator, input, &writer.writer);
        var yaml: Yaml = .{ .source = writer.written() };
        defer yaml.deinit(testing.allocator);
        try yaml.load(testing.allocator);
        var raw_writer: std.Io.Writer.Allocating = .init(testing.allocator);
        defer raw_writer.deinit();
        try yaml.stringify(&raw_writer.writer);
        var reloaded: Yaml = .{ .source = raw_writer.written() };
        defer reloaded.deinit(testing.allocator);
        try reloaded.load(testing.allocator);
        var arena = Arena.init(testing.allocator);
        defer arena.deinit();
        const parsed = try reloaded.parse(arena.allocator(), ?[]const u8);
        if (input) |text| {
            try testing.expect(parsed != null);
            try testing.expectEqualStrings(text, parsed.?);
        } else {
            try testing.expect(parsed == null);
        }
    }
}
