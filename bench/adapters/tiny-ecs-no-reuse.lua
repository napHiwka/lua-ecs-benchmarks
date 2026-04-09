return function(tiny)
    local Adapter = {
        name = "tiny-ecs-no-reuse",
        note =
        "Builds a fresh emulated query system for every query call. This intentionally measures repeated system construction overhead (anti-pattern).",
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

        local entities = system.entities
        local width = #components
        local index = 0

        return function()
            index = index + 1
            local entity = entities[index]
            if not entity then
                return nil
            end

            if width == 1 then
                return entity, entity[components[1]]
            elseif width == 2 then
                return entity, entity[components[1]], entity[components[2]]
            elseif width == 3 then
                return entity, entity[components[1]], entity[components[2]], entity[components[3]]
            elseif width == 4 then
                return entity, entity[components[1]], entity[components[2]], entity[components[3]], entity
                    [components[4]]
            end

            local packed = { entity }
            for componentIndex = 1, width do
                packed[componentIndex + 1] = entity[components[componentIndex]]
            end
            return table.unpack(packed)
        end
    end

    return Adapter
end
