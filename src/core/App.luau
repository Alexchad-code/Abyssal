--[[
    core/App.luau

    Boot sequence and lifecycle owner.

    Boot order is not arbitrary. Each step depends on the one before it:

        1. Context          services exist before anything wants them
        2. server describe  modules may branch on place id during Setup
        3. Obsidian load    the library is needed before any UI call
        4. window + theme   before any tab exists
        5. config attach    SaveManager needs the library
        6. Mount            features receive the context
        7. Setup            modules do pre-UI work
        8. BuildUI          tabs are created and filled
        9. Ready            modules wire signals and config sections
       10. autoload         restoring values requires the options to exist
       11. Start            features turn on last, once everything is in place

    Start is last on purpose. A feature that turns on before the UI exists
    cannot report its own state, and one that turns on before config loads will
    be immediately overridden.
]]

local Context = require("core/Context")
local Config = require("core/Config")
local GameDetector = require("core/GameDetector")
local Logger = require("core/Logger")

local Obsidian = require("ui/Obsidian")
local Theme = require("ui/Theme")
local Window = require("ui/Window")

local App = {}
App.__index = App

export type Options = {
    Title: string?,
    Footer: string?,
    Icon: string?,

    -- Folder that configs and themes are written under.
    ConfigFolder: string?,

    -- Applied as the starting theme. Users can change it from the picker.
    Theme: string?,

    -- Turn on debug logging.
    Debug: boolean?,
}

export type App = typeof(setmetatable(
    {} :: {
        _ctx: any,
        _config: Config.Config,
        _window: any?,
        _bundle: any?,
        _modules: { any },
        _options: Options,
        _log: any,
        _unloadConnections: { any },
        _running: boolean,
    },
    App
))

function App.new(options: Options?): App
    local resolved = options or {}

    return setmetatable({
        _ctx = Context.new(),
        _config = Config.new(),
        _window = nil,
        _bundle = nil,
        _modules = {},
        _options = resolved,
        _log = Logger.new("App"),
        _unloadConnections = {},
        _running = false,
    }, App)
end

function App:GetContext(): any
    return self._ctx
end

function App:GetWindow(): any?
    return self._window
end

function App:GetLibrary(): any?
    return self._bundle and self._bundle.Library or nil
end

-- Registers a module. Modules are mounted in registration order, but only the
-- ones matching the current place are loaded.
function App:Register(module: any): App
    self._ctx.registry:Register(module)
    return self
end

function App:IsRunning(): boolean
    return self._running
end

-- ------------------------------------------------------------------- boot --

