# Abyssal

A multi-game Roblox script hub built on the [Obsidian](https://github.com/deividcomsono/Obsidian) UI library.

One entry script. One folder per game. No build step.

## Using it

Execute `main.lua`:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Alexchad-code/Abyssal/main/main.lua"
))()
```

It loads the UI library, works out which game you are in, and runs the matching
script. Pushing to `main` is the release process — there is nothing to compile.

## Layout

```
main.lua            Entry point. Everything starts here.
libs/
  obsidian/         The UI library. Third-party, MIT. Do not edit.
assets/
  obsidian/         Icons and textures, grouped by what uses them.
games/
  universal.lua     Runs in every game.
  _template.lua     Copy this to add a game. Never loaded.
docs/
AGENTS.md           Instructions for AI agents working here.
llms.txt            A map of this repo for language models.
```

## Adding a game

```bash
cp games/_template.lua games/your-game.lua
```

Write it, then add its place ID to the `GAMES` table in `main.lua`:

```lua
local GAMES = {
    [2753915549] = "blox-fruits",
}
```

A game script is a function. `main.lua` hands it a context and that is the whole
contract:

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

    ctx.OnStop(function()
        -- undo it
    end)
end
```

`games/_template.lua` is commented throughout and is the real reference.
[docs/adding-a-game.md](docs/adding-a-game.md) walks through it.
[docs/how-it-works.md](docs/how-it-works.md) explains the boot sequence.

## Conventions

- **Option ids are global.** `Library.Options` is one flat table for the whole
  hub. Prefix ids with the game — `yourgame.autoSell`, never `autoSell`.
- **Teardown is mandatory.** Anything started must be stoppable, and both exit
  paths — the toggle going off, and the hub being unloaded — must reach the same
  cleanup function. `ctx.OnStop` covers the second.
- **Wire callbacks after creating the widget.** Never pass `Callback` in the
  widget table; create it, then call `:OnChanged`.
- **Throttle per-frame loops.** `Heartbeat` runs at frame rate.
- **Fail soft, report loud.** `pcall` anything touching the game's own objects.
  If a feature cannot run, say so and turn its toggle back off.

## Checking your changes

There is no test suite, and the code cannot be executed outside Roblox. The
Luau toolchain will at least catch syntax and type errors:

```bash
luau-compile --null main.lua
luau-analyze main.lua
```

`luau-analyze` reports `Unknown global 'game'` and similar for every Roblox and
executor global — expected, they are not in Luau's default stdlib. Everything
else it reports is real.

Then load it in the game and click every widget you added.

## For AI agents

[AGENTS.md](AGENTS.md) has the context, the conventions, and the rules that are
not obvious. [llms.txt](llms.txt) is a map of the repo.

## Licence

MIT — see [LICENSE](LICENSE).

Abyssal bundles the Obsidian UI Library, also MIT. Its copyright notice is
retained in `libs/obsidian/LICENSE` and as a header comment in
`libs/obsidian/Library.lua`. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

**Do not add third-party code without a licence file.** No licence means all
rights reserved, and crediting the author does not change that.
