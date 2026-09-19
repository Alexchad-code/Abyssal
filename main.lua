local REPO = "https://raw.githubusercontent.com/Alexchad-code/Abyssal/main/"
local VERSION = "0.3.0"

local GAMES = {
    "universal",
    "template",
}

local DEBUG = false

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

local function fetch(path: string): (string?, string?)
    return http(REPO .. path)
end

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

local stopCallbacks: { () -> () } = {}
local unloaded = false

local function onStop(callback: () -> ())
    table.insert(stopCallbacks, callback)
end

local function track(connection: any)
    if connection ~= nil and connection.Disconnect ~= nil then
        onStop(function()
            pcall(function()
                connection:Disconnect()
            end)
        end)
    end
end

log(`v{VERSION} starting`)

local librarySource, libraryErr = fetch("libs/obsidian.luau")

if librarySource == nil then

    error(`${PREFIX} cannot load libs/obsidian.luau — {libraryErr}`)
end

local libraryChunk = loadstring(librarySource)
local Library = libraryChunk and libraryChunk()

if Library == nil then
    error(`${PREFIX} the UI library failed to initialise`)
end

debug("library loaded")

local ctx = {
    Library = Library,
    Options = Library.Options,
    Toggles = Library.Toggles,

    PlaceId = game.PlaceId,
    JobId = game.JobId,
    Version = VERSION,

    GameFolder = nil,

    SharedTabs = { "home", "ui-settings" },

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

local function matches(config: any): boolean
    local gameIdDeclared = config.GameId ~= nil
    local placesDeclared = config.Places ~= nil

    if not gameIdDeclared and not placesDeclared then
        return false
    end

    if gameIdDeclared then
        local id = tonumber(config.GameId)

        if id ~= nil and id ~= 0 and id == game.GameId then
            return true
        end
    end

    if placesDeclared and type(config.Places) == "table" then
        if table.find(config.Places, game.PlaceId) ~= nil then
            return true
        end
    end

    return false
end

local function isUniversal(config: any): boolean
    return config.GameId == nil and config.Places == nil
end

local function findGame(): string?
    local candidates = {}

    for _, name in GAMES do
        local folder = `games/{name}`
        local config, err = loadFile(`{folder}/config.lua`)

        if config == nil then
            warn_(`{folder}/config.lua: {err}`)
        elseif type(config) ~= "table" then
            warn_(`{folder}/config.lua must return a table`)
        else
            table.insert(candidates, { folder = folder, config = config })
        end
    end

    for _, candidate in candidates do
        if matches(candidate.config) then
            debug(`{candidate.folder} matches`)
            return candidate.folder
        end
    end

    for _, candidate in candidates do
        if isUniversal(candidate.config) then
            debug(`falling back to {candidate.folder}`)
            return candidate.folder
        end
    end

    return nil
end

local folder = findGame()

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

getgenv().Abyssal = {
    Version = VERSION,
    Context = ctx,
    Library = Library,
    Unload = unload,
}

log("ready")
