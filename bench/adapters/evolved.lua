return function(evo)
	local unpack = table.unpack or unpack

	local Adapter = {
		name = "evolved",
		note = "chunk/archetype ECS",
	}

	function Adapter.createContext()
		return {}
	end

	function Adapter.allocComponent(_, _index)
		return evo.id()
	end

	function Adapter.createEntity(_context)
		return evo.id()
	end

	function Adapter.destroyEntity(_context, entity)
		evo.destroy(entity)
	end

	function Adapter.set(_context, entity, component, value)
		evo.set(entity, component, value)
	end

	function Adapter.get(_context, entity, component)
		return evo.get(entity, component)
	end

	function Adapter.has(_context, entity, component)
		return evo.has(entity, component)
	end

	function Adapter.remove(_context, entity, component)
		evo.remove(entity, component)
	end

	function Adapter.query(_context, components)
		local width = #components
		local results = {}
		local count = 0

		local stage = evo.id()
		local sys = evo.builder()
			:group(stage)
			:include(unpack(components))
			:execute(function(chunk, entity_list, entity_count)
				local arrays = { chunk:components(unpack(components)) }
				for i = 1, entity_count do
					count = count + 1
					local row = { entity_list[i] }
					for ci = 1, width do
						row[ci + 1] = arrays[ci][i]
					end
					results[count] = row
				end
			end)
			:build()

		evo.process_with(stage, 0)
		evo.destroy(sys)
		evo.destroy(stage)

		return results
	end

	return Adapter
end
