--[[
    core/Context.luau

    The shared services object. Every module and feature receives this instead
    of reaching for globals.

    The reason is testability and blast radius: a module that only touches what
    it was handed cannot accidentally depend on load order, cannot reach into
    another module's state, and can be driven from a test harness with a stub
    context. It also means there is exactly one place to look when asking "what
    can a feature actually do?".

    ui and config are populated later — ui after the window exists, config once
    SaveManager has been handed the library — so modules must read them in
    Ready(), not at file scope.
]]

local Logger = require("core/Logger")
local Signals = require("core/Signals")
local Registry = require("core/Registry")
local Http = require("core/Http")

local Context = {}

export type Signals = {
    FeatureEnabled: Signals.Signal,
    FeatureDisabled: Signals.Signal,
    ModuleStarted: Signals.Signal,
    ModuleStopped: Signals.Signal,
    Notification: Signals.Signal,
    Unloading: Signals.Signal,
}

export type Context = {
    log: Logger.Logger,
    registry: Registry.Registry,
    signals: Signals,
    http: Http.Http,

    -- Populated by App during boot.
    ui: any?,
    config: any?,
    library: any?,

    -- Set once the hub is fully started.
    started: boolean,

    -- Details of the server we booted into.
    server: any?,
}

function Context.new(): Context
    return {
        log = Logger.new("Abyssal"),
        registry = Registry.new(),
        signals = {
            FeatureEnabled = Signals.new(),
            FeatureDisabled = Signals.new(),
            ModuleStarted = Signals.new(),
            ModuleStopped = Signals.new(),
            Notification = Signals.new(),
            Unloading = Signals.new(),
        },
        http = Http.new(),

        ui = nil,
        config = nil,
        library = nil,
        started = false,
        server = nil,
    }
end

return Context
