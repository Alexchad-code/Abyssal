return {
    GameId = 0,
    Places = { 0 },

    Window = {
        Title = "Abyssal",
        Footer = nil,
        Icon = "waves",

        Size = { 720, 600 },
        Position = { 6, 6 },
        Center = true,
        Resizable = true,
        AlwaysOnTop = false,

        -- Remember size and position between sessions.
        SavePosition = true,

        NotifySide = "Right",
        ShowCustomCursor = true,
        ToggleKeybind = "RightControl",

        CornerRadius = 4,
        Font = "Code",
        Animations = false,
    },

    Theme = {
        Name = "Abyssal",
        Colors = {},

        -- Remember the theme picked in the UI Settings tab.
        Autoload = true,
    },

    UI = {
        DPI = 100,
        ForceCheckbox = false,
    },

    Watermark = {
        Enabled = false,
        Text = "Abyssal",
        Position = { 10, 10 },
        TextSize = 14,
        Transparency = 0.25,
    },

    Configs = {
        Folder = "Abyssal",
        Autoload = nil,
    },

    Tabs = {},
}
