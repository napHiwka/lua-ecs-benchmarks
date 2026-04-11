local Compat = require("bench.shared.compat")
local Consumer = require("bench.shared.consumer")

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
    local components = {}
    for componentIndex = 1, spec.config.dataset.componentsPerWorld do
        components[componentIndex] = adapter.allocComponent(context, componentIndex)
    end

    local makeEntityData = adapter.makeEntityData or defaultMakeEntityData
    local spawnData = {}
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
    local entities = {}
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
    local resolved = {}
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
    local resolved = {}
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
    local resolved = {}
    for index = 1, #indices do
        resolved[index] = componentTable[indices[index]]
    end
    return resolved
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
    local consume = Consumer.detectConsumer(adapter.query(state.context, components), 1)
    return finalizeScenario(
        timeScenario("query_1_component", spec.config.garbageCollection, function()
            local checksum = 0
            for _ = 1, spec.config.queryWorkloads.queryIterations do
                checksum = checksum + consume(adapter.query(state.context, components)) * 1.01
            end
            return checksum
        end),
        state
    )
end

local function runThreeComponentQuery(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local components = resolveComponents(state.components, spec.primaryQueryComponents)
    local consume = Consumer.detectConsumer(adapter.query(state.context, components), 3)
    return finalizeScenario(
        timeScenario("query_3_components", spec.config.garbageCollection, function()
            local checksum = 0
            for _ = 1, spec.config.queryWorkloads.queryIterations do
                checksum = checksum + consume(adapter.query(state.context, components)) * 0.5
            end
            return checksum
        end),
        state
    )
end

local function runWideComponentQuery(adapter, spec)
    local state = prepareSpawnData(adapter, spec)
    local components = resolveComponents(state.components, spec.wideQueryComponents)
    local width = #components
    local entities = {}
    for entityIndex = 1, spec.config.dataset.entitiesPerRun do
        local data = {}
        for componentIndex = 1, width do
            data[components[componentIndex]] = entityIndex * 0.0001 + componentIndex * 0.01
        end
        entities[entityIndex] = spawnEntity(adapter, state.context, data)
    end
    state.entities = entities
    local consume = Consumer.detectConsumer(adapter.query(state.context, components), width)
    return finalizeScenario(
        timeScenario("query_wide_components", spec.config.garbageCollection, function()
            local checksum = 0
            for _ = 1, spec.config.queryWorkloads.queryIterations do
                checksum = checksum + consume(adapter.query(state.context, components))
            end
            return checksum
        end),
        state
    )
end

local function runWorkManyQueries(adapter, spec)
    local state = prepareWorld(adapter, spec)
    local updates = resolveOps(state, spec.updateOps)
    local queries = {}
    local consumers = {}
    for queryIndex = 1, #spec.workQueryDefinitions do
        queries[queryIndex] = resolveComponents(state.components, spec.workQueryDefinitions[queryIndex])
        consumers[queryIndex] =
            Consumer.detectConsumer(adapter.query(state.context, queries[queryIndex]), #queries[queryIndex])
    end
    return finalizeScenario(
        timeScenario("work_many_queries", spec.config.garbageCollection, function()
            local checksum = 0
            local writesPerFrame = spec.config.queryWorkloads.writesPerWorkFrame
            local updateCount = #updates
            for frameIndex = 1, spec.config.queryWorkloads.workFrameCount do
                for queryIndex = 1, #queries do
                    checksum = checksum + consumers[queryIndex](adapter.query(state.context, queries[queryIndex]))
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
    local consumeHot = Consumer.detectConsumer(adapter.query(state.context, hotQuery), #hotQuery)
    local consumePrimary = Consumer.detectConsumer(adapter.query(state.context, primaryQuery), #primaryQuery)
    return finalizeScenario(
        timeScenario("stress_mixed_frame", spec.config.garbageCollection, function()
            local checksum = 0
            local updateCount = #updates
            local structuralCount = #ops
            for frameIndex = 1, spec.config.stress.frameCount do
                checksum = checksum + consumePrimary(adapter.query(state.context, primaryQuery))
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
                checksum = checksum + consumeHot(adapter.query(state.context, hotQuery))
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
