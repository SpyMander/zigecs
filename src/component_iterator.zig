const std = @import("std");
const ArchetypeEntry = @import("archetype_manager.zig").ArchetypeEntry;
const ArchetypeManager = @import("archetype_manager.zig").ArchetypeManager;
const ComponentStorage = @import("component_storage.zig").componentStorage;
const types = @import("ecs_definitions.zig");

// THIS IS FOR ARCHETYPES. couldn't figure out a good name and this works.
pub fn ComponentIterator(comptime componentTypes: []const type) type {
    std.debug.assert(componentTypes.len > 0); //at least put one type in
    return struct {
        archetypeEntriesPtr: []ArchetypeEntry,
        archetypeEntryIndex: i32,
        storageComponentIndex: i32,
        currentStorages: [componentTypes.len]*anyopaque,

        pub fn init(archetypeManager: ArchetypeManager) @This() {
            return .{
                .archetypeEntriesPtr = archetypeManager.archetypeEntries.items,
                .archetypeEntryIndex = -1,
                .storageComponentIndex = -1,
                .currentStorages = undefined,
            };
        }

        // guy returns the storages. pointers.
        // they should match up with the componentTypes array.
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

            std.debug.assert(foundMatchingTypes <= componentTypes.len); // not possible

            if (foundMatchingTypes < componentTypes.len) {
                return null;
            }

            return storages;
        }

        // going through each archetype,
        // checking if it has the necessary types
        // if not check the next archetype.
        pub fn next(self: *@This()) bool {
            if (self.storageComponentIndex < 0) {
                // this means that we should go to the next
                // archetype now.
                // find next archetype
                while (true) {
                    self.archetypeEntryIndex += 1;

                    if (self.archetypeEntryIndex >= self.archetypeEntriesPtr.len) {
                        // only here should it return false;
                        return false;
                    }

                    const archetypeEntry =
                        self.archetypeEntriesPtr[@intCast(self.archetypeEntryIndex)];

                    // you could optimize by writing inside the
                    // the currentStorages buffer directly but
                    // i dont think you would gain much.
                    if (getMatchingComponentStorages(archetypeEntry)) |storages| {
                        const storageT: type = ComponentStorage(componentTypes[0]);
                        const storage: *storageT = @ptrCast(@alignCast(storages[0]));

                        // if it's an archetype with no entities.
                        if (storage.size == 0) continue;

                        self.currentStorages = storages;
                        break;
                    }
                }
            }

            self.storageComponentIndex += 1;
            // getting len of the storage
            const storageT: type = ComponentStorage(componentTypes[0]);
            const storage: *storageT = @ptrCast(@alignCast(self.currentStorages[0]));

            if (self.storageComponentIndex >= storage.size) {
                self.storageComponentIndex = -1;
                // recursive is fine here.
                return self.next();
            }

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

        pub fn getComponent(self: @This(), comptime T: type) *T {
            std.debug.assert(hasType(T)); // this type doesn't exist in the iterator

            // i do not care if it's actually there or not
            var component: *T = undefined;
            inline for (componentTypes, 0..) |componentType, index| {
                if (componentType == T) {
                    const componentStorageType: type = ComponentStorage(T);
                    const storage: *componentStorageType = @ptrCast(@alignCast(self.currentStorages[index]));
                    // we dont care about going through the slice in this case
                    // so we just straight up go to the array and grab the component
                    component = &storage.components[@intCast(self.storageComponentIndex)];
                }
            }

            return component;
        }

        pub fn getEntity(self: @This()) types.entityID {
            // no idea.
            // -1
            const entry = self.archetypeEntriesPtr[@intCast(self.archetypeEntryIndex)];

            return entry.indexToEntity[@intCast(self.storageComponentIndex)];
        }
    };
}
