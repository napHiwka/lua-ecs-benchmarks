package.path = "./?.lua;./?/init.lua;" .. package.path

local Runner = require("bench.shared.runner")
local Reporter = require("bench.shared.reporter")

local adapterSpecs = {
	{
		adapterPath = "bench/adapters/table-based.lua",
		libraryPath = "bench/libraries/_empty/init.lua",
	},
	{
		adapterPath = "bench/adapters/hash-based.lua",
		libraryPath = "bench/libraries/_empty/init.lua",
	},
	{
		adapterPath = "bench/adapters/sparse-based.lua",
		libraryPath = "bench/libraries/_empty/init.lua",
	},
	{
		adapterPath = "bench/adapters/concord.lua",
		libraryPath = "bench/libraries/concord/init.lua",
	},
	{
		adapterPath = "bench/adapters/rune.lua",
		libraryPath = "bench/libraries/rune/init.lua",
	},
	{
		adapterPath = "bench/adapters/alecs.lua",
		libraryPath = "bench/libraries/alecs/init.lua",
	},
	{
		adapterPath = "bench/adapters/lovetoys.lua",
		libraryPath = "bench/libraries/lovetoys/init.lua",
	},
	{
		adapterPath = "bench/adapters/tiny-ecs-reuse.lua",
		libraryPath = "bench/libraries/tiny-ecs/init.lua",
	},
	{
		adapterPath = "bench/adapters/tiny-ecs-no-reuse.lua",
		libraryPath = "bench/libraries/tiny-ecs/init.lua",
	},
	{
		adapterPath = "bench/adapters/evolved.lua",
		libraryPath = "bench/libraries/evolved/init.lua",
	},
	{
		adapterPath = "bench/adapters/ecs-lua.lua",
		libraryPath = "bench/libraries/ecs-lua/init.lua",
	},
	{
		adapterPath = "bench/adapters/ecs-lib.lua",
		libraryPath = "bench/libraries/ecs-lib/init.lua",
	},
}

local moduleCache = {}

local function loadModuleFromPath(path)
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end

	local chunk, err = loadfile(path)
	if not chunk then
		error(err)
	end

	local value = chunk()
	moduleCache[path] = value
	return value
end

local adapters = {}
for index = 1, #adapterSpecs do
	local spec = adapterSpecs[index]
	local ok, result = pcall(function()
		local adapterFactory = loadModuleFromPath(spec.adapterPath)
		local library
		if spec.libraryPath then
			library = loadModuleFromPath(spec.libraryPath)
		else
			print(string.format("No library path provided for %s, using empty library", spec.adapterPath))
			library = loadModuleFromPath("bench/libraries/_empty/init.lua")
		end
		return adapterFactory(library)
	end)

	if ok then
		adapters[#adapters + 1] = result
	else
		print(string.format("Skipping %s: %s", spec.adapterPath, tostring(result)))
	end
end

if #adapters == 0 then
	error("no benchmark adapters could be loaded")
end

Reporter.printConfig(Runner.getConfig())

local allSummaries = {}

for index = 1, #adapters do
	local adapter = adapters[index]
	Reporter.printSection("Running " .. adapter.name .. "...")
	local report = Runner.runAdapter(adapter)
	Reporter.printAdapterHeader(adapter)

	for runIndex = 1, #report.runs do
		Reporter.printRun(runIndex, #report.runs, report.runs[runIndex])
	end
	Reporter.printAggregate(report.summary, adapter.name)

	report.summary.adapterName = adapter.name
	allSummaries[#allSummaries + 1] = report.summary
end

if #adapters > 1 then
	Reporter.printSummaryTable(allSummaries)
end
