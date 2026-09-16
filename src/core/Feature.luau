--[[
    core/Feature.luau

    A single capability inside a game module. Features are the unit of work in
    Abyssal: one toggle in the UI, one enable/disable lifecycle, one config key.

    Subclasses override OnEnable / OnDisable. The base class owns everything
    else: the toggle, the idempotency guards, and error containment.

    Error containment matters more than it looks. A hub runs dozens of features
    against a game that updates without warning, so any feature can start
    throwing at any time. A feature that fails must fail alone: Enable() rolls
    the toggle back to off and reports, rather than leaving the UI claiming
    something is running when it is not.
]]

local Logger = require("core/Logger")

local Feature = {}
Feature.__index = Feature

-- Static marker, resolved through __index rather than stored per instance.
-- Lets Module hold Features and Actions in one ordered list and still tell
-- them apart without type-switching on methods.
Feature.Kind = "Feature"

export type Spec = {
    -- Globally unique. Prefix with the module id, e.g. "universal.rejoin",
    -- so two games can both define "rejoin" without colliding.
    Id: string,
    Name: string,
    Description: string?,
    Default: boolean?,
    Risky: boolean?,
    Tooltip: string?,

    -- Which groupbox this lands in, and which side of the tab. The default
    -- Module:BuildUI groups features by these, so a module only overrides
    -- BuildUI when it wants a layout the defaults cannot express.
    Group: string?,
    Side: "Left" | "Right"?,
}

export type Feature = typeof(setmetatable(
    {} :: {
        Id: string,
        Name: string,
        Description: string?,
        Default: boolean,
        Risky: boolean,
        Tooltip: string?,
        Group: string,
        Side: "Left" | "Right",

        -- Runtime
        _ctx: any,
        _log: any,
        _enabled: boolean,
        _destroyed: boolean,
        _toggle: any,
        _built: boolean,
    },
    Feature
))

function Feature.new(spec: Spec): Feature
    assert(type(spec.Id) == "string" and spec.Id ~= "", "Feature requires an Id")
    assert(type(spec.Name) == "string" and spec.Name ~= "", "Feature requires a Name")

    local self = setmetatable({
        Id = spec.Id,
        Name = spec.Name,
        Description = spec.Description,
        Default = spec.Default == true,
        Risky = spec.Risky == true,
        Tooltip = spec.Tooltip,
        Group = spec.Group or "Features",
        Side = spec.Side or "Left",

        _ctx = nil,
        _log = nil,
        _enabled = false,
        _destroyed = false,
        _toggle = nil,
        _built = false,
    }, Feature)

    return self
end

-- Called by App before any UI is built. Gives the feature its services.
function Feature:Mount(ctx: any)
    self._ctx = ctx
    self._log = Logger.new(`Feature:{self.Id}`)
end

function Feature:IsEnabled(): boolean
    return self._enabled
end

function Feature:IsDestroyed(): boolean
    return self._destroyed
end

-- ---------------------------------------------------------------- lifecycle --

-- Override. Called when the feature turns on. Should be safe to call twice;
-- the base class guards it, but do not rely on that from a subclass.
function Feature:OnEnable() end

-- Override. Must fully undo OnEnable. Called on disable and on destroy.
function Feature:OnDisable() end

-- Override. Called once, after OnDisable, when the hub is shutting down.
function Feature:OnDestroy() end

-- Override. Return extra UI spec to render under the toggle, or nil.
-- See ui/Widgets for the supported shapes.
function Feature:GetExtraUI(): any
    return nil
end

function Feature:Enable(): boolean
    if self._destroyed or self._enabled then
        return self._enabled
    end

    local ok, err = pcall(self.OnEnable, self)

    if not ok then
        self._log:Error(`enable failed: {tostring(err)}`)

        -- Reflect reality: the feature is not running, so the toggle must not
        -- claim it is.
        if self._toggle then
            pcall(function()
                self._toggle:SetValue(false)
            end)
        end

        return false
    end

    self._enabled = true
    return true
end

function Feature:Disable(): boolean
    if not self._enabled then
        return false
    end

    -- Mark off first: a throwing OnDisable must not leave us stuck "on".
    self._enabled = false

    local ok, err = pcall(self.OnDisable, self)

    if not ok then
        self._log:Error(`disable failed: {tostring(err)}`)
    end

    return true
end

function Feature:SetEnabled(enabled: boolean)
    if enabled then
        self:Enable()
    else
        self:Disable()
    end
end

function Feature:Destroy()
    if self._destroyed then
        return
    end

    self:Disable()
    self._destroyed = true

    local ok, err = pcall(self.OnDestroy, self)

    if not ok then
        self._log:Error(`destroy failed: {tostring(err)}`)
    end

    self._toggle = nil
    self._ctx = nil
end

-- ---------------------------------------------------------------------- UI --

-- Builds the toggle for this feature inside the given groupbox and wires it to
-- the lifecycle. Returns the toggle so a module can attach extra widgets.
function Feature:BuildUI(groupbox: any): any
    if self._built then
        return self._toggle
    end

    local toggle = groupbox:AddToggle(self.Id, {
        Text = self.Name,
        Tooltip = self.Tooltip,
        Default = self.Default,
        Risky = self.Risky,
    })

    self._toggle = toggle
    self._built = true

    -- Recommended pattern from Obsidian's docs: build the UI first, wire the
    -- callback after. Keeps widget creation and logic decoupled.
    toggle:OnChanged(function(value: boolean)
        self:SetEnabled(value)
    end)

    return toggle
end

return Feature
