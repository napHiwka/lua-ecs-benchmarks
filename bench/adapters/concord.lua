return function(Concord)
	local Adapter = {
		name = "concord",
		note = "",
	}

	-- Concord.component errors on duplicate names. Track registrations at
	-- module level so createContext can be called multiple times safely
	local registered = {}

	function Adapter.createContext()
		return {
			world = Concord.world(),
			systems = {},
		}
	end

	function Adapter.allocComponent(_context, index)
		local name = "c" .. index
		if not registered[name] then
			Concord.component(name, function(c, v)
				c.value = v
			end)
			registered[name] = true
		end
		return name
	end

	function Adapter.createEntity(context)
		return Concord.entity(context.world)
	end

	function Adapter.set(_context, ent, comp, value)
		ent:give(comp, value)
	end

	function Adapter.get(_context, ent, comp)
		local c = ent[comp]
		return c and c.value or nil
	end

	function Adapter.has(_context, ent, comp)
		return ent[comp] ~= nil
	end

	function Adapter.remove(_context, ent, comp)
		ent:remove(comp)
	end

	function Adapter.query(context, components)
		-- Drain __added / __removed / __dirty queues so system pools reflect
		-- the current state of the world. Without this, pools stay empty
		-- because World:addEntity only writes to __added, and give() only
		-- writes to __dirty; both are resolved inside __flush()
		context.world:__flush()

		local key = table.concat(components, ",")
		if not context.systems[key] then
			local SystemClass = Concord.system({ pool = components })
			context.world:addSystem(SystemClass)
			context.systems[key] = SystemClass
			-- Adding a system after entities already exist requires a second
			-- flush so the new system's pool gets populated immediately
			context.world:__flush()
		end

		local sys = context.world:getSystem(context.systems[key])
		local out = {}
		local count = 0
		for i = 1, sys.pool.size do
			local ent = sys.pool[i]
			count = count + 1
			local row = { ent }
			for j = 1, #components do
				local c = ent[components[j]]
				row[j + 1] = c and c.value or nil
			end
			out[count] = row
		end
		return out
	end

	return Adapter
end
