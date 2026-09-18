--[[
    main.lua

    The entry point. This is what a user executes:

        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/Alexchad-code/Abyssal/main/main.lua"
        ))()

    What it does:

        1. fetch and load the UI library
        2. build the shared context that every game receives
        3. work out which folder in games/ covers this place
        4. run that folder's main.lua
        5. own the teardown

    Nothing is pre-compiled and nothing is bundled. Every file is fetched at
    run time, so pushing to main is the whole release process.

    ─── Routing ──────────────────────────────────────────────────────────────

    A game declares its own places, in games/<folder>/config.lua:

        Places = { 2753915549 },

    This file only lists which folders to look at. Adding a game is a folder
    plus one line in GAMES — the place ids stay with the game, so there is one
    source of truth for "where does this run" and it is not here.

    The cost is one small fetch per game on boot to read its config. That is a
    few hundred bytes each and happens once.
]]

-- ══════════════════════════════════════════════════════════════ configuration

local REPO = "https://raw.githubusercontent.com/Alexchad-code/Abyssal/main/"
local VERSION = "0.3.0"

-- Every game folder in games/, by name. Order does not matter.
local GAMES = {
    "template",

    -- "blox-fruits",
    -- "adopt-me",
}

-- Set true to print debug lines.
local DEBUG = false

-- ═══════════════════════════════════════════════════════════════════ logging

local PREFIX = "[Abyssal]"

local function log(...: any)
    print(PREFIX, ...)
end

local function debug(...: any)
    if DEBUG then
        print(PREFIX, "[debug]", ...)
    end
end

local function warn_(...: any)
    warn(PREFIX, ...)
end

-- ════════════════════════════════════════════════════════════════════ http

-- Returns the body, or nil plus a reason. Never throws, so a failed fetch
-- produces a readable message instead of a stack trace.
local function http(url: string): (string?, string?)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        return nil, `HttpGet failed: {tostring(body)}`
    end

    if type(body) ~= "string" or body == "" then
        return nil, "empty response"
    end

    return body, nil
end

-- Two ways to fetch, because they are not the same thing. Conflating them
-- produces a URL like "https://raw.githubusercontent.com/.../https://games.roblox.com/...".
--
--     Fetch("games/foo.lua")   -> relative to this repo
--     Http("https://...")      -> an absolute URL, e.g. a Roblox API
local function fetch(path: string): (string?, string?)
    return http(REPO .. path)
end

-- Fetches a Lua file from the repo and runs it, returning whatever it returns.
local function loadFile(path: string): (any, string?)
    local source, fetchErr = fetch(path)

    if source == nil then
        return nil, fetchErr
    end

    local chunk, compileErr = loadstring(source)

    if chunk == nil then
        return nil, `syntax error in {path}: {tostring(compileErr)}`
    end

    local ok, result = pcall(chunk)

    if not ok then
        return nil, `error in {path}: {tostring(result)}`
    end

    return result
end

-- ═════════════════════════════════════════════════════════════════ teardown

--[[
    Game scripts register their cleanup here rather than doing it themselves.
    Unload is the easy thing to get wrong: a script that forgets to disconnect
    a loop leaves it running after the UI is gone, and the user sees the
    symptom long after the cause.

    Callbacks run in reverse — last registered, first stopped.
]]
local stopCallbacks: { () -> () } = {}
local unloaded = false

local function onStop(callback: () -> ())
    table.insert(stopCallbacks, callback)
end

-- Convenience for the common case of an RBXScriptConnection.
local function track(connection: any)
    if connection ~= nil and connection.Disconnect ~= nil then
        onStop(function()
            pcall(function()
                connection:Disconnect()
            end)
        end)
    end
end

-- ═════════════════════════════════════════════════════════════════════ boot

log(`v{VERSION} starting`)

-- 1. UI library.
local librarySource, libraryErr = fetch("libs/obsidian.luau")

if librarySource == nil then
    -- Nothing can be shown without the library, so this is the one failure
    -- that is fatal. It is also the failure a wrong REPO produces, so the
    -- message names the file.
    error(`${PREFIX} cannot load libs/obsidian.luau — {libraryErr}`)
end

local libraryChunk = loadstring(librarySource)
local Library = libraryChunk and libraryChunk()

