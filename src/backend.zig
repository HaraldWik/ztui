const std = @import("std");
const builtin = @import("builtin");
const fs = @import("std").fs;
const io = @import("std").io;
const os = @import("std").os;

pub fn Terminal(out: fs.File) type {
    return switch (builtin.target.os.tag) {
        .linux, .macos => struct {
            const unistd = struct {
                extern fn sigemptyset(__set: *linux.sigset_t) c_int;
            };
            const linux = @import("std").os.linux;

            const Self = @This();

            /// This field is os dependent
            original: linux.termios = undefined,
            /// This field is os dependent
            raw: linux.termios = undefined,

            /// Init raw mode
            pub fn init() !Self {
                var original: linux.termios = undefined;
                var raw = original;

                if (linux.tcgetattr(out.handle, &original) != 0 or
                    linux.tcgetattr(out.handle, &raw) != 0)
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

                raw.cc[@intFromEnum(linux.V.TIME)] = 0;
                raw.cc[@intFromEnum(linux.V.MIN)] = 1;
                _ = linux.tcsetattr(out.handle, .FLUSH, &raw);

                try out.writeAll("\x1b[?1049h" ++ "\x1b[?25l"); // Switch to alternate buffer and hide cursor

                return Self{
                    .original = original,
                    .raw = raw,
                };
            }

            pub fn deinit(self: Self) void {
                out.writeAll("\x1b[?1049l" ++ "\x1b[?25h") catch unreachable; // Switch to main buffer and show cursor
                _ = linux.tcsetattr(out.handle, linux.TCSA.NOW, &self.original);
            }

            pub fn getSize(_: Self) !struct { usize, usize } {
                if (!io.getStdOut().supportsAnsiEscapeCodes()) return .{ 0, 0 };

                var buf: std.posix.system.winsize = undefined;
                return switch (std.posix.errno(
                    std.posix.system.ioctl(
                        out.handle,
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
            }
        },

        .windows => struct {
            const windows = @import("std").os.windows;

            const Self = @This();

            /// This field is os dependent
            original_mode: windows.DWORD,

            pub fn init() !Self {
                var original_mode: windows.DWORD = undefined;

                if (windows.kernel32.GetConsoleMode(out.handle, &original_mode) == windows.FALSE) {
                    return error.GetConsoleModeFailed;
                }

                const ENABLE_ECHO_INPUT: u32 = 0x0004;
                const ENABLE_LINE_INPUT: u32 = 0x0002;
                const ENABLE_PROCESSED_INPUT: u32 = 0x0001;
                const ENABLE_MOUSE_INPUT: u32 = 0x0010; // Add this constant to disable mouse input

                const raw_mode = original_mode & ~ENABLE_ECHO_INPUT & ~ENABLE_LINE_INPUT & ~ENABLE_PROCESSED_INPUT & ~ENABLE_MOUSE_INPUT;

                if (windows.kernel32.SetConsoleMode(out.handle, raw_mode) == windows.FALSE) {
                    return error.SetConsoleModeFailed;
                }

                try out.writeAll("\x1b[?1049h" ++ "\x1b[?25l"); // Switch to alternate buffer and hide cursor

                return Self{
                    .original_mode = original_mode,
                };
            }

            pub fn deinit(self: Self) void {
                out.writeAll("\x1b[?1049l" ++ "\x1b[?25h") catch unreachable; // Switch to main buffer and show cursor
                if (windows.kernel32.SetConsoleMode(out.handle, self.original_mode) == windows.FALSE) {}
            }

            pub fn getSize(_: Self) !struct { usize, usize } {
                if (!out.supportsAnsiEscapeCodes()) return .{ 0, 0 };

                var buf: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
                return switch (windows.kernel32.GetConsoleScreenBufferInfo(
                    out.handle,
                    &buf,
                )) {
                    windows.TRUE => .{
                        @intCast(buf.srWindow.Bottom - buf.srWindow.Top + 1),
                        @intCast(buf.srWindow.Right - buf.srWindow.Left + 1),
                    },
                    else => error.Unexpected,
                };
            }
        },

        else => @compileError("Unsupported OS"),
    };
}
