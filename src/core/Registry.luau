--[[
    core/Registry.luau

    Holds every known game module and decides which ones apply to the current
    server.

    Resolution loads ALL matching modules, not just the best one. That is the
    point of the design: a game-specific module and the universal module both
    load, so shared features (rejoin, server hop, UI settings) are available
    regardless of which game you are in. Priority only decides ordering, and
    therefore which module gets the first tab.
]]

local GameDetector = require("core/GameDetector")

local Registry = {}
Registry.__index = Registry

export type Registry = typeof(setmetatable(
    {} :: {
        _modules: { any },
        _byId: { [string]: any },
    },
    Registry
))

function Registry.new(): Registry
    return setmetatable({
        _modules = {},
        _byId = {},
    }, Registry)
end

function Registry:Register(module: any): any
    assert(module ~= nil, "Registry:Register expects a module")
    assert(type(module.Id) == "string", "module is missing an Id")

    if self._byId[module.Id] ~= nil then
        error(`module "{module.Id}" is already registered`)
    end

    table.insert(self._modules, module)
    self._byId[module.Id] = module

    return module
end

function Registry:Get(id: string): any?
    return self._byId[id]
end

function Registry:GetAll(): { any }
    return self._modules
end

-- Modules whose declared place IDs include the current place, highest priority
-- first. A module with no PlaceIds applies everywhere.
function Registry:ResolveApplicable(): { any }
    local matched: { any } = {}

    for _, module in self._modules do
        if GameDetector.Matches(module.PlaceIds) then
            table.insert(matched, module)
        end
    end

    table.sort(matched, function(left, right)
        if left.Priority == right.Priority then
            -- Stable tiebreak so ordering does not depend on registration order.
            return left.Id < right.Id
        end

        return left.Priority > right.Priority
    end)

    return matched
end

-- Every registered module, regardless of whether it applies here. Used by the
-- UI to report unsupported games rather than silently showing nothing.
function Registry:GetUnmatched(): { any }
    local unmatched: { any } = {}

    for _, module in self._modules do
        if not GameDetector.Matches(module.PlaceIds) then
            table.insert(unmatched, module)
        end
    end

    return unmatched
end

return Registry
