return function(_)
	local Adapter = {
		name = "sparse-based",
		note = "simple sparse-set ECS using dense/sparse arrays",
	}

	function Adapter.createContext()
		return {
			nextEntityId = 0,
		}
	end

	function Adapter.createEntity(context)
		context.nextEntityId = context.nextEntityId + 1
		return context.nextEntityId
	end

	function Adapter.allocComponent(context, index)
		return {
			dense = {}, -- dense[i] = entity
			sparse = {}, -- sparse[entity] = i
			data = {}, -- data[i] = component value
			size = 0,
		}
	end

	function Adapter.set(_context, entity, component, value)
		local idx = component.sparse[entity]

		if idx ~= nil then
			component.data[idx] = value
			return
		end

		local size = component.size + 1
		component.size = size

		component.dense[size] = entity
		component.data[size] = value
		component.sparse[entity] = size
	end

	function Adapter.get(_context, entity, component)
		local idx = component.sparse[entity]
		if idx == nil then
			return nil
		end
		return component.data[idx]
	end

	function Adapter.has(_context, entity, component)
		return component.sparse[entity] ~= nil
	end

	function Adapter.remove(_context, entity, component)
		local idx = component.sparse[entity]
		if idx == nil then
			return
		end
		local last = component.size
		local lastEntity = component.dense[last]
		if idx ~= last then
			component.dense[idx] = lastEntity
			component.data[idx] = component.data[last]
			component.sparse[lastEntity] = idx
		end
		component.dense[last] = nil
		component.data[last] = nil
		component.sparse[entity] = nil
		component.size = last - 1
	end

	function Adapter.query(_context, components)
		local width = #components
		if width == 0 then
			return {}
		end

		local primaryIndex = 1
		local primary = components[1]
		for i = 2, width do
			if components[i].size < primary.size then
				primary = components[i]
				primaryIndex = i
			end
		end

		local othersSparse = {}
		local othersData = {}
		local othersRowPos = {}
		local othersCount = 0
		for i = 1, width do
			if i ~= primaryIndex then
				othersCount = othersCount + 1
				othersSparse[othersCount] = components[i].sparse
				othersData[othersCount] = components[i].data
				othersRowPos[othersCount] = i + 1
			end
		end

		local idxCache = {}
		local results = {}
		local count = 0
		local primaryDense = primary.dense
		local primaryData = primary.data
		local primaryRowPos = primaryIndex + 1

		for pos = 1, primary.size do
			local entity = primaryDense[pos]

			local ok = true
			for i = 1, othersCount do
				local idx = othersSparse[i][entity]
				if idx == nil then
					ok = false
					break
				end
				idxCache[i] = idx
			end

			if ok then
				count = count + 1
				local row = { entity }
				row[primaryRowPos] = primaryData[pos]
				for i = 1, othersCount do
					row[othersRowPos[i]] = othersData[i][idxCache[i]]
				end
				results[count] = row
			end
		end

		return results
	end

	return Adapter
end
