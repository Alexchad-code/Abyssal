--[[
    games/template/config.lua

    Per-game settings. Every field has a default that works, so a new game only
    overrides what it actually wants to change — a config that is an empty
    table is valid and produces the standard hub.

    This is the first file main.lua reads and the last thing that should need
    editing. If you find yourself adding a field here that only one game uses,
    it belongs in that game's own code instead.
]]

return {
    --[[
        Which places this game covers.

        The number in the Roblox URL, or game.PlaceId from the executor console.
        List every place — lobby and main game are usually different ids, and a
        game that only lists one will load in the lobby and do nothing in the
        actual game.

        Empty means "everywhere", which is how the universal module works. Do
        not leave it empty here unless you mean that.
    ]]
    Places = { 0 },

    -- ─── window ───────────────────────────────────────────────────────────

    Title = "Abyssal",

    -- nil falls back to the hub version. Set it to label a specific build.
    Footer = nil,

    -- Lucide icon name. https://lucide.dev/
    Icon = "waves",

    -- ─── appearance ───────────────────────────────────────────────────────

    --[[
        Applied on startup, before the window is shown.

        Either a name from libs/Addons/themes.luau ("Abyssal", "Abyssal Light",
        "Midnight"), or a palette table to use without registering it:

            Theme = { AccentColor = "f5a623" },

        A partial palette inherits the rest, so an accent-only override is fine.
        nil leaves the library's own default in place.
    ]]
    Theme = "Abyssal",

    -- ─── defaults for the Home tab ────────────────────────────────────────

    Watermark = false,
    WatermarkText = "Abyssal",

    -- ─── tabs ─────────────────────────────────────────────────────────────

    --[[
        Tab order. Each name is a file in this folder's tabs/ directory.

        Every tab is its own script. To add one, drop a file in tabs/ and add
        its name here — nothing else needs changing.
    ]]
    Tabs = {
        "home",
        "ui-settings",
    },
}
