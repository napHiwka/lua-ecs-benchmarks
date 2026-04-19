-- Iteration-only benchmark: add/remove operations are out of scope

local N = 20000000

-- AoS (Array of Structs)
local aos = {}

for i = 1, N do
	aos[i] = { i * 0.1, i * 0.2 }
end

local function testAoS()
	local sum = 0
	for i = 1, N do
		local p = aos[i]
		sum = sum + p[1] + p[2]
	end
	return sum
end

-- SoA (Struct of Arrays) in wrapper table
local soa = { x = {}, y = {} }

for i = 1, N do
	soa.x[i] = i * 0.1
	soa.y[i] = i * 0.2
end

local function testSoA_wrapped()
	local sum = 0
	local x = soa.x
	local y = soa.y
	for i = 1, N do
		sum = sum + x[i] + y[i]
	end
	return sum
end

-- SoA (bare tables)
local px = {}
local py = {}

for i = 1, N do
	px[i] = i * 0.1
	py[i] = i * 0.2
end

local function testSoA_raw()
	local sum = 0
	local x = px
	local y = py
	for i = 1, N do
		sum = sum + x[i] + y[i]
	end
	return sum
end

-- AoSoA (Array of Struct of Arrays) fixed block size of 128
local BLOCK = 128
local blocks = {}

for i = 1, N do
	local b = math.floor((i - 1) / BLOCK) + 1
	local j = ((i - 1) % BLOCK) + 1

	local block = blocks[b]
	if not block then
		block = { x = {}, y = {} }
		blocks[b] = block
	end

	block.x[j] = i * 0.1
	block.y[j] = i * 0.2
end

local function testAoSoA()
	local sum = 0
	for b = 1, #blocks do
		local block = blocks[b]
		local x = block.x
		local y = block.y
		for j = 1, BLOCK do
			sum = sum + x[j] + y[j]
		end
	end
	return sum
end

local function bench(name, fn)
	collectgarbage()
	collectgarbage()
	local t0 = os.clock()
	local result = fn()
	local t1 = os.clock()
	print(string.format("%-20s %.3f s    result: %.1f", name, t1 - t0, result))
end

bench("AoS", testAoS)
bench("SoA Raw", testSoA_raw)
bench("SoA Wrapped", testSoA_wrapped)
bench("AoSoA (block=128)", testAoSoA)
