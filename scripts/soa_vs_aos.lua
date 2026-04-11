-- AoS (Array of Structs)
local N = 20000000

local polyline = table.create(N)

for i = 1, N do
	polyline[i] = { i * 0.1, i * 0.2 }
end

local function testAoS()
	local sum = 0

	for i = 1, N do
		local p = polyline[i]
		sum = sum + p[1] + p[2]
	end

	return sum
end

---------------------

-- SoA (Structure of Arrays)
local polyline = {
	x = table.create(N),
	y = table.create(N),
}

for i = 1, N do
	polyline.x[i] = i * 0.1
	polyline.y[i] = i * 0.2
end

local function testSoA()
	local sum = 0

	local x = polyline.x
	local y = polyline.y

	for i = 1, N do
		sum = sum + x[i] + y[i]
	end

	return sum
end

local function bench(name, fn)
	collectgarbage()
	collectgarbage()

	local t0 = os.clock()
	local result = fn()
	local t1 = os.clock()

	print(name, t1 - t0, result)
end

bench("AoS", testAoS)
bench("SoA", testSoA)
