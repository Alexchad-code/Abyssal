--[[
    games/_template/features/ExampleFeature.luau

    TEMPLATE. Copy games/_template to games/<your-game>/ and edit. This file is
    never loaded — it is not referenced by games/init.luau, so it stays out of
    the bundle. It exists as the reference for the shape a feature should take.

    ---------------------------------------------------------------------------

    The Feature contract, in order of how often you will get it wrong:

    1. OnEnable must be fully reversible by OnDisable. Module:Stop calls
       Disable on every widget during unload, and if OnDisable misses a
       connection or a thread, that keeps running after the UI is gone.

    2. OnEnable should raise on failure rather than returning quietly. The base
       class catches it, rolls the toggle back to off, and logs — which is what
       you want. A silent failure leaves a toggle claiming to be on.

    3. Do not touch ctx.ui or ctx.config at file scope. Both are populated
       during boot; at file scope they are still nil. Use Setup or OnEnable.

    4. The Id is global across the whole hub, so prefix it with the game.
       "template.exampleFeature", not "exampleFeature".
]]

local Feature = require("core/Feature")

local RunService = game:GetService("RunService")

local ExampleFeature = Feature.new({
    Id = "template.exampleFeature",
    Name = "Example Feature",

    -- Shown as a tooltip. Describe what it does, not that it exists.
    Description = "Does the thing.",

    -- Start enabled for a new user? Prefer false unless the feature is
    -- harmless, because a fresh install should not immediately do things.
    Default = false,

    -- Renders the label red. Reserve for things that are hard to undo.
    Risky = false,

    -- Which groupbox and side. Widgets added in sequence land in that order.
    Group = "Example",
    Side = "Left",
})

-- Optional. Extra widgets rendered beneath this feature's toggle. The index
-- used here is global too, so prefix it the same way.
function ExampleFeature:GetExtraUI()
    return {
        {
            Type = "Slider",
            Id = "template.exampleFeature.interval",
            Text = "Interval (s)",
            Min = 1,
            Max = 60,
            Default = 10,
        },
    }
end

-- Optional. Called after the UI exists but before Start, so this is the first
-- place ctx.ui and ctx.config are safe to use.
function ExampleFeature:Setup(_ctx: any) end

function ExampleFeature:OnEnable()
    local ctx = self._ctx

    -- Start whatever this feature does. Keep the handle so OnDisable can kill
    -- it — that is the whole reason the lifecycle exists.
    self._connection = RunService.Heartbeat:Connect(function()
        -- Do the work. Throttle anything per-frame; Heartbeat runs at frame
        -- rate and a naive loop here will cost more than the feature is worth.
    end)

    self._log:Info("enabled")

    ctx.ui:Notify({
        Title = "Abyssal",
        Text = "Example Feature enabled.",
        Duration = 3,
    })
end

function ExampleFeature:OnDisable()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end

    self._log:Info("disabled")
end

-- Optional. Only needed if the feature owns instances or other resources that
-- outlive OnDisable. Disable is always called first.
function ExampleFeature:OnDestroy() end

return ExampleFeature
