const std = @import("std");
const ztui = @import("ztui");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var screen = try ztui.Screen.init(allocator);
    defer screen.deinit();

    var num: i32 = 0;
    var last_char: u8 = undefined;

    while (true) {
        const size = try screen.getSize();
        try screen.write("Hello, world! {d} {d} {d}", .{ num, size.@"0", size.@"1" }, 5, 9);
        try screen.write("Last char: {d}", .{last_char}, 9, 10);

        switch (try screen.getEvent()) {
            .exit => break,
            .up => num += 1,
            .down => num -= 1,
            else => |char| last_char = @intFromEnum(char),
        }

        try screen.clear();
    }
}
