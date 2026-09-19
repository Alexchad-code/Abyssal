local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

return {
    Name = "Utilities",
    Icon = "wrench",

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

        local serverBox = tab:AddGroupbox({ Side = "Left", Name = "Server" })

        serverBox:AddLabel(`Job ID     {game.JobId ~= "" and game.JobId or "unavailable"}`)
        serverBox:AddLabel(`Place ID   {game.PlaceId}`)
        serverBox:AddLabel(`Game ID    {game.GameId}`)

        serverBox:AddButton({
            Text = "Copy Job ID",
            Tooltip = "JobId identifies this exact server.",
            Func = function()
                if game.JobId == nil or game.JobId == "" then
                    notify("JobId is unavailable in this server.")
                    return
                end

                local ok = pcall(function()
                    setclipboard(game.JobId)
                end)

                notify(ok and `Copied {game.JobId}` or "Clipboard is unavailable.", 5)
            end,
        })

        local clientBox = tab:AddGroupbox({ Side = "Left", Name = "Client" })

        local fpsLabel = clientBox:AddLabel("FPS        --")
        local pingLabel = clientBox:AddLabel("Ping       --")

        local frames, fps, fpsWindowStart = 0, 0, os.clock()
        local lastUpdate = 0

        local function countFrame()
            frames += 1

            local now = os.clock()

            if now - fpsWindowStart >= 1 then
                fps = frames
                frames = 0
                fpsWindowStart = now
            end
        end

        local fpsConnection = RunService.RenderStepped:Connect(countFrame)

        local updateConnection = RunService.Heartbeat:Connect(function()
            local now = os.clock()

            if now - lastUpdate < 0.5 then
                return
            end

            lastUpdate = now

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

            pcall(function()
                fpsLabel:SetText(`FPS        {fps}`)
                pingLabel:SetText(`Ping       {ping}ms`)
            end)
        end)

        ctx.OnStop(function()
            fpsConnection:Disconnect()
            updateConnection:Disconnect()
        end)

        local executorBox = tab:AddGroupbox({ Side = "Right", Name = "Executor" })

        local UNC = ctx.LoadFile("libs/unctest.lua")

        if UNC == nil then
            executorBox:AddLabel("unctest.lua did not load")
        else
            executorBox:AddLabel(`Executor   {UNC.Executor()}`)
            executorBox:AddLabel(`Functions  {UNC.Summary()}`)

            executorBox:AddButton({
                Text = "Print full report",
                Tooltip = "Writes the capability table to the console.",
                Func = function()
                    UNC.Print()
                    notify("Report printed to the console.", 5)
                end,
            })
        end

        local hubBox = tab:AddGroupbox({ Side = "Right", Name = "Hub" })

        hubBox:AddLabel(`Version    {ctx.Version or "?"}`)
        hubBox:AddLabel(`Place      {ctx.PlaceId}`)

        hubBox:AddButton({
            Text = "Unload",
            Tooltip = "Stops everything and closes the window.",
            Risky = true,
            DoubleClick = true,
            Func = function()
                local Abyssal = getgenv().Abyssal

                if Abyssal ~= nil and Abyssal.Unload ~= nil then
                    Abyssal.Unload()
                else
                    library:Unload()
                end
            end,
        })
    end,
}
