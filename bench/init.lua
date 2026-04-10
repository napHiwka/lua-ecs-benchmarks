local Runner = require("bench.shared.runner")
local Reporter = require("bench.shared.reporter")

local adapterSpecs = {
    {
        name = "tiny-ecs-reuse",
        adapterPath = "bench/adapters/tiny-ecs-reuse.lua",
        libraryPath = "bench/libraries/tiny-ecs/init.lua",
    },
    {
        name = "evolved",
        adapterPath = "bench/adapters/evolved.lua",
        libraryPath = "bench/libraries/evolved/init.lua",
    },
    -- {
    --     name = "tiny-ecs-no-reuse",
    --     adapterPath = "bench/adapters/tiny-ecs-no-reuse.lua",
    --     libraryPath = "bench/libraries/tiny-ecs/init.lua",
    -- },
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
        local library = loadModuleFromPath(spec.libraryPath)
        return adapterFactory(library)
    end)

    if ok then
        adapters[#adapters + 1] = result
    else
        print(string.format("Skipping %s: %s", spec.name, tostring(result)))
    end
end

if #adapters == 0 then
    error("no benchmark adapters could be loaded")
end

Reporter.printConfig(Runner.getConfig())

for index = 1, #adapters do
    local adapter = adapters[index]
    local report = Runner.runAdapter(adapter)

    Reporter.printAdapterHeader(adapter, #report.runs)

    for runIndex = 1, #report.runs do
        Reporter.printRun(runIndex, #report.runs, report.runs[runIndex])
    end
    Reporter.printAggregate(report.summary)
end
