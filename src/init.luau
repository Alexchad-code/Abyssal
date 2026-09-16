--[[
    src/init.luau

    Entry point. This is the module the bundle runs last.

    Kept deliberately thin: build the App, register the manifest, run. Anything
    that looks like policy belongs in App or in a module, not here, so that
    this file stays readable as the map of the project.

    The App is exposed on getgenv() for debugging from the executor console:

        getgenv().Abyssal:GetContext().log:Debug("...")
        getgenv().Abyssal:Unload()
]]

local App = require("core/App")
local Modules = require("games/init")

local VERSION = "0.1.0"

local app = App.new({
    Title = "Abyssal",
    Footer = `v{VERSION}`,

    -- Configs and custom themes are written under this folder.
    ConfigFolder = "Abyssal",

    -- Set true while developing; raises the log level to debug.
    Debug = false,
})

for _, module in Modules do
    app:Register(module)
end

app:Run()

getgenv().Abyssal = app

return app
