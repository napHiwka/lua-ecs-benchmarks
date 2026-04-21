return function(_)
	local Adapter = {
		name = "table-based",
		note = "each entity is a plain Lua table. Components are fields on the entity. "
			.. "query() iterates a flat entity list with linear scan. "
			.. "Entities with no remaining components are removed from the list via swap-with-last.",
	}

	function Adapter.createContext()
		return { entities = {}, count = 0 }
	end

	function Adapter.createEntity(context)
		local c = context.count + 1
		context.count = c
		-- _i stores the position in entities for O(1) deletion
		-- _n counts the active components to determine when the entity has become empty
		local entity = { _i = c, _n = 0 }
		context.entities[c] = entity
		return entity
	end

	function Adapter.allocComponent(_context, index)
		return index
	end

	function Adapter.set(_context, entity, component, value)
		if entity[component] == nil then
			entity._n = entity._n + 1
		end
		entity[component] = value
	end

	function Adapter.get(_context, entity, component)
		return entity[component]
	end

	function Adapter.has(_context, entity, component)
		return entity[component] ~= nil
	end

	function Adapter.remove(context, entity, component)
		if entity[component] == nil then
			return
		end
		entity[component] = nil
		local n = entity._n - 1
		entity._n = n
		-- the entity is empty; remove it from the list so it isn't scanned unnecessarily
		if n == 0 then
			local entities = context.entities
			local i = entity._i
			local last = context.count
			if i ~= last then
				local moved = entities[last]
				entities[i] = moved
				moved._i = i
			end
			entities[last] = nil
			context.count = last - 1
		end
	end

	function Adapter.query(context, components)
		local entities = context.entities
		local width = #components
		local results = {}
		local count = 0

		for i = 1, context.count do
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
