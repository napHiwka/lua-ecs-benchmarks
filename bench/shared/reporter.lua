local Reporter = {}

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

function Reporter.printSection(title)
	print(title)
	print(string.rep("-", #title))
end

function Reporter.printConfig(config)
	Reporter.printSection("Benchmark Configuration")
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

function Reporter.printAdapterHeader(adapter)
	if adapter.note and adapter.note ~= "" then
		print("Note: " .. adapter.note .. "\n")
	end
end

function Reporter.printRun(runIndex, runCount, results)
	print(string.format("Run %d/%d", runIndex, runCount))
	for resultIndex = 1, #results do
		local result = results[resultIndex]
		local line = string.format("  %-24s %9.4f s", result.name, result.seconds)

		if runIndex == 1 then
			line = line .. string.format("  checksum %.2f", result.checksum)
			if result.verifyCount > 0 then
				line = line .. string.format("  verify %d / %.3f", result.verifyCount, result.verifySum)
			end
		end

		line = line .. string.format("  mem %.1f KB", result.memoryDeltaKB)
		print(line)
	end
	print("")
end

function Reporter.printAggregate(summary, adapterName)
	Reporter.printSection(string.format("Aggregated Timing (%s)", adapterName))
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

function Reporter.printSummaryTable(allSummaries)
	print("Summary Table (P50)\n")

	if #allSummaries == 0 then
		return
	end

	local MAX_LINE_WIDTH = 110

	local scenarioNames = {}
	for scenarioIndex = 1, #allSummaries[1].scenarios do
		scenarioNames[#scenarioNames + 1] = allSummaries[1].scenarios[scenarioIndex].name
	end
	scenarioNames[#scenarioNames + 1] = "total"

	local adapterNames = {}
	for summaryIndex = 1, #allSummaries do
		adapterNames[#adapterNames + 1] = allSummaries[summaryIndex].adapterName or "Unknown"
	end

	local maxScenarioWidth = 0
	for _, name in ipairs(scenarioNames) do
		maxScenarioWidth = math.max(maxScenarioWidth, #name)
	end

	local COL_WIDTH = 9 -- "X.XXXX" = 8 chars + 2 sep = 10, keep it tight
	local SEP = "  "

	-- Split adapters into groups that fit within MAX_LINE_WIDTH
	local groups = {}
	local currentGroup = {}
	local currentWidth = maxScenarioWidth

	for i, name in ipairs(adapterNames) do
		local colWidth = #SEP + math.max(COL_WIDTH, #name)
		if #currentGroup > 0 and currentWidth + colWidth > MAX_LINE_WIDTH then
			groups[#groups + 1] = currentGroup
			currentGroup = {}
			currentWidth = maxScenarioWidth
		end
		currentGroup[#currentGroup + 1] = i
		currentWidth = currentWidth + colWidth
	end
	if #currentGroup > 0 then
		groups[#groups + 1] = currentGroup
	end

	local function getP50(summary, scenarioName)
		if scenarioName == "total" then
			return summary.totalTiming.p50
		end
		for _, scenario in ipairs(summary.scenarios) do
			if scenario.name == scenarioName then
				return scenario.timing.p50
			end
		end
	end

	local function printGroup(group)
		-- Header
		local header = string.format("%-" .. maxScenarioWidth .. "s", "Scenario")
		for _, idx in ipairs(group) do
			local colWidth = math.max(COL_WIDTH, #adapterNames[idx])
			header = header .. SEP .. string.format("%" .. colWidth .. "s", adapterNames[idx])
		end
		print(header)
		print(string.rep("-", #header))

		for _, scenarioName in ipairs(scenarioNames) do
			local row = string.format("%-" .. maxScenarioWidth .. "s", scenarioName)
			for _, idx in ipairs(group) do
				local colWidth = math.max(COL_WIDTH, #adapterNames[idx])
				local timing = getP50(allSummaries[idx], scenarioName)
				if timing then
					row = row .. SEP .. string.format("%" .. colWidth .. ".4f", timing)
				else
					row = row .. SEP .. string.format("%" .. colWidth .. "s", "N/A")
				end
			end
			print(row)
		end
		print("")
	end

	for _, group in ipairs(groups) do
		printGroup(group)
	end
end

return Reporter
