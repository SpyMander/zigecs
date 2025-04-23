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

        // remove this function.
        pub fn deinit(self: *@This()) void {
            _ = self;
        }

        pub fn getSlice(self: *@This()) []T {
            // referance return.
            return self.components[0..self.size];
        }

        // allways inserts at size
        pub fn insert(self: *@This(), component: T) void {
            std.debug.assert(self.size < types.maxEntities);

            self.components[self.size] = component;

            self.size += 1;
        }

        // TODO: when removing an entity that doesn't exist
        // wierd errors pop up, catch it and give a better error message.
        pub fn remove(self: *@This(), index: usize) void {
            std.debug.assert(self.size > index);
            std.debug.assert(self.size > 0);

            // swap the back with the deleted one.
            self.components[index] = self.components[self.size - 1];
            self.size -= 1;
        }
    };
}
