--[[
    ui/Theme.luau

    Abyssal's colour scheme, registered as a normal Obsidian theme so it shows
    up in the theme picker alongside the built-ins and users can switch away
    from it without losing it.

    Colours are chosen for a dark UI with a single bioluminescent accent —
    deep water rather than neon. Two constraints shaped the palette:

      * AccentColor must stay legible against MainColor. ThemeManager ships a
        contrast checker (GetContrastReport) and will warn on poor pairs, so
        if you retune the accent, re-check it there rather than by eye.
      * BackgroundColor is darker than MainColor by enough to read as a
        distinct surface. Too close and the window loses its edges.

    The sort index is deliberately above the built-ins (1-18) so Abyssal sorts
    last in the picker instead of displacing anything.
]]

local Theme = {}

Theme.Name = "Abyssal"
Theme.SortIndex = 100

Theme.Palette = {
    FontColor = "e6edf3",
    MainColor = "111827",
    BackgroundColor = "0a0f1a",
    OutlineColor = "1f2a3c",
    AccentColor = "2dd4bf",
    BackgroundImage = "",
}

-- Idempotent: registering twice is harmless, which matters because themes can
-- be re-registered on reload.
function Theme.Register(themeManager: any)
    assert(themeManager ~= nil, "Theme.Register expects a ThemeManager")

    themeManager.BuiltInThemes[Theme.Name] = {
        Theme.SortIndex,
        Theme.Palette,
    }
end

-- Registers and immediately applies. Returns false with a reason if the
-- library rejected the theme, so a bad palette fails loudly at boot rather
-- than silently leaving the default colours on screen.
function Theme.Apply(themeManager: any): (boolean, string?)
    Theme.Register(themeManager)

    local ok, err = themeManager:ApplyTheme(Theme.Name)

    if ok == false then
        return false, err
    end

    return true, nil
end

return Theme
