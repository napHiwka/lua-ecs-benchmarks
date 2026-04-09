local Stats = require("bench.shared.stats")
local Workload = require("bench.shared.workload")
local Scenarios = require("bench.shared.scenarios")

local Runner = {}

local config = Workload.loadConfig()
local spec = Workload.build(config)
local scenarioFunctions = Scenarios.build(spec)

local function summarizeRuns(runResults)
    local scenarioSummaries = {}
    local totalTimes = {}

    for runIndex = 1, #runResults do
        local totalTime = 0
        local results = runResults[runIndex]
        for scenarioIndex = 1, #results do
            local result = results[scenarioIndex]
            totalTime = totalTime + result.seconds

            local summary = scenarioSummaries[scenarioIndex]
            if not summary then
                summary = {
                    name = result.name,
                    seconds = {},
                }
                scenarioSummaries[scenarioIndex] = summary
            end
            summary.seconds[#summary.seconds + 1] = result.seconds
        end
        totalTimes[#totalTimes + 1] = totalTime
    end

    for scenarioIndex = 1, #scenarioSummaries do
        scenarioSummaries[scenarioIndex].timing = Stats.summarize(scenarioSummaries[scenarioIndex].seconds)
    end

    return {
        scenarios = scenarioSummaries,
        totalTiming = Stats.summarize(totalTimes),
    }
end

function Runner.runAdapter(adapter)
    local runResults = {}
    for runIndex = 1, config.execution.runsPerAdapter do
        local results = {}
        for scenarioIndex = 1, #scenarioFunctions do
            results[scenarioIndex] = scenarioFunctions[scenarioIndex](adapter, spec)
        end
        runResults[runIndex] = results
    end

    return {
        runs = runResults,
        summary = summarizeRuns(runResults),
    }
end

function Runner.getConfig()
    return config
end

return Runner
