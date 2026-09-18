--[[
    libs/theme.lua

    Abyssal's colour scheme, registered as a normal Obsidian theme so it appears
    in the theme picker alongside the built-ins and users can switch away from
    it without losing it.

    ─── The palette ──────────────────────────────────────────────────────────

    Deep water with a single bioluminescent accent, rather than neon. Two
    constraints shaped it:

      * AccentColor has to stay legible on MainColor. ThemeManager ships a
        contrast checker (GetContrastReport) and will warn on a poor pair — if
        you retune the accent, check it there rather than by eye.
      * BackgroundColor is deliberately darker than MainColor by enough to read
        as a distinct surface. Too close and the window loses its edges.

    The sort index sits above the built-ins (1-18) so Abyssal sorts last in the
    picker instead of displacing anything.

    ─── Per-game overrides ───────────────────────────────────────────────────

    A game can shift its own accent without leaving the theme:

        local theme = Theme.Variant("Abyssal - Blox Fruits", { AccentColor = "f5a623" })
        theme:Register(ThemeManager)

    Use sparingly. A hub where every game has its own colour reads as broken
    rather than customised.
]]

local Theme = {}

Theme.Name = "Abyssal"

-- Above the built-ins so it sorts last.
Theme.SortIndex = 100

Theme.Palette = {
    FontColor = "e6edf3",
    MainColor = "111827",
    BackgroundColor = "0a0f1a",
    OutlineColor = "1f2a3c",
    AccentColor = "2dd4bf",
    BackgroundImage = "",
}

-- Fields ThemeManager expects. Anything missing would be nil in the theme
-- table, which it does not check for.
local REQUIRED = {
    "FontColor",
    "MainColor",
    "BackgroundColor",
    "OutlineColor",
    "AccentColor",
    "BackgroundImage",
}

local function merged(overrides: { [string]: string }?): { [string]: string }
    local palette = {}

    for _, field in REQUIRED do
        palette[field] = Theme.Palette[field]
    end

    if overrides ~= nil then
        for field, value in overrides do
            assert(
                table.find(REQUIRED, field) ~= nil,
                `unknown theme field "{field}"`
            )

            palette[field] = value
        end
    end

    return palette
end

--[[
    Registers the theme. Idempotent, which matters because themes can be
    re-registered on a config reload.

    Returns the sort index it claimed, so a variant can offset from it.
]]
function Theme.Register(themeManager: any, overrides: { [string]: string }?, index: number?): number
    assert(themeManager ~= nil, "Theme.Register expects a ThemeManager")

    local sortIndex = index or Theme.SortIndex

    themeManager.BuiltInThemes[Theme.Name] = {
        sortIndex,
        merged(overrides),
    }

    return sortIndex
end

--[[
    Registers and applies.

    Returns false plus a reason if the library rejected the theme, so a bad
    palette fails loudly at boot rather than silently leaving the default
    colours on screen and looking like the theme code never ran.
]]
function Theme.Apply(themeManager: any, overrides: { [string]: string }?): (boolean, string?)
    Theme.Register(themeManager, overrides)

    local ok, err = themeManager:ApplyTheme(Theme.Name)

    if ok == false then
        return false, err
    end

    return true, nil
end

--[[
    A named variant with its own accent. Registered under its own name, so a
    user who dislikes it can pick the base theme instead.

    This is a proper object rather than a bare table of functions, because a
    bare table invites `variant:Register(tm)` — which silently passes the
    variant as the ThemeManager and the ThemeManager as the index. Methods that
    take self make that call do the right thing.

    The sort index is offset by a hash of the name so variants do not fight
    over the same slot and the picker order stays stable between runs.
]]
local Variant = {}
Variant.__index = Variant

export type Variant = typeof(setmetatable(
    {} :: {
        Name: string,
        Palette: { [string]: string },
        _offset: number,
    },
    Variant
))

function Variant:Register(themeManager: any, index: number?): number
    assert(themeManager ~= nil, "Variant:Register expects a ThemeManager")
    assert(
        type(themeManager) == "table" and themeManager.BuiltInThemes ~= nil,
        "Variant:Register got something that is not a ThemeManager"
    )

    local sortIndex = index or (Theme.SortIndex + 1 + self._offset)

    themeManager.BuiltInThemes[self.Name] = { sortIndex, self.Palette }

    return sortIndex
end

function Variant:Apply(themeManager: any): (boolean, string?)
    self:Register(themeManager)

    local ok, err = themeManager:ApplyTheme(self.Name)

    if ok == false then
        return false, err
    end

    return true, nil
end

function Theme.Variant(name: string, overrides: { [string]: string }?): Variant
    assert(type(name) == "string" and name ~= "", "Variant needs a name")

    -- Simple stable offset. Not a real hash — it only needs to be consistent
    -- between runs so the picker order does not shuffle.
    local offset = 0

    for index = 1, #name do
        offset = (offset + name:byte(index)) % 500
    end

    return setmetatable({
        Name = name,
        Palette = merged(overrides),
        _offset = offset,
    }, Variant)
end

return Theme
