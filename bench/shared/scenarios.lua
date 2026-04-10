local Compat = require("bench.shared.compat")

local Scenarios = {}

local function collectIfConfigured(gcConfig, phase)
    if gcConfig[phase] then
        collectgarbage("collect")
    end
end

local function defaultMakeEntityData(_, components, blueprint)
    local data = {}
    for index = 1, #blueprint.components do
        data[components[blueprint.components[index]]] = blueprint.values[index]
    end
    return data
end

local function spawnEntity(adapter, context, data)
    if adapter.spawn then
        return adapter.spawn(context, data)
    end

    local entity = adapter.createEntity(context)
    for component, value in pairs(data) do
        adapter.set(context, entity, component, value)
    end
    return entity
end

local function prepareSpawnData(adapter, spec)
    local context = adapter.createContext()
    local components = Compat.createArray()
    for componentIndex = 1, spec.config.dataset.componentsPerWorld do
        components[componentIndex] = adapter.allocComponent(context, componentIndex)
    end

    local makeEntityData = adapter.makeEntityData or defaultMakeEntityData
    local spawnData = Compat.createArray()
    for entityIndex = 1, spec.config.dataset.entitiesPerRun do
        spawnData[entityIndex] = makeEntityData(context, components, spec.blueprints[entityIndex])
    end

    return {
        adapter = adapter,
        context = context,
        components = components,
        spawnData = spawnData,
        entities = nil,
    }
end

local function prepareWorld(adapter, spec)
    local state = prepareSpawnData(adapter, spec)
    local entities = Compat.createArray()
    for entityIndex = 1, spec.config.dataset.entitiesPerRun do
        entities[entityIndex] = spawnEntity(adapter, state.context, state.spawnData[entityIndex])
    end
    state.entities = entities
    return state
end

local function timeScenario(name, gcConfig, callback)
    collectIfConfigured(gcConfig, "collectBeforeScenario")
    local beforeKB = collectgarbage("count")
    local started = os.clock()
    local checksum = callback()
    local finished = os.clock()
    collectIfConfigured(gcConfig, "collectAfterScenario")
    local afterKB = collectgarbage("count")

    return {
        name = name,
        seconds = finished - started,
        checksum = checksum,
        verifyCount = 0,
        verifySum = 0,
        memoryDeltaKB = afterKB - beforeKB,
    }
end

local function fingerprintState(state)
    if not state.entities then
        return 0, 0
    end

    local count = 0
    local sum = 0
    for entityIndex = 1, #state.entities do
        local entity = state.entities[entityIndex]
        for componentIndex = 1, #state.components do
            local component = state.components[componentIndex]
            if state.adapter.has(state.context, entity, component) then
                count = count + 1
                local value = state.adapter.get(state.context, entity, component)
                if type(value) == "number" then
                    sum = sum + value + componentIndex * 0.0001
                else
                    sum = sum + componentIndex * 0.0001
                end
            end
        end
    end

    return count, sum
end

local function finalizeScenario(result, state)
    local verifyCount, verifySum = fingerprintState(state)
    result.verifyCount = verifyCount
    result.verifySum = verifySum
    return result
end

local function resolveOps(state, ops)
    local resolved = Compat.createArray()
    for index = 1, #ops do
        local op = ops[index]
        resolved[index] = {
            entity = state.entities[op.entityIndex],
            component = state.components[op.componentIndex],
            componentIndex = op.componentIndex,
            value = op.value,
        }
    end
    return resolved
end

local function resolveReadOps(state, ops)
    local resolved = Compat.createArray()
    for index = 1, #ops do
        local op = ops[index]
        resolved[index] = {
            entity = state.entities[op.entityIndex],
            component = state.components[op.componentIndex],
            componentIndex = op.componentIndex,
        }
    end
    return resolved
end

local function resolveComponents(componentTable, indices)
    local resolved = Compat.createArray()
    for index = 1, #indices do
        resolved[index] = componentTable[indices[index]]
    end
    return resolved
end

local function consumeQuery(iterator, width)
    local checksum = 0
    if width == 1 then
        while true do
            local entity, a = iterator()
            if entity == nil then
                break
            end
            checksum = checksum + a * 0.02
        end
    elseif width == 2 then
        while true do
            local entity, a, b = iterator()
            if entity == nil then
                break
            end
            checksum = checksum + a * 0.02 + b * 0.03
        end
    elseif width == 3 then
        while true do
            local entity, a, b, c = iterator()
            if entity == nil then
                break
            end
            checksum = checksum + a * 0.02 + b * 0.03 + c * 0.04
        end
    elseif width == 4 then
        while true do
            local entity, a, b, c, d = iterator()
            if entity == nil then
                break
            end
            checksum = checksum + a * 0.02 + b * 0.03 + c * 0.04 + d * 0.05
        end
    elseif width == 9 then
        while true do
            local entity, a, b, c, d, e, f, g, h, i = iterator()
            if entity == nil then
                break
            end
            checksum = checksum
                + a * 0.02
                + b * 0.03
                + c * 0.04
                + d * 0.05
                + e * 0.06
                + f * 0.07
                + g * 0.08
                + h * 0.09
                + i * 0.10
        end
    else
        while true do
            local packed = Compat.pack(iterator())
            if packed[1] == nil then
                break
            end
            for valueIndex = 2, packed.n do
                checksum = checksum + packed[valueIndex] * (0.01 * valueIndex)
            end
        end
    end
    return checksum
