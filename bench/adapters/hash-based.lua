return function(_)
	local Adapter = {
		name = "hash-based",
		note = "naive hash ECS using plain Lua tables",
	}

	function Adapter.createContext()
		return {
			nextEntityId = 0,
			components = {},
		}
	end

	function Adapter.createEntity(context)
		context.nextEntityId = context.nextEntityId + 1
		return context.nextEntityId
	end

	function Adapter.allocComponent(_context, _index)
		return { data = {}, size = 0 }
	end

	function Adapter.set(_context, entity, component, value)
		if component.data[entity] == nil then
			component.size = component.size + 1
		end
		component.data[entity] = value
	end

	function Adapter.get(_context, entity, component)
		return component.data[entity]
	end

	function Adapter.has(_context, entity, component)
		return component.data[entity] ~= nil
	end

	function Adapter.remove(_context, entity, component)
		if component.data[entity] ~= nil then
			component.size = component.size - 1
		end
		component.data[entity] = nil
	end

	function Adapter.query(_context, components)
		-- find smallest component set to iterate over
		local primary = components[1]
		for i = 2, #components do
			if components[i].size < primary.size then
				primary = components[i]
			end
		end

		local width = #components
		local results = {}
		local count = 0

		for entity in next, primary.data do
			local ok = true
			for i = 1, width do
				if components[i].data[entity] == nil then
					ok = false
					break
				end
			end

			if ok then
				count = count + 1
				local row = { entity }
				for i = 1, width do
					row[i + 1] = components[i].data[entity]
				end
				results[count] = row
			end
		end

		return results
	end
	return Adapter
end
