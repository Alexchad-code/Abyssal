--[[
    games/universal/features/RejoinServer.luau

    Teleports the player back into the server they are already in.

    This is a reconnect, not a hop: it reuses the current JobId, so you land in
    the same server rather than a fresh one. It only works while that server is
    still alive, which is why failure is reported rather than swallowed — a
    dead JobId produces an error from the teleport service and the player would
    otherwise be left guessing.
]]

local Action = require("core/Action")

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local RejoinServer = Action.new({
    Id = "universal.rejoinServer",
    Name = "Rejoin Server",
    Description = "Reconnect to this exact server.",
    Tooltip = "Returns you to the same server. Fails if the server has shut down.",
    Confirm = true,
    Group = "Server",
    Side = "Left",
})

function RejoinServer:OnClick()
    local ctx = self._ctx
    local player = Players.LocalPlayer

    if player == nil then
        return
    end

    local placeId = game.PlaceId
    local jobId = game.JobId

    if jobId == nil or jobId == "" then
        ctx.ui:Notify({
            Title = "Abyssal",
            Text = "Cannot rejoin: JobId is unavailable.",
            Duration = 4,
        })

        return
    end

    ctx.ui:Notify({
        Title = "Abyssal",
        Text = "Rejoining this server...",
        Duration = 3,
    })

    -- TeleportToPlaceInstance yields and throws on a dead instance.
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
    end)

    if not ok then
        self._log:Error(`rejoin failed: {tostring(err)}`)

        ctx.ui:Notify({
            Title = "Abyssal",
            Text = "Rejoin failed. The server may have closed.",
            Duration = 5,
        })
    end
end

return RejoinServer
