# ztui - Zig Tui

A minimal ~~cross platform~~ TUI liberary for Zig.

### Supports

- Unicode (emojis, non english letters)
- Input with arrows
- And ofc simple TUI things

---

### Roadmap 2025 (Q2 - Q4)

_These may not be completed since I'm currently not interested in working on this project much, but you're free to fork it or submit a pull request_

| Tasks                            | Status | Tested |
| -------------------------------- | ------ | ------ |
| Add better input system          | ✅     | ✅     |
| Add simple game example          | ✅     | ✅     |
| **Windows support**              | ⏳     | ❌     |
| Add simple UI elements (widgets) | ❌     | ❌     |

---

### Installation

    zig fetch --save https://github.com/HaraldWik/ztui/archive/refs/heads/main.tar.gz

###### build.zig

```zig
const ztui_dep = b.dependency("ztui", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("ztui", ztui_dep.module("ztui"));
```

---

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

        switch (try screen.getEvent()) {
            .exit => break,
            .up => num += 1,
            .down => num -= 1,
            .esc => num = 0,
            else => {},
        }

        try screen.clear();
    }
}
```
