const std = @import("std");
const types = @import("ecs_definitions.zig");
const ComponentStorage = @import("component_storage.zig").componentStorage;

const ComponentStorageEntry = struct {
    typeName: *const c_char,
    ptr: *anyopaque,
};

pub const Archetype = struct {
    arena: std.heap.ArenaAllocator,
    componentStorageEntries: []ComponentStorageEntry,
    entityAmount: u32,
    entityToIndex: [types.maxEntities]u32,
    indexToEntity: [types.maxEntities]types.entityID,

    pub fn init(allocator: std.mem.Allocator, componentTypes: []const type) @This() {
        var arena = std.heap.ArenaAllocator.init(allocator);

        var storageEntries = arena.allocator().alloc(ComponentStorageEntry, componentTypes.len) catch unreachable;

        inline for (componentTypes, 0..) |T, i| {
            std.debug.print("T: {}\n", .{T});
            var storagePtr = arena.allocator().alloc(ComponentStorage(T), 1) catch unreachable;

            storagePtr[0] = ComponentStorage(T).init();

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

    // TODO: DELETE THIS
    pub fn insert(self: *@This(), comptime T: type, value: T) void {
        if (self.getComponentStorage(T)) |storage|
            storage.insert(value);
    }

    fn verifyComponentInputs(self: *@This(), comptime componentLiterals: anytype) bool {
        inline for (componentLiterals, 0..) |literal, index| {
            const inputTypeName = types.getCharPtrName(@TypeOf(literal));
            const typeName = self.componentStorageEntries[index].typeName;

            if (inputTypeName != typeName) {
                const entryTypeNameString: [*:0]const u8 = @ptrCast(typeName);
                std.debug.print("FATAL: incorrect types passed, expected: {s}, got {any}\n", .{ entryTypeNameString, @TypeOf(literal) });

                return false;
            }
        }
        return true;
    }

    // this must be in order as the types passed durring initalization.
    // multithreadable?
    pub fn insertAtOnce(self: *@This(), entity: types.entityID, comptime componentLiterals: anytype) void {
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

    // shouldn't have error handling, the idea is that this guy
    // should never fail.
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
