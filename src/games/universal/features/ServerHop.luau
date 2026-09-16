--[[
    games/universal/features/ServerHop.luau

    Moves the player to a different server of the same place.

    Uses the public servers endpoint rather than the deprecated
    GetCurrentServer / player-list tricks, because those stopped working and
    the endpoint is the supported route. Picks the emptiest joinable server, on
    the theory that a quiet server is what you want when hopping — if you want
    the busiest, change the sort in pickServer.

    Note the endpoint is rate limited per IP and returns an empty list when it
    trips, which is indistinguishable from "no servers available". Both cases
    report the same thing rather than pretending to know the difference.
]]

local Action = require("core/Action")

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local SERVERS_URL = "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"

local ServerHop = Action.new({
    Id = "universal.serverHop",
    Name = "Server Hop",
    Description = "Move to a different server of this game.",
    Tooltip = "Picks the least populated joinable server.",
    Confirm = true,
    Group = "Server",
    Side = "Left",
})

-- Returns the chosen server id, or nil plus a reason.
function ServerHop:pickServer(): (string?, string?)
    local url = string.format(SERVERS_URL, game.PlaceId)
    local ok, payload = self._ctx.http:GetJson(url, false)

    if not ok then
        return nil, `could not list servers: {tostring(payload)}`
    end

    if type(payload) ~= "table" or type(payload.data) ~= "table" then
        return nil, "unexpected response from the servers endpoint"
    end

    local best: any = nil

    for _, server in payload.data do
        local joinable = type(server.playing) == "number"
            and type(server.maxPlayers) == "number"
            and server.playing < server.maxPlayers
            and server.id ~= game.JobId

        if joinable then
            if best == nil or server.playing < best.playing then
                best = server
            end
        end
    end

    if best == nil then
        return nil, "no joinable servers found"
    end

    return best.id, nil
end

function ServerHop:OnClick()
    local ctx = self._ctx
    local player = Players.LocalPlayer

    if player == nil then
        return
    end

    local serverId, reason = self:pickServer()

    if serverId == nil then
        self._log:Warn(reason or "no server found")

        ctx.ui:Notify({
            Title = "Abyssal",
            Text = "No joinable server found. Try again shortly.",
            Duration = 5,
        })

        return
    end

    ctx.ui:Notify({
        Title = "Abyssal",
        Text = "Hopping to another server...",
        Duration = 3,
    })

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, player)
    end)

    if not ok then
        self._log:Error(`hop failed: {tostring(err)}`)

        ctx.ui:Notify({
            Title = "Abyssal",
            Text = "Server hop failed.",
            Duration = 5,
        })
    end
end

return ServerHop
