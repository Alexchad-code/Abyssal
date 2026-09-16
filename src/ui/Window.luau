--[[
    ui/Window.luau

    Facade over the Obsidian window. Modules never touch the raw library
    object; they go through here.

    Two reasons. First, tab bookkeeping: the library keeps its own tab table,
    but the hub needs to look tabs up by the name it asked for, and needs to
    fail loudly on a duplicate rather than silently overwriting. Second,
    isolation: when Obsidian's API shifts, this file absorbs the change instead
    of every module.

    The raw library is still reachable via GetLibrary() for anything the facade
    does not cover. That is an escape hatch, not the intended path.
]]

local Logger = require("core/Logger")

local Window = {}
Window.__index = Window

export type Options = {
    Title: string,
    Footer: string?,
    Icon: string?,
    NotifySide: "Left" | "Right"?,
    Center: boolean?,
    AutoShow: boolean?,
    Resizable: boolean?,
    ShowCustomCursor: boolean?,
    AlwaysOnTop: boolean?,
}

export type Window = typeof(setmetatable(
    {} :: {
        _library: any,
        _window: any,
        _tabs: { [string]: any },
        _log: any,
    },
    Window
))

function Window.new(library: any, options: Options): Window
    assert(library ~= nil, "Window.new expects the Obsidian library")

    local self = setmetatable({
        _library = library,
        _window = nil,
        _tabs = {},
        _log = Logger.new("UI"),
    }, Window)

    self._window = library:CreateWindow({
        Title = options.Title,
        Footer = options.Footer or "",
        Icon = options.Icon,
        NotifySide = options.NotifySide or "Right",
        Center = options.Center or false,
        AutoShow = options.AutoShow ~= false,
        Resizable = options.Resizable ~= false,
        ShowCustomCursor = options.ShowCustomCursor ~= false,
        AlwaysOnTop = options.AlwaysOnTop or false,
    })

    return self
end

function Window:GetLibrary(): any
    return self._library
end

function Window:GetRaw(): any
    return self._window
end

function Window:AddTab(name: string, icon: string?): any
    if self._tabs[name] ~= nil then
        error(`tab "{name}" already exists`)
    end

    local tab = self._window:AddTab(name, icon)
    self._tabs[name] = tab

    return tab
end

function Window:GetTab(name: string): any?
    return self._tabs[name]
end

-- A keybind tab, for feature hotkeys.
function Window:AddKeyTab(name: string): any
    if self._tabs[name] ~= nil then
        error(`tab "{name}" already exists`)
    end

    local tab = self._window:AddKeyTab(name)
    self._tabs[name] = tab

    return tab
end

function Window:Notify(options: any)
    local ok, err = pcall(function()
        self._library:Notify(options)
    end)

    if not ok then
        self._log:Warn(`notify failed: {tostring(err)}`)
    end
end

--[[
    Renders extra widgets beneath a parent widget from a declarative spec.

    A spec is a list of tables, each with a Type field. Supported types map
    onto the corresponding Obsidian method:

        { Type = "Slider",      Id = "...", Text = "...", Min = 0, Max = 100, Default = 50 }
        { Type = "Dropdown",    Id = "...", Text = "...", Values = {...}, Default = ... }
        { Type = "Input",       Id = "...", Text = "...", Default = "" }
        { Type = "ColorPicker", Id = "...", Default = Color3.new(1, 1, 1) }
        { Type = "KeyPicker",   Id = "...", Default = "E" }
        { Type = "Label",       Text = "..." }
        { Type = "Divider" }

    Callbacks belong on the Options table via :OnChanged, not in the spec, so
    that widget creation stays separate from logic. See Feature:GetExtraUI.
]]
local RENDERERS: { [string]: (any, any) -> any } = {
    Slider = function(parent, spec)
        return parent:AddSlider(spec.Id, spec)
    end,
    Dropdown = function(parent, spec)
        return parent:AddDropdown(spec.Id, spec)
    end,
    Input = function(parent, spec)
        return parent:AddInput(spec.Id, spec)
    end,
    ColorPicker = function(parent, spec)
        return parent:AddColorPicker(spec.Id, spec)
    end,
    KeyPicker = function(parent, spec)
        return parent:AddKeyPicker(spec.Id, spec)
    end,
    Label = function(parent, spec)
        return parent:AddLabel(spec.Text)
    end,
    Divider = function(parent, _spec)
        return parent:AddDivider()
    end,
}

function Window:RenderExtra(parent: any, specs: { any })
    for _, spec in specs do
        local renderer = RENDERERS[spec.Type]

        if renderer == nil then
            self._log:Warn(`unknown widget type "{tostring(spec.Type)}"; skipping`)
        else
            local ok, err = pcall(renderer, parent, spec)

            if not ok then
                self._log:Warn(`failed to render {spec.Type} widget: {tostring(err)}`)
            end
        end
    end
end

return Window
