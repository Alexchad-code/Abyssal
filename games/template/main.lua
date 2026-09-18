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
            ctx.Warn(`unknown {tostring(enumType)} "{name}"`)
            return fallback
        end

        return value
    end

    local windowConfig = section("Window")
    local themeConfig = section("Theme")
    local uiConfig = section("UI")
    local configsConfig = section("Configs")

    if type(uiConfig.ForceCheckbox) == "boolean" then
        library.ForceCheckbox = uiConfig.ForceCheckbox
    end

    if type(uiConfig.DPI) == "number" and uiConfig.DPI > 0 then
        pcall(function()
            library:SetDPIScale(uiConfig.DPI)
        end)
    end

    -- Configs before the theme: saved state decides which theme to start on.
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
            ctx.Configs = nil
        end
    end

    local state = {}

    if ctx.Configs ~= nil then
        local saved = ctx.Configs:LoadState()

        if type(saved) == "table" then
            state = saved
        end
    end

    local Themes = ctx.LoadFile("libs/Addons/themes.luau")

    if Themes == nil then
        ctx.Warn("themes.luau did not load")
    else
        local themeName = themeConfig.Name

        if themeConfig.Autoload == true and type(state.Theme) == "string" then
            themeName = state.Theme
        end

        if type(themeName) == "string" then
            local colors = themeConfig.Colors

            if type(colors) == "table" and next(colors) ~= nil then
                pcall(Themes.Register, themeName, colors)
            end

            local ok, err = Themes.Apply(library, themeName)

            if not ok then
                ctx.Warn(`theme: {err}`)
            end
        end
    end

    local size = offset(windowConfig.Size, UDim2.fromOffset(720, 600))
    local position = offset(windowConfig.Position, UDim2.fromOffset(6, 6))

    if windowConfig.SavePosition == true then
        size = offset(state.Size, size)
        position = offset(state.Position, position)
    end

    local animations = windowConfig.Animations == true

    local window = library:CreateWindow({
        Title = windowConfig.Title or "Abyssal",
        Footer = windowConfig.Footer or ctx.Version or "",
        Icon = windowConfig.Icon,

        Size = size,
        Position = position,
        Center = windowConfig.Center ~= false,
        Resizable = windowConfig.Resizable ~= false,
        AlwaysOnTop = windowConfig.AlwaysOnTop == true,

        NotifySide = windowConfig.NotifySide or "Right",
        ShowCustomCursor = windowConfig.ShowCustomCursor ~= false,
        ToggleKeybind = enumItem(Enum.KeyCode, windowConfig.ToggleKeybind, Enum.KeyCode.RightControl),

        CornerRadius = windowConfig.CornerRadius or 4,
        Font = enumItem(Enum.Font, windowConfig.Font, Enum.Font.Code),

        Animations = {
            ToggleWindow = animations,
            TabSwitch = animations,
            Groupbox = animations,
            Dropdown = animations,
            KeyPicker = animations,
        },
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

    if ctx.Configs ~= nil then
        if type(configsConfig.Autoload) == "string" and configsConfig.Autoload ~= "" then
            local data, err = ctx.Configs:Load(configsConfig.Autoload)

            if data == nil then
                ctx.Warn(`autoload "{configsConfig.Autoload}": {err}`)
            else
                ctx.Configs:Apply("", data)
            end
        end

        if windowConfig.SavePosition == true or themeConfig.Autoload == true then
            ctx.OnStop(function()
                local out = {}

                if windowConfig.SavePosition == true then
                    local frame = window.MainFrame

                    if frame ~= nil then
                        out.Size = { frame.Size.X.Offset, frame.Size.Y.Offset }
                        out.Position = { frame.Position.X.Offset, frame.Position.Y.Offset }
                    end
                end

                if themeConfig.Autoload == true and Themes ~= nil then
                    local current = Themes.Current()

                    if type(current) == "string" then
                        out.Theme = current
                    end
                end

                ctx.Configs:SaveState(out)
            end)
        end
    end

    ctx.Log(`{built}/{attempted} tabs`)
end
