--[[
    games/universal/init.luau

    The universal module: features that work in any game, loaded alongside
    whichever game-specific module matches.

    It declares no PlaceIds, which is how the Registry reads "applies
    everywhere", and it sits at a negative priority so a game module always
    gets the first tab. Universal is the fallback, not the headline.

    Widgets are built at module scope and shared, because a module is required
    once and cached — the same instances are handed to Mount, which is what
    lets config find them by id later.
]]

local Module = require("core/Module")

local ConnectionWatchdog = require("games/universal/features/ConnectionWatchdog")
local CopyJobId = require("games/universal/features/CopyJobId")
local RejoinServer = require("games/universal/features/RejoinServer")
local ServerHop = require("games/universal/features/ServerHop")

local Universal = Module.new({
    Id = "universal",
    Name = "Universal",
    Description = "Features that work in any game.",
    Icon = "globe",
    Priority = -100,
})

-- Actions render in the order added.
Universal:AddAction(CopyJobId)
Universal:AddAction(RejoinServer)
Universal:AddAction(ServerHop)

Universal:AddFeature(ConnectionWatchdog)

return Universal
