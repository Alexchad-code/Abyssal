--[[
    games/universal.lua

    Runs in every game, alongside whichever dedicated script matches the place.
    Anything here must work without knowing anything about the game it is in.

    A game script is a function. main.lua calls it with the shared context and
    that is the entire contract:

        return function(ctx)
            local tab = ctx.Window:AddTab("Name", "lucide-icon")
            -- build UI, wire behaviour
            ctx.OnStop(function() ... end)   -- anything that needs cleanup
        end

    ctx is documented in AGENTS.md. The short version: it carries the Obsidian
    library, the window, logging, fetch, and the teardown registry.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")

return function(ctx)
    local tab = ctx.Window:AddTab("Universal", "globe")

    local function notify(text: string, duration: number?)
        ctx.Library:Notify({
            Title = "Abyssal",
            Text = text,
            Duration = duration or 4,
        })
    end

    -- ───────────────────────────────────────────────────────────── server ──

    local server = tab:AddGroupbox({ Side = "Left", Name = "Server" })

    server:AddButton({
        Text = "Copy Job ID",
        Tooltip = "JobId identifies this exact server. Useful for rejoining it later.",
        Func = function()
            local jobId = game.JobId

            if jobId == nil or jobId == "" then
                notify("JobId is unavailable in this server.")
                return
            end

            local copied = pcall(function()
                setclipboard(jobId)
            end)

            notify(copied and `Copied: {jobId}` or `JobId: {jobId}`, 5)
        end,
    })

    server:AddButton({
        Text = "Rejoin Server",
        Tooltip = "Returns you to this same server. Fails if it has shut down.",
        DoubleClick = true,
        Func = function()
            local player = Players.LocalPlayer

            if player == nil then
                return
            end

            if game.JobId == nil or game.JobId == "" then
                notify("Cannot rejoin: JobId is unavailable.")
                return
            end

            notify("Rejoining this server...", 3)

            local ok, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
            end)

            if not ok then
                ctx.Warn(`rejoin failed: {tostring(err)}`)
                notify("Rejoin failed. The server may have closed.", 5)
            end
        end,
    })

    server:AddButton({
        Text = "Server Hop",
        Tooltip = "Moves you to the least populated joinable server of this game.",
        DoubleClick = true,
        Func = function()
            local player = Players.LocalPlayer

            if player == nil then
                return
            end

            local url = `https://games.roblox.com/v1/games/{game.PlaceId}/servers/Public?sortOrder=Asc&limit=100`
            local body, httpErr = ctx.Http(url)

            if body == nil then
                ctx.Warn(`server list failed: {httpErr}`)
                notify("Could not list servers. Try again shortly.", 5)
                return
            end

            local decoded
            local decodeOk = pcall(function()
                decoded = game:GetService("HttpService"):JSONDecode(body)
            end)

            if not decodeOk or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
                notify("Unexpected response from the server list.", 5)
                return
            end

            local best = nil

            for _, entry in decoded.data do
                local joinable = type(entry.playing) == "number"
                    and type(entry.maxPlayers) == "number"
                    and entry.playing < entry.maxPlayers
                    and entry.id ~= game.JobId

                if joinable and (best == nil or entry.playing < best.playing) then
                    best = entry
                end
            end

            if best == nil then
                notify("No joinable server found. Try again shortly.", 5)
                return
            end

            notify("Hopping to another server...", 3)

            local ok, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, player)
            end)

            if not ok then
                ctx.Warn(`hop failed: {tostring(err)}`)
                notify("Server hop failed.", 5)
            end
        end,
    })

    -- ──────────────────────────────────────────────────────── diagnostics ──

    local diagnostics = tab:AddGroupbox({ Side = "Right", Name = "Diagnostics" })

    local watchdog = diagnostics:AddToggle("universal.watchdog", {
        Text = "Connection Watchdog",
        Tooltip = "Watches ping and notifies you when it crosses the threshold.",
        Default = false,
    })

    watchdog:AddSlider("universal.watchdogThreshold", {
        Text = "Warn above (ms)",
        Min = 100,
        Max = 1000,
        Default = 300,
        Rounding = 0,
    })

    --[[
        The lifecycle, spelled out. OnChanged can fire repeatedly, so it always
        stops the previous loop first — otherwise toggling on/off/on leaves the
        first loop running and you get two notifications per spike.

        ctx.OnStop covers the other exit: the user unloading the hub while the
        toggle is still on.
    ]]
    local watchdogConnection = nil
    local lastWarnedAt = 0

    local function stopWatchdog()
        if watchdogConnection then
            watchdogConnection:Disconnect()
            watchdogConnection = nil
        end
    end

    local function threshold(): number
        local option = ctx.Options["universal.watchdogThreshold"]

        if option == nil or type(option.Value) ~= "number" then
            return 300
        end

        return option.Value
    end

    watchdog:OnChanged(function(enabled: boolean)
        stopWatchdog()

        if not enabled then
            return
        end

        local pingStat = Stats.Network.ServerStatsItem["Data Ping"]

        if pingStat == nil then
            ctx.Warn("ping stat unavailable; watchdog disabled")
            watchdog:SetValue(false)
            return
        end

        watchdogConnection = RunService.Heartbeat:Connect(function()
            local ping = pingStat:GetValue()
            local limit = threshold()

            if ping < limit then
                return
            end

            -- Do not spam a sustained bad connection.
            if os.clock() - lastWarnedAt < 30 then
                return
            end

            lastWarnedAt = os.clock()

            notify(`Ping is {math.floor(ping)}ms (threshold {math.floor(limit)}ms)`, 6)
        end)
    end)

    ctx.OnStop(stopWatchdog)
end
