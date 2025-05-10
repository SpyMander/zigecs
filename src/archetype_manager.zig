const std = @import("std");
const types = @import("ecs_definitions.zig");
const Archetype = @import("archetype.zig").Archetype;
const ComponentStorageEntry = @import("archetype.zig").ComponentStorageEntry;
const ComponentStorage = @import("component_storage.zig").componentStorage;
const HashMap = std.AutoArrayHashMap;
const ArrayList = std.ArrayList;
const ComponentIterator = @import("component_iterator.zig").ComponentIterator;

// it might just be possible to turn this whole thing into a
// comptime structure. it would be more optimized.

pub const ArchetypeEntry = struct {
    // TODO: is keeping the storage entries important?
    componentStorageEntries: []ComponentStorageEntry,
    entityToIndex: *[types.maxEntities]u32,
    indexToEntity: *[types.maxEntities]types.entityID,
    ptr: *anyopaque,
};

pub const ArchetypeManager = struct {
    archetypeEntries: ArrayList(ArchetypeEntry),
    // could use the storage entries for retrival, but this is faster.
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator) @This() {
        const arena = std.heap.ArenaAllocator.init(allocator);
        const archetypeEntries = ArrayList(ArchetypeEntry).init(allocator);

        return .{
            .archetypeEntries = archetypeEntries,
            .arena = arena,
        };
    }

    pub fn deinit(self: *@This()) void {
        // for some reason, not calling the deinit of the
        // archetypes is fine.
        // TODO: that might be a problem. callbacks of fn deinit?

        self.archetypeEntries.deinit();
        self.arena.deinit();
    }

    pub fn addArchetype(self: *@This(), comptime componentTypes: []const type) void {
        const allocator = self.arena.allocator();
        const archetype = allocator.create(Archetype(componentTypes)) catch unreachable;

        archetype.* = Archetype(componentTypes).init(allocator);

        const storageEntries = archetype.componentStorageEntries;
        const entityToIndex = &archetype.entityToIndex;
        const indexToEntity = &archetype.indexToEntity;

        self.archetypeEntries.append(.{
            .componentStorageEntries = storageEntries,
            .entityToIndex = entityToIndex,
            .indexToEntity = indexToEntity,
            .ptr = @ptrCast(archetype),
        }) catch unreachable;
    }

    fn getArchetypePtr(self: *@This(), componentTypeNames: []*const c_char) ?*anyopaque {
        for (self.archetypeEntries.items) |archetypeEntry| {
            if (archetypeEntry.componentStorageEntries.len != componentTypeNames.len) {
                continue;
            }
            const storageEntries = archetypeEntry.componentStorageEntries;
            for (storageEntries, 0..) |storageEntry, index| {
                if (storageEntry.typeName != componentTypeNames[index]) {
                    break;
                }

                if (index + 1 == storageEntries.len) {
                    return archetypeEntry.ptr;
                }
            }
        }

        return null;
    }

    // TODO: check if anytype is a tuple
    fn getTypesFromAnytypeLiterals(tuple: anytype) []const type {
        comptime var typesAccumulator: [tuple.len]type = undefined;
        inline for (tuple, 0..) |literal, index| {
            typesAccumulator[index] = @TypeOf(literal);
        }
        // a copy happens here.
        const typesConst = typesAccumulator;
        return &typesConst;
    }

    // this guy finds the archetype himself.
    // todo: think if it should create the archetype if it doesn't exist;
    pub fn autoInsert(self: *@This(), entity: types.entityID, componentLiterals: anytype) void {
        const componentTypes: []const type = getTypesFromAnytypeLiterals(componentLiterals);
        const archetypeType: type = Archetype(componentTypes);
        var typenames: [componentLiterals.len]*const c_char = undefined;
        inline for (componentLiterals, 0..) |literal, index| {
            typenames[index] = types.getCharPtrName(@TypeOf(literal));
        }

        const archetypePtr = self.getArchetypePtr(&typenames) orelse {
            std.debug.print("!this archetype doesn't exist!\n", .{});
            unreachable;
        };

        var archetype: *archetypeType = @ptrCast(@alignCast(archetypePtr));
        archetype.insertAtOnce(entity, componentLiterals);
    }

    pub fn insert(
        self: *@This(),
        entity: types.entityID,
        comptime componentTypes: []const type,
        componentLiterals: anytype,
    ) void {
        std.debug.assert(componentTypes.len == componentLiterals.len);

        var typenames: [componentTypes.len]*const c_char = undefined;
        inline for (componentTypes, 0..) |T, index| {
            typenames[index] = types.getCharPtrName(T);
        }

        const archetypeType: type = Archetype(componentTypes);

        const archetypePtr: *anyopaque = self.getArchetypePtr(&typenames) orelse {
            std.debug.print("FATAL: this archetype doesn't exist in the archetype manager!\n", .{});
            unreachable;
        };

        var archetype: *archetypeType = @ptrCast(@alignCast(archetypePtr));

        archetype.insertAtOnce(entity, componentLiterals);
    }

    // my magnum opus, the culmination
    pub fn getComponentIterator(
        self: @This(),
        comptime componentTypes: []const type,
    ) ComponentIterator(componentTypes) {
        return ComponentIterator(componentTypes).init(self);
    }
};
