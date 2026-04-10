local Reporter = {}

local function printSection(title)
    print(title)
    print(string.rep("-", #title))
end

local function printConfigSection(title, lines)
    print(title)
    for index = 1, #lines do
        print("  " .. lines[index])
    end
    print("")
end

local function formatNumber(value)
    return string.format("%.4f", value)
end

function Reporter.printConfig(config)
    printSection("Benchmark Configuration")
    printConfigSection("Execution", {
        string.format("seed: %d", config.seed),
        string.format("runs per adapter: %d", config.execution.runsPerAdapter),
        string.format("include stress scenarios: %s", tostring(config.execution.includeStressScenarios)),
    })
    printConfigSection("Garbage Collection", {
        string.format("collect before scenario: %s", tostring(config.garbageCollection.collectBeforeScenario)),
        string.format("collect after scenario:  %s", tostring(config.garbageCollection.collectAfterScenario)),
    })
    printConfigSection("Dataset", {
        string.format("entities per run: %d", config.dataset.entitiesPerRun),
        string.format("components per world: %d", config.dataset.componentsPerWorld),
        string.format("base component fill: %.2f", config.dataset.baseComponentFill),
        string.format("primary query fill: %.2f", config.dataset.primaryQueryComponentFill),
        string.format("hot component fill: %.2f", config.dataset.hotComponentFill),
    })
    printConfigSection("Query Workloads", {
        string.format("query iterations: %d", config.queryWorkloads.queryIterations),
        string.format("wide query width: %d", config.queryWorkloads.wideQueryWidth),
        string.format("random read count: %d", config.queryWorkloads.randomReadCount),
        string.format("work query count: %d", config.queryWorkloads.multiQueryCount),
        string.format("work frame count: %d", config.queryWorkloads.workFrameCount),
        string.format("writes per work frame: %d", config.queryWorkloads.writesPerWorkFrame),
    })
    printConfigSection("Mutation Workloads", {
        string.format("writes per phase: %d", config.mutationWorkloads.writesPerPhase),
        string.format("structural changes per phase: %d", config.mutationWorkloads.structuralChangesPerPhase),
    })
    printConfigSection("Stress", {
        string.format("frame count: %d", config.stress.frameCount),
        string.format("write passes: %d", config.stress.writePasses),
        string.format("structural passes: %d", config.stress.structuralPasses),
    })
end

function Reporter.printAdapterHeader(adapter, runCount)
    printSection(adapter.name)
    if adapter.note and adapter.note ~= "" then
        print("note: " .. adapter.note)
    end
    print(string.format("planned runs: %d", runCount))
    print("")
end

function Reporter.printRun(runIndex, runCount, results)
    print(string.format("Run %d/%d", runIndex, runCount))
    for resultIndex = 1, #results do
        local result = results[resultIndex]
        local line = string.format("  %-24s %9.4f s  checksum %.2f", result.name, result.seconds, result.checksum)
        if result.verifyCount > 0 then
            line = line .. string.format("  verify %d / %.3f", result.verifyCount, result.verifySum)
        end
        line = line .. string.format("  mem %.1f KB", result.memoryDeltaKB)
        print(line)
    end
    print("")
end

function Reporter.printAggregate(summary)
    print("Aggregated Timing")
    for scenarioIndex = 1, #summary.scenarios do
        local scenario = summary.scenarios[scenarioIndex]
        print(
            string.format(
                "  %-24s mean %7s  p50 %7s  p90 %7s  p95 %7s  min %7s  max %7s",
                scenario.name,
                formatNumber(scenario.timing.mean),
                formatNumber(scenario.timing.p50),
                formatNumber(scenario.timing.p90),
                formatNumber(scenario.timing.p95),
                formatNumber(scenario.timing.min),
                formatNumber(scenario.timing.max)
            )
        )
    end

    local total = summary.totalTiming
    print(
        string.format(
            "  %-24s mean %7s  p50 %7s  p90 %7s  p95 %7s  min %7s  max %7s",
            "total",
            formatNumber(total.mean),
            formatNumber(total.p50),
            formatNumber(total.p90),
            formatNumber(total.p95),
            formatNumber(total.min),
            formatNumber(total.max)
        )
    )
    print("")
end

return Reporter
