# Architecture

Why Abyssal is shaped the way it is, and what to keep in mind when extending it.

## Design goals

1. **Adding a game is a copy-paste.** No change to the core, no change to other
   games.
2. **The core knows nothing about any game.** Everything game-specific lives in
   a module.
3. **Nothing runs that cannot be stopped.** Every capability has a teardown
   path, because an unload that leaks a thread is a bug the user sees and you
   do not.
4. **Failures are contained.** Games update without warning. A feature that
   breaks must break alone.

## The three layers

```
        ┌──────────────────────────────────────────────────┐
        │  games/          game-specific modules            │
        │  universal/  your-game/  their-game/              │
        │  Features, Actions, Setup, Ready                  │
        └───────────────────────┬──────────────────────────┘
                                │ uses
        ┌───────────────────────▼──────────────────────────┐
        │  core/           game-agnostic framework          │
        │  App, Context, Registry, Module,                  │
        │  Feature, Action, Signals, Config, Logger         │
        └───────────────────────┬──────────────────────────┘
                                │ drives
        ┌───────────────────────▼──────────────────────────┐
        │  ui/             Obsidian integration             │
        │  Obsidian, Window, Theme                          │
        └───────────────────────┬──────────────────────────┘
                                │ wraps
        ┌───────────────────────▼──────────────────────────┐
        │  vendor/obsidian/    the UI library (MIT)         │
        └──────────────────────────────────────────────────┘
```

Dependencies point one way. `core` never imports from `games`, and `games` never
import from `vendor` — a module that reaches past `ui/` to poke the library
directly is a bug waiting to happen, because it will miss the facade's
bookkeeping.

## Boot sequence

`App:Run()` is ordered deliberately. Each step depends on the previous one:

| # | Step | Why here |
|---|------|----------|
| 1 | Build `Context` | Services exist before anything asks for them |
| 2 | Describe the server | Modules may branch on place id during `Setup` |
| 3 | Load Obsidian | The library is needed before any UI call |
| 4 | Create window, apply theme | Before any tab exists |
| 5 | Attach config | SaveManager needs the library object |
| 6 | `Mount` every applicable module | Widgets receive the context |
| 7 | `Setup` | Pre-UI work, resolve remotes |
| 8 | `BuildUI` | Tabs are created and filled |
| 9 | `Ready` | Wire signals, register config sections |
| 10 | Load autoload config | Options must exist before values are restored |
| 11 | `Start` | Features turn on last, once everything is in place |

`Start` is last on purpose. A feature that turns on before the UI exists cannot
report its own state, and one that turns on before config loads is immediately
overridden by it.

Teardown runs in reverse, and every step is individually `pcall`'d — a module
that throws on the way out must not prevent the others from stopping.

## The widget model

Two types, deliberately not one.

**`Feature`** — a stateful capability. A toggle, a lifecycle, a config key.
Subclasses implement `OnEnable` / `OnDisable`.

**`Action`** — a one-shot command. A button. No state, nothing to persist.

They are separate types because a Feature's entire contract is that it can be
turned off and that its state round-trips through config. A button has neither
property. Merging them into one type with a `Kind` flag would force every
consumer to branch on which kind it holds.

They do share a shape — `Id`, `Name`, `Group`, `Side`, `BuildUI`, `Destroy` —
which is what lets `Module` hold both in one ordered list and group them
identically. The `Kind` marker on each class is resolved through `__index`
rather than stored per instance, and exists only so `Module` can tell them apart
when it genuinely needs to.

### Grouping

A widget declares `Group` and `Side`. The default `Module:BuildUI` buckets them
in insertion order and creates one groupbox per bucket. Insertion order is
preserved, so the order you call `AddFeature` in is the order users see.

Override `BuildUI` only for a layout this cannot express — tabboxes, inline
dividers, warning banners. If you do override it, keep calling
`widget:BuildUI(groupbox)` for anything with a lifecycle, or its toggle will not
exist and config cannot restore it.

## Lifecycle contracts

These are the invariants the test harness enforces.

### `OnEnable` must be fully reversible by `OnDisable`

