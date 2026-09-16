--[[
    core/Module.luau

    A game module. One per game, plus one universal module that applies
    everywhere.

    A module owns a tab and an ordered list of widgets — Features (stateful,
    config-backed toggles) and Actions (one-shot buttons). They share one list
    because the order they were added in is the order they should appear in,
    and because grouping, teardown, and layout are identical for both. The
    Kind marker on each widget is what lets this file tell them apart when it
    needs to.

    The default lifecycle is enough for most games:

        Setup    -> pre-UI work (resolve remotes, read game state)
        BuildUI  -> create the tab contents
        Ready    -> wire signals, register config sections
        Start    -> turn on whatever saved config had enabled
        Stop     -> turn everything off, cleanly
        Destroy  -> tear down

    Stop() is deliberately unconditional: it walks every widget and disables
    it, so an unload never leaves a loop running.
]]

local Logger = require("core/Logger")

local Module = {}
Module.__index = Module

export type Spec = {
    -- Stable identifier, used for config keys and diagnostics.
    Id: string,
    Name: string,
    Description: string?,

    -- Place IDs this module applies to. nil or empty means "everywhere",
    -- which is how the universal module is declared.
    PlaceIds: { number }?,

    -- Lucide icon name for the tab. See https://lucide.dev/
    Icon: string?,

    -- Higher wins when several modules match. The universal module runs at a
    -- low priority so a game-specific module gets the first tab.
    Priority: number?,
}

export type Module = typeof(setmetatable(
    {} :: {
        Id: string,
        Name: string,
        Description: string?,
        PlaceIds: { number }?,
        Icon: string,
        Priority: number,

        _ctx: any,
        _log: any,
        _widgets: { any },
        _started: boolean,
        _destroyed: boolean,
    },
    Module
))

function Module.new(spec: Spec): Module
    assert(type(spec.Id) == "string" and spec.Id ~= "", "Module requires an Id")
    assert(type(spec.Name) == "string" and spec.Name ~= "", "Module requires a Name")

    return setmetatable({
        Id = spec.Id,
        Name = spec.Name,
        Description = spec.Description,
        PlaceIds = spec.PlaceIds,
        Icon = spec.Icon or "gamepad-2",
        Priority = spec.Priority or 0,

        _ctx = nil,
        _log = nil,
        _widgets = {},
        _started = false,
        _destroyed = false,
    }, Module)
end

local function addWidget(self: Module, widget: any, kind: string): any
    assert(not self._destroyed, `cannot add to destroyed module {self.Id}`)
    assert(widget ~= nil, `${kind} is nil`)
    assert(type(widget.Id) == "string", `${kind} is missing an Id`)

    for _, existing in self._widgets do
        if existing.Id == widget.Id then
            error(`duplicate widget id "{widget.Id}" in module "{self.Id}"`)
        end
    end

    table.insert(self._widgets, widget)
    return widget
end

function Module:AddFeature(feature: any): any
    return addWidget(self, feature, "Feature")
end

function Module:AddAction(action: any): any
    return addWidget(self, action, "Action")
end

function Module:GetWidgets(): { any }
    return self._widgets
end

function Module:GetFeatures(): { any }
    local features: { any } = {}

    for _, widget in self._widgets do
        if widget.Kind == "Feature" then
            table.insert(features, widget)
        end
    end

    return features
end

function Module:GetActions(): { any }
    local actions: { any } = {}

    for _, widget in self._widgets do
        if widget.Kind == "Action" then
            table.insert(actions, widget)
        end
    end

    return actions
end

function Module:Find(id: string): any?
    for _, widget in self._widgets do
        if widget.Id == id then
            return widget
        end
    end

    return nil
end

function Module:IsStarted(): boolean
    return self._started
end

-- Called by App. Hands every widget the shared context.
function Module:Mount(ctx: any)
    self._ctx = ctx
    self._log = Logger.new(`Module:{self.Id}`)

    for _, widget in self._widgets do
        widget:Mount(ctx)
    end
end

-- ------------------------------------------------------- overridable hooks --

-- Pre-UI work. Resolve remotes, read player state, bail out early if this is
-- not actually the game we think it is.
function Module:Setup(_ctx: any) end

-- Post-UI, pre-start. Wire cross-widget signals, register config sections.
function Module:Ready(_ctx: any) end

-- Builds the tab contents. The default groups widgets into groupboxes by their
-- Group and Side, preserving the order they were added. Override for a layout
-- the defaults cannot express, but keep calling widget:BuildUI for anything
-- with a lifecycle.
function Module:BuildUI(ctx: any, tab: any)
    local buckets: { { side: string, group: string, widgets: { any } } } = {}
    local index: { [string]: number } = {}

    for _, widget in self._widgets do
        local key = `{widget.Side}/{widget.Group}`

        if index[key] == nil then
            index[key] = #buckets + 1
            table.insert(buckets, {
                side = widget.Side,
                group = widget.Group,
                widgets = {},
            })
        end

        table.insert(buckets[index[key]].widgets, widget)
    end

    for _, bucket in buckets do
        local groupbox = tab:AddGroupbox({
            Side = bucket.side,
            Name = bucket.group,
        })

        for _, widget in bucket.widgets do
            local built = widget:BuildUI(groupbox)

            -- Extra widgets hang off the toggle, so only Features can have
            -- them. Actions return nil from GetExtraUI.
            if widget.Kind == "Feature" and ctx.ui then
                local extra = widget:GetExtraUI()

                if extra ~= nil then
                    ctx.ui:RenderExtra(built, extra)
                end
            end
        end
    end
end

-- Called once the UI exists and config has loaded. Logs the module in.
function Module:Start(_ctx: any)
    if self._started then
        return
    end

    self._started = true
    self._log:Info(`started ({#self:GetFeatures()} features, {#self:GetActions()} actions)`)
end

-- Unconditional teardown. Every widget is disabled regardless of what the UI
-- believes, so nothing is left running. Action:Disable is a no-op, which is
-- why this can walk the list without branching.
function Module:Stop(_ctx: any)
    if not self._started then
        return
    end

    for _, widget in self._widgets do
        pcall(function()
            widget:Disable()
        end)
    end

    self._started = false
    self._log:Info("stopped")
end

function Module:Destroy()
    if self._destroyed then
        return
    end

    self:Stop(self._ctx)

    for _, widget in self._widgets do
        pcall(function()
            widget:Destroy()
        end)
    end

    table.clear(self._widgets)
    self._destroyed = true
    self._ctx = nil
end

return Module
