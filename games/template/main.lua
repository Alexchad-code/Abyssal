return function(ctx)
    local FOLDER = ctx.GameFolder or "games/template"
    local library = ctx.Library

    local config, configErr = ctx.LoadFile(`{FOLDER}/config.lua`)

    if config == nil then
        ctx.Warn(`config: {configErr}`)
        config = {}
    end

    local function section(name: string): any
        local value = config[name]
        return type(value) == "table" and value or {}
    end

    local function offset(pair: any, fallback: UDim2): UDim2
        if type(pair) ~= "table" or type(pair[1]) ~= "number" or type(pair[2]) ~= "number" then
            return fallback
        end

        return UDim2.fromOffset(pair[1], pair[2])
    end

    local function enumItem(enumType: any, name: any, fallback: any): any
        if type(name) ~= "string" then
            return fallback
        end

        local ok, value = pcall(function()
            return enumType[name]
        end)

        if not ok or value == nil then
            ctx.Warn(`unknown {tostring(enumType)} name "{name}"`)
            return fallback
        end

        return value
    end

    local windowConfig = section("Window")
    local themeConfig = section("Theme")
    local uiConfig = section("UI")
    local configsConfig = section("Configs")

    -- Library-wide, so before the window exists.
    if type(uiConfig.ForceCheckbox) == "boolean" then
        library.ForceCheckbox = uiConfig.ForceCheckbox
    end

    if type(uiConfig.ShowToggleFrameInKeybinds) == "boolean" then
        library.ShowToggleFrameInKeybinds = uiConfig.ShowToggleFrameInKeybinds
    end

    if type(uiConfig.DPI) == "number" and uiConfig.DPI > 0 then
        pcall(function()
            library:SetDPIScale(uiConfig.DPI)
        end)
    end

    -- Theme, before the window is drawn.
    local Themes = ctx.LoadFile("libs/Addons/themes.luau")

    if Themes == nil then
        ctx.Warn("themes.luau did not load")
    elseif type(themeConfig.Name) == "string" then
        local colors = themeConfig.Colors

        if type(colors) == "table" and next(colors) ~= nil then
            pcall(Themes.Register, themeConfig.Name, colors)
        end

        local ok, err = Themes.Apply(library, themeConfig.Name)

        if not ok then
            ctx.Warn(`theme: {err}`)
        end
    end

    local animations = windowConfig.Animations == true

    local window = library:CreateWindow({
        Title = windowConfig.Title or "Abyssal",
        Footer = windowConfig.Footer or ctx.Version or "",
        Icon = windowConfig.Icon,

        Size = offset(windowConfig.Size, UDim2.fromOffset(720, 600)),
        Position = offset(windowConfig.Position, UDim2.fromOffset(6, 6)),
        Center = windowConfig.Center ~= false,
        Resizable = windowConfig.Resizable ~= false,
        AutoShow = windowConfig.AutoShow ~= false,
        AlwaysOnTop = windowConfig.AlwaysOnTop == true,
        UnlockMouseWhileOpen = windowConfig.UnlockMouseWhileOpen ~= false,

        NotifySide = windowConfig.NotifySide or "Right",
        ShowCustomCursor = windowConfig.ShowCustomCursor ~= false,
        ToggleKeybind = enumItem(Enum.KeyCode, windowConfig.ToggleKeybind, Enum.KeyCode.RightControl),

        CornerRadius = windowConfig.CornerRadius or 4,
        Font = enumItem(Enum.Font, windowConfig.Font, Enum.Font.Code),
        BackgroundImage = windowConfig.BackgroundImage or "",

        GlobalSearch = windowConfig.GlobalSearch == true,
        Snapping = windowConfig.Snapping == true,
        EnableSidebarResize = windowConfig.EnableSidebarResize == true,
        EnableCompacting = windowConfig.EnableCompacting ~= false,
        SidebarCompacted = windowConfig.SidebarCompacted == true,

        ShowMobileButtons = windowConfig.ShowMobileButtons ~= false,
        MobileButtonsSide = windowConfig.MobileButtonsSide or "Left",

        Animations = {
            ToggleWindow = animations,
            TabSwitch = animations,
            Groupbox = animations,
            Dropdown = animations,
            KeyPicker = animations,
        },
        TabTransitionTime = windowConfig.TabTransitionTime or 0.22,
    })

    ctx.Window = window

    local built, attempted = 0, 0

    local function buildTabs(source: string, names: { string })
        for _, name in names do
            attempted += 1

            local definition, err = ctx.LoadFile(`{source}/{name}.lua`)

            if definition == nil then
                ctx.Warn(`tab "{name}": {err}`)
            elseif type(definition) ~= "table" or type(definition.Build) ~= "function" then
                ctx.Warn(`tab "{name}" needs a Build function`)
            else
                local ok, tabErr = pcall(function()
                    local tab = window:AddTab(definition.Name or name, definition.Icon)
                    definition.Build(ctx, config, tab)
                end)

                if ok then
                    built += 1
                else
                    ctx.Warn(`tab "{name}": {tostring(tabErr)}`)
                end
            end
        end
    end

    buildTabs("libs/tabs", ctx.SharedTabs or {})
    buildTabs(`{FOLDER}/tabs`, config.Tabs or {})

    local Configs = ctx.LoadFile("libs/Addons/configs.luau")

    if Configs == nil then
        ctx.Warn("configs.luau did not load")
    else
        ctx.Configs = Configs.new({
            Folder = configsConfig.Folder or "Abyssal",
            Game = tostring(game.PlaceId),
            Library = library,
        })

        local available, reason = ctx.Configs:Available()

        if not available then
            ctx.Warn(`configs: {reason}`)
        elseif type(configsConfig.Autoload) == "string" and configsConfig.Autoload ~= "" then
            local data, err = ctx.Configs:Load(configsConfig.Autoload)

            if data == nil then
                ctx.Warn(`autoload "{configsConfig.Autoload}": {err}`)
            else
                ctx.Configs:Apply("", data)
            end
        end
    end

    ctx.Log(`{built}/{attempted} tabs`)
end
