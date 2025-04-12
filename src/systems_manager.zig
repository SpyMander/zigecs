const std = @import("std");
const types = @import("ecs_defenitions.zig");
const arrayBitSet = std.bit_set.ArrayBitSet;

// TODO: hashmap might be overkill, test and try out other ways.
pub const SystemsManager = struct {
    componentToEntity: std.AutoHashMap(*const c_char, arrayBitSet(u8, types.maxEntities)),

    // array of callbacks.

    pub fn init(self: *@This(), allocator: std.mem.Allocator) void {
        self.componentToEntity = std.AutoHashMap(*const c_char, arrayBitSet(u8, types.maxEntities)).init(allocator);
    }

    pub fn deinit(self: *@This()) void {
        self.componentToEntity.deinit();
    }

    // add "components" when nessesary.

    pub fn addComponent(self: *@This(), comptime T: type) !void {
        const c_ptr: *const c_char = types.getCharPtrName(T);
        try self.componentToEntity.put(c_ptr, arrayBitSet(u8, types.maxEntities).initEmpty());
    }

    pub fn assignComponentToEntity(self: *@This(), comptime T: type, entity: types.entityID) !void {
        const c_ptr: *const c_char = types.getCharPtrName(T);

        if (self.componentToEntity.getPtr(c_ptr)) |bitset| {
            std.debug.assert(!bitset.isSet(entity)); // DOUBLE SET.
            bitset.set(entity);
        } else {
            // CHANGE!!
            std.debug.print("this component wasn't found\n", .{});
            std.debug.print("doin it myself (adding)\n", .{});
            try self.addComponent(T);
        }
    }

    pub fn removeComponentFromEntity(self: *@This(), comptime T: type, entity: types.entityID) void {
        const c_ptr: *const c_char = types.getCharPtrName(T);
        if (self.componentToEntity.getPtr(c_ptr)) |bitset| {
            // assert that this entity is set.
            // err if it doesn't exist or allready was unset.
            std.debug.assert(bitset.isSet(entity)); // wasn't set.
            bitset.unset(entity);
        } else {
            unreachable; // (THIS COMPONENT WASNT FOUND)
        }
    }
};

// TODO: fix this init mess.
pub fn createSystemsManager(allocator: std.mem.Allocator) SystemsManager {
    var m: SystemsManager = .{ .componentToEntity = undefined };
    m.init(allocator);
    return m;
}
