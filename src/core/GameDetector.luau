--[[
    core/GameDetector.luau

    Reports facts about the server the hub is running in. It does NOT decide
    which game module to load — that is the Registry's job, using the place IDs
    each module declares.

    Keeping detection dumb means a new game needs no changes here.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local GameDetector = {}

export type ServerInfo = {
    placeId: number,
    gameId: number,
    jobId: string,
    placeName: string?,
    creatorId: number,
    creatorType: Enum.CreatorType,
    isStudio: boolean,
}

local cachedInfo: ServerInfo? = nil

local function fetchPlaceName(placeId: number): string?
    -- GetProductInfo yields and can fail on a bad connection; never let that
    -- stop the hub from loading.
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(placeId, Enum.InfoType.Asset)
    end)

    if ok and type(info) == "table" then
        return info.Name
    end

    return nil
end

function GameDetector.Describe(): ServerInfo
    if cachedInfo then
        return cachedInfo
    end

    local placeId = game.PlaceId

    cachedInfo = {
        placeId = placeId,
        gameId = game.GameId,
        jobId = game.JobId,
        placeName = fetchPlaceName(placeId),
        creatorId = game.CreatorId,
        creatorType = game.CreatorType,
        isStudio = RunService:IsStudio(),
    }

    return cachedInfo
end

function GameDetector.GetPlaceId(): number
    return game.PlaceId
end

-- True when the current place is one of the listed IDs. An empty or nil list
-- means "applies everywhere", which is how universal modules declare themselves.
function GameDetector.Matches(placeIds: { number }?): boolean
    if placeIds == nil or #placeIds == 0 then
        return true
    end

    return table.find(placeIds, game.PlaceId) ~= nil
end

function GameDetector.Invalidate()
    cachedInfo = nil
end

return GameDetector
