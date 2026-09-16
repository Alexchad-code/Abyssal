--[[
    core/Action.luau

    A one-shot command: rejoin, server hop, copy the job id. No state, no
    enable/disable, nothing to persist.

    Why this is a separate type from Feature rather than a flag on it: a
    Feature's whole contract is that it can be turned off and that its state
    round-trips through config. A button has neither property. Modelling them
    as one type would force every consumer to branch on which kind it is
    holding.

    Action deliberately exposes the same shape Module needs — Id, Name, Group,
    Side, BuildUI, Destroy — so grouping and teardown treat both types the same
    without knowing the difference. Disable() is a no-op for the same reason:
    Module:Stop walks everything and turns it off, and an Action has nothing to
    turn off.
]]

local Logger = require("core/Logger")

local Action = {}
Action.__index = Action

-- Static marker, resolved through __index. See core/Feature.luau.
Action.Kind = "Action"

export type Spec = {
    -- Globally unique, same convention as Feature: "universal.rejoin".
    Id: string,
    Name: string,
    Description: string?,
    Tooltip: string?,

    -- Renders the label in the scheme's red. Use for destructive or
    -- irreversible actions, not for emphasis.
    Risky: boolean?,

    -- Requires a second click to fire. Good default for anything that
    -- teleports or disconnects the player.
    Confirm: boolean?,

    Group: string?,
    Side: "Left" | "Right"?,
}

export type Action = typeof(setmetatable(
    {} :: {
        Id: string,
        Name: string,
        Description: string?,
        Tooltip: string?,
        Risky: boolean,
        Confirm: boolean,
        Group: string,
        Side: "Left" | "Right",

        _ctx: any,
        _log: any,
        _button: any,
        _built: boolean,
        _destroyed: boolean,
    },
    Action
))

function Action.new(spec: Spec): Action
    assert(type(spec.Id) == "string" and spec.Id ~= "", "Action requires an Id")
    assert(type(spec.Name) == "string" and spec.Name ~= "", "Action requires a Name")

    return setmetatable({
        Id = spec.Id,
        Name = spec.Name,
        Description = spec.Description,
        Tooltip = spec.Tooltip,
        Risky = spec.Risky == true,
        Confirm = spec.Confirm == true,
        Group = spec.Group or "Actions",
        Side = spec.Side or "Left",

        _ctx = nil,
        _log = nil,
        _button = nil,
        _built = false,
        _destroyed = false,
    }, Action)
end

function Action:Mount(ctx: any)
    self._ctx = ctx
    self._log = Logger.new(`Action:{self.Id}`)
end

-- Override. This is the action body.
function Action:OnClick() end

-- Present so Module:Stop can walk Features and Actions without branching.
function Action:Disable() end

function Action:Destroy()
    if self._destroyed then
        return
    end

    self._destroyed = true

    if self._button then
        pcall(function()
            self._button:Destroy()
        end)
    end

    self._button = nil
    self._ctx = nil
end

function Action:BuildUI(groupbox: any): any
    if self._built then
        return self._button
    end

    local button = groupbox:AddButton({
        Text = self.Name,
        Tooltip = self.Tooltip,
        DoubleClick = self.Confirm,
        Risky = self.Risky,
        Func = function()
            if self._destroyed then
                return
            end

            local ok, err = pcall(self.OnClick, self)

            if not ok then
                self._log:Error(`action failed: {tostring(err)}`)
            end
        end,
    })

    self._button = button
    self._built = true

    return button
end

return Action
