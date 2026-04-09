local Compat = require("bench.shared.compat")

local Stats = {}

local function percentile(sortedValues, fraction)
    if #sortedValues == 0 then
        return 0
    end

    local rank = (#sortedValues - 1) * fraction + 1
    local lowerIndex = math.floor(rank)
    local upperIndex = math.ceil(rank)
    local lowerValue = sortedValues[lowerIndex]
    local upperValue = sortedValues[upperIndex]
    if lowerIndex == upperIndex then
        return lowerValue
    end

    local weight = rank - lowerIndex
    return lowerValue + (upperValue - lowerValue) * weight
end

function Stats.summarize(values)
    if #values == 0 then
        return {
            count = 0,
            min = 0,
            max = 0,
            mean = 0,
            p50 = 0,
            p90 = 0,
            p95 = 0,
        }
    end

    local sortedValues = Compat.sortNumbers(values)
    local sum = 0
    for index = 1, #sortedValues do
        sum = sum + sortedValues[index]
    end

    return {
        count = #sortedValues,
        min = sortedValues[1],
        max = sortedValues[#sortedValues],
        mean = sum / #sortedValues,
        p50 = percentile(sortedValues, 0.50),
        p90 = percentile(sortedValues, 0.90),
        p95 = percentile(sortedValues, 0.95),
    }
end

return Stats
