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
    -- ─── where this runs ──────────────────────────────────────────────────

    --[[
        The universe id — the game itself.

        Every place in a game shares one universe, so this single number covers
        all of them: lobby, main game, sub-places. Get it from game.GameId in
        the executor console.

        Usually the only one of these two you need to set.
    ]]
    GameId = 0,

    --[[
        Specific places, if you want only some of the universe.

        The number in the Roblox URL, or game.PlaceId. Use it when a game has
        places you do not want the script to load in.

        GameId and Places are a union — declaring either is enough to match.

        Only removing BOTH fields entirely means "load everywhere". A field
        that is present but wrong does not fall through to that, so a typo
        cannot make this load in every game. 0 is the "not set" placeholder,
        which is why the template matches nothing until you change one of them.
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
        This game's own tabs, in the order they appear.

        Home and UI Settings are NOT listed here. They are shared — built from
        libs/tabs for every game, so a fix to one lands everywhere at once.
        They always come first; whatever is listed here follows them.

        Each name is a file in this folder's tabs/ directory. To add a tab,
        drop a file there and add its name here.
    ]]
    Tabs = {
        -- "auto-farm",
        -- "misc",
    },
}
