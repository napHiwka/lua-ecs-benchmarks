return function(ecsLibrary)
    local Adapter = {
        name = "name",
        note = "",
    }

    function Adapter.createContext()
        return {}
    end

    function Adapter.allocComponent(context, index)
    end

    -- You can use any of this ways to create entity
    function Adapter.createEntity(context)
    end

    function Adapter.spawn(context, data)
    end

    function Adapter.makeEntityData(context, components, blueprint)
    end

    function Adapter.set(context, entity, component, value)
    end

    function Adapter.get(context, entity, component)
    end

    function Adapter.has(context, entity, component)
    end

    function Adapter.remove(context, entity, component)
    end

    function Adapter.query(context, components)
    end

    return Adapter
end
