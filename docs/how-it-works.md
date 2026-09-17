# How it works

What happens between executing Abyssal and the window appearing.

## The sequence

```
  you execute main.lua
        │
        ├─ 1. fetch libs/obsidian/Library.lua, compile it, call it
        │     → the Obsidian library object
        │
        ├─ 2. fetch the two addons: ThemeManager, SaveManager
        │     (a failure here is reported but not fatal — you lose themes or
        │      config, not the whole hub)
        │
        ├─ 3. create the window
        │
        ├─ 4. register the Abyssal theme, then apply it
        │
        ├─ 5. look up game.PlaceId in the GAMES table
        │     → universal.lua, plus your-game.lua if there is a match
        │
        ├─ 6. fetch and run each script, handing it ctx
        │
        ├─ 7. build the shared Settings tab
        │
        └─ 8. show a notification saying how many scripts loaded
```

Everything is fetched from `raw.githubusercontent.com` at run time. Nothing is
pre-compiled, which is why pushing to `main` is the release process.

## Why fetch instead of bundle

The alternative is concatenating everything into one file. That has real
advantages — nothing to fetch means a dead CDN cannot take the UI down, and the
library version you run is fixed.

It was rejected because it costs a build step before every release, and because
the whole point of this repo is that a game script is one readable file you can
edit and push. If the UI ever starts failing to load, the fix is to move
`libs/obsidian` into the main script — the rest of the design does not change.

## The context object

Game scripts never reach for globals. They receive one table, built in
`main.lua`:

```
ctx = {
    Library, SaveManager, ThemeManager,   -- the UI stack
    Options, Toggles,                     -- shortcuts into the library
    Window,                               -- for AddTab
    PlaceId, JobId,                       -- where we are
    Log, Debug, Warn,                     -- prefixed console output
    Fetch, Http, LoadFile,                -- getting things
    OnStop, Track,                        -- teardown
}
```

The point is that a script's dependencies are visible in one place. It also
means the teardown registry is shared, so unloading stops everything rather than
whatever the script remembered to handle.

`Fetch` is relative to this repo; `Http` takes an absolute URL. Conflating them
produces a URL like `https://raw.githubusercontent.com/.../https://games.roblox.com/...`,
which is why they are two functions.

## Teardown

`main.lua` keeps a list of stop callbacks. On unload it runs them in **reverse
order** — last registered, first stopped — then unloads the library.

There are two ways a feature gets switched off, and both have to lead to the
same cleanup:

1. **The user toggles it off.** `OnChanged` fires; the script disconnects.
2. **The user unloads the hub.** `OnChanged` never fires. The stop callback
   registered with `ctx.OnStop` handles it.

A script that only handles the first case leaves its loop running after the UI
is gone. That is the most common bug in a hub, and it is why the template spells
the pattern out.

## When no script matches

If `game.PlaceId` is not in `GAMES`, only `universal.lua` runs. The hub opens
with rejoin, server hop and the rest, plus a notification naming the place.

This is deliberate. An empty window reads as broken; a working window with
utilities reads as "this game is not supported yet", which is what is actually
true.

## Theme

The Abyssal palette is registered into `ThemeManager.BuiltInThemes` at index
100, above the built-ins (1–18), so it sorts last in the picker rather than
displacing anything. It is applied on boot but the user can switch away from it
and switch back.

To retune it, edit `THEME_PALETTE` in `main.lua`. Check the accent against the
main colour with ThemeManager's own contrast report rather than by eye —
`ThemeManager:GetContrastReport()`.

## Config

Saved configs go under `Abyssal/Place_<placeId>/`. They are namespaced per place
because option ids differ between game scripts, and loading one game's config in
another would silently apply unrelated values.

This is also why option ids must be prefixed with the game. See
[adding-a-game.md](adding-a-game.md).
