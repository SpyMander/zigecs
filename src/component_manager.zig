const std = @import("std");
const arrayList = std.ArrayList;
const cmpArray = @import("component_array.zig");
const types = @import("ecs_definitions.zig");
const arenaAllocator = std.heap.ArenaAllocator;

pub const ComponentManager = struct {
    // stuff;
    arena: arenaAllocator,
    list: std.ArrayList(cmpArray.IComponentArray),

    pub fn init(allocator: std.mem.Allocator) @This() {
        const list = std.ArrayList(cmpArray.IComponentArray).init(allocator);
        const arena = arenaAllocator.init(allocator);
        return .{ .list = list, .arena = arena };
    }

    pub fn deinit(self: *@This()) void {
        for (self.list.items) |item| {
            item.deinitHandler(item.ptr);
        }
        self.list.deinit();
        self.arena.deinit();
    }

    fn hasComponent(self: *@This(), comp: cmpArray.IComponentArray) bool {
        for (self.list.items) |item| {
            if (item.arrayComponentType == comp.arrayComponentType) {
                return true;
            }
        }
        return false;
    }

    fn getComponentArray(self: @This(), comp: *const c_char) ?cmpArray.IComponentArray {
        for (self.list.items) |item| {
            if (item.arrayComponentType == comp) {
                return item;
            }
        }

        return null;
    }

    fn makeSlice(comptime T: type, ptr: [*]T, len: usize) []T {
        // this guy returns the pointer so, no copies.
        return ptr[0..len];
    }

    pub fn getComponents(self: @This(), comptime T: type) ![]T {

        // maybe this cptr thing should be a function? good idea.
        const cptr: *const c_char = @ptrCast(@typeName(T).ptr);
        if (self.getComponentArray(cptr)) |icomponent| {
            const arrptr: [*]u8 = icomponent.getComponentsPtrHandler(icomponent.ptr);
            const typeptr: [*]T = @ptrCast(@alignCast(arrptr));
            const arrsize = icomponent.getSizeHandler(icomponent.ptr);

            const slice = makeSlice(T, typeptr, arrsize);
            return slice;
        }
        return error.componentNotFound;
    }

    pub fn registerComponent(self: *@This(), comptime T: type, capacity: u32, componentAllocator: std.mem.Allocator) !void {
        // does this component already exist?

        const componentArrayType = cmpArray.createComponentArray(T);

        const componentArrayPtr = try self.arena.allocator().alloc(componentArrayType, 1);

        componentArrayPtr[0] = try componentArrayType.init(capacity, componentAllocator);

        // there is a copy here but it isn't that bad. i think
        // better to error check.
        const interface = componentArrayPtr[0].getInterface();

        std.debug.assert(!self.hasComponent(interface));
        try self.list.append(interface);
    }

    pub fn removeEntity(self: *@This(), entity: types.entityID) void {
        for (self.list.items) |item| {
            item.removeHandler(item.ptr, entity);
        }
    }

    // TODO: change to c_ptr?
    // TODO use the getcharptrname function
    pub fn insert(self: *@This(), comptime T: type, component: T, entity: types.entityID) void {
        const cptr: *const c_char = types.getCharPtrName(T);

        const componentArray = self.getComponentArray(cptr);
        const componentPtr: *const anyopaque = @ptrCast(&component);

        if (componentArray) |v| {
            v.insertHandler(v.ptr, componentPtr, entity);
            return;
        } else {
            std.debug.print("###invalid component type, it wasn't registerd?\n", .{});
        }
        unreachable;
    }
};
