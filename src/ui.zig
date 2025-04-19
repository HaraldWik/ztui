const std = @import("std");
const builtin = @import("builtin");
const io = @import("std").io;
const os = @import("std").os;

const ElementManager = @import("elements.zig");

const c = @cImport({
    @cDefine("PDC_FORCE_UTF8", "1");
    @cInclude("curses.h"); // ncurses
    @cInclude("locale.h");
});

const Self = @This();

allocator: std.mem.Allocator,
stdout: std.fs.File,

screen: *c.WINDOW,

pub const ButtonConfig = struct {
    width: usize = 0,
    height: usize = 0,
    selected: bool = false,
};

pub fn init(allocator: std.mem.Allocator, stdout: std.fs.File) !Self {
    _ = c.setlocale(c.LC_ALL, "en_US.UTF-8");

    const screen = c.initscr() orelse return error.InitScreenIsNull;
    _ = c.cbreak();
    _ = c.noecho();
    _ = c.keypad(c.stdscr, true);

    _ = c.setlocale(c.LC_ALL, "en_US.UTF-8");

    if (stdout.supportsAnsiEscapeCodes()) _ = try stdout.write("\x1b[?25l"); // Hide mouse
    _ = c.cbreak(); // Raw = (no ctrl + c / x / z)

    return Self{
        .allocator = allocator,
        .stdout = stdout,
        .screen = screen,
    };
}

pub fn deinit(self: Self) void {
    if (self.stdout.supportsAnsiEscapeCodes()) _ = self.stdout.write("\x1b[?25h") catch unreachable; // Hide mouse
    _ = c.clear();
    _ = c.endwin();
}

pub fn message(self: Self, text: []const u8) !void {
    const elements = try ElementManager.init(self.allocator, self.screen);
    defer elements.deinit();

    const label: []const u8 = "Ok";

    while (true) {
        elements.clear();

        try elements.text("{s}\n", .{text});

        try elements.button(
            label,
            .{},
            true,
        );

        elements.refresh();

        const char = c.getch();
        switch (char) {
            '\n' => break,
            else => {},
        }
    }
}

/// True is yes and false is no
pub fn yesno(self: Self, text: []const u8) !bool {
    const elements = try ElementManager.init(self.allocator, self.screen);
    defer elements.deinit();

    var selected: bool = true;
    var final: ?bool = null;

    while (final == null) {
        elements.clear();

        try elements.text("{s}\n", .{text});

        try elements.button("Yes", .{}, selected);
        try elements.text(" ", .{});
        try elements.button("No", .{}, !selected);

        elements.refresh();

        const char = c.getch();
        switch (char) {
            c.KEY_UP, c.KEY_DOWN, c.KEY_RIGHT, c.KEY_LEFT, '\t' => selected = !selected,
            '\n' => final = selected,
            else => {},
        }
    }

    _ = c.wclear(self.screen);
    return final.?;
}

pub fn input(self: Self, text: []const u8, max_len: comptime_int) ![]const u8 {
    const elements = try ElementManager.init(self.allocator, self.screen);
    defer elements.deinit();

    if (self.stdout.supportsAnsiEscapeCodes()) _ = self.stdout.write("\x1b[?25h") catch unreachable; // Hide mouse

    var output = [_]u8{' '} ** @max(1, max_len);
    var pos: usize = 0;
    var len: usize = 0;

    while (true) {
        elements.clear();

        const visual = try std.fmt.allocPrint(self.allocator, "{s}\n", .{output[0..len]});
        try elements.text("{s}\n{s}", .{ text, visual });

        _ = c.move(1, @intCast(pos));

        elements.refresh();

        const char = c.getch();
        switch (char) {
            c.KEY_RIGHT => {
                if (pos < len) pos += 1;
            },
            c.KEY_LEFT => {
                if (pos != 0) pos -= 1;
            },
            '\n' => break,
            c.KEY_BACKSPACE, 127 => {
                if (pos > 0 and len > 0) {
                    pos -= 1;
                    len -= 1;
                    output[pos] = ' ';
                }
            },
            else => {
                if (char >= 32 and char <= 126 and len < output.len) {
                    output[pos] = @as(u8, @intCast(char));
                    if (pos == len) {
                        len += 1;
                    }
                    pos += 1;
                }
            },
        }
    }

    if (self.stdout.supportsAnsiEscapeCodes()) _ = self.stdout.write("\x1b[?25l") catch unreachable; // Hide mouse

    const visual = try std.fmt.allocPrint(self.allocator, "{s}", .{output[0..len]});
    return visual;
}

pub fn menu(comptime text: []const u8, args: anytype, choices: [][]const u8, start_selection: usize) !usize {
    var selected: isize = @intCast(start_selection);

    while (true) {
        const num_choices = choices.len;
        if (selected < 0) selected += @intCast(num_choices);
        if (selected >= num_choices) selected -= @intCast(num_choices);

        try screen.clear();

        const size = try screen.getSize();

        const offset = 2;
        const visible = size.@"0" - offset;

        const raw_camera = if (selected < offset * 2) 0 else @as(usize, @intCast(selected - offset * 2));
        const max_start = if (choices.len > visible) choices.len - visible else 0;
        const camera_pos = @min(raw_camera, max_start);
        const end = @min(camera_pos + visible, choices.len);

        try screen.write(text, args, 0, 0);

        for (camera_pos..end) |i| {
            if (i == selected) try screen.write("\x1b[7m", .{}, i + 2, 0);
            try screen.write("{s}\n", .{choices[i]}, i + 2, 0);
            try screen.write("\x1b[0m", .{}, i + 2, 0);
        }

        switch (try screen.getInput()) {
            lib.Input.exit => return lib.Input.exit,
            lib.Input.up => selected -= 1,
            lib.Input.down, lib.Input.tab => selected += 1,
            lib.Input.right, lib.Input.enter => return @intCast(selected),
            else => {},
        }
    }

    return lib.Input.exit;
}
