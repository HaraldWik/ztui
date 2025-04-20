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

### Installation

`zig fetch --save https://github.com/HaraldWik/ztui/archive/refs/heads/main.tar.gz`

### Simple example

This is a simple example, can be found [here!](https://github.com/HaraldWik/ztui/tree/main/examples/simple)

```zig
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
```
