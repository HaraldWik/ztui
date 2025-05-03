const std = @import("std");
const ztui = @import("ztui");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const screen = try ztui.Screen.init(allocator);
    defer screen.deinit();

    var player_data = PlayerData{};

    while (true) {
        try screen.write("&", .{}, player_data.row, player_data.col);

        switch (try screen.getEvent()) {
            .exit => break,
            .up, .down, .right, .left => |event| player_data.make(event),
            else => {},
        }

        try screen.clear();
    }
}

pub const PlayerData = struct {
    const Self = @This();

    speed: usize = 1,

    row: usize = 0,
    col: usize = 0,

    pub fn make(self: *Self, event: ztui.Event) void {
        switch (event) {
            .up => self.row -%= self.speed,
            .down => self.row +%= self.speed,
            .right => self.col +%= self.speed,
            .left => self.col -%= self.speed,
            else => {},
        }
    }
};
