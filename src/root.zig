const std = @import("std");
const builtin = @import("builtin");
const fs = @import("std").fs;
const io = @import("std").io;
const os = @import("std").os;
const linux = @import("std").os.linux;
const unistd = switch (builtin.os.tag) {
    .linux, .macos => struct {
        extern fn isatty(fd: std.linux.fd_t) c_int;
        extern fn sigemptyset(__set: *linux.sigset_t) c_int;
        const STDIN_FILENO = 0;
        const STDOUT_FILENO = 1;
        const STDERR_FILENO = 2;
    },
    else => @compileError("Unistd is not supported on non unix systems"),
};

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

pub const Screen = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    terminal: struct {
        original: linux.termios = undefined,
        raw: linux.termios = undefined,
        tty: fs.File = undefined,
    } = undefined,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var original: linux.termios = undefined;
        var raw = original;

        const writer = io.getStdOut().writer();

        try writer.writeAll("\x1b[?1049h"); // Switch to alternate buffer
        try writer.writeAll("\x1b[?25l"); // Hide cursor

        const tty = try fs.cwd().openFile("/dev/tty", .{});

        if (linux.tcgetattr(tty.handle, &original) != 0 or
            linux.tcgetattr(tty.handle, &raw) != 0)
            return error.Tcgetattr;

        var act: linux.Sigaction = undefined;
        _ = unistd.sigemptyset(&act.mask);
        act.flags = 0;
        act.flags = 0;
        if (linux.sigaction(linux.SIG.HUP, &act, null) != 0 or
            linux.sigaction(linux.SIG.INT, &act, null) != 0 or
            linux.sigaction(linux.SIG.QUIT, &act, null) != 0 or
            linux.sigaction(linux.SIG.TERM, &act, null) != 0 or
            linux.sigaction(linux.SIG.PIPE, &act, null) != 0 or
            linux.sigaction(linux.SIG.ALRM, &act, null) != 0)
            return error.Sigaction;

        raw.iflag = .{
            .BRKINT = false,
            .ICRNL = false,
            .INPCK = false,
            .ISTRIP = false,
            .IXON = false,
        };

        raw.oflag = .{}; // Disable all output processing

        raw.cflag = .{
            .CSIZE = .CS8, // 8-bit chars
        };

        raw.lflag = .{
            .ECHO = false,
            .ICANON = false,
            .IEXTEN = false,
            .ISIG = false,
        };

        raw.cc[@intFromEnum(linux.V.TIME)] = 0; // VTIME
        raw.cc[@intFromEnum(linux.V.MIN)] = 1; // VMIN
        _ = linux.tcsetattr(tty.handle, .FLUSH, &raw);

        return Self{
            .allocator = allocator,
            .terminal = .{
                .original = original,
                .raw = raw,
                .tty = tty,
            },
        };
    }

    pub fn deinit(self: Self) void {
        const writer = io.getStdOut().writer();

        writer.writeAll("\x1b[?1049l") catch unreachable; // Switch to main buffer
        writer.writeAll("\x1b[?25h") catch unreachable; // Show cursor

        _ = linux.tcsetattr(self.terminal.tty.handle, linux.TCSA.NOW, &self.terminal.original);
        self.terminal.tty.close();
    }

    pub fn getSize(self: Self) !struct { usize, usize } {
        if (!self.terminal.tty.supportsAnsiEscapeCodes()) return .{ 0, 0 };

        return switch (builtin.os.tag) {
            .windows => blk: {
                var buf: os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
                break :blk switch (os.windows.kernel32.GetConsoleScreenBufferInfo(
                    self.terminal.tty.handle,
                    &buf,
                )) {
                    os.windows.TRUE => .{
                        @intCast(buf.srWindow.Bottom - buf.srWindow.Top + 1),
                        @intCast(buf.srWindow.Right - buf.srWindow.Left + 1),
                    },
                    else => error.Unexpected,
                };
            },
            .linux, .macos => blk: {
                var buf: std.posix.system.winsize = undefined;
                break :blk switch (std.posix.errno(
                    std.posix.system.ioctl(
                        self.terminal.tty.handle,
                        std.posix.T.IOCGWINSZ,
                        @intFromPtr(&buf),
                    ),
                )) {
                    .SUCCESS => .{
                        buf.row,
                        buf.col,
                    },
                    else => error.IoctlError,
                };
            },
            else => error.Unsupported,
        };
    }

    pub fn getInput(_: Self) !u8 {
        const reader = std.io.getStdIn().reader();

        while (true) {
            switch (try reader.readByte()) {
                3 => return Input.exit,
                // Escape codes
                27 => {
                    try reader.skipBytes(1, .{ .buf_size = 512 });
                    return switch (try reader.readByte()) {
                        65 => Input.up, // 'A' -> Up
                        66 => Input.down, // 'B' -> Down
                        67 => Input.right, // 'D' -> Right
                        68 => Input.left, // 'C' -> Left
                        else => Input.escape,
                    };
                },
                else => |char| return char,
            }
        }
    }

    pub fn write(self: Self, comptime fmt: []const u8, args: anytype, row: usize, col: usize) !void {
        const writer = std.io.getStdOut().writer();

        // Move cursor to row 10, column 20
        // ANSI escape sequence: \x1b[{ROW};{COL}H
        try writer.writeAll(try std.fmt.allocPrint(self.allocator, "\x1b[{d};{d}H", .{ row, col }));
        try writer.writeAll(try std.fmt.allocPrint(self.allocator, fmt, args));
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
