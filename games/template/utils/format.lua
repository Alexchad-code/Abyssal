local Format = {}

function Format.Compact(value: number): string
    assert(type(value) == "number", "Compact expects a number")

    local sign = value < 0 and "-" or ""
    local size = math.abs(value)

    if size < 1000 then
        return sign .. tostring(math.floor(size))
    end

    local units = { "K", "M", "B", "T", "Qa", "Qi" }

    local index = 0

    while size >= 1000 and index < #units do
        size /= 1000
        index += 1
    end

    if index < #units and size >= 999.995 then
        size /= 1000
        index += 1
    end

    local text = string.format("%.2f", size)

    text = text:gsub("%.?0+$", "")

    return sign .. text .. units[index]
end

function Format.Commas(value: number): string
    assert(type(value) == "number", "Commas expects a number")

    local text = tostring(math.floor(value))
    local sign = ""

    if text:sub(1, 1) == "-" then
        sign = "-"
        text = text:sub(2)
    end

    local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()

    return sign .. formatted:gsub("^,", "")
end

function Format.Duration(seconds: number): string
    assert(type(seconds) == "number", "Duration expects a number")

    local remaining = math.max(0, math.floor(seconds))

    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    local minutes = math.floor((remaining % 3600) / 60)
    local secs = remaining % 60

    local parts = {}

    if days > 0 then
        table.insert(parts, `{days}d`)
    end

    if hours > 0 then
        table.insert(parts, `{hours}h`)
    end

    if minutes > 0 then
        table.insert(parts, `{minutes}m`)
    end

    if #parts == 0 then
        table.insert(parts, `{secs}s`)
    end

    return table.concat(parts, " ", 1, math.min(2, #parts))
end

return Format
