--[[
    core/Logger.luau

    Scoped, levelled logging.

    Everything the hub prints goes through here so output stays greppable and a
    noisy feature can be silenced without touching its code.
]]

local Logger = {}
Logger.__index = Logger

export type Level = "debug" | "info" | "warn" | "error"

export type Logger = typeof(setmetatable(
    {} :: {
        _scope: string,
        _minLevel: number,
    },
    Logger
))

local LEVEL_ORDER: { [string]: number } = {
    debug = 10,
    info = 20,
    warn = 30,
    error = 40,
}

-- Set to "debug" while developing, "info" for release.
local GLOBAL_MIN_LEVEL: number = LEVEL_ORDER.info

local LEVEL_TAG: { [string]: string } = {
    debug = "DBG",
    info = "INF",
    warn = "WRN",
    error = "ERR",
}

function Logger.setGlobalLevel(level: Level)
    assert(LEVEL_ORDER[level] ~= nil, `unknown log level: {level}`)
    GLOBAL_MIN_LEVEL = LEVEL_ORDER[level]
end

function Logger.getGlobalLevel(): Level
    for name, order in LEVEL_ORDER do
        if order == GLOBAL_MIN_LEVEL then
            return name :: Level
        end
    end

    return "info"
end

function Logger.new(scope: string, level: Level?): Logger
    return setmetatable({
        _scope = scope,
        _minLevel = LEVEL_ORDER[level or "info"] or LEVEL_ORDER.info,
    }, Logger)
end

-- Returns a child logger whose scope is nested under this one, e.g.
--   local log = Logger.new("Abyssal")
--   local gameLog = log:Scoped("Universal")   --> "[Abyssal/Universal]"
function Logger:Scoped(scope: string): Logger
    return setmetatable({
        _scope = `{self._scope}/{scope}`,
        _minLevel = self._minLevel,
    }, Logger)
end

function Logger:SetLevel(level: Level)
    assert(LEVEL_ORDER[level] ~= nil, `unknown log level: {level}`)
    self._minLevel = LEVEL_ORDER[level]
end

function Logger:_emit(level: Level, ...: any)
    local order = LEVEL_ORDER[level]

    if order < self._minLevel or order < GLOBAL_MIN_LEVEL then
        return
    end

    local prefix = `[{LEVEL_TAG[level]}] [{self._scope}]`
    local parts = table.create(select("#", ...))

    for index = 1, select("#", ...) do
        parts[index] = tostring(select(index, ...))
    end

    local message = `{prefix} {table.concat(parts, " ")}`

    if level == "error" then
        warn(message)
    else
        print(message)
    end
end

function Logger:Debug(...: any)
    self:_emit("debug", ...)
end

function Logger:Info(...: any)
    self:_emit("info", ...)
end

function Logger:Warn(...: any)
    self:_emit("warn", ...)
end

function Logger:Error(...: any)
    self:_emit("error", ...)
end

return Logger
