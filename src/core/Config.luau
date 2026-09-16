--[[
    core/Config.luau

    Config persistence, backed by Obsidian's SaveManager.

    SaveManager is a UI-layer object — it builds its own section into a tab and
    reads the library's Options table — so this module exists to keep that
    dependency in one place instead of letting every feature reach into it.

    Configs are namespaced per game. A config saved in one game is not offered
    in another, because option indexes differ between modules and loading the
    wrong set would silently apply unrelated values.
]]

local Logger = require("core/Logger")

local Config = {}
Config.__index = Config

export type Config = typeof(setmetatable(
    {} :: {
        _log: any,
        _saveManager: any,
        _folder: string,
        _subFolder: string,
        _ready: boolean,
    },
    Config
))

function Config.new(): Config
    return setmetatable({
        _log = Logger.new("Config"),
        _saveManager = nil,
        _folder = "Abyssal",
        _subFolder = "Default",
        _ready = false,
    }, Config)
end

-- Called during boot once SaveManager has been loaded and the library exists.
function Config:Attach(saveManager: any, library: any, folder: string?, subFolder: string?)
    assert(saveManager ~= nil, "Config:Attach expects a SaveManager")

    self._saveManager = saveManager
    self._folder = folder or self._folder
    self._subFolder = subFolder or self._subFolder

    saveManager:SetLibrary(library)
    saveManager:SetFolder(self._folder)
    saveManager:SetSubFolder(self._subFolder)

    self._ready = true
    self._log:Info(`config folder: {self._folder}/{self._subFolder}`)
end

function Config:IsReady(): boolean
    return self._ready
end

-- Option indexes that must never be written to or read from config: things
-- like "unload", or anything whose value is a live instance reference.
function Config:SetIgnoredIndexes(indexes: { string })
    if not self._ready then
        return
    end

    self._saveManager:SetIgnoreIndexes(indexes)
end

-- Builds the save/load UI into a tab. Call once, after the tab exists.
function Config:BuildSection(tab: any)
    if not self._ready then
        self._log:Warn("BuildSection called before Attach; skipping")
        return
    end

    self._saveManager:BuildConfigSection(tab)
end

-- Applies the config marked as autoload, if any. Called after all features
-- have been registered, otherwise the options it wants to set do not exist yet.
function Config:LoadAutoload()
    if not self._ready then
        return false
    end

    local ok, err = pcall(function()
        self._saveManager:LoadAutoloadConfig()
    end)

    if not ok then
        self._log:Warn(`autoload failed: {tostring(err)}`)
        return false
    end

    return true
end

function Config:Save(name: string)
    if not self._ready then
        return
    end

    local ok, err = pcall(function()
        self._saveManager:Save(name)
    end)

    if not ok then
        self._log:Error(`save "{name}" failed: {tostring(err)}`)
    end
end

function Config:Load(name: string)
    if not self._ready then
        return
    end

    local ok, err = pcall(function()
        self._saveManager:Load(name)
    end)

    if not ok then
        self._log:Error(`load "{name}" failed: {tostring(err)}`)
    end
end

return Config
