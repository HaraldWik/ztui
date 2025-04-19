# ZTUI - Zig Tui

A minimal TUI liberary for Zig.

### Supports

- Unicode (emojis, non english letters)
- Input with arrows
- And ofc simple TUI things

### Plans (not in order)

- Make better input system
- Add simple UI elements (widgets)
- **Add platform support for non unix operating systems (Windows)**
- Add more examples

This is a simple example

```zig
const std = @import("std");
const ztui = @import("ztui");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const screen = try ztui.Screen.init(allocator);
    defer screen.deinit();

    while (true) {
        screen.write("Hello, world! {d}", .{6 * 9}, 5, 9);

        switch (try screen.getInput()) {
            ztui.Input.exit => break,
            else => {},
        }

        screen.clear();
    }
}
```