function App:Run(): boolean
    if self._running then
        self._log:Warn("already running; ignoring Run()")
        return false
    end

    if self._options.Debug then
        Logger.setGlobalLevel("debug")
    end

    local ctx = self._ctx

    self._log:Info("booting")

    ctx.server = GameDetector.Describe()

    local placeName = ctx.server.placeName or "unknown place"
    self._log:Info(`place {ctx.server.placeId} ({placeName})`)

    -- 3. Load the UI library.
    local ok, bundle = pcall(Obsidian.Load)

    if not ok then
        self._log:Error(`failed to load Obsidian: {tostring(bundle)}`)
        return false
    end

    self._bundle = bundle
    ctx.library = bundle.Library

    -- 4. Window and theme.
    local window = Window.new(bundle.Library, {
        Title = self._options.Title or "Abyssal",
        Footer = self._options.Footer or "v0.1.0",
        Icon = self._options.Icon,
    })

    self._window = window
    ctx.ui = window

    local themeOk, themeErr = Theme.Apply(bundle.ThemeManager)

    if not themeOk then
        self._log:Warn(`theme not applied: {tostring(themeErr)}`)
    end

    -- 5. Config.
    local configFolder = self._options.ConfigFolder or "Abyssal"
    self._config:Attach(
        bundle.SaveManager,
        bundle.Library,
        configFolder,
        `Game_{ctx.server.placeId}`
    )

    ctx.config = self._config

    -- 6. Resolve and mount.
    local applicable = ctx.registry:ResolveApplicable()

    if #applicable == 0 then
        self._log:Warn("no module supports this place")
        self:_buildUnsupportedUI(bundle)
        self._running = true
        return true
    end

    self._log:Info(`loading {#applicable} module(s)`)

    for _, module in applicable do
        module:Mount(ctx)
        table.insert(self._modules, module)
    end

    -- 7. Setup.
    for _, module in self._modules do
        local setupOk, setupErr = pcall(module.Setup, module, ctx)

        if not setupOk then
            self._log:Error(`{module.Id} setup failed: {tostring(setupErr)}`)
        end
    end

    -- 8. Build UI — one tab per module, highest priority first.
    for _, module in self._modules do
        local tabOk, tabErr = pcall(function()
            local tab = window:AddTab(module.Name, module.Icon)
            module:BuildUI(ctx, tab)
            return tab
        end)

        if not tabOk then
            self._log:Error(`{module.Id} BuildUI failed: {tostring(tabErr)}`)
        end
    end

    -- 9. Ready, then the shared settings tab.
    for _, module in self._modules do
        local readyOk, readyErr = pcall(module.Ready, module, ctx)

        if not readyOk then
            self._log:Error(`{module.Id} Ready failed: {tostring(readyErr)}`)
        end
    end

    self:_buildSettingsTab(bundle)

    -- 10. Restore saved state, now that every option exists.
    self._config:LoadAutoload()

    -- 11. Start.
    for _, module in self._modules do
        local startOk, startErr = pcall(module.Start, module, ctx)

        if not startOk then
            self._log:Error(`{module.Id} Start failed: {tostring(startErr)}`)
        end
    end

    self:_installUnloadHandler(bundle)

    ctx.started = true
    self._running = true

    self._log:Info("ready")

    window:Notify({
        Title = "Abyssal",
        Text = `Loaded {#self._modules} module(s)`,
        Duration = 4,
    })

    return true
end

-- ------------------------------------------------------------------- tabs --

function App:_buildSettingsTab(bundle: any)
    local tabOk, tabErr = pcall(function()
        local tab = self._window:AddTab("UI Settings", "settings")

        bundle.ThemeManager:SetLibrary(bundle.Library)
        bundle.ThemeManager:ApplyToTab(tab, "palette")

        self._config:BuildSection(tab)
    end)

    if not tabOk then
        self._log:Error(`settings tab failed: {tostring(tabErr)}`)
    end
end

-- Shown when the hub is injected into a game it has no module for. Better than
-- an empty window, which reads as "broken" rather than "unsupported".
function App:_buildUnsupportedUI(bundle: any)
    local ok, err = pcall(function()
        local tab = self._window:AddTab("Unsupported", "triangle-alert")
        local groupbox = tab:AddGroupbox({
            Side = "Left",
            Name = "No module for this game",
        })

        groupbox:AddLabel(
            `Abyssal has no module for place {self._ctx.server.placeId}.`
        )

        bundle.ThemeManager:SetLibrary(bundle.Library)
        bundle.ThemeManager:ApplyToTab(tab, "palette")
    end)

    if not ok then
        self._log:Error(`unsupported UI failed: {tostring(err)}`)
    end
end

-- --------------------------------------------------------------- shutdown --

function App:_installUnloadHandler(bundle: any)
    local ok, err = pcall(function()
        bundle.Library:OnUnload(function()
            self:Unload()
        end)
    end)

    if not ok then
        self._log:Warn(`could not register unload handler: {tostring(err)}`)
    end
end

-- Tears everything down in reverse boot order. Safe to call twice, and safe to
-- call from an error handler, because every step is individually guarded —
-- a module that throws on the way out must not prevent the others from
-- stopping.
function App:Unload()
    if not self._running then
        return
    end

    self._log:Info("unloading")

    self._running = false

    self._ctx.signals.Unloading:Fire()

    for _, connection in self._unloadConnections do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(self._unloadConnections)

    -- Reverse order: last started, first stopped.
    for index = #self._modules, 1, -1 do
        local module = self._modules[index]

        pcall(function()
            module:Stop(self._ctx)
        end)

        pcall(function()
            module:Destroy()
        end)
    end

    table.clear(self._modules)

    local ok, err = pcall(function()
        self._bundle.Library:Unload()
    end)

    if not ok then
        self._log:Warn(`library unload failed: {tostring(err)}`)
    end

    self._ctx.started = false
    self._log:Info("unloaded")
end

return App
