const std = @import("std");
const ztui = @import("ztui");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var screen = try ztui.Screen.init(allocator);
    defer screen.deinit();

    var num: i32 = 0;

    while (true) {
        try screen.write("Hello, world! {d}", .{num}, 5, 9);

        switch (try screen.getInput()) {
            ztui.Input.exit => break,
            ztui.Input.up => num += 1,
            ztui.Input.down => num -= 1,
            else => {},
        }

        try screen.clear();
    }
}
