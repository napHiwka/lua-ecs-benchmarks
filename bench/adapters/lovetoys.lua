return function(library)
	local Adapter = {
		name = "lovetoys",
		note = "uses Engine + Entity. Queries via engine:getEntitiesWithComponent (single component) "
			.. "or custom System for multi-component. No native multi-component query outside systems.",
	}
	library.initialize({ debug = false, globals = false })
	function Adapter.createContext()
		local engine = library.Engine()
		return {
			engine = engine,
			componentClasses = {},
		}
	end

	function Adapter.createEntity(context)
		local entity = library.Entity()
		return entity
	end

	function Adapter.allocComponent(context, index)
		local name = "Comp" .. index
		if not context.componentClasses[name] then
			context.componentClasses[name] = library.Component.create(name, { "value" }, { value = 0 })
		end
		return name
	end

	function Adapter.set(context, entity, component, value)
		local cls = context.componentClasses[component]
		if cls then
			entity:set(cls(value))
		end
	end

	function Adapter.get(context, entity, component)
		return entity:get(component)
	end

	function Adapter.has(context, entity, component)
		return entity:has(component)
	end

	function Adapter.remove(context, entity, component)
		entity:remove(component)
	end

	function Adapter.addEntityToWorld(context, entity)
		context.engine:addEntity(entity)
	end

	function Adapter.query(context, components)
		if #components == 0 then
			return {}
		end

		local primary = components[1]
		local candidates = context.engine:getEntitiesWithComponent(primary) or {}

		local result = {}

		for _, entity in ipairs(candidates) do
			local row = { entity }

			local allMatch = true
			for i = 2, #components do
				if not entity:has(components[i]) then
					allMatch = false
					break
				end
			end

			if allMatch then
				for _, compName in ipairs(components) do
					local comp = entity:get(compName)
					table.insert(row, comp and comp.value or nil)
				end
				table.insert(result, row)
			end
		end

		return result
	end

	return Adapter
end
