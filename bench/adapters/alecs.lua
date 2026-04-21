return function(library)
	local Adapter = {
		name = "alecs",
		note = "entities are plain Lua tables; components are fields. "
			.. "query uses alecs:filter() which is a full linear scan via pairs(entities). "
			.. "removing a component does not remove the entity from the scan -- "
			.. "stale entities continue to participate in query iterations. "
			.. "removeEntity() nils the slot, leaving a sparse table for pairs().",
	}

	function Adapter.createContext()
		return {
			world = library(),
		}
	end

	function Adapter.createEntity(context)
		-- addEntity returns the id, but we need the entity table itself
		-- for direct field access in set/get/has/remove
		local entity = {}
		context.world:addEntity(entity)
		return entity
	end

	function Adapter.allocComponent(_context, index)
		-- Alecs identifies components by string keys on the entity table
		return "c" .. index
	end

	function Adapter.set(_context, entity, component, value)
		entity[component] = value
	end

	function Adapter.get(_context, entity, component)
		return entity[component]
	end

	function Adapter.has(_context, entity, component)
		return entity[component] ~= nil
	end

	function Adapter.remove(_context, entity, component)
		entity[component] = nil
	end

	function Adapter.query(context, components)
		local width = #components
		if width == 0 then
			return {}
		end

		-- alecs:filter expects an array of component name strings
		-- and returns matching entity tables
		local matched = context.world:filter(components)

		local results = {}
		local count = 0
		for i = 1, #matched do
			local entity = matched[i]
			count = count + 1
			local row = { entity }
			for j = 1, width do
				row[j + 1] = entity[components[j]]
			end
			results[count] = row
		end

		return results
	end

	return Adapter
end
