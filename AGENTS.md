# AGENTS.md

Instructions for AI agents working in this repository. Humans want
[README.md](README.md) and [docs/](docs/).

## What this is

Abyssal is a multi-game Roblox script hub. It runs in an executor, presents a UI
built on the Obsidian library, and loads a game-specific script depending on
which place it is running in.

It is **not** a compiled project. There is no build step. `main.lua` fetches
everything it needs from `raw.githubusercontent.com` at run time, so merging to
`main` *is* the release.

## Layout

```
main.lua              Entry point. Everything starts here.
libs/obsidian/        The UI library. Third-party, MIT. Do not edit.
assets/               Icons and images, grouped by what uses them.
games/                One file per game. Self-contained.
  universal.lua       Runs in every game.
  _template.lua       Copy this to add a game. Never loaded.
docs/                 Human documentation.
```

## The contract

A game script is a function that takes a context and returns nothing:

```lua
return function(ctx)
    local tab = ctx.Window:AddTab("Name", "lucide-icon")
    -- build UI, wire behaviour
    ctx.OnStop(function() ... end)
end
```

`ctx` is built in `main.lua`. Its fields:

| Field | What it is |
|---|---|
| `Library` | The Obsidian library object |
| `SaveManager` / `ThemeManager` | Obsidian addons, already configured |
| `Options` / `Toggles` | `Library.Options` / `Library.Toggles`, by option id |
| `Window` | For `AddTab` |
| `PlaceId` / `JobId` | `game.PlaceId` / `game.JobId` |
| `Log` / `Debug` / `Warn` | Prefixed console output |
| `Fetch(path)` | GET a file from this repo. **Relative path.** |
| `Http(url)` | GET an absolute URL, e.g. a Roblox API |
| `LoadFile(path)` | Fetch and run a Lua file from this repo |
| `OnStop(fn)` | Register teardown. Runs in reverse order on unload. |
| `Track(conn)` | Shorthand: disconnect `conn` on unload |

**Do not add fields to `ctx` without documenting them here.** Scripts in `games/`
are written against this table.

## Rules

### 1. Never add third-party code without a licence

This is the rule that matters most, and it is not hypothetical — a previous
account of the owner's was permanently banned for redistributing someone else's
script with the name changed.

Before vendoring anything:

- **Check for a licence file.** No licence means all rights reserved. There is
  no permission to copy, modify, or redistribute, and **attribution does not
  create one.** A credit line is not a licence.
- **Preserve the notice.** Keep the `LICENSE` file and any copyright headers.
  Add an entry to `THIRD_PARTY_NOTICES.md`.
- **Check compatibility.** This project is MIT. Copyleft licences such as the
  GPL cannot be bundled into it without relicensing the whole project.
- **MIT and Apache-2.0 are fine** with the notice retained.

If you are asked to integrate code whose licence you cannot determine, stop and
say so. Do not integrate it and note the problem afterwards.

### 2. Option ids are global

`Library.Options` is one flat table for the whole hub. Prefix ids with the game:

```lua
main:AddToggle("yourgame.autoSell", { ... })   -- correct
main:AddToggle("autoSell", { ... })            -- collides with another script
```

### 3. Teardown is mandatory

Anything started must be stoppable. `main.lua` runs registered stop callbacks in
reverse on unload, and a script that leaks a connection leaves it running after
the UI is gone — a bug the user notices long after the cause.

```lua
local connection = nil

local function stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

toggle:OnChanged(function(enabled)
    stop()                     -- always stop first: OnChanged can fire repeatedly
    if enabled then
        connection = RunService.Heartbeat:Connect(...)
    end
end)

ctx.OnStop(stop)               -- and the unload path
```

Both paths must lead to the same function.

### 4. Wire callbacks after creating the widget

Never pass `Callback` in the widget info table. Create the widget, then call
`:OnChanged`. This is Obsidian's own recommendation, and it prevents a config
load from firing your callback mid-construction.

### 5. Fail soft, report loud

A game update will break things. When it does:

- `pcall` anything that touches the game's own objects or yields.
- If a feature cannot run, tell the user and turn its toggle back off rather
  than leaving it on and doing nothing.
- If a module cannot boot, log and continue. A script that errors on load gives
  the user nothing.

### 6. Comments explain why, not what

The code says what it does. Comments should say why it does it that way — the
constraint, the failure mode being avoided, the reason the obvious approach is
wrong. See any file in `games/` for the register.

## Verifying changes

There is no test suite. The toolchain is Luau's, not Roblox's:

```bash
luau-compile --null main.lua           # syntax check
luau-analyze main.lua                  # type and lint check
```

`luau-analyze` will report `Unknown global 'game'` and similar for every Roblox
and executor global. That is expected — they are not in Luau's default stdlib.
Filter those out; everything else is a real finding.

**Syntax checking is not enough.** There is no way to execute this code outside
Roblox. If you change control flow, say plainly that it is unverified and
describe what a human should click to confirm it.

## Do not

- Edit anything in `libs/obsidian/` except to fix its licence notice. It is
  upstream code; changes there are lost on the next sync and make the vendored
  copy diverge from upstream for no reason.
- Add a build step. The no-build design is deliberate.
- Add a base class, a module system, or a registry to `games/`. The flat
  function contract is deliberate — it was chosen over a framework after one was
  built and rejected. Scripts are meant to be readable top to bottom.
- Hardcode a URL that should be `ctx.Fetch` or `ctx.Http`.
- Commit anything to `main` that you have not syntax-checked.
