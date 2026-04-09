local Compat = require("bench.shared.compat")
local Config = require("bench.config")

local RngMethods = {}
RngMethods.__index = RngMethods

function RngMethods:nextUInt()
	local state = (self.state * 16807) % 2147483647
	if state <= 0 then
		state = 1
	end
	self.state = state
	return state
end

function RngMethods:nextFloat()
	return (self:nextUInt() % 1000000) / 1000000
end

function RngMethods:nextInt(minValue, maxValue)
	local span = maxValue - minValue + 1
	return minValue + (self:nextUInt() % span)
end

local function newRng(seed)
	local initial = math.floor(math.abs(seed)) % 2147483647
	if initial == 0 then
		initial = 1
	end

	return setmetatable({
		state = initial,
	}, RngMethods)
end

local function componentFill(config, componentIndex)
	if componentIndex == 1 then
		return config.dataset.hotComponentFill
	elseif componentIndex <= 3 then
		return config.dataset.primaryQueryComponentFill
	end

	return config.dataset.baseComponentFill
end

local function makeBlueprint(rng, config)
	local components = Compat.createArray()
	local values = Compat.createArray()

	for componentIndex = 1, config.dataset.componentsPerWorld do
		if rng:nextFloat() <= componentFill(config, componentIndex) then
			components[#components + 1] = componentIndex
			values[#values + 1] = rng:nextFloat()
		end
	end

	if #components == 0 then
		components[1] = 1
		values[1] = rng:nextFloat()
	end

	return {
		components = components,
		values = values,
	}
end

local function chooseExistingComponent(rng, blueprint)
	return blueprint.components[rng:nextInt(1, #blueprint.components)]
end

local function makeQueryDefinitions(config, rng)
	local queryDefinitions = Compat.createArray()
	local queryCount = config.queryWorkloads.multiQueryCount
	local componentCount = config.dataset.componentsPerWorld

	for queryIndex = 1, queryCount do
		local width
		if queryIndex % 6 == 0 then
			width = 4
		elseif queryIndex % 3 == 0 then
			width = 3
		elseif queryIndex % 2 == 0 then
			width = 2
		else
			width = 1
		end

		local used = {}
		local components = Compat.createArray()
		while #components < width do
			local componentIndex
			if #components == 0 and queryIndex <= 8 then
				componentIndex = ((queryIndex - 1) % 4) + 1
			else
				componentIndex = rng:nextInt(1, componentCount)
			end

			if not used[componentIndex] then
				used[componentIndex] = true
				components[#components + 1] = componentIndex
			end
		end

		queryDefinitions[#queryDefinitions + 1] = components
	end

	return queryDefinitions
end

local Workload = {}

function Workload.build(config)
	local rng = newRng(config.seed)

	local blueprints = Compat.createArray()
	for entityIndex = 1, config.dataset.entitiesPerRun do
		blueprints[entityIndex] = makeBlueprint(rng, config)
	end

	local updateOps = Compat.createArray()
	for opIndex = 1, config.mutationWorkloads.writesPerPhase do
		local entityIndex = rng:nextInt(1, config.dataset.entitiesPerRun)
		local componentIndex = chooseExistingComponent(rng, blueprints[entityIndex])
		updateOps[opIndex] = {
			entityIndex = entityIndex,
			componentIndex = componentIndex,
			value = rng:nextFloat(),
		}
	end

	local structuralOps = Compat.createArray()
	for opIndex = 1, config.mutationWorkloads.structuralChangesPerPhase do
		structuralOps[opIndex] = {
			entityIndex = rng:nextInt(1, config.dataset.entitiesPerRun),
			componentIndex = rng:nextInt(1, config.dataset.componentsPerWorld),
			value = rng:nextFloat(),
		}
	end

	local randomReadOps = Compat.createArray()
	for readIndex = 1, config.queryWorkloads.randomReadCount do
		randomReadOps[readIndex] = {
			entityIndex = rng:nextInt(1, config.dataset.entitiesPerRun),
			componentIndex = rng:nextInt(1, config.dataset.componentsPerWorld),
		}
	end

	local wideQueryComponents = Compat.createArray()
	for componentIndex = 1, config.queryWorkloads.wideQueryWidth do
		wideQueryComponents[componentIndex] = componentIndex
	end

	return {
		config = config,
		blueprints = blueprints,
		updateOps = updateOps,
		structuralOps = structuralOps,
		randomReadOps = randomReadOps,
		primaryQueryComponents = { 1, 2, 3 },
		wideQueryComponents = wideQueryComponents,
		hotComponent = 1,
		workQueryDefinitions = makeQueryDefinitions(config, rng),
	}
end

function Workload.loadConfig()
	return Config
end

return Workload
