const std = @import("std");
const component_manager = @import("component_manager.zig");
const entity_manager = @import("entity_manager.zig");
const systems_manager = @import("systems_manager.zig");
const types = @import("ecs_definitions.zig");
const healthComponent = @import("components/health.zig").health;
const component_storage = @import("component_storage.zig").componentStorage;
const arAloc = std.heap.ArenaAllocator;
const archetype = @import("archetype.zig").Archetype;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        std.debug.print("gpa deinit leak?: {}\n", .{status == .leak});
    }

    const allocator = gpa.allocator();

    var entityManager = entity_manager.createEntityManager();

    const components = [_]type{ healthComponent, u32 };

    var x = archetype.init(
        allocator,
        &components,
    );

    // test entity "0"

    // i like this way.
    x.insertAtOnce(
        entityManager.createEntity(),
        .{
            healthComponent{ .max = 100, .current = 30 },
            @as(u32, 8),
        },
    );

    x.insertAtOnce(
        entityManager.createEntity(),
        .{
            healthComponent{ .max = 50, .current = 1 },
            @as(u32, 100),
        },
    );

    for (x.getSlice(healthComponent), x.getSlice(u32)) |component, number| {
        std.debug.print("health: {any} ", .{component});
        std.debug.print("num: {}\n", .{number});
    }

    defer x.deinit();
}
