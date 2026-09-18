--[[
    libs/Addons/configs.luau

    Save and load settings to disk. Replaces Obsidian's SaveManager.

    Obsidian's version builds its own UI section and reads straight out of
    Library.Options, which couples saving to the widget layer. This one is
    dumb: it serialises a plain table to JSON, writes it to a file, reads it
    back. What you save is up to you.

    ─── Use ─────────────────────────────────────────────────────────────────

        local Configs = require("libs/Addons/configs")

        local configs = Configs.new({
            Folder = "Abyssal",
            Game = "blox-fruits",
            Library = Library,          -- only needed for Snapshot/Apply
        })

        configs:Save("main", { autoSell = true, sellDelay = 5 })
        local data = configs:Load("main")

        -- Or let it pull the game's own options, and push them back:
        configs:Save("main", configs:Snapshot("blox-fruits."))
        configs:Apply("blox-fruits.", data)

    ─── Filesystem ──────────────────────────────────────────────────────────

    This needs executor filesystem functions (writefile, readfile, isfile,
    makefolder, listfiles, delfile). Not every executor has them — run
    libs/unctest.lua to find out what yours provides.

    Everything degrades rather than throwing. Available() tells you up front;
    if the filesystem is missing, Save returns false with a reason and Load
    returns nothing, so a hub still runs, it just cannot remember anything.
]]

local HttpService = game:GetService("HttpService")

local Configs = {}
Configs.__index = Configs

export type Options = {
    Folder: string,
    Game: string,
    Library: any?,
}

export type Configs = typeof(setmetatable(
    {} :: {
        _folder: string,
        _game: string,
        _library: any?,
        _fs: { [string]: any }?,
        _missing: { string },
    },
    Configs
))

-- ─────────────────────────────────────────────────────────────── filesystem

--[[
    Direct references, for the same reason as unctest: there is no portable way
    to index the globals by name. getgenv is not guaranteed to exist, Luau has
    no getfenv, and _G is readonly in some contexts. Reading an undefined
    global gives nil rather than erroring, which is the check being made.
]]
local function detect(): ({ [string]: any }?, { string })
    local fs = {
        write = writefile,
        read = readfile,
        exists = isfile,
        existsFolder = isfolder,
        makeFolder = makefolder,
        list = listfiles,
        remove = delfile,
    }

    local missing = {}

    for name, fn in fs do
        if type(fn) ~= "function" then
            table.insert(missing, name)
        end
    end

    table.sort(missing)

    if #missing > 0 then
        return nil, missing
    end

    return fs, {}
end

-- ───────────────────────────────────────────────────────────── serialisation

--[[
    Obsidian options are not all JSON-safe. Dropdowns hold tables, colour
    pickers hold Color3. Anything else — a function, an Instance, a thread —
    cannot be represented, so it is skipped rather than silently mangled into
    something that looks fine and is not.
]]
local function encode(value: any): any
    local kind = typeof(value)

    if kind == "number" or kind == "boolean" or kind == "string" then
        return value
    end

    if kind == "Color3" then
        return { __type = "Color3", r = value.R, g = value.G, b = value.B }
    end

    if kind == "table" then
        local out = {}

        for key, item in value do
            local encoded = encode(item)

            if encoded ~= nil then
                out[key] = encoded
            end
        end

        return out
    end

    return nil
end

local function decode(value: any): any
    if type(value) ~= "table" then
        return value
    end

    if value.__type == "Color3" then
        return Color3.new(value.r, value.g, value.b)
    end

    local out = {}

    for key, item in value do
        out[key] = decode(item)
    end

    return out
end

-- ──────────────────────────────────────────────────────────────────── setup

function Configs.new(options: Options): Configs
    assert(options ~= nil, "Configs.new needs options")
    assert(type(options.Folder) == "string", "Configs.new needs a Folder")
    assert(type(options.Game) == "string", "Configs.new needs a Game")

    local fs, missing = detect()

    return setmetatable({
        -- Slashes and spaces in a game name would produce awkward paths, and
        -- some executors reject them outright.
        _folder = options.Folder:gsub("[/\\]", "-"),
        _game = options.Game:gsub("[/\\%s]", "-"):lower(),
        _library = options.Library,
        _fs = fs,
        _missing = missing,
    }, Configs)
end

-- True if the executor can actually persist anything.
function Configs:Available(): (boolean, string?)
    if self._fs ~= nil then
        return true, nil
    end

    return false, `this executor is missing: {table.concat(self._missing, ", ")}`
end

function Configs:Directory(): string
    return `{self._folder}/{self._game}`
end

function Configs:Path(name: string): string
    return `{self:Directory()}/{name}.json`
end

function Configs:_ensureFolder(): (boolean, string?)
    if self._fs == nil then
        return false, "no filesystem"
    end

    -- isfolder, not isfile: this is a directory, and isfile would answer false
    -- every time, making this call makefolder on every single save.
    if not self._fs.existsFolder(self:Directory()) then
        local ok, err = pcall(self._fs.makeFolder, self:Directory())

        if not ok then
            return false, `could not create {self:Directory()}: {tostring(err)}`
        end
    end

    return true, nil
