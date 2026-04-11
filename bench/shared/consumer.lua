local Compat = require("bench.shared.compat")

local Consumer = {}

local function packedRowChecksum(row, width)
	if width == 1 then
		return row[2] * 0.02
	elseif width == 2 then
		return row[2] * 0.02 + row[3] * 0.03
	elseif width == 3 then
		return row[2] * 0.02 + row[3] * 0.03 + row[4] * 0.04
	else
		local sum = 0
		for i = 2, row.n do
			sum = sum + row[i] * (0.01 * i)
		end
		return sum
	end
end

local function consumeArray(results, width)
	local checksum = 0
	for rowIndex = 1, #results do
		local row = results[rowIndex]
		if row and type(row) == "table" then
			if width == 1 then
				local a = row[2]
				if a then
					checksum = checksum + a * 0.02
				end
			elseif width == 2 then
				local a, b = row[2], row[3]
				if a then
					checksum = checksum + a * 0.02
				end
				if b then
					checksum = checksum + b * 0.03
				end
			elseif width == 3 then
				local a, b, c = row[2], row[3], row[4]
				if a then
					checksum = checksum + a * 0.02
				end
				if b then
					checksum = checksum + b * 0.03
				end
				if c then
					checksum = checksum + c * 0.04
				end
				for componentIndex = 1, width do
					local value = row[componentIndex + 1]
					if value then
						checksum = checksum + value * (0.01 * (componentIndex + 1))
					end
				end
			end
		end
	end
	return checksum
end

local function consumeIterator(iterator, width)
	local checksum = 0
	if width == 1 then
		while true do
			local entity, a = iterator()
			if entity == nil then
				break
			end
			checksum = checksum + a * 0.02
		end
	elseif width == 2 then
		while true do
			local entity, a, b = iterator()
			if entity == nil then
				break
			end
			checksum = checksum + a * 0.02 + b * 0.03
		end
	elseif width == 3 then
		while true do
			local entity, a, b, c = iterator()
			if entity == nil then
				break
			end
			checksum = checksum + a * 0.02 + b * 0.03 + c * 0.04
		end
	else
		while true do
			local packed = Compat.pack(iterator())
			if packed[1] == nil then
				break
			end
			for i = 2, packed.n do
				checksum = checksum + packed[i] * (0.01 * i)
			end
		end
	end
	return checksum
end

function Consumer.detectConsumer(probeResult, width)
	local probeType = type(probeResult)
	if probeType == "function" then
		while probeResult() ~= nil do
		end
		return function(queryResult)
			local firstRow = Compat.pack(queryResult())
			if firstRow[1] == nil then
				return 0
			end
			return packedRowChecksum(firstRow, width) + consumeIterator(queryResult, width)
		end
	elseif probeType == "table" then
		return function(queryResult)
			return consumeArray(queryResult, width)
		end
	else
		error("Unsupported query result type: " .. probeType)
	end
end

return Consumer