end

local function runCreateEntities(adapter, spec)
    local state = prepareSpawnData(adapter, spec)
    return timeScenario("create_entities", spec.config.garbageCollection, function()
        local checksum = 0
        for entityIndex = 1, spec.config.dataset.entitiesPerRun do
            local entity = spawnEntity(adapter, state.context, state.spawnData[entityIndex])
            if entity ~= nil then
                checksum = checksum + entityIndex + 1
            else
                checksum = checksum + entityIndex
            end
        end
        return checksum
    end)
end

local function runSetExisting(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local updates = resolveOps(state, spec.updateOps)
    return finalizeScenario(
        timeScenario("set_existing_component", spec.config.garbageCollection, function()
            local checksum = 0
            for index = 1, #updates do
                local op = updates[index]
                adapter.set(state.context, op.entity, op.component, op.value)
                checksum = checksum + op.value
            end
            return checksum
        end),
        state
    )
end

local function runArchetypeTransition(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local ops = resolveOps(state, spec.structuralOps)
    return finalizeScenario(
        timeScenario("add_remove_component", spec.config.garbageCollection, function()
            local checksum = 0
            for index = 1, #ops do
                local op = ops[index]
                if adapter.has(state.context, op.entity, op.component) then
                    adapter.remove(state.context, op.entity, op.component)
                    checksum = checksum + op.componentIndex * 0.5
                else
                    adapter.set(state.context, op.entity, op.component, op.value)
                    checksum = checksum + op.value
                end
            end
            return checksum
        end),
        state
    )
end

local function runRandomReads(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local reads = resolveReadOps(state, spec.randomReadOps)
    return finalizeScenario(
        timeScenario("random_component_reads", spec.config.garbageCollection, function()
            local checksum = 0
            for index = 1, #reads do
                local op = reads[index]
                local value = adapter.get(state.context, op.entity, op.component)
                if type(value) == "number" then
                    checksum = checksum + value + op.componentIndex * 0.0001
                else
                    checksum = checksum + op.componentIndex * 0.0001
                end
            end
            return checksum
        end),
        state
    )
end

local function runSingleComponentQuery(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local components = { state.components[spec.hotComponent] }
    return finalizeScenario(
        timeScenario("query_1_component", spec.config.garbageCollection, function()
            local checksum = 0
            for _ = 1, spec.config.queryWorkloads.queryIterations do
                local iterator = adapter.query(state.context, components)
                while true do
                    local entity, value = iterator()
                    if entity == nil then
                        break
                    end
                    checksum = checksum + value * 1.01
                end
            end
            return checksum
        end),
        state
    )
end

local function runThreeComponentQuery(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local components = resolveComponents(state.components, spec.primaryQueryComponents)
    return finalizeScenario(
        timeScenario("query_3_components", spec.config.garbageCollection, function()
            local checksum = 0
            for _ = 1, spec.config.queryWorkloads.queryIterations do
                local iterator = adapter.query(state.context, components)
                while true do
                    local entity, a, b, c = iterator()
                    if entity == nil then
                        break
                    end
                    checksum = checksum + a * 0.5 + b * 0.25 + c * 0.125
                end
            end
            return checksum
        end),
        state
    )
end

local function runWideComponentQuery(adapter, spec)
    local state = prepareSpawnData(adapter, spec)
    local components = resolveComponents(state.components, spec.wideQueryComponents)
    local entities = Compat.createArray()

    for entityIndex = 1, spec.config.dataset.entitiesPerRun do
        local data = {}
        for componentIndex = 1, #components do
            data[components[componentIndex]] = entityIndex * 0.0001 + componentIndex * 0.01
        end
        entities[entityIndex] = spawnEntity(adapter, state.context, data)
    end
    state.entities = entities

    return finalizeScenario(
        timeScenario("query_wide_components", spec.config.garbageCollection, function()
            local checksum = 0
            for _ = 1, spec.config.queryWorkloads.queryIterations do
                checksum = checksum + consumeQuery(adapter.query(state.context, components), #components)
            end
            return checksum
        end),
        state
    )
end

local function runWorkManyQueries(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local updates = resolveOps(state, spec.updateOps)
    local queries = Compat.createArray()
    for queryIndex = 1, #spec.workQueryDefinitions do
        queries[queryIndex] = resolveComponents(state.components, spec.workQueryDefinitions[queryIndex])
    end

    return finalizeScenario(
        timeScenario("work_many_queries", spec.config.garbageCollection, function()
            local checksum = 0
            local writesPerFrame = spec.config.queryWorkloads.writesPerWorkFrame
            local updateCount = #updates

            for frameIndex = 1, spec.config.queryWorkloads.workFrameCount do
                for queryIndex = 1, #queries do
                    checksum = checksum
                        + consumeQuery(adapter.query(state.context, queries[queryIndex]), #queries[queryIndex])
                end

                local baseIndex = ((frameIndex - 1) * writesPerFrame) % updateCount
                for offset = 1, writesPerFrame do
                    local op = updates[((baseIndex + offset - 1) % updateCount) + 1]
                    local value = op.value + frameIndex * 0.0001
                    adapter.set(state.context, op.entity, op.component, value)
                    checksum = checksum + value
                end
            end

            return checksum
        end),
        state
    )
end

local function runStressDataUpdates(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local updates = resolveOps(state, spec.updateOps)
    return finalizeScenario(
        timeScenario("stress_data_updates", spec.config.garbageCollection, function()
            local checksum = 0
            for passIndex = 1, spec.config.stress.writePasses do
                for index = 1, #updates do
                    local op = updates[index]
                    local value = op.value + passIndex * 0.0001
                    adapter.set(state.context, op.entity, op.component, value)
                    local current = adapter.get(state.context, op.entity, op.component)
                    if type(current) == "number" then
                        checksum = checksum + current
                    end
                end
            end
            return checksum
        end),
        state
    )
end

local function runStressStructuralChurn(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local ops = resolveOps(state, spec.structuralOps)
    return finalizeScenario(
        timeScenario("stress_structural_churn", spec.config.garbageCollection, function()
            local checksum = 0
            for roundIndex = 1, spec.config.stress.structuralPasses do
                for index = 1, #ops do
                    local op = ops[index]
                    if adapter.has(state.context, op.entity, op.component) then
                        adapter.remove(state.context, op.entity, op.component)
                        checksum = checksum + op.componentIndex * 0.01
                    else
                        local value = op.value + roundIndex * 0.0001
                        adapter.set(state.context, op.entity, op.component, value)
                        checksum = checksum + value
                    end
                end
            end
            return checksum
        end),
        state
    )
end

local function runStressMixedFrame(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local updates = resolveOps(state, spec.updateOps)
    local ops = resolveOps(state, spec.structuralOps)
    local hotQuery = { state.components[spec.hotComponent] }
    local primaryQuery = resolveComponents(state.components, spec.primaryQueryComponents)
    return finalizeScenario(
        timeScenario("stress_mixed_frame", spec.config.garbageCollection, function()
            local checksum = 0
            local updateCount = #updates
            local structuralCount = #ops

            for frameIndex = 1, spec.config.stress.frameCount do
                checksum = checksum + consumeQuery(adapter.query(state.context, primaryQuery), #primaryQuery)

                local updateBase = ((frameIndex - 1) * 200) % updateCount
                for offset = 1, 200 do
                    local op = updates[((updateBase + offset - 1) % updateCount) + 1]
                    local value = op.value + frameIndex * 0.0001
                    adapter.set(state.context, op.entity, op.component, value)
                    checksum = checksum + value
                end

                local structuralBase = ((frameIndex - 1) * 120) % structuralCount
                for offset = 1, 120 do
                    local op = ops[((structuralBase + offset - 1) % structuralCount) + 1]
                    if adapter.has(state.context, op.entity, op.component) then
                        adapter.remove(state.context, op.entity, op.component)
                        checksum = checksum + op.componentIndex * 0.01
                    else
                        local value = op.value + frameIndex * 0.0002
                        adapter.set(state.context, op.entity, op.component, value)
                        checksum = checksum + value
                    end
                end

                checksum = checksum + consumeQuery(adapter.query(state.context, hotQuery), #hotQuery)
            end

            return checksum
        end),
        state
    )
end

function Scenarios.build(spec)
    local scenarios = {
        runCreateEntities,
        runSetExisting,
        runArchetypeTransition,
        runRandomReads,
        runSingleComponentQuery,
        runThreeComponentQuery,
        runWideComponentQuery,
        runWorkManyQueries,
    }

    if spec.config.execution.includeStressScenarios then
        scenarios[#scenarios + 1] = runStressDataUpdates
        scenarios[#scenarios + 1] = runStressStructuralChurn
        scenarios[#scenarios + 1] = runStressMixedFrame
    end

    return scenarios
end

return Scenarios
