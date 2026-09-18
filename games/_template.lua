--[[
    games/_template.lua

    The starting point for a game. Copy it, rename it, add your tabs at the
    bottom. Everything above the marked line is premade and identical in every
    game — you should not need to touch it.

    ─── What you get for free ────────────────────────────────────────────────

        Home tab
          Player box    avatar headshot (same image the Roblox website uses on
                        a profile) plus display name, username, user id,
                        account age and premium status
          General box   watermark toggle, server hop, rejoin

        UI Settings tab
          theme picker, config save/load/delete

    ─── Adding a game ────────────────────────────────────────────────────────

        cp games/_template.lua games/your-game.lua
        -- edit the header, add tabs at the bottom
        -- register the place id in main.lua

    ─── What ctx must provide ────────────────────────────────────────────────

        ctx.Window      the window, for AddTab
        ctx.Library     the Obsidian library object
        ctx.Options     Library.Options
        ctx.Toggles     Library.Toggles
        ctx.PlaceId     game.PlaceId
        ctx.JobId       game.JobId
        ctx.LoadFile(path)  fetch and run a Lua file from this repo
        ctx.Http(url)       GET an absolute URL
        ctx.Log / Warn
        ctx.OnStop(fn)      teardown, runs in reverse on unload
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")

return function(ctx)
    local library = ctx.Library
    local player = Players.LocalPlayer

    local function notify(text: string, duration: number?)
        library:Notify({
            Title = "Abyssal",
            Text = text,
            Duration = duration or 4,
        })
    end

    --[[
        Where overlay GUIs go.

        gethui() is the executor's protected container and is what you want —
        CoreGui is parented over by Roblox on some games and can be cleared.
        Neither is guaranteed, so this degrades rather than erroring.
    ]]
    local function guiParent(): Instance
        if type(gethui) == "function" then
            local ok, hui = pcall(gethui)

            if ok and hui ~= nil then
                return hui
            end
        end

        return game:GetService("CoreGui")
    end

    -- ══════════════════════════════════════════════════════════════════════
    --  HOME TAB — premade, identical in every game
    -- ══════════════════════════════════════════════════════════════════════

    local home = ctx.Window:AddTab("Home", "house")

    -- ── Player box ────────────────────────────────────────────────────────

    local playerBox = home:AddGroupbox({ Side = "Left", Name = "Player" })

    --[[
        The avatar is the same thumbnail the Roblox website shows on a profile
        or in the friends list: rbxthumb://type=AvatarHeadShot. It renders
        straight into an ImageLabel with no HTTP call, and the library already
        whitelists the rbxthumb scheme.

        Size 420 because that is what the site requests; smaller looks soft on
        a high-DPI screen.
    ]]
    local avatar = playerBox:AddImage("home.avatar", {
        Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=420&h=420`,
        Height = 160,
        ScaleType = Enum.ScaleType.Fit,
    })

    --[[
        Round it off, because the website avatar is circular.

        Obsidian builds an image as Holder > Box > ImageLabel, where the Box is
        a bordered rectangle. Left alone you get a square photo in a box, which
        does not read as a profile picture. So: clear the Box, crop the label to
        a square, and round it with a UICorner at 100%.

        This reaches into the library's internal structure, which is a real
        risk — it is guarded, and if the layout ever changes the avatar simply
        stays square instead of the script erroring.
    ]]
    local function roundAvatar(image: any)
        pcall(function()
            local box = image.Holder:FindFirstChildOfClass("Frame")

            if box == nil then
                return
            end

            box.BackgroundTransparency = 1
            box.BorderSizePixel = 0

            local label = box:FindFirstChildOfClass("ImageLabel")

            if label == nil then
                return
            end

            -- Crop, not Fit: Fit letterboxes, which is wrong for a square
            -- headshot being masked into a circle.
            label.ScaleType = Enum.ScaleType.Crop

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = label
        end)
    end

    roundAvatar(avatar)

    playerBox:AddLabel(`{player.DisplayName}`)
    playerBox:AddLabel(`@{player.Name}`)

    playerBox:AddDivider()

    local function accountAge(): string
        local days = player.AccountAge

        if days >= 365 then
            return `{math.floor(days / 365)}y {(days % 365)}d`
        end

        return `{days}d`
    end

    playerBox:AddLabel(`User ID   {player.UserId}`)
    playerBox:AddLabel(`Account   {accountAge()}`)
    playerBox:AddLabel(`Premium   {player.MembershipType == Enum.MembershipType.Premium and "yes" or "no"}`)

    playerBox:AddButton({
        Text = "Copy User ID",
        Tooltip = "Copies your user id to the clipboard.",
        Func = function()
            local ok = pcall(function()
                setclipboard(tostring(player.UserId))
            end)

            notify(ok and `Copied {player.UserId}` or "Clipboard is unavailable.")
        end,
    })

    -- ── General box ───────────────────────────────────────────────────────

    local general = home:AddGroupbox({ Side = "Left", Name = "General" })

    general:AddToggle("home.watermark", {
        Text = "Watermark",
        Tooltip = "Shows the Abyssal watermark in the top left.",
        Default = false,
    })

    general:AddInput("home.watermarkText", {
        Text = "Watermark label",
        Default = "Abyssal",
        Placeholder = "Abyssal",
    })

    general:AddButton({
        Text = "Server Hop",
        Tooltip = "Moves you to the least populated joinable server.",
        DoubleClick = true,
        Func = function()
            local url = `https://games.roblox.com/v1/games/{game.PlaceId}/servers/Public?sortOrder=Asc&limit=100`
            local body, httpErr = ctx.Http(url)

            if body == nil then
                ctx.Warn(`server list failed: {httpErr}`)
                notify("Could not list servers. Try again shortly.", 5)
                return
            end

            local decoded
            local ok = pcall(function()
                decoded = game:GetService("HttpService"):JSONDecode(body)
            end)

            if not ok or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
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

            local hopped, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, player)
            end)

            if not hopped then
                ctx.Warn(`hop failed: {tostring(err)}`)
                notify("Server hop failed.", 5)
            end
        end,
    })

    general:AddButton({
        Text = "Rejoin Server",
        Tooltip = "Returns you to this same server.",
        DoubleClick = true,
        Func = function()
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

    -- ── Watermark ─────────────────────────────────────────────────────────
    --[[
        A small always-on overlay. Built lazily on first enable and destroyed
        on disable, rather than created up front and hidden — an unused
        ScreenGui still costs a slot in the render pass on a low-end device.

        The loop is throttled to 4 Hz. FPS and ping do not need to be redrawn
        at frame rate, and doing so is the single easiest way to cost more than
        the feature is worth.
    ]]
    local watermarkGui: ScreenGui? = nil
    local watermarkLabel: TextLabel? = nil
    local watermarkLoop: RBXScriptConnection? = nil
    local fpsCounter: RBXScriptConnection? = nil
    local lastTextUpdate = 0

    --[[
        Frames are counted every frame but only read once a second, so the
        figure is a real average rather than an instantaneous reading. Reading
        it per frame gives a number that jitters by 30 either way and tells you
        nothing.
    ]]
    local frames, fps, fpsWindowStart = 0, 0, os.clock()

    local function countFrame()
        frames += 1

        local now = os.clock()

        if now - fpsWindowStart >= 1 then
            fps = frames
            frames = 0
            fpsWindowStart = now
        end
    end

    local function watermarkText(): string
        local option = ctx.Options["home.watermarkText"]
        local label = option ~= nil and option.Value or "Abyssal"

        if type(label) ~= "string" or label == "" then
            label = "Abyssal"
        end

        local ping = 0

        local pingStat = Stats.Network.ServerStatsItem["Data Ping"]

        if pingStat ~= nil then
            local ok, value = pcall(function()
                return pingStat:GetValue()
            end)

            if ok and type(value) == "number" then
                ping = math.floor(value)
            end
        end

        return `{label}  |  {player.Name}  |  {fps}fps  |  {ping}ms`
    end

    local function startWatermark()
        if watermarkGui ~= nil then
            return
        end

        local gui = Instance.new("ScreenGui")
        gui.Name = "AbyssalWatermark"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = guiParent()

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundColor3 = library.Scheme.BackgroundColor
        label.BackgroundTransparency = 0.25
        label.BorderSizePixel = 0
        label.TextColor3 = library.Scheme.FontColor
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.Size = UDim2.new(0, 280, 0, 24)
        label.Position = UDim2.new(0, 10, 0, 10)
        label.Text = watermarkText()
        label.Parent = gui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = label

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 6)
        padding.PaddingRight = UDim.new(0, 6)
        padding.Parent = label

        watermarkGui = gui
        watermarkLabel = label

        fpsCounter = RunService.RenderStepped:Connect(countFrame)

        watermarkLoop = RunService.Heartbeat:Connect(function()
            if watermarkLabel == nil then
                return
            end

            -- 4 Hz is plenty for text nobody reads mid-frame.
            local now = os.clock()

            if now - lastTextUpdate < 0.25 then
                return
            end

            lastTextUpdate = now
            watermarkLabel.Text = watermarkText()
        end)
    end

    local function stopWatermark()
        if watermarkLoop ~= nil then
            watermarkLoop:Disconnect()
            watermarkLoop = nil
        end

        if fpsCounter ~= nil then
            fpsCounter:Disconnect()
            fpsCounter = nil
        end

        if watermarkGui ~= nil then
            watermarkGui:Destroy()
            watermarkGui = nil
        end

        watermarkLabel = nil
    end

    ctx.Toggles["home.watermark"]:OnChanged(function(enabled: boolean)
        stopWatermark()

        if enabled then
            startWatermark()
        end
    end)

    ctx.OnStop(stopWatermark)

    -- ══════════════════════════════════════════════════════════════════════
    --  UI SETTINGS TAB — premade, identical in every game
    -- ══════════════════════════════════════════════════════════════════════

    local settings = ctx.Window:AddTab("UI Settings", "settings")

    local Themes = ctx.LoadFile("libs/Addons/themes.luau")
    local Configs = ctx.LoadFile("libs/Addons/configs.luau")

    if Themes ~= nil then
        local appearance = settings:AddGroupbox({ Side = "Left", Name = "Appearance" })

        appearance:AddDropdown("home.theme", {
            Text = "Theme",
            Values = Themes.Names(),
            Default = "Abyssal",
            Multi = false,
        })

        ctx.Options["home.theme"]:OnChanged(function(name: string)
            local ok, err = Themes.Apply(library, name)

            if not ok then
                notify(`Could not apply that theme: {err}`, 5)
            end
        end)
    end

    if Configs ~= nil then
        local configs = Configs.new({
            Folder = "Abyssal",
            Game = tostring(game.PlaceId),
            Library = library,
        })

        local available, reason = configs:Available()
        local box = settings:AddGroupbox({ Side = "Right", Name = "Configs" })

        if not available then
            -- Better to say why than to show a save button that silently does
            -- nothing, which is what an executor without a filesystem gives you.
            box:AddLabel(`Unavailable: {reason}`)
            box:AddLabel("Run libs/unctest.lua to see what this executor supports.")
        else
            box:AddInput("home.configName", {
                Text = "Config name",
                Default = "default",
                Placeholder = "default",
            })

            box:AddButton({
                Text = "Save",
                Func = function()
                    local name = ctx.Options["home.configName"].Value

                    if type(name) ~= "string" or name == "" then
                        notify("Give the config a name first.")
                        return
                    end

                    local ok, err = configs:Save(name, configs:Snapshot("home."))

                    notify(ok and `Saved "{name}"` or `Could not save: {err}`, 5)
                end,
            })

            box:AddButton({
                Text = "Load",
                DoubleClick = true,
                Func = function()
                    local name = ctx.Options["home.configName"].Value
                    local data, err = configs:Load(name)

                    if data == nil then
                        notify(`Could not load: {err}`, 5)
                        return
                    end

                    configs:Apply("home.", data)
                    notify(`Loaded "{name}"`)
                end,
            })

            box:AddButton({
                Text = "Delete",
                Risky = true,
                DoubleClick = true,
                Func = function()
                    local name = ctx.Options["home.configName"].Value
                    local ok, err = configs:Delete(name)

                    notify(ok and `Deleted "{name}"` or `Could not delete: {err}`, 5)
                end,
            })
        end
    end

    -- ══════════════════════════════════════════════════════════════════════
    --  YOUR GAME STARTS HERE
    --
    --  Everything above is shared. Add your tabs below.
    --
    --  Prefix every option id with the game — "yourgame.autoSell", not
    --  "autoSell". Library.Options is one flat table for the whole hub, so an
    --  unprefixed id collides with another script and the symptom is a
    --  setting that randomly resets rather than an error you can see.
    --
    --  Anything you start must be stoppable. Register teardown with
    --  ctx.OnStop, and stop the previous instance inside OnChanged before
    --  starting a new one — OnChanged fires more than once.
    -- ══════════════════════════════════════════════════════════════════════

    -- local game = ctx.Window:AddTab("Your Game", "gamepad-2")
    -- local main = game:AddGroupbox({ Side = "Left", Name = "Main" })
    --
    -- main:AddToggle("yourgame.autoSell", {
    --     Text = "Auto Sell",
    --     Default = false,
    -- }):OnChanged(function(enabled)
    --     -- do something
    -- end)
    --
    -- ctx.OnStop(function()
    --     -- undo it
    -- end)
end
