const std = @import("std");

fn testComp(comptime T: u8, arg: u8) type {
    @typeInfo(T);
    std.debug.print("Arg: {}", .{arg});

    return struct { value: u32 };
}

pub fn main() !void {
    const myAlloc = std.heap.GeneralPurposeAllocator();

    defer myAlloc.deinit();

    const writer = std.io.getStdOut().writer();
    const reader = std.io.getStdIn().reader();

    try writer.print("Enter: ", .{});
    const read1 = try reader.readUntilDelimiterAlloc(myAlloc.allocator(), '\n', 100);

    for (read1) |char| {
        try writer.print("c: {c}\n", .{char});
    }
}
