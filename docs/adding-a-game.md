# Adding a game

## 1. Find the place ID

It is the number in the Roblox URL:

```
https://www.roblox.com/games/2753915549/Blox-Fruits
                              ^^^^^^^^^^
```

Or from the executor console: `print(game.PlaceId)`.

**List every place the script should cover.** Lobby and main game are usually
different IDs. A script that only lists one will load in the lobby and silently
do nothing in the actual game, which looks like a bug and is not one.

## 2. Copy the template

```bash
cp games/_template.lua games/your-game.lua
```

The filename is the script's name. Keep it lowercase and hyphenated.

## 3. Write it

A game script is a function. `main.lua` calls it with the shared context:

```lua
return function(ctx)
    local tab = ctx.Window:AddTab("Your Game", "gamepad-2")
    local main = tab:AddGroupbox({ Side = "Left", Name = "Main" })

    main:AddToggle("yourgame.autoSell", {
        Text = "Auto Sell",
        Default = false,
    }):OnChanged(function(enabled)
        -- do something
    end)
end
```

`games/_template.lua` is commented throughout and covers toggles, sliders,
dropdowns, buttons, inputs, resolving game objects, and the cleanup pattern.
Read it — it is the actual reference, not this page.

`ctx` is documented in [AGENTS.md](../AGENTS.md).

## 4. Register it

Open `main.lua` and add a line to the `GAMES` table:

```lua
local GAMES = {
    [2753915549] = "blox-fruits",
}
```

The value is the filename in `games/` without the `.lua`.

## 5. Push

```bash
git add games/your-game.lua main.lua
git commit -m "Add Blox Fruits script"
git push
```

There is no build step. The next person to run Abyssal gets the new script.

## Things that will bite you

**Option ids are global.** `Library.Options` is one flat table shared by every
script. Prefix with the game — `yourgame.autoSell`, not `autoSell`. Two scripts
using the same id means two widgets fighting over one stored value, and the
symptom looks like a random reset, not a collision.

**Toggling on/off/on can leave two loops running.** `OnChanged` fires every
time. If it starts something, it must stop the previous instance first:

```lua
toggle:OnChanged(function(enabled)
    stop()                          -- always, first
    if enabled then start() end
end)
```

**Unloading the hub is a second exit.** If the user unloads while your toggle is
on, `OnChanged` never fires. Register the same cleanup with `ctx.OnStop(stop)`.

**Do not put `Callback` in the widget table.** Create the widget, then call
`:OnChanged`. Obsidian's docs recommend this, and it stops a config load from
firing your callback while the UI is still being built.

**Throttle anything per-frame.** `Heartbeat` runs at frame rate. A naive loop
costs more on a low-end device than most features are worth.

## Testing

You cannot run this outside Roblox. Syntax-check at least:

```bash
luau-compile --null games/your-game.lua
```

Then load it in the actual game and click every widget you added. There is no
substitute — the failure modes that matter here (a loop that will not stop, a
remote that moved) only appear at run time.
