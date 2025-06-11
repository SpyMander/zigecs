const std = @import("std");
const entity_manager = @import("entity_manager.zig");
const types = @import("ecs_definitions.zig");
const component_storage = @import("component_storage.zig").componentStorage;
const healthComponent = @import("components/health.zig").health;
const arAloc = std.heap.ArenaAllocator;
const Archetype = @import("archetype.zig").Archetype;
const ArchetypeManager = @import("archetype_manager.zig").ArchetypeManager;

test "generic test" {
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

    y.insert(
        entityManager.createEntity(),
        rando2,
        .{
            healthComponent{ .max = 532, .current = 531 },
            @as(f32, 62.5),
        },
    );

    var iter = y.getComponentIterator(&[_]type{healthComponent});
    while (iter.next()) {
        const component = iter.getComponent(healthComponent);
        std.debug.print("component info: max:{} | cur:{}\n", .{ component.max, component.current });
        std.debug.print("ent: {}\n", .{iter.getEntity()});
    }

    std.debug.print("ending!\n", .{});
    //try std.testing.expect(true);
}

test "one element test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }

    var x = ArchetypeManager.init(gpa.allocator());
    defer x.deinit();

    const randoType = &[_]type{ u32, f32 };
    x.addArchetype(randoType);

    x.insert(
        0,
        randoType,
        .{
            @as(u32, 5),
            @as(f32, 12.4),
        },
    );
    x.insert(
        1,
        randoType,
        .{
            @as(u32, 5),
            @as(f32, 12.4),
        },
    );
    x.insert(
        2,
        randoType,
        .{
            @as(u32, 5),
            @as(f32, 12.4),
        },
    );

    var iterAmount: usize = 0;
    var iter = x.getComponentIterator(&[_]type{u32});
    while (iter.next()) {
        const value = iter.getComponent(u32);

        std.debug.print("val: {}", .{value.*});
        std.debug.print(" ent: {}\n", .{iter.getEntity()});
        try std.testing.expect(iterAmount == iter.getEntity());
        try std.testing.expect(value.* == 5);

        iterAmount += 1;
    }

    try std.testing.expect(iterAmount == 3);
}

test "components in components" {
    std.debug.print("\n\n| COMPONENTS IN COMPONENTS TEST!!!|\n\n", .{});
    const metaComponent = struct {
        hp: healthComponent,
        someBullshit: u32,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer {
        const status = gpa.deinit();
        std.debug.print("gpa deinit leak?: {}\n", .{status == .leak});
    }

    const allocator = gpa.allocator();

    var entityManager = entity_manager.createEntityManager();
    var y = ArchetypeManager.init(allocator);
    defer y.deinit();

    // adding an f32 to rando fixes is for some reason.
    const rando: []const type = &[_]type{ metaComponent, u32 };
    const rando2: []const type = &[_]type{ u32, healthComponent };

    y.addArchetype(rando);
    y.addArchetype(rando2);

    y.insert( // 1
        entityManager.createEntity(),
        rando2,
        .{
            @as(u32, 9),
            healthComponent{ .current = 7, .max = 8 },
        },
    );
    y.insert( // 2
        entityManager.createEntity(),
        rando,
        .{
            metaComponent{
                .hp = healthComponent{
                    .current = 20,
                    .max = 400,
                },
                .someBullshit = @as(u32, 500),
            },
            @as(u32, 9),
        },
    );

    var iter = y.getComponentIterator(&[_]type{u32});

    var iterAmount: usize = 0;
    while (iter.next()) {
        iterAmount += 1;
        const component = iter.getComponent(u32);
        try std.testing.expect(component.* == 9);
    }

    std.debug.print("ending!\n", .{});
    try std.testing.expect(iterAmount == 2);
}

test "iterator" {
    std.debug.print("\n\n| COMPONENTS IN COMPONENTS TEST!!!|\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer {
        const status = gpa.deinit();
        std.debug.print("gpa deinit leak?: {}\n", .{status == .leak});
    }

    const allocator = gpa.allocator();

    var entityManager = entity_manager.createEntityManager();
    var y = ArchetypeManager.init(allocator);
    defer y.deinit();

    // adding an f32 to rando fixes is for some reason.
    const rando: []const type = &[_]type{u32};
    const rando2: []const type = &[_]type{ healthComponent, f64 };

    y.addArchetype(rando);
    y.addArchetype(rando2);

    y.insert( // 1
        entityManager.createEntity(),
        rando,
        .{
            @as(u32, 9),
        },
    );
    y.insert( // 2
        entityManager.createEntity(),
        rando2,
        .{
            healthComponent{
                .current = 20,
                .max = 400,
            },
            @as(f64, 9),
        },
    );

    var iter = y.getComponentIterator(&[_]type{healthComponent});

    var iterAmount: usize = 0;
    while (iter.next()) {
        iterAmount += 1;
        const component = iter.getComponent(healthComponent);
        try std.testing.expect(component.max == 400);
        try std.testing.expect(iter.getEntity() == iterAmount);
    }

    std.debug.print("iter amount: {}\n", .{iterAmount});
    try std.testing.expect(iterAmount == 1);
}
