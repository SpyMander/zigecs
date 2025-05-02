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

    var y = ArchetypeManager.init(allocator);
    defer y.deinit();

    const rando: []const type = &[_]type{ healthComponent, u32 };
    const rando2: []const type = &[_]type{ healthComponent, f32 };

    y.addArchetype(rando);
    y.addArchetype(rando2);

    y.autoInsert(
        entityManager.createEntity(),
        .{
            healthComponent{ .max = 999, .current = 99 },
            @as(u32, 5),
        },
    );

    y.insert(
        entityManager.createEntity(),
        rando,
        .{
            healthComponent{ .max = 123, .current = 321 },
            @as(u32, 456),
        },
    );

    y.insert(
        entityManager.createEntity(),
        rando2,
        .{
            healthComponent{ .max = 987, .current = 765 },
            @as(f32, 12.5),
        },
    );

    var iter = y.getComponentIterator(&[_]type{ healthComponent, u32 });
    while (iter.next()) {
        const component = iter.get(healthComponent);
        const component2 = iter.get(u32);
        std.debug.print("component info: max:{} | cur:{}\n", .{ component.max, component.current });
        std.debug.print("component info2: val:{}\n", .{component2.*});
    }

    std.debug.print("ending!\n", .{});
}
