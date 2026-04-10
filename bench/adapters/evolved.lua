return function(evo)
    local unpack = table.unpack or unpack

    local Adapter = {
        name = "evolved (not real usage)",
        note = table.concat({
            "Chunk/archetype ECS; fragments are plain integer IDs.",
            "createEntity allocates an ID only. World registration happens on the first set().",
            "query() performs a single process_with collection pass into a flat array,",
            "then iterates that array. This faithfully represents the cost of adapting",
            "a chunk-level API to an entity-level iterator contract.",
            "It's possible that this implementation of the adapter",
            "still have a lot of space to optimize library effectiveness.",
        }, " "),
    }

    function Adapter.createContext()
        return {}
    end

    -- Returns a new unique fragment ID. Index argument is ignored because
    -- evolved's identity space is a single monotone counter, not an array
    function Adapter.allocComponent(_, _index)
        return evo.id()
    end

    -- The entity enters an archetype only after the first set() call below
    function Adapter.createEntity(_context)
        return evo.id()
    end

    function Adapter.destroyEntity(_context, entity)
        evo.destroy(entity)
    end

    function Adapter.set(_context, entity, component, value)
        evo.set(entity, component, value)
    end

    function Adapter.get(_context, entity, component)
        return evo.get(entity, component)
    end

    function Adapter.has(_context, entity, component)
        return evo.has(entity, component)
    end

    function Adapter.remove(_context, entity, component)
        evo.remove(entity, component)
    end

    -- Returns a stateless Lua iterator over (entity, c1, c2, ...) tuples
    --
    -- Implementation: creates a temporary stage + system, runs one process_with
    -- pass to collect all matching chunk rows into a flat table, then destroys
    -- both the stage and system. The iterator walks the collected table
    --
    -- This is the honest cost of wrapping a chunk-level API: one allocation pass
    -- plus GC pressure from the result rows. Frameworks with native entity-level
    -- iterators will not pay this price.
    function Adapter.query(_context, components)
        local width = #components
        local results = {}
        local count = 0

        local stage = evo.id()
        local sys = evo.builder()
            :group(stage)
            :include(unpack(components))
            :execute(function(chunk, entity_list, entity_count)
                -- chunk: components accepts multiple fragments and returns
                -- multiple arrays in one call, matching evolved's native idiom
                local arrays = { chunk:components(unpack(components)) }
                for i = 1, entity_count do
                    count = count + 1
                    local row = { entity_list[i] }
                    for ci = 1, width do
                        row[ci + 1] = arrays[ci][i]
                    end
                    results[count] = row
                end
            end)
            :build()

        evo.process_with(stage, 0)

        -- we can destroy it; the collected data lives in `results`
        evo.destroy(sys)
        evo.destroy(stage)

        local index = 0
        return function()
            index = index + 1
            local row = results[index]
            if not row then
                return nil
            end
            return unpack(row)
        end
    end

    return Adapter
end
