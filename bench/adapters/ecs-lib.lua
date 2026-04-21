return function(library)
	local Adapter = {
		name = "ecs-lib",
		note = "AoS per archetype (chunk[entity][name]) ecs",
	}

	function Adapter.createContext()
		local world = library.world:new("bench")
		return {
			em = world.entity_mgr,
		}
	end

	function Adapter.createEntity(context)
		-- create entity in the root (empty) archetype
		return context.em:create_entity()
	end

	function Adapter.allocComponent(_context, index)
		-- library identifies components by string name;
		-- map numeric index to a stable unique name
		return "c" .. index
	end

	function Adapter.set(context, entity, component, value)
		context.em:set_component(entity, component, value)
	end

	function Adapter.get(context, entity, component)
		return context.em:get_component(entity, component)
	end

	function Adapter.has(context, entity, component)
		return context.em:has_component(entity, component)
	end

	function Adapter.remove(context, entity, component)
		context.em:remove_component(entity, component)
	end

	function Adapter.query(context, components)
		local width = #components
		if width == 0 then
			return {}
		end

		local filter = library.all(table.unpack(components))

		local results = {}
		local count = 0

		-- e_data layout: { entity = id, [com_name] = value, ... }
		context.em:foreach(filter, function(e_data)
			count = count + 1
			local row = { e_data.entity }
			for i = 1, width do
				row[i + 1] = e_data[components[i]]
			end
			results[count] = row
		end)

		return results
	end

	return Adapter
end
