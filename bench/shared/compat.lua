local Compat = {}

local function copyArray(values)
	local copy = {}
	for index = 1, #values do
		copy[index] = values[index]
	end
	return copy
end

Compat.unpack = table.unpack or unpack

function Compat.pack(...)
	return { n = select("#", ...), ... }
end

function Compat.sortNumbers(values)
	local sorted = copyArray(values)
	table.sort(sorted)
	return sorted
end

return Compat
