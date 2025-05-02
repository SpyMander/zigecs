const std = @import("std");
const ArchetypeEntry = @import("archetype_manager.zig").ArchetypeEntry;
const ArchetypeManager = @import("archetype_manager.zig").ArchetypeManager;
const ComponentStorage = @import("component_storage.zig").componentStorage;
const types = @import("ecs_definitions.zig");

// THIS IS FOR ARCHETYPES. couldn't figure out a good name and this works.
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
        // componentTypes array.
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
