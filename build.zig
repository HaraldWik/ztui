const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const lib_name = "ztui";

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    switch (builtin.target.os.tag) {
        .windows => @compileLog("Liberary '" ++ lib_name ++ "' Does not support non unix systems at the moment, this is work in progress"),
        else => {},
    }

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = lib_name,
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