if Library == nil then
    error(`${PREFIX} the UI library failed to initialise`)
end

debug("library loaded")

-- 2. Shared context. Everything a game or tab can reach goes through this.
local ctx = {
    Library = Library,
    Options = Library.Options,
    Toggles = Library.Toggles,

    PlaceId = game.PlaceId,
    JobId = game.JobId,
    Version = VERSION,

    -- Set below once routing decides, and read by the game's main.lua.
    GameFolder = nil,

    --[[
        Tabs every game builds, loaded from libs/tabs.

        They live here rather than in each game's tabs/ folder because they are
        identical everywhere and one fix should not mean editing every game.
        The list is here for the same reason — one copy, not one per game.

        A game builds these first, then its own on top.
    ]]
    SharedTabs = { "home", "ui-settings" },

    -- Set by the game's main.lua.
    Window = nil,
    Configs = nil,

    Log = log,
    Debug = debug,
    Warn = warn_,

    Fetch = fetch,
    Http = http,
    LoadFile = loadFile,

    OnStop = onStop,
    Track = track,
}

-- 3. Routing. A game declares its own places; this only asks each one.
local function findGame(): string?
    local considered = {}

    for _, name in GAMES do
        local folder = `games/{name}`
        local config, err = loadFile(`{folder}/config.lua`)

        if config == nil then
            warn_(`{folder}/config.lua: {err}`)
        elseif type(config) ~= "table" then
            warn_(`{folder}/config.lua must return a table`)
        else
            local places = config.Places

            -- An empty or missing Places means "everywhere", matching how the
            -- template documents it.
            if places == nil or #places == 0 or table.find(places, game.PlaceId) then
                debug(`{folder} covers place {game.PlaceId}`)
                return folder
            end

            table.insert(considered, name)
        end
    end

    if #considered > 0 then
        debug(`no match among: {table.concat(considered, ", ")}`)
    end

    return nil
end

local folder = findGame()

-- 4. Run it, or explain why not.
if folder ~= nil then
    ctx.GameFolder = folder

    log(`place {game.PlaceId} -> {folder}`)

    local gameMain, err = loadFile(`{folder}/main.lua`)

    if gameMain == nil then
        warn_(err)
    elseif type(gameMain) ~= "function" then
        warn_(`{folder}/main.lua must return a function`)
    else
        local ok, runErr = pcall(gameMain, ctx)

        if not ok then
            warn_(`{folder}/main.lua failed: {tostring(runErr)}`)
        end
    end
end

--[[
    Nothing matched. Build a window anyway.

    An empty screen reads as broken; a window naming the place id reads as
    "this game is not supported yet", which is what is actually true.
]]
if ctx.Window == nil then
    log(`place {game.PlaceId} has no game folder`)

    local Themes = loadFile("libs/Addons/themes.luau")

    if Themes ~= nil then
        Themes.Apply(Library, "Abyssal")
    end

    local window = Library:CreateWindow({
        Title = "Abyssal",
        Footer = `v{VERSION}`,
        Icon = "triangle-alert",
        NotifySide = "Right",
        ShowCustomCursor = true,
    })

    ctx.Window = window

    local tab = window:AddTab("Unsupported", "triangle-alert")
    local box = tab:AddGroupbox({ Side = "Left", Name = "No game folder" })

    box:AddLabel(`Nothing in games/ covers place {game.PlaceId}.`)
    box:AddLabel("Add a folder and list it in GAMES, or add this place to an existing config.")

    window:Notify({
        Title = "Abyssal",
        Text = "No game folder for this place.",
        Duration = 6,
    })
end

-- 5. Teardown.
local function unload()
    if unloaded then
        return
    end

    unloaded = true
    log("unloading")

    for index = #stopCallbacks, 1, -1 do
        local ok, err = pcall(stopCallbacks[index])

        if not ok then
            warn_(`stop callback failed: {tostring(err)}`)
        end
    end

    table.clear(stopCallbacks)

    pcall(function()
        Library:Unload()
    end)
end

pcall(function()
    Library:OnUnload(unload)
end)

-- Exposed for the console:  getgenv().Abyssal.Unload()
getgenv().Abyssal = {
    Version = VERSION,
    Context = ctx,
    Library = Library,
    Unload = unload,
}

log("ready")
