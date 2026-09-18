--[[
    games/template/utils/format.lua

    An example of a game-local utility, and the pattern to copy for your own.

    Anything in utils/ belongs to one game. If a helper would be useful to
    every game it belongs in libs/ instead — the split is "this game's
    knowledge" versus "the hub's".

    A tab loads these the same way everything else is loaded:

        local Format = ctx.LoadFile("games/template/utils/format.lua")
        box:AddLabel(`Cash   {Format.Compact(cash)}`)

    Returns a table of functions. No state, no side effects — a util that
    needs teardown is a feature, and features are tabs.
]]

local Format = {}

--[[
    Short form for numbers that get long: 1234 -> "1.23K", 1234567 -> "1.23M".

    Two decimal places, trailing zeros trimmed, so 1000 reads "1K" rather than
    "1.00K". Negative numbers keep their sign.
]]
function Format.Compact(value: number): string
    assert(type(value) == "number", "Compact expects a number")

    local sign = value < 0 and "-" or ""
    local size = math.abs(value)

    -- Below a thousand there is nothing to shorten, and "999" is more useful
    -- than "999".
    if size < 1000 then
        return sign .. tostring(math.floor(size))
    end

    local units = { "K", "M", "B", "T", "Qa", "Qi" }

    -- Starts at 0, not 1: the index counts divisions, and units[1] is the
    -- first one applied. Starting at 1 put everything one unit high — 1000
    -- came out as "1M".
    local index = 0

    while size >= 1000 and index < #units do
        size /= 1000
        index += 1
    end

    --[[
        Rounding to two places can push a value back over the boundary: 999,999
        divides to 999.999, which formats as "1000.00" and reads as "1000K"
        instead of "1M". Promote it before formatting.

        The threshold is 999.995 rather than 999.999 because %.2f rounds half
        up, so anything at or above that would have displayed as 1000.00.
    ]]
    if index < #units and size >= 999.995 then
        size /= 1000
        index += 1
    end

    -- Truncate rather than round: showing 1.00M for 999,999 reads as more than
    -- it is, and in a game where the number is currency that matters.
    local text = string.format("%.2f", size)

    text = text:gsub("%.?0+$", "")

    return sign .. text .. units[index]
end

-- Full form with separators: 1234567 -> "1,234,567".
function Format.Commas(value: number): string
    assert(type(value) == "number", "Commas expects a number")

    local text = tostring(math.floor(value))
    local sign = ""

    if text:sub(1, 1) == "-" then
        sign = "-"
        text = text:sub(2)
    end

    -- Insert a comma every three digits from the right.
    local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()

    return sign .. formatted:gsub("^,", "")
end

--[[
    A duration in seconds as "1h 2m" / "45s".

    At most two units, because "1h 2m 3s 400ms" is noise — nobody reads past
    the second one.
]]
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

    -- Seconds are only worth showing when nothing larger is present.
    if #parts == 0 then
        table.insert(parts, `{secs}s`)
    end

    return table.concat(parts, " ", 1, math.min(2, #parts))
end

return Format
