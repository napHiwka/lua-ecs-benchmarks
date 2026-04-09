local Compat = {}

function Compat.createArray()
    return {}
end

function Compat.pack(...)
    return { n = select("#", ...), ... }
end

Compat.unpack = table.unpack or unpack

function Compat.copyArray(values)
    local copy = {}
    for index = 1, #values do
        copy[index] = values[index]
    end
    return copy
end

function Compat.sortNumbers(values)
    local sorted = Compat.copyArray(values)
    table.sort(sorted)
    return sorted
end

return Compat
