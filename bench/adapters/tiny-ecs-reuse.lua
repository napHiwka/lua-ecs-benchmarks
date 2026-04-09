return function(tiny)
    local Adapter = {
        name = "tiny-ecs-reuse",
        note =
        "Tiny-ECS does not provide native ECS queries here. The adapter reuses emulated systems and refreshes the world before iteration.",
    }

    function Adapter.createContext()
        return {
            world = tiny.world(),
            systems = {},
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

    local function makeQueryKey(components)
        local ids = {}
        for index = 1, #components do
            ids[index] = tostring(components[index])
        end
        return table.concat(ids, "|")
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

    local function getSystem(context, components)
        local key = makeQueryKey(components)
        local system = context.systems[key]
        if not system then
            system = makeSystem(components)
            context.systems[key] = system
            tiny.addSystem(context.world, system)
            tiny.refresh(context.world)
        end
        return system
    end

    function Adapter.query(context, components)
        tiny.refresh(context.world)
        local entities = getSystem(context, components).entities
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
