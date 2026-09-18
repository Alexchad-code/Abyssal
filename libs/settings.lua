--[[
    libs/settings.lua

    Per-game settings.

    The problem this solves: Obsidian keeps every option in one flat table,
    Library.Options, keyed by an id you choose. With more than one game script
    that is a collision waiting to happen — two games both wanting "autoSell"
    fight over one stored value, and the symptom is a setting that randomly
    resets rather than an error you can see.

    So every game gets a namespace. You declare the game once, and option ids
    are prefixed automatically:

        local settings = Settings.new("blox-fruits", Library)

        groupbox:AddToggle(settings:Key("autoSell"), { ... })

        -- reads and writes go through the namespace
        settings:Schema({
            autoSell  = { Default = false },
            sellDelay = { Default = 5, Type = "number", Min = 1, Max = 60 },
        })

        settings:Get("sellDelay")   --> 5

    ─── Why a schema ─────────────────────────────────────────────────────────

    A default belongs next to the widget that uses it, but the *value* lives in
    the library and may not exist yet — the widget might not have been built, or
    a config might have restored nothing. Get() therefore falls back to the
    declared default, which means you can read a setting before the UI exists
    and get something sane instead of nil.

    The optional Type/Min/Max are checked on write. That matters because config
    files are user-editable and a hand-edited number is otherwise a crash three
    layers down in a loop.
]]

local Settings = {}
Settings.__index = Settings

export type Rule = {
    Default: any,
    Type: "number" | "boolean" | "string" | "table" | "Color3"?,
    Min: number?,
    Max: number?,

    -- Return false, or false plus a reason, to reject a value.
    Validate: ((value: any) -> (boolean, string?))?,
}

export type Settings = typeof(setmetatable(
    {} :: {
        _gameId: string,
        _library: any,
        _rules: { [string]: Rule },
        _prefix: string,
    },
    Settings
))

function Settings.new(gameId: string, library: any): Settings
    assert(type(gameId) == "string" and gameId ~= "", "Settings.new needs a game id")
    assert(library ~= nil, "Settings.new needs the Obsidian library")

    -- Strip anything that would make the id awkward to read in a config file.
    local safe = gameId:gsub("%s+", "-"):lower()

    return setmetatable({
        _gameId = gameId,
        _library = library,
        _rules = {},
        _prefix = safe .. ".",
    }, Settings)
end

function Settings:GameId(): string
    return self._gameId
end

-- The prefixed option id. Use this for every widget the game creates.
function Settings:Key(name: string): string
    return self._prefix .. name
end

-- Declares defaults. Safe to call more than once; later calls merge.
function Settings:Schema(rules: { [string]: Rule })
    for name, rule in rules do
        assert(
            type(rule) == "table" and rule.Default ~= nil,
            `schema entry "{name}" needs a Default`
        )

        self._rules[name] = rule
    end
end

function Settings:Rule(name: string): Rule?
    return self._rules[name]
end

-- ─────────────────────────────────────────────────────────────────── values

--[[
    Reads a value.

    Order: the live option, then the declared default. The live option wins
    because it may have been changed by the user or restored from a config.
]]
function Settings:Get(name: string): any
    local rule = self._rules[name]
    local option = self._library.Options[self:Key(name)]

    if option ~= nil and option.Value ~= nil then
        return option.Value
    end

    if rule ~= nil then
        return rule.Default
    end

    return nil
end

local function passes(rule: Rule?, value: any): (boolean, string?)
    if rule == nil then
        return true, nil
    end

    if rule.Type ~= nil and typeof(value) ~= rule.Type then
        return false, `expected {rule.Type}, got {typeof(value)}`
    end

    if rule.Type == "number" then
        if rule.Min ~= nil and value < rule.Min then
            return false, `below minimum {rule.Min}`
        end

        if rule.Max ~= nil and value > rule.Max then
            return false, `above maximum {rule.Max}`
        end
    end

    if rule.Validate ~= nil then
        local ok, reason = rule.Validate(value)

        if ok == false then
            return false, reason or "rejected by validator"
        end
    end

    return true, nil
end

--[[
    Writes a value.

    Returns false plus a reason if it was rejected, so a caller can tell the
    user rather than silently keeping the old value.
]]
function Settings:Set(name: string, value: any): (boolean, string?)
    local rule = self._rules[name]
    local ok, reason = passes(rule, value)

    if not ok then
        return false, `{name}: {reason}`
    end

    local option = self._library.Options[self:Key(name)]

    if option == nil then
        -- Not built yet. That is not an error — the value will come from the
        -- schema default until the widget exists.
        return false, `{name} has no option yet; is its widget built?`
    end

    local setOk, err = pcall(function()
        option:SetValue(value)
    end)

    if not setOk then
        return false, `{name}: {tostring(err)}`
    end

    return true, nil
end

-- Every setting this game declares, as a plain table. Useful for debugging and
-- for handing to a webhook or a diagnostics panel.
function Settings:All(): { [string]: any }
    local out = {}

    for name in self._rules do
        out[name] = self:Get(name)
    end

    return out
end

-- ────────────────────────────────────────────────────────────────── watching

--[[
    Runs handler whenever the setting changes.

    Returns a connection with Disconnect, so the caller can clean up — a
    settings listener that outlives its game script is the same leak as any
    other. Register it with whatever teardown mechanism the script uses.
]]
function Settings:OnChanged(name: string, handler: (any) -> ())
    local option = self._library.Options[self:Key(name)]

    if option == nil then
        return {
            Connected = false,
            Disconnect = function() end,
        }
    end

    return option:OnChanged(handler)
end

--[[
    Applies the schema defaults to options that are currently nil.

    Only needed if a config load left something unset. Normally you do not call
    this: Get() already falls back to the default.
]]
function Settings:ApplyDefaults()
    for name, rule in self._rules do
        local option = self._library.Options[self:Key(name)]

        if option ~= nil and option.Value == nil then
            pcall(function()
                option:SetValue(rule.Default)
            end)
        end
    end
end

-- ─────────────────────────────────────────────────────────────── validation

--[[
    Validates every setting against its rule.

    Call after a config load. A config file is user-editable, and a value that
    no longer fits the schema is otherwise a crash somewhere unrelated much
    later. Returns a list of problems, empty if clean.
]]
function Settings:Validate(): { string }
    local problems = {}

    for name, rule in self._rules do
        local value = self:Get(name)
        local ok, reason = passes(rule, value)

        if not ok then
            table.insert(problems, `{name}: {reason}`)
        end
    end

    return problems
end

return Settings
