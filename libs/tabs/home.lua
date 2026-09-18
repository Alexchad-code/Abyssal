--[[
    libs/tabs/home.lua

    The Home tab: who you are, and the utilities every game wants.

    Shared. Built by every game from libs/tabs, not copied into each one — so a
    fix here reaches every game at once instead of needing an edit per game.
    Games should not have their own copy of this file.

    Two boxes:

        Player   avatar headshot, name, id, account age, premium, copy id
        General  watermark, server hop, rejoin

    The avatar is the same thumbnail the Roblox website shows on a profile.
    See the note on roundAvatar for why it is fiddly.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")

return {
    Name = "Home",
    Icon = "house",

    Build = function(ctx, config, tab)
        local library = ctx.Library
        local player = Players.LocalPlayer

        local function notify(text: string, duration: number?)
            library:Notify({
                Title = "Abyssal",
                Text = text,
                Duration = duration or 4,
            })
        end

        -- ── Player box ────────────────────────────────────────────────────

        local playerBox = tab:AddGroupbox({ Side = "Left", Name = "Player" })

        --[[
            rbxthumb://type=AvatarHeadShot is the image the website uses for a
            profile picture or a friends-list entry. It renders straight into an
            ImageLabel with no HTTP call, and the library already whitelists the
            rbxthumb scheme.

            420 is what the site requests. Smaller looks soft on a high-DPI
            screen, and the cost is the same because Roblox caches it.
        ]]
        local avatar = playerBox:AddImage("home.avatar", {
            Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=420&h=420`,
            Height = 160,
            ScaleType = Enum.ScaleType.Fit,
        })

        --[[
            Round the avatar, because a profile picture is circular.

            Obsidian builds an image as Holder > Box > ImageLabel, where Box is
            a bordered rectangle. Left alone you get a square photo in a box,
            which does not read as a profile picture.

            So: clear the Box, crop the label to a square, round it with a
            UICorner at 100%. Crop rather than Fit — Fit letterboxes, which is
            wrong for a square headshot being masked into a circle.

            This reaches into the library's internal layout, which is a real
            fragility. It is guarded, so if that layout ever changes the avatar
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

        local premium = player.MembershipType == Enum.MembershipType.Premium

        playerBox:AddLabel(`Premium   {premium and "yes" or "no"}`)

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

        -- ── General box ───────────────────────────────────────────────────

        local general = tab:AddGroupbox({ Side = "Left", Name = "General" })

        general:AddToggle("home.watermark", {
            Text = "Watermark",
            Tooltip = "Shows the Abyssal watermark in the top left.",
            Default = config.Watermark == true,
        })

        general:AddInput("home.watermarkText", {
            Text = "Watermark label",
            Default = config.WatermarkText or "Abyssal",
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

        -- ── Watermark ─────────────────────────────────────────────────────

        --[[
            Built on first enable and destroyed on disable, rather than created
            up front and hidden — an unused ScreenGui still costs a slot in the
            render pass on a low-end device.

            Two loops: a per-frame frame counter, and a 4 Hz text update. Text
            nobody reads mid-frame does not need redrawing at frame rate, and
            doing so is the easiest way to cost more than the feature is worth.
        ]]
        local gui: ScreenGui? = nil
        local label: TextLabel? = nil
        local textLoop: RBXScriptConnection? = nil
        local fpsCounter: RBXScriptConnection? = nil
        local lastTextUpdate = 0
        local frames, fps, fpsWindowStart = 0, 0, os.clock()

        local function countFrame()
            frames += 1

            local now = os.clock()

            -- Sampled once a second, so the figure is a real average rather
            -- than a per-frame number that jitters by 30 either way.
            if now - fpsWindowStart >= 1 then
                fps = frames
                frames = 0
                fpsWindowStart = now
            end
        end

        local function watermarkText(): string
            local option = ctx.Options["home.watermarkText"]
            local text = option ~= nil and option.Value or "Abyssal"

            if type(text) ~= "string" or text == "" then
                text = "Abyssal"
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

            return `{text}  |  {player.Name}  |  {fps}fps  |  {ping}ms`
        end

        -- gethui() is the executor's protected container and is what you want;
        -- CoreGui can be cleared on some games. Neither is guaranteed.
        local function guiParent(): Instance
            if type(gethui) == "function" then
                local ok, hui = pcall(gethui)

                if ok and hui ~= nil then
                    return hui
                end
            end

            return game:GetService("CoreGui")
        end

        local function startWatermark()
            if gui ~= nil then
                return
            end

            local screen = Instance.new("ScreenGui")
            screen.Name = "AbyssalWatermark"
            screen.ResetOnSpawn = false
            screen.IgnoreGuiInset = true
            screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            screen.Parent = guiParent()

            local textLabel = Instance.new("TextLabel")
            textLabel.Name = "Label"
            textLabel.BackgroundColor3 = library.Scheme.BackgroundColor
            textLabel.BackgroundTransparency = 0.25
            textLabel.BorderSizePixel = 0
            textLabel.TextColor3 = library.Scheme.FontColor
            textLabel.TextXAlignment = Enum.TextXAlignment.Left
            textLabel.Font = Enum.Font.Code
            textLabel.TextSize = 14
            textLabel.Size = UDim2.new(0, 280, 0, 24)
            textLabel.Position = UDim2.new(0, 10, 0, 10)
            textLabel.Text = watermarkText()
            textLabel.Parent = screen

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = textLabel

            local padding = Instance.new("UIPadding")
            padding.PaddingLeft = UDim.new(0, 6)
            padding.PaddingRight = UDim.new(0, 6)
            padding.Parent = textLabel

            gui = screen
            label = textLabel

            fpsCounter = RunService.RenderStepped:Connect(countFrame)

            textLoop = RunService.Heartbeat:Connect(function()
                if label == nil then
                    return
                end

                local now = os.clock()

                if now - lastTextUpdate < 0.25 then
                    return
                end

                lastTextUpdate = now
                label.Text = watermarkText()
            end)
        end

        local function stopWatermark()
            if textLoop ~= nil then
                textLoop:Disconnect()
                textLoop = nil
            end

            if fpsCounter ~= nil then
                fpsCounter:Disconnect()
                fpsCounter = nil
            end

            if gui ~= nil then
                gui:Destroy()
                gui = nil
            end

            label = nil
        end

        ctx.Toggles["home.watermark"]:OnChanged(function(enabled: boolean)
            -- Always stop first: OnChanged fires on every change, so without
            -- this, toggling on/off/on leaves two loops running.
            stopWatermark()

            if enabled then
                startWatermark()
            end
        end)

        -- The other exit: the user unloads the hub with the toggle still on.
        ctx.OnStop(stopWatermark)

        -- A config load sets the toggle without firing OnChanged in some paths,
        -- so honour the default explicitly.
        if config.Watermark == true then
            startWatermark()
        end
    end,
}
