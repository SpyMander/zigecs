const std = @import("std");
const types = @import("ecs_definitions.zig");

pub fn componentStorage(comptime T: type) type {
    return struct {
        size: u32,
        components: [types.maxEntities]T,

        pub fn init() @This() {
            return .{
                .size = 0,
                .components = undefined,
            };
        }

        pub fn deinit(self: *@This()) void {
            _ = self;
        }

        pub fn getSlice(self: *@This()) []T {
            // referance return.
            return self.components[0..self.size];
        }

        //returns index where it placed it
        // allways inserts at size
        pub fn insert(self: *@This(), component: T) void {
            std.debug.print("inserting into storage {} {}\n", .{ self.size, types.maxEntities });
            std.debug.assert(self.size < types.maxEntities);

            self.components[self.size] = component;

            self.size += 1;
        }
    };
}
