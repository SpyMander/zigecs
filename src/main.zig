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

    var value = @as(f32, 4);
    value += 5;
    x.insertAtOnce(
        entityManager.createEntity(),
        .{
            healthComponent{ .max = 70, .current = 30 },
            @as(u32, 2),
            @as(f32, value),
        },
    );

    x.insertAtOnce(entityManager.createEntity(), 2);

    //const ptr: *anyopaque = @ptrCast(&x);

    //comptime var componentTypes: [3]type = undefined;
    //componentTypes[0] = healthComponent;
    //componentTypes[1] = u32;
    //componentTypes[2] = f32;

    // copies to make it const?
    //const componentTypesConst = componentTypes;

    //const archetypeType: type = Archetype(componentTypesConst[0..]);
    //const y: *archetypeType = @ptrCast(@alignCast(ptr));
    //_ = y;

    for (x.getSlice(healthComponent)) |health| {
        std.debug.print("health: {}\n", .{health.max});
    }

    var y = ArchetypeManager.init(allocator);
    defer y.deinit();

    y.addArchetype(&[_]type{ healthComponent, u32 });
    y.insert(2, .{ healthComponent{ .max = 999, .current = 99 }, @as(u32, 5) });

    std.debug.print("ending!\n", .{});
}
