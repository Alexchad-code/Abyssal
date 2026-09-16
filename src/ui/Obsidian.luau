--[[
    ui/Obsidian.luau

    The single place that knows how Obsidian is obtained.

    Obsidian is vendored under vendor/obsidian rather than fetched at runtime.
    That is deliberate: a hub that downloads its UI on every load is one dead
    CDN away from showing nothing, and it leaks the library version you run.
    Vendoring also means the MIT notice travels with the build.

    Because the library is bundled, these requires resolve to in-bundle modules
    at build time. See tools/build.py for the resolution rules.
]]

local Obsidian = {}

export type Bundle = {
    Library: any,
    SaveManager: any,
    ThemeManager: any,
}

local cached: Bundle? = nil

function Obsidian.Load(): Bundle
    if cached then
        return cached
    end

    local Library = require("vendor/obsidian/Library")
    local SaveManager = require("vendor/obsidian/addons/SaveManager")
    local ThemeManager = require("vendor/obsidian/addons/ThemeManager")

    cached = {
        Library = Library,
        SaveManager = SaveManager,
        ThemeManager = ThemeManager,
    }

    return cached
end

return Obsidian
