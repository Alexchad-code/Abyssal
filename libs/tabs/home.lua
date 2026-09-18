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

        local watermark = type(config.Watermark) == "table" and config.Watermark or {}

        local function notify(text: string, duration: number?)
            library:Notify({
                Title = "Abyssal",
                Text = text,
                Duration = duration or 4,
            })
        end

        local playerBox = tab:AddGroupbox({ Side = "Left", Name = "Player" })

        local avatar = playerBox:AddImage("home.avatar", {
            Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=420&h=420`,
            Height = 160,
            ScaleType = Enum.ScaleType.Fit,
        })

        -- Obsidian builds an image as Holder > Box > ImageLabel. The box is a
        -- bordered rectangle, so it has to be cleared for a circular avatar.
        pcall(function()
            local box = avatar.Holder:FindFirstChildOfClass("Frame")

            if box == nil then
                return
            end

            box.BackgroundTransparency = 1
            box.BorderSizePixel = 0

            local imageLabel = box:FindFirstChildOfClass("ImageLabel")

            if imageLabel == nil then
                return
            end

            imageLabel.ScaleType = Enum.ScaleType.Crop

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = imageLabel
        end)

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

        local general = tab:AddGroupbox({ Side = "Left", Name = "General" })

        general:AddToggle("home.watermark", {
            Text = "Watermark",
            Tooltip = "Shows the Abyssal watermark in the top left.",
            Default = watermark.Enabled == true,
        })

        general:AddInput("home.watermarkText", {
            Text = "Watermark label",
            Default = watermark.Text or "Abyssal",
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
                    ctx.Warn(`server list: {httpErr}`)
                    notify("Could not list servers.", 5)
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
                    notify("No joinable server found.", 5)
                    return
                end

                notify("Hopping...", 3)

                local hopped, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, player)
                end)

                if not hopped then
                    ctx.Warn(`hop: {tostring(err)}`)
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

                notify("Rejoining...", 3)

                local ok, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
                end)

                if not ok then
                    ctx.Warn(`rejoin: {tostring(err)}`)
                    notify("Rejoin failed.", 5)
                end
            end,
        })

        local gui: ScreenGui? = nil
        local textLabel: TextLabel? = nil
        local textLoop: RBXScriptConnection? = nil
        local fpsCounter: RBXScriptConnection? = nil
        local lastTextUpdate = 0
        local frames, fps, fpsWindowStart = 0, 0, os.clock()

        local textSize = tonumber(watermark.TextSize) or 14

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

            local position = watermark.Position
            local x = type(position) == "table" and tonumber(position[1]) or 10
            local y = type(position) == "table" and tonumber(position[2]) or 10

            local screen = Instance.new("ScreenGui")
            screen.Name = "AbyssalWatermark"
            screen.ResetOnSpawn = false
            screen.IgnoreGuiInset = true
            screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            screen.Parent = guiParent()

            local label = Instance.new("TextLabel")
            label.Name = "Label"
            label.BackgroundColor3 = library.Scheme.BackgroundColor
            label.BackgroundTransparency = tonumber(watermark.Transparency) or 0.25
            label.BorderSizePixel = 0
            label.TextColor3 = library.Scheme.FontColor
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Font = Enum.Font.Code
            label.TextSize = textSize
            label.Size = UDim2.new(0, 280, 0, textSize + 10)
            label.Position = UDim2.fromOffset(x, y)
            label.Text = watermarkText()
            label.Parent = screen

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = label

            local padding = Instance.new("UIPadding")
            padding.PaddingLeft = UDim.new(0, 6)
            padding.PaddingRight = UDim.new(0, 6)
            padding.Parent = label

            gui = screen
            textLabel = label

            fpsCounter = RunService.RenderStepped:Connect(countFrame)

            textLoop = RunService.Heartbeat:Connect(function()
                if textLabel == nil then
                    return
                end

                local now = os.clock()

                if now - lastTextUpdate < 0.25 then
                    return
                end

                lastTextUpdate = now
                textLabel.Text = watermarkText()
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

            textLabel = nil
        end

        ctx.Toggles["home.watermark"]:OnChanged(function(enabled: boolean)
            stopWatermark()

            if enabled then
                startWatermark()
            end
        end)

        ctx.OnStop(stopWatermark)

        if watermark.Enabled == true then
            startWatermark()
        end
    end,
}
