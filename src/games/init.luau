--[[
    games/init.luau

    The module manifest. Every game module must be listed here.

    This is explicit rather than discovered on purpose. The bundler resolves
    requires statically, so a module that nothing references is not in the
    build — an auto-discovered directory would appear to work in source and
    then vanish from the bundle. One line here per game is the cost of that
    being obvious.

    The _template directory is deliberately absent. It is reference source, not
    a module; listing it would load it into every game.
]]

return {
    require("games/universal/init"),

    -- Add game modules here, highest priority first is not required —
    -- Registry sorts by each module's Priority.
    --
    -- require("games/your-game/init"),
}
