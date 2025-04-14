pub const entityID = u32;
pub const maxEntities = 1024;

pub fn getCharPtrName(comptime T: type) *const c_char {
    const c_ptr: *const c_char = @ptrCast(@typeName(T).ptr);
    return c_ptr;
}
