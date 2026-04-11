return function(ecs)
	local Adapter = {
		name = "ecs-lua",
		note = "Component-object ECS: each ComponentClass wraps values in { value = ... }",
	}

	function Adapter.createContext()
		local world = ecs.World(nil, 30, true)
		return { world = world }
	end

	function Adapter.allocComponent(_context, _index)
		return ecs.Component({ value = 0 })
	end

	function Adapter.createEntity(context)
		return context.world:Entity()
	end

	function Adapter.spawn(context, data)
		local instances = {}
		for compClass, value in pairs(data) do
			instances[#instances + 1] = compClass({ value = value })
		end
		return context.world:Entity(table.unpack(instances))
	end

	function Adapter.makeEntityData(_context, components, blueprint)
		local data = {}
		for index = 1, #blueprint.components do
			data[components[blueprint.components[index]]] = blueprint.values[index]
		end
		return data
	end

	function Adapter.set(_context, entity, component, value)
		entity:Set(component, component({ value = value }))
	end

	function Adapter.get(_context, entity, component)
		local instance = entity[component]
		return instance and instance.value or nil
	end

	function Adapter.has(_context, entity, component)
		return entity[component] ~= nil
	end

	function Adapter.remove(_context, entity, component)
		entity[component] = nil
	end

	function Adapter.query(context, components)
		context.world:Update("process", os.clock())

		local q = ecs.Query.All(table.unpack(components))
		local entities = context.world:Exec(q):ToArray()
		local width = #components
		local results = {}

		for i = 1, #entities do
			local entity = entities[i]
			local row = { entity }
			for ci = 1, width do
				local inst = entity[components[ci]]
				row[ci + 1] = inst and inst.value
			end
			results[i] = row
		end

		return results
	end

	return Adapter
end
