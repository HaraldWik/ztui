const std = @import("std");
const builtin = @import("builtin");
const fs = @import("std").fs;
const io = @import("std").io;
const os = @import("std").os;
const backend = @import("backend.zig");

pub const Input = struct {
    pub const escape = 27;
    pub const up = 129;
    pub const down = 141;
    pub const left = 143;
    pub const right = 144;
    pub const exit = 157;
    pub const enter = 13;
    pub const tab = 9;
};

pub const Event = enum(u8) {
    const Self = @This();

    nul = 0, // Null
    soh = 1, // Start of Header
    stx = 2, // Start of Text
    etx = 3, // End of Text
    eot = 4, // End of Transmission
    enq = 5, // Enquiry
    ack = 6, // Acknowledge
    bel = 7, // Bell
    bs = 8, // Backspace
    tab = 9, // Horizontal Tab
    lf = 10, // Line Feed
    vt = 11, // Vertical Tab
    ff = 12, // Form Feed
    enter = 13, // Carriage Return
    so = 14, // Shift Out
    si = 15, // Shift In
    dle = 16, // Data Link Escape
    dc1 = 17, // Device Control 1
    dc2 = 18, // Device Control 2
    dc4 = 20, // Device Control 4
    nak = 21, // Negative Acknowledge
    syn = 22, // Synchronous Idle
    etb = 23, // End of Transmission Block
    can = 24, // Cancel
    em = 25, // End of Medium
    sub = 26, // Substitute
    esc = 27, // Escape
    fs = 28, // File Separator
    gs = 29, // Group Separator
    rs = 30, // Record Separator
    us = 31, // Unit Separator

    space = 32,
    bang = 33, // !
    quote = 34, // "
    hash = 35, // #
    dollar = 36, // $
    percent = 37, // %
    amp = 38, // &
    apostrophe = 39, // '
    lparen = 40, // (
    rparen = 41, // )
    star = 42, // *
    plus = 43, // +
    comma = 44, // ,
    dash = 45, // -
    dot = 46, // .
    slash = 47, // /

    @"0" = 48,
    @"1" = 49,
    @"2" = 50,
    @"3" = 51,
    @"4" = 52,
    @"5" = 53,
    @"6" = 54,
    @"7" = 55,
    @"8" = 56,
    @"9" = 57,

    colon = 58, // :
    semicolon = 59, // ;
    less = 60, // <
    equal = 61, // =
    greater = 62, // >
    question = 63, // ?
    at = 64, // @

    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,

    lbracket = 91, // [
    backslash = 92, // \
    rbracket = 93, // ]
    caret = 94, // ^
    underscore = 95, // _
    backtick = 96, // `

    a = 97,
    b = 98,
    c = 99,
    d = 100,
    e = 101,
    f = 102,
    g = 103,
    h = 104,
    i = 105,
    j = 106,
    k = 107,
    l = 108,
    m = 109,
    n = 110,
    o = 111,
    p = 112,
    q = 113,
    r = 114,
    s = 115,
    t = 116,
    u = 117,
    v = 118,
    w = 119,
    x = 120,
    y = 121,
    z = 122,

    lbrace = 123, // {
    pipe = 124, // |
    rbrace = 125, // }
    tilde = 126, // ~
    del = 127, // Delete

    // Custom
    exit = 157,
    up = 129,
    down = 141,
    left = 143,
    right = 144,

    pub fn fromInt(comptime T: anytype, val: T) ?Self {
        const fields = @typeInfo(Self).@"enum".fields;
        inline for (fields) |field| {
            if (val == @intFromEnum(@field(Self, field.name)))
                return @field(Self, field.name);
        }
        return null;
    }
};

pub const Screen = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    terminal: backend.Terminal(io.getStdOut()),

    pub fn init(allocator: std.mem.Allocator) !Self {
        const terminal = try backend.Terminal(io.getStdOut()).init();

        return Self{
            .allocator = allocator,
            .terminal = terminal,
        };
    }

    pub fn deinit(self: Self) void {
        self.terminal.deinit();
    }

    pub fn getSize(self: Self) !struct { usize, usize } {
        return self.terminal.getSize();
    }

    pub fn getEvent(_: Self) !Event {
        const reader = std.io.getStdIn().reader();

        while (true) {
            return switch (try reader.readByte()) {
                3 => .exit,
                // Escape codes
                27 => blk: {
                    try reader.skipBytes(1, .{ .buf_size = 512 });
                    break :blk switch (try reader.readByte()) {
                        65 => .up, // 'A' -> Up
                        66 => .down, // 'B' -> Down
                        67 => .right, // 'D' -> Right
                        68 => .left, // 'C' -> Left
                        else => .esc,
                    };
                },
                else => |char| Event.fromInt(u8, char) orelse .nul,
            };
        }
    }

    pub fn write(self: Self, comptime fmt: []const u8, args: anytype, row: usize, col: usize) !void {
        const writer = std.io.getStdOut().writer();

        const size = try self.getSize();
        if (row > size.@"0" or col > size.@"1") return;

        // Move cursor to row 10, column 20
        try writer.writeAll(try std.fmt.allocPrint(self.allocator, "\x1b[{d};{d}H", .{ row, col }));

        const format = try std.fmt.allocPrint(self.allocator, fmt, args);
        try writer.writeAll(format[0..@min(format.len, size.@"1" - col)]);
    }

    pub fn debug(self: Self, comptime fmt: []const u8, args: anytype) void {
        switch (builtin.mode) {
            .Debug => {
                self.clear() catch unreachable;

                while (true) {
                    switch (self.getInput() catch unreachable) {
                        Input.exit => return,
                        'c' => self.clear() catch unreachable,
                        else => {},
                    }

                    std.debug.print("\x1b[31m", .{});
                    std.debug.print(fmt, args);
                    std.debug.print("\x1b[0m", .{});
                }
            },
            else => {},
        }
    }

    pub fn clear(_: Self) !void {
        const writer = std.io.getStdOut().writer();
        try writer.writeAll("\x1b[2J\x1b[H");
    }
};
