const std = @import("std");
const types = @import("ecs_definitions.zig");
const ComponentStorage = @import("component_storage.zig").componentStorage;

pub const ComponentStorageEntry = struct {
    typeName: *const c_char,
    ptr: *anyopaque,
};

pub fn Archetype(comptime componentTypes: []const type) type {
    // TODO: make it not possible to put reapinting types in the array.
    // TODO: componentStorageEntries does an unnesessary allocation?
    // fix dat.
    return struct {
        arena: std.heap.ArenaAllocator,
        componentStorageEntries: []ComponentStorageEntry,
        entityAmount: u32,
        entityToIndex: [types.maxEntities]u32,
        indexToEntity: [types.maxEntities]types.entityID,

        pub fn init(allocator: std.mem.Allocator) @This() {
            var arena = std.heap.ArenaAllocator.init(allocator);

            var storageEntries = arena.allocator().alloc(ComponentStorageEntry, componentTypes.len) catch unreachable;

            inline for (componentTypes, 0..) |T, i| {
                const storagePtr = arena.allocator().create(ComponentStorage(T)) catch unreachable;

                storagePtr.* = ComponentStorage(T).init();

                const anyopaqueStoragePtr: *anyopaque = @ptrCast(storagePtr);
                storageEntries[i] = .{
                    .typeName = types.getCharPtrName(T),
                    .ptr = anyopaqueStoragePtr,
                };
            }

            return .{
                .arena = arena,
                .componentStorageEntries = storageEntries,
                .entityAmount = 0,
                .entityToIndex = undefined,
                .indexToEntity = undefined,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
        }

        fn getComponentStorage(self: @This(), comptime T: type) ?*ComponentStorage(T) {
            const storageType: type = ComponentStorage(T);
            var found: bool = false;
            var storage: *storageType = undefined;
            for (self.componentStorageEntries) |entry| {
                if (types.getCharPtrName(T) == entry.typeName) {
                    found = true;
                    storage = @ptrCast(@alignCast(entry.ptr));
                }
            }

            if (!found) {
                return null;
            }

            return storage;
        }

        fn hasType(self: @This(), comptime T: type) bool {
            if (self.getComponentStorage(T)) {
                return true;
            } else {
                return false;
            }
        }

        fn hasEntity(self: @This(), entity: types.entityID) bool {
            for (0..self.entityAmount) |index| {
                if (self.indexToEntity[index] == entity) {
                    return true;
                }
            }

            return false;
        }

        fn verifyComponentInputs(self: *@This(), componentLiterals: anytype) bool {
            inline for (componentLiterals, 0..) |literal, index| {
                const inputTypeName = types.getCharPtrName(@TypeOf(literal));
                // component storage entries fucked?
                const typeName = self.componentStorageEntries[index].typeName;

                if (inputTypeName != typeName) {
                    const entryTypeNameString: [*:0]const u8 = @ptrCast(typeName);
                    // print error before exiting.
                    std.debug.print("FATAL: incorrect types passed, expected: {s}, got {any}\n", .{ entryTypeNameString, @TypeOf(literal) });

                    return false;
                }
            }
            return true;
        }

        // this guy also checks the order, it matters.
        // we hoping that this reduces to a bool durring comptime.
        pub fn hasComponentStorages(self: *@This(), comptime inputComponentTypes: []const type) bool {
            _ = self;
            if (inputComponentTypes.len != componentTypes.len) {
                return false;
            }
            inline for (inputComponentTypes, componentTypes) |T, compareT| {
                if (T != compareT) {
                    return false;
                }
            }

            return true;
        }

        // this must be in order as the types passed durring initalization.
        // multithreadable?
        pub fn insertAtOnce(self: *@This(), entity: types.entityID, componentLiterals: anytype) void {
            std.debug.assert(componentLiterals.len == self.componentStorageEntries.len);
            std.debug.assert(self.verifyComponentInputs(componentLiterals));

            std.debug.assert(!self.hasEntity(entity)); // this entity exists

            const insertIndex = self.entityAmount;

            inline for (componentLiterals) |component| {
                const componentType: type = @TypeOf(component);
                if (self.getComponentStorage(componentType)) |storage| {
                    _ = storage.insert(component);
                }
            }

            self.entityToIndex[entity] = insertIndex;
            self.indexToEntity[insertIndex] = entity;
            self.entityAmount += 1;
        }

        pub fn removeEntity(self: *@This(), entity: types.entityID) void {
            const deletedIndex = self.entityToIndex[entity];
            const backEntity = self.indexToEntity[self.entityAmount - 1];
            inline for (componentTypes, 0..) |T, index| {
                const storageType: type = ComponentStorage(T);

                var storage: *storageType = @ptrCast(@alignCast(self.componentStorageEntries[index].ptr));

                storage.remove(deletedIndex);
            }

            self.entityToIndex[entity] = self.entityToIndex[backEntity];
            self.indexToEntity[deletedIndex] = backEntity;
            self.entityAmount -= 1;
        }

        // shouldn't have error handling, the idea is that this guy
        // should never fail.
        // TODO: this guy is kinda useless? might be removed?
        pub fn getSlice(self: *@This(), comptime T: type) []T {
            const storageType: type = ComponentStorage(T);
            var storage: *storageType = undefined;
            for (self.componentStorageEntries) |entry| {
                if (types.getCharPtrName(T) == entry.typeName) {
                    storage = @ptrCast(@alignCast(entry.ptr));
                }
            }

            return storage.getSlice();
        }
    };
}
