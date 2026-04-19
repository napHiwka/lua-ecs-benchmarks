local ITERATIONS = 50000000

local function bench(name, fn)
	collectgarbage()
	collectgarbage()
	local t0 = os.clock()
	local result = fn()
	local t1 = os.clock()
	print(string.format("%-36s %.3f s    result: %s", name, t1 - t0, tostring(result)))
end

local function section(name)
	print("\n-- " .. name)
end

-- Plain table

local plain = {}
for i = 1, ITERATIONS do
	plain[i] = i
end

section("Plain table (read)")

bench("plain: get (hit)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		sum = sum + plain[i]
	end
	return sum
end)

bench("plain: rawget (hit)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		sum = sum + rawget(plain, i)
	end
	return sum
end)

section("Plain table (write existing keys)")

bench("plain: set", function()
	for i = 1, ITERATIONS do
		plain[i] = i
	end
end)

bench("plain: rawset", function()
	for i = 1, ITERATIONS do
		rawset(plain, i, i)
	end
end)

-- Metatable __index overhead
local proto = {}
for i = 1, ITERATIONS do
	proto[i] = i
end

local obj_table = setmetatable({}, { __index = proto })
local obj_func = setmetatable({}, {
	__index = function()
		return 1
	end,
})

section("Metatable __index overhead (always miss)")

bench("mt(__index=table): get (miss -> proto)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		sum = sum + obj_table[i]
	end
	return sum
end)

bench("mt(__index=func):  get (miss -> func)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		sum = sum + obj_func[i]
	end
	return sum
end)
