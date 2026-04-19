return function(rune)
	local Adapter = {
		name = "rune",
		note = "deferred ECS",
	}

	function Adapter.createContext()
		return { world = rune.World() }
	end

	function Adapter.allocComponent(_context, index)
		return { name = tostring(index) }
	end

	function Adapter.createEntity(context)
		local uid = context.world.add_entity({})
		context.world:update(0)
		return uid
	end

	function Adapter.spawn(context, data)
		local compList = {}
		for handle, value in pairs(data) do
			compList[#compList + 1] = { name = handle.name, value = value }
		end
		local uid = context.world.add_entity(compList)
		context.world:update(0)
		return uid
	end

	function Adapter.makeEntityData(_context, components, blueprint)
		local data = {}
		for i = 1, #blueprint.components do
			data[components[blueprint.components[i]]] = blueprint.values[i]
		end
		return data
	end

	function Adapter.set(context, entity, component, value)
		context.world.add_component(entity, { name = component.name, value = value })
	end

	function Adapter.get(context, entity, component)
		local e = context.world.entities[entity]
		if not e then
			return nil
		end
		local c = e[component.name]
		return c and c.value
	end

	function Adapter.has(context, entity, component)
		local e = context.world.entities[entity]
		return e ~= nil and e[component.name] ~= nil
	end

	function Adapter.remove(context, entity, component)
		context.world.remove_component(entity, component)
	end

	function Adapter.query(context, components)
		context.world:update(0)

		local width = #components
		local names = {}
		for i = 1, width do
			names[i] = components[i].name
		end

		local results = {}
		local count = 0

		for uid, entity in pairs(context.world.entities) do
			local ok = true
			for i = 1, width do
				if entity[names[i]] == nil then
					ok = false
					break
				end
			end
			if ok then
				count = count + 1
				local row = { uid }
				for i = 1, width do
					row[i + 1] = entity[names[i]].value
				end
				results[count] = row
			end
		end

		return results
	end

	return Adapter
end
