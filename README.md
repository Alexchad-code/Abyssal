# Abyssal

A multi-game Roblox script hub built on the [Obsidian](https://github.com/deividcomsono/Obsidian) UI library.

The design goal is that adding a game is a copy-paste, not a refactor. The core
knows nothing about any specific game; games are plug-in modules that declare
which places they apply to and then contribute features.

## Layout

```
src/
  init.luau                 Entry point — build App, register manifest, run
  core/                     Game-agnostic framework
    App.luau                Boot sequence and lifecycle owner
    Context.luau            Shared services handed to every module
    Registry.luau           Module collection and place-based resolution
    Module.luau             Base class for a game module
    Feature.luau            Stateful capability — a toggle with a lifecycle
    Action.luau             One-shot command — a button
    Signals.luau            Event bus
    Config.luau             Persistence, backed by Obsidian's SaveManager
    GameDetector.luau       Reports facts about the current server
    Http.luau               Executor HTTP wrapper
    Logger.luau             Scoped, levelled logging
  ui/                       Obsidian integration
    Obsidian.luau           Loads the vendored library and addons
    Window.luau             Window facade, tab bookkeeping, widget rendering
    Theme.luau              The Abyssal colour scheme
  games/
    init.luau               Module manifest — every game must be listed
    universal/              Features that work anywhere
    _template/              Copy this to add a game. Never loaded.
vendor/obsidian/            The UI library (MIT). See THIRD_PARTY_NOTICES.md
tools/
  build.py                  Single-file bundler
  tests/                    Headless test harness
dist/                       Build output (gitignored)
```

## Quickstart

Requires Python 3.9+ for the build. No Roblox toolchain needed unless you want
to run StyLua or Selene.

```bash
# Build the single-file script
python tools/build.py

# Strip comments too
python tools/build.py --minify

# Resolve the module graph without writing anything
python tools/build.py --check
```

Output is `dist/Abyssal.lua`. Execute it with an executor's `loadstring`, or
host it and use a loader.

## Adding a game

```bash
cp -r src/games/_template src/games/your-game
```

Then:

1. Rename the `Id` and `Name` in `src/games/your-game/init.luau`.
2. Put the game's place IDs in `PlaceIds`. List **every** place the module
   should cover — lobby and main game are usually different IDs.
3. Replace the example feature with real ones.
4. Register it in `src/games/init.luau`.
5. Rebuild.

The template is heavily commented and is the reference for the shape a feature
should take. `docs/ARCHITECTURE.md` explains why.

## Testing

The core framework runs headlessly. A mock Roblox environment stands in for the
engine, so the lifecycle logic can be exercised without launching the game:

```bash
python tools/build.py --entry tools/tests/entry --out dist/Abyssal.test.lua
luau dist/Abyssal.test.lua
```

`luau` is the standalone interpreter from
[luau-lang/luau releases](https://github.com/luau-lang/luau/releases) — grab
`luau-ubuntu.zip` / `luau-windows.zip` / `luau-macos.zip` and put it on your
`PATH`. CI runs the same commands on every push.

Tests cover the invariants that are easy to break silently: that a feature
which throws on enable does not leave its toggle claiming to be on, that
`OnDisable` fully reverses `OnEnable`, that duplicate widget ids are rejected,
and that module resolution sorts by priority rather than registration order.

Obsidian itself is not covered — it needs a real instance tree, and mocking one
would test the mock.

## Conventions

- **Module ids are paths.** `require("core/Logger")` resolves to
  `src/core/Logger.luau`; `require("vendor/obsidian/Library")` resolves to
  `vendor/obsidian/Library.lua`. Ids are repo-relative with `src/` stripped.
- **Widget ids are global.** Prefix with the game: `yourgame.autoSell`, not
  `autoSell`. Collisions are an error at registration, not a silent overwrite.
- **Features own their teardown.** If `OnEnable` starts something, `OnDisable`
  must stop it. `Module:Stop` relies on this during unload.
- **Fail soft, report loud.** A feature that cannot start should raise; the base
  class contains it and rolls the toggle back. A module that cannot find a
  remote should log and continue.
- **Comments explain why.** The code says what it does.

## Licensing

Abyssal is MIT — see `LICENSE`.

It bundles the Obsidian UI Library, also MIT. Obsidian's copyright notice is
retained in `vendor/obsidian/LICENSE`, as a header comment in
`vendor/obsidian/Library.lua`, and in the generated bundle. See
`THIRD_PARTY_NOTICES.md` for the full text and the rules a bundler must follow.

Do not add third-party code without a licence. No licence means no permission,
regardless of whether credit is given.
