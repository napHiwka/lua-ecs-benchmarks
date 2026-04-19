return function(tiny)
	local Adapter = {
		name = "tiny-ecs-no-reuse",
		note = "builds a fresh emulated query system for every query call. This intentionally measures repeated system construction overhead (anti-pattern)",
	}

	function Adapter.createContext()
		return {
			world = tiny.world(),
		}
	end

	function Adapter.allocComponent(_, index)
		return index
	end

	function Adapter.createEntity(context)
		local entity = {}
		tiny.addEntity(context.world, entity)
		return entity
	end

	function Adapter.set(context, entity, component, value)
		entity[component] = value
		tiny.addEntity(context.world, entity)
	end

	function Adapter.get(_, entity, component)
		return entity[component]
	end

	function Adapter.has(_, entity, component)
		return entity[component] ~= nil
	end

	function Adapter.remove(context, entity, component)
		entity[component] = nil
		tiny.addEntity(context.world, entity)
	end

	local function makeSystem(components)
		return tiny.system({
			filter = function(_, entity)
				for index = 1, #components do
					if entity[components[index]] == nil then
						return false
					end
				end
				return true
			end,
		})
	end

	function Adapter.query(context, components)
		local system = makeSystem(components)
		tiny.addSystem(context.world, system)
		tiny.refresh(context.world)
		local results = {}

		local entities = system.entities

		for entityIndex = 1, #entities do
			local entity = entities[entityIndex]
			local row = { entity }
			for ci = 1, #components do
				row[ci + 1] = entity[components[ci]]
			end
			results[entityIndex] = row
		end

		return results
	end

	return Adapter
end
