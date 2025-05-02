const std = @import("std");
const types = @import("ecs_definitions.zig");
const Archetype = @import("archetype.zig").Archetype;
const ComponentStorageEntry = @import("archetype.zig").ComponentStorageEntry;
const ComponentStorage = @import("component_storage.zig").componentStorage;
const HashMap = std.AutoArrayHashMap;
const ArrayList = std.ArrayList;

// it might just be possible to turn this whole thing into a
// comptime structure. it would be more optimized.

const ArchetypeEntry = struct {
    // TODO: is keeping the storage entries important?
    componentStorageEntries: []ComponentStorageEntry,
    entityToIndex: *[types.maxEntities]u32,
    indexToEntity: *[types.maxEntities]types.entityID,
    ptr: *anyopaque,
};

pub const ArchetypeManager = struct {
    archetypeEntries: ArrayList(ArchetypeEntry),
    // could use the storage entries for retrival, but this is faster.
    typenameToStorages: HashMap(*const c_char, ArrayList(*anyopaque)),
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator) @This() {
        const arena = std.heap.ArenaAllocator.init(allocator);
        const archetypeEntries = ArrayList(ArchetypeEntry).init(allocator);
        const typenameToStorages = HashMap(*const c_char, ArrayList(*anyopaque)).init(allocator);

        return .{
            .archetypeEntries = archetypeEntries,
            .typenameToStorages = typenameToStorages,
            .arena = arena,
        };
    }

    pub fn deinit(self: *@This()) void {
        // for some reason, not calling the deinit of the
        // archetypes is fine.
        // TODO: that might be a problem. callbacks of fn deinit?

        for (self.typenameToStorages.values()) |list|
            list.deinit();
        self.typenameToStorages.deinit();

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

        // TODO: This guy handles the relation between types and
        // the storages for them, keeps track of the pointers,
        // it works but looks like shit. put this in a different
        // function

        inline for (componentTypes, 0..) |T, index| {
            const typename: *const c_char = types.getCharPtrName(T);

            if (self.typenameToStorages.getPtr(typename)) |storageArr| {
                storageArr.append(@ptrCast(storageEntries[index].ptr)) catch unreachable;
            } else {
                self.typenameToStorages.put(typename, ArrayList(*anyopaque).init(allocator)) catch unreachable;

                if (self.typenameToStorages.getPtr(typename)) |storageArr| {
                    storageArr.append(@ptrCast(storageEntries[index].ptr)) catch unreachable;
                } else {
                    std.debug.print("shit\n", .{});
                }
            }
        }
    }

    fn getArchetypePtr(self: *@This(), componentTypeNames: []*const c_char) ?*anyopaque {
        for (self.archetypeEntries.items) |archetypeEntry| {
            if (archetypeEntry.componentStorageEntries.len != componentTypeNames.len) {
                continue;
            }
            const storageEntries = archetypeEntry.componentStorageEntries;

            for (componentTypeNames, 0..) |typename, index| {
                if (storageEntries[index].typeName == typename) {
                    // test this loop
                    if (index + 1 == componentTypeNames.len) {
                        const archetype = archetypeEntry.ptr;

                        return archetype;
                    }
                } else {
                    continue;
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

    pub fn getComponentStorages(
        self: @This(),
        comptime componentType: type,
    ) [][]componentType {
        const componentSlices: [][]componentType = undefined;

        const typename: *const c_char = types.getCharPtrName(componentType);

        std.debug.print("acessing: {}!\n", .{typename});

        if (self.typenameToStorages.getPtr(typename)) |sptr| {
            for (sptr.items) |storageptr| {
                const storage: *ComponentStorage(componentType) = @ptrCast(@alignCast(storageptr));
                std.debug.print("size: {}\n", .{storage.size});
                //std.debug.print("ent: {}\n", .{archetypeEntry});
            }
        } else {
            std.debug.print("that shit doesn't even exist!\n", .{});
        }

        return componentSlices;
    }
};

pub fn ComponentIterator(comptime componentTypes: []const type) type {
    return struct {
        archetypeEntriesPtr: []ArchetypeEntry,
        componentEntryIndex: usize,
        currentStorages: [componentTypes.len]*anyopaque,
        storageComponentIndex: usize,
        reachedStorageEnd: bool, // TODO: better name??

        pub fn init(archetypeManager: ArchetypeManager) @This() {
            return .{
                .archetypeEntriesPtr = archetypeManager.archetypeEntries.items,
                .componentEntryIndex = 0,
                .currentStorages = undefined,
                .storageComponentIndex = 0,
                .reachedStorageEnd = true,
            };
        }

        // we cant really return the types, so we
        // return ptr's that are match the
        // componentTypesarray.
        fn getMatchingComponentStorages(
            archetypeEntry: ArchetypeEntry,
        ) ?[componentTypes.len]*anyopaque {
            var storages: [componentTypes.len]*anyopaque = undefined;

            // if the type was found, the matching index
            // will be turned to true.
            var matchedTypes: [componentTypes.len]bool = undefined;
            @memset(&matchedTypes, false);

            var foundMatchingTypes: usize = 0;

            for (archetypeEntry.componentStorageEntries) |entry| {
                inline for (componentTypes, 0..) |T, typeIndex| {
                    // would do an early continue, but that is a control
                    // flow error, :(
                    if (entry.typeName == types.getCharPtrName(T)) {
                        // TODO: repeating, should it even be checked for?
                        if (!matchedTypes[typeIndex]) {
                            storages[typeIndex] = entry.ptr;
                            foundMatchingTypes += 1;
                            matchedTypes[typeIndex] = true;
                        }
                    }
                }
            }

            std.debug.assert(foundMatchingTypes <= componentTypes.len); // how?

            if (foundMatchingTypes < componentTypes.len) {
                return null;
            }

            return storages;
        }

        // going through each archetype,
        // checking if it has the necessary types
        // if not check the next archetype.
        pub fn next(self: *@This()) bool {
            if (self.componentEntryIndex >= self.archetypeEntriesPtr.len)
                return false;

            if (!self.reachedStorageEnd) {
                const storageType: type = ComponentStorage(componentTypes[0]);
                const storage: *storageType = @ptrCast(@alignCast(self.currentStorages[0]));
                const max = storage.size;

                self.storageComponentIndex += 1;

                if (self.storageComponentIndex >= max - 1)
                    self.reachedStorageEnd = true;

                return true;
            }

            while (true) {
                if (getMatchingComponentStorages(self.archetypeEntriesPtr[self.componentEntryIndex])) |storages| {
                    self.currentStorages = storages;
                } else {
                    return false;
                }

                const storageType: type = ComponentStorage(componentTypes[0]);
                const storage: *storageType = @ptrCast(@alignCast(self.currentStorages[0]));
                // skip ones that dont have any entities inside them.
                if (storage.size != 0)
                    break;
            }

            // reset the "head"
            self.storageComponentIndex = 0;
            self.reachedStorageEnd = false;
            self.componentEntryIndex += 1;
            return true;
        }

        // used for asserting
        fn hasType(comptime T: type) bool {
            inline for (componentTypes) |componentType| {
                if (T == componentType) {
                    return true;
                }
            }

            return false;
        }

        pub fn get(self: @This(), comptime T: type) *T {
            std.debug.assert(hasType(T));
            // i do not care if it's actually there or not
            var component: *T = undefined;
            inline for (componentTypes, 0..) |componentType, index| {
                if (componentType == T) {
                    const componentStorageType: type = ComponentStorage(T);
                    const storage: *componentStorageType = @ptrCast(@alignCast(self.currentStorages[index]));
                    // we dont care about going through the slice in this case
                    // so we just straight up go to the array and grab the component
                    component = &storage.components[self.storageComponentIndex];
                }
            }

            return component;
        }
    };
}
