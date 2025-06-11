const std = @import("std");
const types = @import("ecs_definitions.zig");

pub const EntityManager = struct {
    // u32 is too much?
    // entity id increments but doesn't decrement
    // + static array
    entityIDs: [types.maxEntities]types.entityID,
    entityAmount: u32,

    pub fn init(self: *@This()) void {
        for (&self.entityIDs, 0..) |*ptr, i| {
            ptr.* = @intCast(i);
        }

        self.entityAmount = 0;
    }

    pub fn getAllEntities(self: *@This()) []types.entityID {
        return self.entityIDs[0..self.entityAmount];
    }

    pub fn createEntity(self: *@This()) types.entityID {
        std.debug.assert(self.entityAmount <= types.maxEntities);
        const id = self.entityIDs[self.entityAmount];
        self.entityAmount += 1;
        return id;
    }

    pub fn removeEntity(self: *@This(), entity: types.entityID) void {
        // overflow
        std.debug.assert(entity <= self.entityAmount - 1);

        // no entities were created
        std.debug.assert(self.entityAmount != 0);

        // entity has been remove already
        std.debug.assert(self.entityIDs[entity] == entity);

        const removedId = self.entityIDs[entity];
        const swapId = self.entityIDs[self.entityAmount - 1];

        self.entityIDs[entity] = swapId;
        self.entityIDs[self.entityAmount - 1] = removedId;
        self.entityAmount -= 1;
    }
};

pub fn createEntityManager() EntityManager {
    var entityManager: EntityManager = .{ .entityAmount = undefined, .entityIDs = undefined };

    entityManager.init();

    return entityManager;
}