`Module:Stop` calls `Disable` on every widget during unload. Anything
`OnEnable` started and `OnDisable` missed keeps running after the UI is gone.
Capture the handle:

```lua
function MyFeature:OnEnable()
    self._connection = RunService.Heartbeat:Connect(function() ... end)
end

function MyFeature:OnDisable()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
end
```

### `OnEnable` should raise on failure, not return quietly

The base class catches it, logs it, and rolls the toggle back to off. That
rollback is the point: a silent failure leaves a toggle claiming to be on when
nothing is running, which is worse than an error.

### `Enable` and `Disable` are idempotent

Calling either twice is a no-op. `Module:Stop` relies on this.

### `OnDisable` marks state off *before* doing work

A throwing `OnDisable` must not leave the feature stuck "on". The base class
sets `_enabled = false` first, then calls the hook.

## Module resolution

A module declares `PlaceIds`:

```lua
PlaceIds = { 12345, 67890 }   -- only these places
PlaceIds = nil                -- everywhere (the universal module)
```

`Registry:ResolveApplicable()` returns **all** matching modules, sorted by
`Priority` descending. All, not just the best one — that is the whole point. A
game-specific module and the universal module both load, so rejoin and server
hop are available regardless of which game you are in.

Priority only decides ordering, and therefore which module gets the first tab.
The universal module runs at `-100` so it is always last.

When no module matches, `App` builds an "unsupported" tab naming the place id.
An empty window reads as broken; a message reads as unsupported.

## Config namespacing

Configs are written per place id:

```
Abyssal/
  Game_12345/
    autoload.txt
    my-config.txt
```

A config saved in one game is not offered in another, because option indexes
differ between modules and loading the wrong set would silently apply unrelated
values.

Widget ids are global across the hub, so prefix them with the game
(`yourgame.autoSell`). Collisions are a hard error at registration rather than a
silent overwrite, because a silent overwrite means two features fighting over
one toggle.

## Why a custom bundler

A Roblox hub is delivered as one script via `loadstring`. Wally produces a
package tree, which is the wrong shape for that.

`tools/build.py` resolves the same `require` ids, inlines the vendored library,
and emits one file. Two details worth knowing:

**Requires are scanned from source with comments and strings tracked, not by
regex.** A regex over raw source picks up requires inside comments — the
template files contain commented-out requires by design, and those do not
resolve. Blanking strings first would destroy the module path itself. So the
scanner walks the source and only reads `require()` when it is in actual code.

**Each module is wrapped in `function(...)`, and `require` is shadowed inside.**
The varargs matter: a bundled chunk may reference `...` at its top level, which
is legal in a vararg function and a syntax error otherwise. Shadowing means
module bodies call `require("core/Logger")` unchanged, with no source rewriting.

The build fails if Obsidian's MIT notice is missing from the output, because the
bundle is a distributed copy of the library.

## Extension points

| I want to | Do this |
|---|---|
| Add a game | `cp -r src/games/_template src/games/your-game`, register in `src/games/init.luau` |
| Add a toggle | Subclass `Feature`, implement `OnEnable`/`OnDisable` |
| Add a button | Subclass `Action`, implement `OnClick` |
| Add a slider/dropdown under a feature | Return a spec from `GetExtraUI` |
| Change the look | Edit `src/ui/Theme.luau` |
| React to another feature | `ctx.signals.FeatureEnabled:Connect(...)` |
| Custom tab layout | Override `Module:BuildUI` |
| Resolve remotes once | `Module:Setup` |

## Deliberately not here

- **No auto-discovery of game modules.** The bundler resolves requires
  statically, so a module nothing references is not in the build. An
  auto-discovered directory would appear to work in source and then vanish from
  the bundle. The manifest makes that explicit.
- **No minifier beyond comment stripping.** Safe whitespace minification needs a
  real tokenizer; a naive one produces code that parses differently. If you add
  one, it must re-emit the Obsidian notice.
- **No `--!strict`.** The core is annotated but not strict-checked, because the
  Roblox and executor globals it depends on are not in Luau's default stdlib and
  strict mode would drown in false positives. Turn it on per-file once you have
  a Roblox-aware type environment.
