--[[
    games/template/main.lua

    A game's entry point. The root loader picks the game by place id, hands it
    the shared context, and this runs.

    What it does, in order:

        1. read config.lua
        2. apply the configured theme, before anything is drawn
        3. create the window
        4. build the shared tabs from libs/tabs
        5. build this game's tabs from tabs/
        6. set up config persistence, shared by every tab

    ─── Two kinds of tab ─────────────────────────────────────────────────────

    Shared tabs — Home and UI Settings — live in libs/tabs and are built by
    every game. They are identical everywhere, so one fix reaches all games
    instead of needing an edit in each. The list is on ctx.SharedTabs, for the
    same reason.

    A game's own tabs live in this folder's tabs/ and are the only ones it
    lists in config.Tabs.

    Either way, a tab is a file returning:

        return {
            Name = "Home",          -- tab label
            Icon = "house",         -- lucide icon, optional
            Build = function(ctx, config, tab) ... end,
        }

    That is the whole interface. Tabs never reach for globals — everything
    comes through ctx, and anything they start they register with ctx.OnStop.

    ─── Adding a game ────────────────────────────────────────────────────────

        cp -r games/template games/your-game
        -- edit config.lua (places, title)
        -- add your own tabs in tabs/
        -- register the folder in the loader's manifest

    You should not need to touch the shared tabs, and should not copy them.

    ─── What this needs from ctx ─────────────────────────────────────────────

        ctx.Library     the Obsidian library object
        ctx.LoadFile(path)  fetch and run a Lua file from this repo
        ctx.Log / Warn
        ctx.OnStop(fn)
        ctx.Version     the hub version string, for the default footer
        ctx.GameFolder  this game's folder, e.g. "games/your-game"
        ctx.SharedTabs  names of the shared tabs in libs/tabs

    It adds two fields for the tabs to use:

        ctx.Window      the window it created
        ctx.Configs     a configs.luau instance, already pointed at this place
]]

return function(ctx)
    --[[
        The folder this game lives in.

        Prefer ctx.GameFolder, which the loader sets when it picks the game.
        The literal fallback is only for running this file directly, and is the
        one line to change if you copy the folder and the loader does not set it.
    ]]
    local FOLDER = ctx.GameFolder or "games/template"

    -- ── 1. config ─────────────────────────────────────────────────────────

    local config, configErr = ctx.LoadFile(`{FOLDER}/config.lua`)

    if config == nil then
        -- Not fatal. Every field below has a default, so a missing or broken
        -- config gives you a working hub rather than a blank screen — which
        -- matters, because the config is the file most likely to be mid-edit.
        ctx.Warn(`could not load config: {configErr}`)
        config = {}
    end

    -- ── 2. theme ──────────────────────────────────────────────────────────

    -- Applied before the window exists so nothing is drawn in the wrong
    -- colours and then repainted.
    if config.Theme ~= nil then
        local Themes = ctx.LoadFile("libs/Addons/themes.luau")

        if Themes == nil then
            ctx.Warn("themes.luau did not load; keeping the default colours")
        else
            local ok, err = Themes.Apply(ctx.Library, config.Theme)

            if not ok then
                ctx.Warn(`theme not applied: {err}`)
            end
        end
    end

    -- ── 3. window ─────────────────────────────────────────────────────────

    local window = ctx.Library:CreateWindow({
        Title = config.Title or "Abyssal",
        Footer = config.Footer or ctx.Version or "",
        Icon = config.Icon or "waves",
        NotifySide = "Right",
        ShowCustomCursor = true,
    })

    ctx.Window = window

    -- ── 4. tabs ───────────────────────────────────────────────────────────

    --[[
        Tabs come from two places.

        Shared tabs live in libs/tabs and are identical in every game, so a fix
        to the Home tab lands everywhere at once instead of needing an edit in
        each game. The list of them comes from ctx for the same reason — one
        copy, not one per game.

        A game's own tabs live in this folder's tabs/ and are the only ones it
        declares in config.Tabs.
    ]]
    local built, attempted = 0, 0

    local function buildTabs(source: string, names: { string })
        for _, name in names do
            attempted += 1

            local definition, err = ctx.LoadFile(`{source}/{name}.lua`)

            if definition == nil then
                ctx.Warn(`tab "{name}" from {source}: {err}`)
            elseif type(definition) ~= "table" or type(definition.Build) ~= "function" then
                ctx.Warn(`tab "{name}" must return a table with a Build function`)
            else
                -- One bad tab must not take the rest of the UI with it, so each
                -- is built inside its own pcall.
                local ok, tabErr = pcall(function()
                    local tab = window:AddTab(definition.Name or name, definition.Icon)
                    definition.Build(ctx, config, tab)
                end)

                if ok then
                    built += 1
                else
                    ctx.Warn(`tab "{name}" failed to build: {tostring(tabErr)}`)
                end
            end
        end
    end

    -- Shared first, so Home and UI Settings are always at the front and a
    -- game's own tabs follow.
    buildTabs("libs/tabs", ctx.SharedTabs or {})
    buildTabs(`{FOLDER}/tabs`, config.Tabs or {})

    -- ── 5. config persistence ─────────────────────────────────────────────

    -- Created here rather than inside the UI Settings tab so any tab can save
    -- and load, not just the one that happens to own the buttons.
    local Configs = ctx.LoadFile("libs/Addons/configs.luau")

    if Configs ~= nil then
        ctx.Configs = Configs.new({
            Folder = "Abyssal",
            Game = tostring(game.PlaceId),
            Library = ctx.Library,
        })

        local available, reason = ctx.Configs:Available()

        if not available then
            -- Worth saying out loud at boot: the alternative is a save button
            -- that silently does nothing.
            ctx.Warn(`configs unavailable: {reason}`)
        end
    end

    ctx.Log(`{built}/{attempted} tab(s) built`)

    return {
        Folder = FOLDER,
        Config = config,
        Window = window,
    }
end
