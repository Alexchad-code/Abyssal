--[[
    games/universal/features/ConnectionWatchdog.luau

    Watches server ping and warns when it climbs.

    This one exists to demonstrate the stateful half of the lifecycle: it starts
    a connection on enable, tears it down on disable, and exposes a slider for
    its threshold via GetExtraUI. If you are adding a feature that runs a loop,
    copy this shape — the important part is that OnDisable fully reverses
    OnEnable, because Module:Stop relies on that to leave nothing running.

    The loop reads the engine's own ping stat rather than measuring round trips,
    which is both cheaper and consistent with the figure Roblox shows in the
    performance overlay.
]]

local Feature = require("core/Feature")

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local THRESHOLD_INDEX = "universal.watchdog.threshold"

-- Warn at most this often, so a sustained bad connection does not spam.
local WARN_COOLDOWN = 30

local ConnectionWatchdog = Feature.new({
    Id = "universal.connectionWatchdog",
    Name = "Connection Watchdog",
    Description = "Warn when server ping spikes.",
    Tooltip = "Monitors ping and notifies you when it crosses the threshold.",
    Group = "Diagnostics",
    Side = "Right",
})

function ConnectionWatchdog:GetExtraUI()
    return {
        {
            Type = "Slider",
            Id = THRESHOLD_INDEX,
            Text = "Warn above (ms)",
            Min = 100,
            Max = 1000,
            Default = 300,
            -- No Callback here on purpose: logic is wired in OnEnable via
            -- OnChanged, keeping widget creation and behaviour separate.
        },
    }
end

function ConnectionWatchdog:getThreshold(): number
    local options = self._ctx.library and self._ctx.library.Options

    if options == nil then
        return 300
    end

    local option = options[THRESHOLD_INDEX]

    if option == nil or type(option.Value) ~= "number" then
        return 300
    end

    return option.Value
end

function ConnectionWatchdog:OnEnable()
    local ctx = self._ctx
    local lastWarnedAt = 0

    local pingStat = Stats.Network.ServerStatsItem["Data Ping"]

    if pingStat == nil then
        -- Nothing to watch. Fail loudly so Enable() rolls the toggle back
        -- instead of leaving a toggle on that does nothing.
        error("ping stat unavailable")
    end

    self._connection = RunService.Heartbeat:Connect(function()
        local ping = pingStat:GetValue()
        local threshold = self:getThreshold()

        if ping < threshold then
            return
        end

        local now = os.clock()

        if now - lastWarnedAt < WARN_COOLDOWN then
            return
        end

        lastWarnedAt = now

        ctx.ui:Notify({
            Title = "Abyssal",
            Text = `Ping is {math.floor(ping)}ms (threshold {math.floor(threshold)}ms)`,
            Duration = 6,
        })
    end)

    self._log:Info(`watching, threshold {self:getThreshold()}ms`)
end

function ConnectionWatchdog:OnDisable()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
end

return ConnectionWatchdog
