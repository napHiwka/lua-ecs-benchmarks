return function(_)
	local Adapter = {
		name = "table-based",
		note = "each entity is a plain Lua table. Components are fields on the entity. "
			.. "query() iterates a flat entity list with linear scan."
			.. "There is a flaw - removing a component does not remove the entity from `context.entities`"
			.. " means that deleted entities continue to be included in the query scan.",
	}

	function Adapter.createContext()
		return { entities = {} }
	end

	function Adapter.createEntity(context)
		local entity = {}
		context.entities[#context.entities + 1] = entity
		return entity
	end

	function Adapter.allocComponent(_context, index)
		return index
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
		local entities = context.entities
		local width = #components
		local results = {}
		local count = 0

		for i = 1, #entities do
			local entity = entities[i]
			local ok = true
			for j = 1, width do
				if entity[components[j]] == nil then
					ok = false
					break
				end
			end
			if ok then
				count = count + 1
				local row = { entity }
				for j = 1, width do
					row[j + 1] = entity[components[j]]
				end
				results[count] = row
			end
		end

		return results
	end

	return Adapter
end
