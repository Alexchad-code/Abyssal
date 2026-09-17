--[[
    ═══════════════════════════════════════════════════════════════════════════
    ABYSSAL
    ═══════════════════════════════════════════════════════════════════════════

    This is the main script. Execute it and it does the rest:

        1. loads the UI library from libs/obsidian
        2. builds the window and the shared settings tab
        3. works out which script in games/ belongs to your game
        4. runs it

    Nothing is pre-compiled. Every file is fetched at run time, so pushing to
    the repo is the whole release process.

    ─── To use it ────────────────────────────────────────────────────────────

        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/Alexchad-code/Abyssal/main/main.lua"
        ))()

    ─── To add a game ────────────────────────────────────────────────────────

        copy games/_template.lua to games/your-game.lua
        edit it
        add its place ID to GAMES below

    See docs/adding-a-game.md. See AGENTS.md if you are an AI working here.

    ─── Licence ──────────────────────────────────────────────────────────────

    MIT. Bundles the Obsidian UI Library, also MIT — see THIRD_PARTY_NOTICES.md.
]]

-- ══════════════════════════════════════════════════════════════ configuration

local REPO = "https://raw.githubusercontent.com/Alexchad-code/Abyssal/main/"
local VERSION = "0.2.0"

--[[
    Which script runs in which game.

    The key is the place ID, the value is a file in games/ without the .lua.
    Find a place ID in the Roblox URL, or from game.PlaceId in the executor
    console.

    List every place a script should cover. Lobby and main game are usually
    different IDs, and a script that only lists one will silently do nothing in
    the other.

    Anything not listed here still gets the universal script, so the hub opens
    with working utilities rather than an empty window.
]]
local GAMES = {
    -- [2753915549] = "blox-fruits",
    -- [920587237]  = "adopt-me",
}

-- Always loaded, whatever the game. Set to nil to disable.
local UNIVERSAL = "universal"

-- Set true to print debug lines to the console.
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
-- produces a readable message instead of a stack trace in the console.
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

--[[
    Two ways to fetch, because they are not the same thing and conflating them
    produces a URL like "https://raw.githubusercontent.com/.../https://games.roblox.com/...".

        ctx.Fetch("games/foo.lua")   -> relative to this repo
        ctx.Http("https://...")      -> an absolute URL, e.g. a Roblox API
]]
local function fetch(path: string): (string?, string?)
    return http(REPO .. path)
end

-- Fetches a Lua file and runs it, returning whatever it returns.
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

-- ══════════════════════════════════════════════════════════════════ theme

local THEME_NAME = "Abyssal"

local THEME_PALETTE = {
    FontColor = "e6edf3",
    MainColor = "111827",
    BackgroundColor = "0a0f1a",
    OutlineColor = "1f2a3c",
    AccentColor = "2dd4bf",
    BackgroundImage = "",
}

-- ═════════════════════════════════════════════════════════════════════ boot

log(`v{VERSION} starting`)

-- 1. UI library.
local librarySource, libraryErr = fetch("libs/obsidian/Library.lua")

if librarySource == nil then
    error(`${PREFIX} cannot load the UI library — {libraryErr}`)
end

local libraryChunk = loadstring(librarySource)
local Library = libraryChunk and libraryChunk()

if Library == nil then
    error(`${PREFIX} the UI library failed to initialise`)
end

-- loadFile returns (result, err), so assigning to one name takes the result.
local ThemeManager, themeErr = loadFile("libs/obsidian/addons/ThemeManager.lua")
local SaveManager, saveErr = loadFile("libs/obsidian/addons/SaveManager.lua")

if ThemeManager == nil or SaveManager == nil then
    warn_(`an addon failed to load — themes: {themeErr or "ok"}, config: {saveErr or "ok"}`)
end

debug("library loaded")

-- 2. Window.
local Window = Library:CreateWindow({
    Title = "Abyssal",
    Footer = `v{VERSION}`,
    Icon = "waves",
    NotifySide = "Right",
    ShowCustomCursor = true,
})

-- 3. Theme, registered so it shows up in the picker alongside the built-ins.
if ThemeManager then
    ThemeManager.BuiltInThemes[THEME_NAME] = { 100, THEME_PALETTE }
    ThemeManager:SetLibrary(Library)

    local ok = ThemeManager:ApplyTheme(THEME_NAME)

    if not ok then
        warn_(`could not apply the {THEME_NAME} theme`)
    end
end

-- 4. Shared teardown registry.
--[[
    Game scripts register their cleanup here instead of doing it themselves.
    That matters because unload is the easy thing to get wrong: a script that
    forgets to disconnect a loop leaves it running after the UI is gone, and the
    user sees the symptom long after the cause.

    Callbacks run in reverse order — last registered, first stopped.
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

-- 5. Context handed to game scripts.
local ctx = {
    Library = Library,
    SaveManager = SaveManager,
    ThemeManager = ThemeManager,

    -- Shortcuts, so scripts do not have to reach through Library every time.
    Options = Library.Options,
    Toggles = Library.Toggles,

    Window = Window,
    PlaceId = game.PlaceId,
    JobId = game.JobId,

    Log = log,
    Debug = debug,
    Warn = warn_,

    Fetch = fetch,
    Http = http,
    LoadFile = loadFile,

    OnStop = onStop,
    Track = track,
}

-- 6. Settings tab — shared, so every game script gets it for free.
local function buildSettingsTab()
    local ok, err = pcall(function()
        local tab = Window:AddTab("Settings", "settings")

        if ThemeManager then
            ThemeManager:ApplyToTab(tab, "palette")
        end

        if SaveManager then
            SaveManager:SetLibrary(Library)
            SaveManager:SetFolder("Abyssal")
            SaveManager:SetSubFolder(`Place_{game.PlaceId}`)
            SaveManager:BuildConfigSection(tab)
        end
    end)

    if not ok then
        warn_(`settings tab failed: {tostring(err)}`)
    end
end

-- 7. Which scripts to run.
local gameScript = GAMES[game.PlaceId]

local toRun: { string } = {}

if UNIVERSAL then
    table.insert(toRun, UNIVERSAL)
end

if gameScript then
    table.insert(toRun, gameScript)
    log(`place {game.PlaceId} -> games/{gameScript}.lua`)
else
    log(`place {game.PlaceId} has no dedicated script; running universal only`)
end

-- 8. Run them.
local loaded = 0

for _, name in toRun do
    local script, loadErr = loadFile(`games/{name}.lua`)

    if script == nil then
        warn_(loadErr)
    elseif type(script) ~= "function" then
        warn_(`games/{name}.lua must return a function, got {typeof(script)}`)
    else
        local ok, runErr = pcall(script, ctx)

        if ok then
            loaded += 1
            debug(`games/{name}.lua running`)
        else
            warn_(`games/{name}.lua failed: {tostring(runErr)}`)
        end
    end
end

buildSettingsTab()

-- 9. Unload.
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

if loaded == 0 then
    local tab = Window:AddTab("No scripts", "triangle-alert")
    tab:AddGroupbox({ Side = "Left", Name = "Nothing to run" }):AddLabel(
        `No script loaded for place {game.PlaceId}. See docs/adding-a-game.md.`
    )
end

Library:Notify({
    Title = "Abyssal",
    Text = loaded > 0 and `Loaded {loaded} script(s)` or "No scripts for this game",
    Duration = 4,
})

-- Exposed for the console:  getgenv().Abyssal.Unload()
getgenv().Abyssal = {
    Version = VERSION,
    Window = Window,
    Library = Library,
    Context = ctx,
    Unload = unload,
}

log("ready")
