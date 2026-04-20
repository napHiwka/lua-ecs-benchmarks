return function(rune)
	local Adapter = {
		name = "rune",
		note = "",
	}

	local function resolveEntity(context, entity)
		if type(entity) == "table" then
			return entity
		end
		return context.entities[entity]
	end

	function Adapter.createContext()
		local world = rune.World()
		return {
			world = world,
			entities = world.entities,
			next_uid = 0,
		}
	end

	function Adapter.allocComponent(_context, index)
		return { name = tostring(index) }
	end

	function Adapter.createEntity(context)
		context.next_uid = context.next_uid + 1
		local uid = context.next_uid
		context.entities[uid] = { uid = uid }
		return uid
	end

	function Adapter.spawn(context, data)
		context.next_uid = context.next_uid + 1
		local uid = context.next_uid

		local entity = { uid = uid }
		for handle, value in pairs(data) do
			entity[handle.name] = { name = handle.name, value = value }
		end

		context.entities[uid] = entity
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
		local e = resolveEntity(context, entity)
		if not e then
			return
		end
		e[component.name] = { name = component.name, value = value }
	end

	function Adapter.get(context, entity, component)
		local e = resolveEntity(context, entity)
		if not e then
			return nil
		end
		local c = e[component.name]
		return c and c.value or nil
	end

	function Adapter.has(context, entity, component)
		local e = resolveEntity(context, entity)
		return e ~= nil and e[component.name] ~= nil
	end

	function Adapter.remove(context, entity, component)
		local e = resolveEntity(context, entity)
		if not e then
			return
		end
		e[component.name] = nil
	end

	function Adapter.query(context, components)
		local width = #components
		local names = {}
		for i = 1, width do
			names[i] = components[i].name
		end

		local results = {}
		local count = 0

		for uid, entity in pairs(context.entities) do
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
