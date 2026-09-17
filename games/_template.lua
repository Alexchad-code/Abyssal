--[[
    games/_template.lua

    Copy this to games/your-game.lua and edit it. Add its place ID to GAMES in
    main.lua. That is the whole process.

    ───────────────────────────────────────────────────────────────────────────

    A game script is a function. main.lua calls it with ctx and that is the
    entire contract. There is no base class to inherit and nothing to register.

        return function(ctx)
            -- build UI
            -- ctx.OnStop(function() ... end) for anything needing cleanup
        end

    ctx gives you:

        ctx.Library         the Obsidian library object
        ctx.SaveManager     config persistence (already set up for you)
        ctx.ThemeManager    themes (already set up for you)
        ctx.Options         Library.Options, indexed by option id
        ctx.Toggles         Library.Toggles, indexed by option id
        ctx.Window          the window, for AddTab
        ctx.PlaceId         game.PlaceId
        ctx.JobId           game.JobId
        ctx.Log / Debug / Warn
        ctx.Fetch(path)     GET a file from this repo, e.g. "assets/data.json"
        ctx.Http(url)       GET an absolute URL, e.g. a Roblox API
        ctx.OnStop(fn)      run fn when the hub unloads
        ctx.Track(conn)     shorthand: disconnect conn on unload

    ───────────────────────────────────────────────────────────────────────────

    Four things that are easy to get wrong:

    1. Option ids are global across the whole hub. Prefix them with the game —
       "yourgame.autoSell", not "autoSell". Two scripts using the same id means
       two widgets fighting over one stored value.

    2. OnChanged can fire more than once. If it starts something, it must stop
       the previous instance first, or toggling on/off/on leaves two loops
       running.

    3. ctx.OnStop is for teardown the user does not trigger — them unloading the
       hub while your toggle is still on. Handle that as well as the toggle
       going off. Both paths lead to the same cleanup function.

    4. Register OnChanged AFTER creating the widget, never in the info table.
       Obsidian's own docs recommend this: it keeps UI creation and behaviour
       separate, and it means a config load can set the value without your
       callback firing mid-construction.
]]

local RunService = game:GetService("RunService")

return function(ctx)
    -- One tab per game script. The icon is a Lucide name — https://lucide.dev/
    local tab = ctx.Window:AddTab("Your Game", "gamepad-2")

    local function notify(text: string, duration: number?)
        ctx.Library:Notify({
            Title = "Abyssal",
            Text = text,
            Duration = duration or 4,
        })
    end

    -- ────────────────────────────────────────────────────────────── setup ──

    --[[
        Resolve anything the game needs once, here, rather than on every use.
        WaitForChild with a timeout, and fail soft: if the game updated and a
        remote moved, log it and let the rest of the script load. A script that
        errors on boot gives the user nothing.
    ]]
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local someRemote = nil

    local ok, result = pcall(function()
        return ReplicatedStorage:WaitForChild("SomeRemote", 5)
    end)

    if ok and result ~= nil then
        someRemote = result
    else
        ctx.Warn("SomeRemote not found; features depending on it will not work")
    end

    -- ──────────────────────────────────────────────────────────────── ui ──

    local main = tab:AddGroupbox({
        Side = "Left",
        Name = "Main",
        -- Description = "Shown under the title",
        -- IconName = "boxes",
    })

    -- A toggle that runs a loop. The interesting part is the cleanup.
    local auto = main:AddToggle("yourgame.autoThing", {
        Text = "Auto Thing",
        Tooltip = "Does the thing automatically.",
        Default = false,
        -- Risky = true,   -- red label, for things that are hard to undo
    })

    auto:AddSlider("yourgame.autoThingDelay", {
        Text = "Delay (s)",
        Min = 1,
        Max = 30,
        Default = 5,
        Rounding = 1,
    })

    local autoConnection = nil
    local lastRunAt = 0

    -- One function, called from both exit paths.
    local function stopAutoThing()
        if autoConnection then
            autoConnection:Disconnect()
            autoConnection = nil
        end
    end

    auto:OnChanged(function(enabled: boolean)
        -- Always stop first. See point 2 in the header.
        stopAutoThing()

        if not enabled then
            return
        end

        if someRemote == nil then
            ctx.Warn("auto thing needs SomeRemote, which is missing")
            notify("This feature is unavailable in this game.", 5)
            auto:SetValue(false)
            return
        end

        autoConnection = RunService.Heartbeat:Connect(function()
            --[[
                Throttle anything per-frame. Heartbeat runs at frame rate, and a
                naive loop here costs more than the feature is worth on a
                low-end device.
            ]]
            if os.clock() - lastRunAt < 1 then
                return
            end

            lastRunAt = os.clock()

            -- Do the work.
        end)
    end)

    -- The other exit path: the user unloads the hub with the toggle still on.
    ctx.OnStop(stopAutoThing)

    -- A button. DoubleClick = true for anything that teleports or disconnects,
    -- so a stray click cannot move the player.
    main:AddButton({
        Text = "Do Something",
        Tooltip = "What it does.",
        Func = function()
            notify("Done.", 3)
        end,
    })

    -- A dropdown. Get its value later with ctx.Options["yourgame.mode"].Value
    main:AddDropdown("yourgame.mode", {
        Text = "Mode",
        Values = { "Safe", "Fast", "Silent" },
        Default = "Safe",
        Multi = false,
    })

    -- A right-hand column, for a second groupbox.
    local extra = tab:AddGroupbox({ Side = "Right", Name = "Extra" })

    extra:AddLabel("Labels support rich text.")

    extra:AddDivider()

    extra:AddInput("yourgame.webhook", {
        Text = "Webhook URL",
        Default = "",
        Placeholder = "https://discord.com/api/webhooks/...",
    })
end
