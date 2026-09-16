--[[
    tools/tests/entry.luau

    Test entry point. Bundled and run with:

        python tools/build.py --entry tools/tests/entry --out dist/Abyssal.test.lua
        luau dist/Abyssal.test.lua

    Exercises the invariants the architecture actually depends on — the ones
    that are easy to break silently and expensive to debug in-game:

      * a feature that throws on enable must not leave its toggle on
      * OnDisable must fully reverse OnEnable, or Module:Stop leaks threads
      * duplicate widget ids must be rejected, not silently shadowed
      * module resolution must sort by priority, not registration order

    The UI library is deliberately not bundled here. Obsidian needs a real
    instance tree, and mocking one would test the mock rather than the hub.
    The Window facade is stubbed instead.
]]

local Mock = require("tools/tests/mock")
Mock.install()

local Signals = require("core/Signals")
local Feature = require("core/Feature")
local Action = require("core/Action")
local Module = require("core/Module")
local Registry = require("core/Registry")
local GameDetector = require("core/GameDetector")

-- ---------------------------------------------------------------- harness --

local passed = 0
local failed = 0

local function check(label: string, condition: boolean, detail: string?)
    if condition then
        passed += 1
        print(`  ok   {label}`)
    else
        failed += 1
        print(`  FAIL {label}{detail and (" — " .. detail) or ""}`)
    end
end

local function section(name: string)
    print(`\n{name}`)
end

-- ------------------------------------------------------------------ stubs --

local function makeToggle(default: boolean)
    local toggle = { Value = default, _handler = nil }

    function toggle:OnChanged(handler)
        self._handler = handler
    end

    function toggle:SetValue(value: boolean)
        self.Value = value
        if self._handler then
            self._handler(value)
        end
    end

    return toggle
end

local function makeGroupbox()
    local box = { toggles = {}, buttons = {} }

    function box:AddToggle(id: string, info: any)
        local toggle = makeToggle(info.Default == true)
        toggle.Id = id
        self.toggles[id] = toggle
        return toggle
    end

    function box:AddButton(info: any)
        local button = { Info = info }

        function button:Destroy() end

        table.insert(self.buttons, button)
        return button
    end

    function box:AddLabel(text: string)
        return { Text = text }
    end

    return box
end

local function makeTab()
    local tab = { boxes = {} }

    function tab:AddGroupbox(info: any)
        local box = makeGroupbox()
        box.Side = info.Side
        box.Name = info.Name
        table.insert(self.boxes, box)
        return box
    end

    return tab
end

local stubContext = {
    log = { Debug = function() end },
    ui = { Notify = function() end, RenderExtra = function() end },
}

-- ----------------------------------------------------------------- tests --

section("Signals")

