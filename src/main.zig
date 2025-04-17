const std = @import("std");
const entity_manager = @import("entity_manager.zig");
const types = @import("ecs_definitions.zig");
const component_storage = @import("component_storage.zig").componentStorage;
const healthComponent = @import("components/health.zig").health;
const arAloc = std.heap.ArenaAllocator;
const Archetype = @import("archetype.zig").Archetype;
const ArchetypeManager = @import("archetype_manager.zig").ArchetypeManager;

// 1) not repeating archetypes via comparison of typenames
// on creation of archetype, get the typenames array and store it
// and assosiate it with the archetype object/ptr.

// 2) archetype manager.getSlice will give slices gained from all of the
// arhcetypes. [][]T. i think it should be.
// maybe use an iterator?

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        std.debug.print("gpa deinit leak?: {}\n", .{status == .leak});
    }

    const allocator = gpa.allocator();

    var entityManager = entity_manager.createEntityManager();

    var x = Archetype(
        &[_]type{ healthComponent, u32, f32 },
    ).init(allocator);

    defer x.deinit();

    // i like this way.
    x.insertAtOnce(
        entityManager.createEntity(),
        .{
            healthComponent{ .max = 10, .current = 20 },
            @as(u32, 2),
            @as(f32, 3),
        },
    );

    x.insertAtOnce(
        entityManager.createEntity(),
        .{
            healthComponent{ .max = 20, .current = 30 },
            @as(u32, 2),
            @as(f32, 3),
        },
    );

    const ptr: *anyopaque = @ptrCast(&x);
    const callback: *const fn (selfptr: *anyopaque, entity: types.entityID, componentLiterals: anytype) void = Archetype(
        &[_]type{ healthComponent, u32, f32 },
    ).insertAtOnceHandler;

    callback(
        ptr,
        entityManager.createEntity(),
        .{
            healthComponent{ .max = 999, .current = 300 },
            @as(u32, 2),
            @as(f32, 3),
        },
    );

    for (x.getSlice(healthComponent)) |health| {
        std.debug.print("health: {}\n", .{health.max});
    }

    //var y = ArchetypeManager.init(allocator);
    //defer y.deinit();

    //y.addArchetype(&[_]type{ healthComponent, u32 });
    //for (y.archetypeEntries.items) |entry| {
    //std.debug.print("entrydata: {any}\n", .{entry.componentStorageEntries});
    //}
    std.debug.print("ending!\n", .{});
}
