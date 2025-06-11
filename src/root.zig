pub const ArchetypeManager = @import("archetype_manager.zig").ArchetypeManager;
pub const Archetype = @import("archetype.zig").Archetype;

pub const ComponentIterator = @import("component_iterator.zig").ComponentIterator;
pub const ComponentStorage = @import("component_storage.zig").componentStorage;

pub const EntityManager = @import("entity_manager.zig").createEntityManager;

pub const ECSDefinitions = @import("ecs_definitions.zig");
