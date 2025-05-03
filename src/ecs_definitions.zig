pub const entityID = u32;
// this value is set in the build configuration.
pub const maxEntities = @import("zigecsOptions").maxEntities;

pub fn getCharPtrName(comptime T: type) *const c_char {
    const c_ptr: *const c_char = @ptrCast(@typeName(T).ptr);
    return c_ptr;
}
