const std = @import("std");
const component_manager = @import("component_manager.zig");
const entity_manager = @import("entity_manager.zig");
const systems_manager = @import("systems_manager.zig");
const types = @import("ecs_defenitions.zig");
const healthComponent = @import("components/health.zig").health;
const arAloc = std.heap.ArenaAllocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        std.debug.print("gpa deinit leak?: {}\n", .{status == .leak});
    }

    // var set = std.bit_set.ArrayBitSet(u8, types.maxEntities).initEmpty();
    //set.set(7);

    //const val = set.isSet(0);

    //std.debug.print("val: {}\n", .{val});

    const allocator = gpa.allocator();

    var componentManager = component_manager.ComponentManager.init(allocator);

    var entityManager = entity_manager.createEntityManager();

    _ = entityManager.createEntity();

    for (entityManager.getAllEntities()) |e| {
        std.debug.print("entity: {}\n", .{e});
    }

    try componentManager.registerComponent(healthComponent, types.maxEntities, allocator);
    defer componentManager.deinit();

    componentManager.insert(healthComponent, .{ .current = 25, .max = 200 }, 0);

    componentManager.insert(healthComponent, .{ .current = 5, .max = 10 }, 1);

    componentManager.insert(healthComponent, .{ .current = 505, .max = 600 }, 9);

    componentManager.insert(healthComponent, .{ .current = 505, .max = 77 }, 3);

    //componentManager.removeEntity(9);
    componentManager.removeEntity(0);

    const healths = try componentManager.getComponents(healthComponent);

    for (healths) |component| {
        std.debug.print("current: {} | max: {}\n", .{ component.current, component.max });
    }

    var systemsManager = systems_manager.createSystemsManager(allocator);

    defer systemsManager.deinit();

    try systemsManager.addComponent(healthComponent);
    try systemsManager.assignComponentToEntity(healthComponent, 0);
    systemsManager.removeComponentFromEntity(healthComponent, 0);
}
