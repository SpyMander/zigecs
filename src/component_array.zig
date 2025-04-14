const std = @import("std");
const types = @import("ecs_definitions.zig");

pub const IComponentArray = struct {
    ptr: *anyopaque,
    arrayComponentType: *const c_char,
    deinitHandler: *const fn (ptr: *anyopaque) void,
    insertHandler: *const fn (selfptr: *anyopaque, componentptr: *const anyopaque, enitity: types.entityID) void,

    removeHandler: *const fn (selfptr: *anyopaque, entity: types.entityID) void,

    getComponentsPtrHandler: *const fn (selfptr: *anyopaque) [*]u8,

    getSizeHandler: *const fn (selfptr: *anyopaque) u32,
};

//fixed sized array.
pub fn createComponentArray(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        arrayPtr: []T,
        indexToEntityID: []u32,
        entityIDToIndex: []u32,
        size: u32,
        capacity: u32,

        pub fn init(capacity: u32, allocator: std.mem.Allocator) !@This() {
            const arrptr = try allocator.alloc(T, capacity);
            const indexToEntity = try allocator.alloc(u32, capacity);
            const entityToIndex = try allocator.alloc(u32, capacity);

            return .{
                .allocator = allocator,
                .arrayPtr = arrptr,
                .size = 0,
                .capacity = capacity,
                .indexToEntityID = indexToEntity,
                .entityIDToIndex = entityToIndex,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.arrayPtr);
            self.allocator.free(self.entityIDToIndex);
            self.allocator.free(self.indexToEntityID);
        }

        pub fn deinitHandler(ptr: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self.deinit();
        }

        pub fn getInterface(self: *@This()) IComponentArray {
            const typenamePtr: *const c_char = types.getCharPtrName(T);
            return .{
                .ptr = self,
                .deinitHandler = deinitHandler,
                .arrayComponentType = typenamePtr,
                .insertHandler = insertHandler,
                .removeHandler = removeHandler,
                .getComponentsPtrHandler = getComponentsPtrHandler,
                .getSizeHandler = getSizeHandler,
            };
        }

        fn hasEntity(self: @This(), entity: types.entityID) bool {
            for (self.indexToEntityID[0..self.size]) |i| {
                if (entity == i) {
                    //std.debug.print("HIT! {any}\n", .{self.indexToEntityID[0 .. self.size + 1]});
                    return true;
                }
            }

            return false;
        }

        pub fn insert(self: *@This(), component: T, entityId: types.entityID) void {
            std.debug.assert(self.size < self.capacity);
            std.debug.assert(!self.hasEntity(entityId));

            self.arrayPtr[self.size] = component;

            self.indexToEntityID[self.size] = entityId;
            self.entityIDToIndex[entityId] = self.size;

            self.size += 1;
        }

        pub fn remove(self: *@This(), entity: types.entityID) void {
            std.debug.assert(self.hasEntity(entity));

            const lastIndex: u32 = self.size - 1;

            const removalIndex = self.entityIDToIndex[entity];

            // copy the back to the guy thats being removed
            self.arrayPtr[removalIndex] = self.arrayPtr[lastIndex];

            // remapping the maps
            const lastElementEntity = self.indexToEntityID[lastIndex];
            self.indexToEntityID[removalIndex] = lastElementEntity;
            self.entityIDToIndex[lastElementEntity] = removalIndex;
            // deleted dudes positions', index-to-entity is now fixed

            // no need to reset the actual component

            self.size -= 1;
        }

        pub fn getComponentIndex(self: @This(), index: u32) T {
            std.debug.assert(index <= (self.size - 1));
            return self.arrayPtr[index];
        }

        pub fn getComponentEntity(self: @This(), entity: types.entityID) T {
            const index: u32 = self.entityIDToIndex[entity];
            std.debug.assert(index <= (self.size - 1));
            return self.arrayPtr[index];
        }

        pub fn insertHandler(selfptr: *anyopaque, componentptr: *const anyopaque, enitity: types.entityID) void {
            const self: *@This() = @ptrCast(@alignCast(selfptr));
            const component: *const T = @ptrCast(@alignCast(componentptr));

            self.insert(component.*, enitity);
        }

        // TODO: REMOVE THIS FUNCTION
        pub fn removeHandler(selfptr: *anyopaque, entity: types.entityID) void {
            const self: *@This() = @ptrCast(@alignCast(selfptr));

            self.remove(entity);
        }

        // u8 is for any type, this guy will be type casted.
        pub fn getComponentsPtrHandler(selfptr: *anyopaque) [*]u8 {
            const self: *@This() = @ptrCast(@alignCast(selfptr));
            const ptr: [*]u8 = @ptrCast(self.arrayPtr.ptr);
            return ptr;
        }

        pub fn getSizeHandler(selfptr: *anyopaque) u32 {
            const self: *@This() = @ptrCast(@alignCast(selfptr));
            return self.size;
        }
    };
}
