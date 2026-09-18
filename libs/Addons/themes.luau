local Themes = {}

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

    ["Abyssal"] = Themes.Base,

    ["Abyssal Light"] = {
        BackgroundColor = "eef1f5",
        MainColor = "ffffff",
        AccentColor = "0f766e",
        OutlineColor = "d5dbe4",
        FontColor = "111827",
        IsLight = true,
    },

    ["Midnight"] = {
        BackgroundColor = "0d0d10",
        MainColor = "17171c",
        AccentColor = "7c8cff",
        OutlineColor = "2a2a33",
        FontColor = "e8e8ee",
    },
}

local current: string? = nil

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

function Themes.Names(): { string }
    local names = {}

    for name in Themes.BuiltIn do
        table.insert(names, name)
    end

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

function Themes.Current(): string?
    return current
end

return Themes
