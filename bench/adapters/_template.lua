return function(library)
	local Adapter = {
		name = "name",
		note = "",
	}

	function Adapter.createContext()
		return {}
	end

	function Adapter.createEntity(context) end

	function Adapter.allocComponent(context, index) end

	-- Optional: implement if your library has an efficient batch-creation API
	-- If omitted, the harness calls createEntity + set for each component
	-- function Adapter.spawn(context, data) end

	-- Optional: override if your library needs a different data layout
	-- than { [componentHandle] = value }.
	-- function Adapter.makeEntityData(context, components, blueprint) end

	function Adapter.set(context, entity, component, value) end

	function Adapter.get(context, entity, component) end

	function Adapter.has(context, entity, component) end

	function Adapter.remove(context, entity, component) end

	-- Must return one of:
	--
	-- Iterator: function() -> entity, v1, v2, ...  (nil when exhausted)
	-- Array:    { { entity, v1, v2, ... }, ... }
	function Adapter.query(context, components) end

	return Adapter
end
