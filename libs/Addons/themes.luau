--[[
    libs/Addons/themes.luau

    Themes for the Obsidian library. Replaces Obsidian's ThemeManager.

    How theming actually works in Obsidian: it keeps every coloured property in
    a registry, and each entry names the Scheme key it should follow. So
    applying a theme is two steps — write the new colours into Library.Scheme,
    then call UpdateColorsUsingRegistry() to push them out to the instances.
    That is all ThemeManager was doing on top, plus a picker and a JSON format
    for saved custom themes.

    Colours are written as hex strings because they are easier to read and
    diff than three floats.

    ─── Use ─────────────────────────────────────────────────────────────────

        local Themes = require("libs/Addons/themes")

        Themes.Apply(Library, "Abyssal")

        -- or your own
        Themes.Register("My Game", {
            BackgroundColor = "0b0b0f",
            MainColor = "15151c",
            AccentColor = "f5a623",
            OutlineColor = "26262f",
            FontColor = "eceff4",
        })

    Every field except the four colours is optional — anything you leave out
    falls back to the base palette, so a theme can be a one-line accent change.
]]

local Themes = {}

--[[
    The palette shape.

    Only these keys are read. Obsidian's Scheme has more (RedColor,
    DestructiveColor, DarkColor, WhiteColor, BackgroundImage) — those are left
    alone deliberately, because they are semantic rather than decorative and
    overriding them per theme is how you end up with an unreadable red.
]]
local FIELDS = {
    "BackgroundColor",
    "MainColor",
    "AccentColor",
    "OutlineColor",
    "FontColor",
}

Themes.Base = {
    BackgroundColor = "0a0f1a",
    MainColor = "111827",
    AccentColor = "2dd4bf",
    OutlineColor = "1f2a3c",
    FontColor = "e6edf3",
    IsLight = false,
}

Themes.BuiltIn = {
    -- Deep water with a single bioluminescent accent.
    ["Abyssal"] = Themes.Base,

    -- Same shape, inverted. Proves IsLight is wired up; also just useful.
    ["Abyssal Light"] = {
        BackgroundColor = "eef1f5",
        MainColor = "ffffff",
        AccentColor = "0f766e",
        OutlineColor = "d5dbe4",
        FontColor = "111827",
        IsLight = true,
    },

    -- Neutral, for people who find teal loud.
    ["Midnight"] = {
        BackgroundColor = "0d0d10",
        MainColor = "17171c",
        AccentColor = "7c8cff",
        OutlineColor = "2a2a33",
        FontColor = "e8e8ee",
    },
}

local current: string? = nil

-- ─────────────────────────────────────────────────────────────────── colours

local function hex(value: string): Color3
    assert(
        type(value) == "string" and #value == 6,
        `expected a 6-digit hex colour, got {tostring(value)}`
    )

    local red = tonumber(value:sub(1, 2), 16)
    local green = tonumber(value:sub(3, 4), 16)
    local blue = tonumber(value:sub(5, 6), 16)

    if red == nil or green == nil or blue == nil then
        error(`"{value}" is not valid hex`)
    end

    return Color3.fromRGB(red, green, blue)
end

-- Fills in anything the caller left out, so a theme can be a partial.
local function resolve(palette: { [string]: any }): { [string]: any }
    local full = {}

    for _, field in FIELDS do
        local value = palette[field]

        if value == nil then
            value = Themes.Base[field]
        end

        full[field] = value
    end

    full.IsLight = palette.IsLight == true

    return full
end

-- ──────────────────────────────────────────────────────────────────── public

function Themes.Names(): { string }
    local names = {}

    for name in Themes.BuiltIn do
        table.insert(names, name)
    end

    -- Lua table order is not stable; sort so a picker does not shuffle.
    table.sort(names)

    return names
end

function Themes.Get(name: string): { [string]: any }?
    local palette = Themes.BuiltIn[name]

    if palette == nil then
        return nil
    end

    return resolve(palette)
end

-- Adds or replaces a theme. Idempotent, so re-registering on reload is safe.
function Themes.Register(name: string, palette: { [string]: any })
    assert(type(name) == "string" and name ~= "", "Register needs a name")
    assert(type(palette) == "table", "Register needs a palette table")

    for field in palette do
        if field ~= "IsLight" and table.find(FIELDS, field) == nil then
            error(`unknown theme field "{field}"`)
        end
    end

    Themes.BuiltIn[name] = resolve(palette)
end

--[[
    Applies a theme by name, or a palette table directly.

    Returns false plus a reason rather than throwing, so a bad theme fails at
    the call site with something readable instead of taking the hub down.
]]
function Themes.Apply(library: any, theme: string | { [string]: any }): (boolean, string?)
    if library == nil or library.Scheme == nil then
        return false, "Themes.Apply needs the Obsidian library"
    end

    local palette
    local name

    if type(theme) == "string" then
        name = theme
        palette = Themes.Get(theme)

        if palette == nil then
            return false, `no theme called "{theme}"`
        end
    else
        palette = resolve(theme)
    end

    local scheme = library.Scheme
    local ok, err = pcall(function()
        for _, field in FIELDS do
            scheme[field] = hex(palette[field])
        end
    end)

    if not ok then
        return false, tostring(err)
    end

    -- Drives a few contrast decisions inside the library, so it has to be set
    -- before the registry is flushed rather than after.
    library.IsLightTheme = palette.IsLight == true

    local flushed, flushErr = pcall(function()
        library:UpdateColorsUsingRegistry()
    end)

    if not flushed then
        return false, `could not apply colours: {tostring(flushErr)}`
    end

    current = name

    return true, nil
end

-- The last theme applied by name, or nil if a palette table was passed.
function Themes.Current(): string?
    return current
end

return Themes
