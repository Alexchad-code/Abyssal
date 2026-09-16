--[[
    games/_template/init.luau

    TEMPLATE. To add a game:

        1. cp -r src/games/_template src/games/your-game
        2. Rename the module Id and Name below.
        3. Put the game's place IDs in PlaceIds.
        4. Replace the example feature with real ones.
        5. Register it in src/games/init.luau.
        6. Rebuild: python tools/build.py

    ---------------------------------------------------------------------------

    Finding the place ID: it is the number in the Roblox URL, or
    game.PlaceId from the executor's console. List every place the module
    should cover — lobby and main game are usually different IDs, and a module
    that only lists one will silently do nothing in the other.

    A game module loads ALONGSIDE the universal module, not instead of it.
    Do not re-add rejoin or server hop here.
]]

local Module = require("core/Module")

local ExampleFeature = require("games/_template/features/ExampleFeature")

local Template = Module.new({
    Id = "template",
    Name = "Example Game",

    -- Shown in diagnostics. Not rendered anywhere yet.
    Description = "Reference module.",

    -- Place IDs this module applies to. nil or {} means every place, which is
    -- how the universal module is declared — do not do that here, or this
    -- module will load in games it does not support.
    PlaceIds = { 0 },

    -- Lucide icon for the tab. https://lucide.dev/
    Icon = "gamepad-2",

    -- Game modules should outrank universal (which is -100) so they get the
    -- first tab. Use a higher number to outrank another game module that
    -- also matches, e.g. a shared hub place.
    Priority = 10,
})

-- Optional. Runs before any UI is built. This is where a game module resolves
-- the things it will need: remotes, modules under ReplicatedStorage, cached
-- player state. Anything you resolve here can be read in OnEnable without
-- re-scanning the tree.
--
-- Fail soft. If the game has updated and a remote moved, log it and let the
-- module load with that feature disabled, rather than erroring the whole hub.
function Template:Setup(ctx: any)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local ok, result = pcall(function()
        return ReplicatedStorage:WaitForChild("SomeRemote", 5)
    end)

    if not ok or result == nil then
        self._log:Warn("SomeRemote not found; features depending on it will not work")
        self._remote = nil
        return
    end

    self._remote = result
    ctx.log:Debug("resolved SomeRemote")
end

-- Optional. Runs after the UI exists and after config has been attached, but
-- before Start. Wire cross-widget signals here.
function Template:Ready(_ctx: any) end

-- Optional. The default implementation groups widgets by Group and Side and
-- preserves insertion order, which covers most cases. Override only for a
-- layout it cannot express — tabboxes, per-feature dividers, warnings.
--
-- If you override, keep calling widget:BuildUI(groupbox) for anything with a
-- lifecycle, or its toggle will not exist and config cannot restore it.
-- function Template:BuildUI(ctx: any, tab: any)
--     local groupbox = tab:AddGroupbox({ Side = "Left", Name = "Main" })
--     for _, widget in self:GetWidgets() do
--         widget:BuildUI(groupbox)
--     end
-- end

Template:AddFeature(ExampleFeature)

return Template