end

-- ──────────────────────────────────────────────────────────────────── files

function Configs:Exists(name: string): boolean
    if self._fs == nil then
        return false
    end

    local ok, result = pcall(self._fs.exists, self:Path(name))

    return ok and result == true
end

function Configs:Save(name: string, data: { [string]: any }): (boolean, string?)
    local ready, reason = self:_ensureFolder()

    if not ready then
        return false, reason
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(encode(data))
    end)

    if not ok then
        return false, `could not encode: {tostring(encoded)}`
    end

    local written, err = pcall(self._fs.write, self:Path(name), encoded)

    if not written then
        return false, `could not write: {tostring(err)}`
    end

    return true, nil
end

function Configs:Load(name: string): ({ [string]: any }?, string?)
    if self._fs == nil then
        return nil, "no filesystem"
    end

    if not self:Exists(name) then
        return nil, `no config called "{name}"`
    end

    local ok, raw = pcall(self._fs.read, self:Path(name))

    if not ok then
        return nil, `could not read: {tostring(raw)}`
    end

    local decoded

    local decodeOk = pcall(function()
        decoded = HttpService:JSONDecode(raw)
    end)

    if not decodeOk then
        -- A truncated or hand-edited file. Report it rather than returning an
        -- empty table, which would look like a fresh install and silently
        -- wipe the user's settings on the next save.
        return nil, `"{name}" is not valid JSON`
    end

    if type(decoded) ~= "table" then
        return nil, `"{name}" does not contain a table`
    end

    return decode(decoded), nil
end

function Configs:List(): { string }
    if self._fs == nil then
        return {}
    end

    local ok, files = pcall(self._fs.list, self:Directory())

    if not ok or type(files) ~= "table" then
        return {}
    end

    local names = {}

    for _, file in files do
        local name = tostring(file):match("([^/\\]+)%.json$")

        if name ~= nil then
            table.insert(names, name)
        end
    end

    table.sort(names)

    return names
end

function Configs:Delete(name: string): (boolean, string?)
    if self._fs == nil then
        return false, "no filesystem"
    end

    if not self:Exists(name) then
        return false, `no config called "{name}"`
    end

    local ok, err = pcall(self._fs.remove, self:Path(name))

    if not ok then
        return false, `could not delete: {tostring(err)}`
    end

    return true, nil
end

-- ───────────────────────────────────────────────────────────────── autoload

--[[
    Autoload is a one-line text file naming the config to load on start, rather
    than a flag inside every config. Keeping it separate means "which config is
    the default" is one fact in one place, and deleting the named config
    degrades to "no autoload" instead of a half-broken state.
]]
function Configs:SetAutoload(name: string): (boolean, string?)
    local ready, reason = self:_ensureFolder()

    if not ready then
        return false, reason
    end

    local ok, err = pcall(self._fs.write, `{self:Directory()}/autoload.txt`, name)

    if not ok then
        return false, tostring(err)
    end

    return true, nil
end

function Configs:GetAutoload(): string?
    if self._fs == nil then
        return nil
    end

    local path = `{self:Directory()}/autoload.txt`

    if not self._fs.exists(path) then
        return nil
    end

    local ok, name = pcall(self._fs.read, path)

    if not ok or type(name) ~= "string" then
        return nil
    end

    name = name:gsub("%s+", "")

    if name == "" then
        return nil
    end

    return name
end

function Configs:LoadAutoload(): ({ [string]: any }?, string?)
    local name = self:GetAutoload()

    if name == nil then
        return nil, "nothing is set to autoload"
    end

    return self:Load(name)
end

-- ─────────────────────────────────────────────────────── Obsidian integration

--[[
    Pulls every option whose id starts with prefix into a plain table.

    This is what makes the module useful without a settings layer: a game
    namespaces its option ids, hands the same prefix here, and gets a snapshot
    without listing its options twice.

        configs:Save("main", configs:Snapshot("blox-fruits."))
]]
function Configs:Snapshot(prefix: string): { [string]: any }
    local out = {}

    if self._library == nil or self._library.Options == nil then
        return out
    end

    for id, option in self._library.Options do
        if type(id) == "string" and id:sub(1, #prefix) == prefix then
            local key = id:sub(#prefix + 1)

            if key ~= "" and option.Value ~= nil then
                out[key] = option.Value
            end
        end
    end

    return out
end

--[[
    Pushes a snapshot back into the options it came from.

    Returns how many were applied. An option named in the data but not present
    in the library is skipped, not an error — that happens legitimately when a
    game removes a feature and an old config still mentions it.
]]
function Configs:Apply(prefix: string, data: { [string]: any }): number
    if self._library == nil or self._library.Options == nil then
        return 0
    end

    local applied = 0

    for key, value in data do
        local option = self._library.Options[prefix .. key]

        if option ~= nil then
            local ok = pcall(function()
                option:SetValue(value)
            end)

            if ok then
                applied += 1
            end
        end
    end

    return applied
end

return Configs
