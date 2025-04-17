const std = @import("std");
const types = @import("ecs_definitions.zig");
const Archetype = @import("archetype.zig").Archetype;
const ComponentStorageEntry = @import("archetype.zig").ComponentStorageEntry;
const HashMap = std.AutoArrayHashMap;
const ArrayList = std.ArrayList;

// it might just be possible to turn this whole thing into a
// comptime structure. it would be more optimized.

const ArchetypeEntry = struct {
    componentStorageEntries: []ComponentStorageEntry,
    ptr: *anyopaque,
};

pub const ArchetypeManager = struct {
    archetypeEntries: ArrayList(ArchetypeEntry),
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
        const archetype = allocator.alloc(Archetype(componentTypes), 1) catch unreachable;

        archetype[0] = Archetype(componentTypes).init(allocator);

        const storageEntries = archetype[0].componentStorageEntries;

        self.archetypeEntries.append(.{
            .componentStorageEntries = storageEntries,
            .ptr = archetype.ptr,
        }) catch unreachable;
    }

    fn getArchetype(self: *@This(), comptime componentTypes: []const type) ?*Archetype(componentTypes) {
        const archetypeType: type = Archetype(componentTypes);

        for (self.archetypeEntries.items) |archetypeEntry| {
            if (archetypeEntry.componentStorageEntries.len != componentTypes.len) {
                continue;
            }
            const storageEntries = archetypeEntry.componentStorageEntries;

            inline for (componentTypes, 0..) |T, index| {
                if (storageEntries[index].typeName == types.getCharPtrName(T)) {
                    if (index + 1 == componentTypes.len) {
                        const archetype: *archetypeType = @ptrCast(@alignCast(archetypeEntry.ptr));

                        return archetype;
                    }
                } else {
                    continue;
                }
            }
        }

        return null;
    }

    fn getTypesFromAnytype(comptime tuple: anytype) []const type {
        return blk: {
            break :blk &[_]type{
                inline for (tuple) |item| @TypeOf(item),
            };
        };
    }

    // shitty language wont let me extract the types from the tuple
    // so u gon have to pass it yourself. >:(
    //pub fn insert(self: *@This(), entity: types.entityID, comptime componentLiterals: anytype) void {

    //}
};
