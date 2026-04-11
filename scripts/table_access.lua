local ITERATIONS = 50000000

local function bench(name, fn)
	collectgarbage()
	collectgarbage()

	local t0 = os.clock()
	local result = fn()
	local t1 = os.clock()

	print(name, t1 - t0, result)
end

-- Plain table
local plain = {}
for i = 1, ITERATIONS do
	plain[i] = i
end

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

bench("\nplain: set", function()
	for i = 1, ITERATIONS do
		plain[i] = i
	end
end)

bench("plain: rawset", function()
	for i = 1, ITERATIONS do
		rawset(plain, i, i)
	end
end)

-- __index = table
local proto = {}
for i = 1, ITERATIONS do
	proto[i] = i
end

local mt_table = { __index = proto }
local obj_table = setmetatable({}, mt_table)

bench("\nmt(table): get (miss -> proto)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		sum = sum + obj_table[i]
	end
	return sum
end)

bench("mt(table): rawget (miss)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		local v = rawget(obj_table, i)
		if v then
			sum = sum + v
		end
	end
	return sum
end)

bench("\nmt(table): set (__newindex bypass)", function()
	for i = 1, ITERATIONS do
		obj_table[i] = i
	end
end)

bench("mt(table): rawset", function()
	for i = 1, ITERATIONS do
		rawset(obj_table, i, i)
	end
end)

-- __index = function
local mt_func = {
	__index = function(_, _)
		return 1
	end,
}

local obj_func = setmetatable({}, mt_func)

bench("\nmt(func): get (miss -> func)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		sum = sum + obj_func[i]
	end
	return sum
end)

bench("mt(func): rawget (miss)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		local v = rawget(obj_func, i)
		if v then
			sum = sum + v
		end
	end
	return sum
end)

-- self
local Class = {}
Class.__index = Class

function Class:get(k)
	return self[k]
end

function Class:get_raw(k)
	return rawget(self, k)
end

local obj = setmetatable({}, Class)

for i = 1, ITERATIONS do
	obj[i] = i
end

bench("\nmethod: self[k] (hit)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		sum = sum + obj:get(i)
	end
	return sum
end)

bench("method: rawget(self,k)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		sum = sum + obj:get_raw(i)
	end
	return sum
end)

local obj_miss = setmetatable({}, Class)

bench("method: self[k] (miss -> __index)", function()
	local sum = 0
	for i = 1, ITERATIONS do
		local v = obj_miss:get(i)
		if v then
			sum = sum + v
		end
	end
	return sum
end)

bench("method: rawget(self,k) miss", function()
	local sum = 0
	for i = 1, ITERATIONS do
		local v = obj_miss:get_raw(i)
		if v then
			sum = sum + v
		end
	end
	return sum
end)

-- Nested access
local components = {}
for i = 1, ITERATIONS do
	components[i] = i
end

local entity = {
	components = components,
}

bench("\nnested: entity.components[i]", function()
	local sum = 0
	for i = 1, ITERATIONS do
		sum = sum + entity.components[i]
	end
	return sum
end)

bench("nested: rawget chain", function()
	local sum = 0
	for i = 1, ITERATIONS do
		local c = rawget(entity, "components")
		sum = sum + rawget(c, i)
	end
	return sum
end)