do
    local signal = Signals.new()
    local calls = {}

    local connection = signal:Connect(function(value)
        table.insert(calls, value)
    end)

    signal:Fire("a")
    signal:Fire("b")

    check("handlers receive fired values", #calls == 2 and calls[1] == "a" and calls[2] == "b")

    connection:Disconnect()
    signal:Fire("c")

    check("disconnected handlers stop firing", #calls == 2)
    check("handler count reflects disconnect", signal:GetHandlerCount() == 0)
end

do
    local signal = Signals.new()
    local reached = false

    signal:Connect(function()
        error("intentional failure")
    end)

    signal:Connect(function()
        reached = true
    end)

    signal:Fire()

    check("a throwing handler does not block later handlers", reached)
end

section("Feature lifecycle")

do
    local feature = Feature.new({
        Id = "test.plain",
        Name = "Plain",
        Default = false,
    })

    feature:Mount(stubContext)

    local box = makeGroupbox()
    feature:BuildUI(box)

    check("BuildUI registers a toggle", box.toggles["test.plain"] ~= nil)

    box.toggles["test.plain"]:SetValue(true)
    check("toggle on enables the feature", feature:IsEnabled())

    box.toggles["test.plain"]:SetValue(false)
    check("toggle off disables the feature", not feature:IsEnabled())

    feature:Disable()
    check("Disable is safe when already off", not feature:IsEnabled())
end

do
    -- The important one: a feature that cannot start must not claim to be on.
    local feature = Feature.new({
        Id = "test.broken",
        Name = "Broken",
        Default = false,
    })

    feature:Mount(stubContext)

    function feature:OnEnable()
        error("cannot start")
    end

    local box = makeGroupbox()
    feature:BuildUI(box)

    local toggle = box.toggles["test.broken"]
    toggle:SetValue(true)

    check("failed enable reports off", not feature:IsEnabled())
    check("failed enable rolls the toggle back", toggle.Value == false)
end

do
    -- OnDisable must be reached exactly once per enable, or teardown leaks.
    local feature = Feature.new({ Id = "test.counted", Name = "Counted" })
    feature:Mount(stubContext)

    local enables, disables = 0, 0

    function feature:OnEnable()
        enables += 1
    end

    function feature:OnDisable()
        disables += 1
    end

    feature:Enable()
    feature:Enable() -- idempotent
    check("enable is idempotent", enables == 1)

    feature:Disable()
    feature:Disable()
    check("disable is idempotent", disables == 1)

    feature:Enable()
    feature:Destroy()
    check("destroy disables first", disables == 2)
end

section("Action")

do
    local action = Action.new({ Id = "test.action", Name = "Do Thing" })
    action:Mount(stubContext)

    local clicks = 0

    function action:OnClick()
        clicks += 1
    end

    local box = makeGroupbox()
    action:BuildUI(box)

    check("BuildUI registers a button", #box.buttons == 1)

    box.buttons[1].Info.Func()
    box.buttons[1].Info.Func()

    check("button fires the action", clicks == 2)
    check("action kind is marked", action.Kind == "Action")
end

do
    local action = Action.new({ Id = "test.actionBroken", Name = "Broken" })
    action:Mount(stubContext)

    function action:OnClick()
        error("boom")
    end

    local box = makeGroupbox()
    action:BuildUI(box)

    local ok = pcall(box.buttons[1].Info.Func)
    check("a throwing action is contained", ok)
end

section("Module")

do
    local module = Module.new({ Id = "test.mod", Name = "Test", Priority = 5 })
    module:Mount(stubContext)

    module:AddFeature(Feature.new({ Id = "test.a", Name = "A", Group = "One" }))
    module:AddFeature(Feature.new({ Id = "test.b", Name = "B", Group = "One" }))
    module:AddAction(Action.new({ Id = "test.c", Name = "C", Group = "Two", Side = "Right" }))

    check("features and actions are counted separately", #module:GetFeatures() == 2 and #module:GetActions() == 1)
    check("Find locates a widget by id", module:Find("test.c") ~= nil)

    local duplicateRejected = not pcall(function()
        module:AddFeature(Feature.new({ Id = "test.a", Name = "Duplicate" }))
    end)

    check("duplicate widget ids are rejected", duplicateRejected)

    local tab = makeTab()
    module:BuildUI(stubContext, tab)

    check("groupboxes are created per group", #tab.boxes == 2)
    check("insertion order is preserved", tab.boxes[1].Name == "One" and tab.boxes[2].Name == "Two")
    check("side is honoured", tab.boxes[2].Side == "Right")
end

do
    -- Stop must disable everything, whatever the UI believes.
    local module = Module.new({ Id = "test.stop", Name = "Stop" })
    module:Mount(stubContext)

    local feature = Feature.new({ Id = "test.stopA", Name = "A" })
    module:AddFeature(feature)

    local tab = makeTab()
    module:BuildUI(stubContext, tab)

    module:Start(stubContext)
    feature:Enable()

    check("feature is on before stop", feature:IsEnabled())

    module:Stop(stubContext)

    check("stop disables every feature", not feature:IsEnabled())
    check("stop marks the module stopped", not module:IsStarted())
end

section("Registry")

do
    local registry = Registry.new()

    local universal = Module.new({ Id = "universal", Name = "Universal", Priority = -100 })
    local gameA = Module.new({ Id = "gameA", Name = "Game A", PlaceIds = { 12345 }, Priority = 10 })
    local gameB = Module.new({ Id = "gameB", Name = "Game B", PlaceIds = { 99999 }, Priority = 20 })

    registry:Register(universal)
    registry:Register(gameA)
    registry:Register(gameB)

    local applicable = registry:ResolveApplicable()

    check("universal and the matching game both load", #applicable == 2)
    check("highest priority sorts first", applicable[1].Id == "gameA")
    check("universal sorts last", applicable[2].Id == "universal")
    check("non-matching game is excluded", registry:Get("gameB") ~= nil and #registry:GetUnmatched() == 1)
end

do
    local registry = Registry.new()
    registry:Register(Module.new({ Id = "dup", Name = "Dup" }))

    local rejected = not pcall(function()
        registry:Register(Module.new({ Id = "dup", Name = "Dup Again" }))
    end)

    check("duplicate module ids are rejected", rejected)
end

section("GameDetector")

do
    check("matches an empty list", GameDetector.Matches({}))
    check("matches nil", GameDetector.Matches(nil))
    check("matches the current place", GameDetector.Matches({ 12345 }))
    check("rejects a different place", not GameDetector.Matches({ 1, 2, 3 }))

    local info = GameDetector.Describe()
    check("describes the server", info.placeId == 12345 and info.jobId == "mock-job-id")
end

-- ---------------------------------------------------------------- summary --

print(`\n{passed} passed, {failed} failed`)

if failed > 0 then
    error(`{failed} test(s) failed`)
end

return true
