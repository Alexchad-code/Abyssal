return {
    Name = "UI Settings",
    Icon = "settings",

    Build = function(ctx, config, tab)
        local library = ctx.Library

        local function notify(text: string, duration: number?)
            library:Notify({
                Title = "Abyssal",
                Text = text,
                Duration = duration or 4,
            })
        end

        local Themes = ctx.LoadFile("libs/Addons/themes.luau")

        if Themes == nil then
            tab:AddGroupbox({ Side = "Left", Name = "Themes", IconName = "paintbrush" })
                :AddLabel("themes.luau did not load")
        else
            local themesBox = tab:AddGroupbox({
                Side = "Left",
                Name = "Themes",
                IconName = "paintbrush",
            })

            themesBox:AddDropdown("ui.theme", {
                Text = "Theme list",
                Values = Themes.Names(),
                Default = Themes.Current() or (type(config.Theme) == "table" and config.Theme.Name) or "Abyssal",
                Multi = false,
            })

            ctx.Options["ui.theme"]:OnChanged(function(name: string)
                local ok, err = Themes.Apply(library, name)

                if not ok then
                    notify(`Could not apply that theme: {err}`, 5)
                end
            end)

            themesBox:AddDivider()

            themesBox:AddInput("ui.customTheme", {
                Text = "Custom theme name",
                Default = "",
                Placeholder = "my theme",
            })

            local function hex(value: Color3): string
                local function part(channel: number): string
                    return string.format("%02x", math.floor(channel * 255 + 0.5))
                end

                return part(value.R) .. part(value.G) .. part(value.B)
            end

            themesBox:AddButton({
                Text = "Save current as theme",
                Tooltip = "Registers the colours on screen as a new theme.",
                Func = function()
                    local option = ctx.Options["ui.customTheme"]
                    local name = option ~= nil and option.Value or nil

                    if type(name) ~= "string" or name == "" then
                        notify("Give the theme a name first.")
                        return
                    end

                    local scheme = library.Scheme

                    local ok = pcall(Themes.Register, name, {
                        BackgroundColor = hex(scheme.BackgroundColor),
                        MainColor = hex(scheme.MainColor),
                        AccentColor = hex(scheme.AccentColor),
                        OutlineColor = hex(scheme.OutlineColor),
                        FontColor = hex(scheme.FontColor),
                    })

                    if not ok then
                        notify("Could not register that theme.", 5)
                        return
                    end

                    local dropdown = ctx.Options["ui.theme"]

                    if dropdown ~= nil and dropdown.SetValues ~= nil then
                        dropdown:SetValues(Themes.Names())
                    end

                    notify(`Saved theme "{name}"`)
                end,
            })
        end

        local configsBox = tab:AddGroupbox({
            Side = "Right",
            Name = "Configuration",
            IconName = "folder-cog",
        })

        local configs = ctx.Configs

        if configs == nil then
            configsBox:AddLabel("configs.luau did not load, or this executor has no filesystem.")
            return
        end

        configsBox:AddInput("ui.configName", {
            Text = "Config name",
            Default = "default",
            Placeholder = "default",
        })

        local list = configsBox:AddDropdown("ui.config", {
            Text = "Config list",
            Values = configs:List(),
            Default = "",
            Multi = false,
        })

        local function refresh()
            local names = configs:List()

            if #names == 0 then
                names = { "" }
            end

            list:SetValues(names)
        end

        local function targetName(): string?
            local typed = ctx.Options["ui.configName"]
            local selected = ctx.Options["ui.config"]

            local name = typed ~= nil and typed.Value or nil

            if type(name) ~= "string" or name == "" then
                name = selected ~= nil and selected.Value or nil
            end

            if type(name) ~= "string" or name == "" then
                return nil
            end

            return name
        end

        configsBox:AddButton({
            Text = "Create config",
            Tooltip = "Writes every setting under this place id.",
            Func = function()
                local name = targetName()

                if name == nil then
                    notify("Give the config a name first.")
                    return
                end

                local ok, err = configs:Save(name, configs:Snapshot(""))

                notify(ok and `Saved "{name}"` or `Could not save: {err}`, 5)

                if ok then
                    refresh()
                end
            end,
        })

        configsBox:AddDivider()

        configsBox:AddButton({
            Text = "Load config",
            Tooltip = "Applies a saved config.",
            DoubleClick = true,
            Func = function()
                local name = targetName()

                if name == nil then
                    notify("Pick a config or type a name.")
                    return
                end

                local data, err = configs:Load(name)

                if data == nil then
                    notify(`Could not load: {err}`, 5)
                    return
                end

                local applied = configs:Apply("", data)

                notify(`Loaded "{name}" ({applied} settings)`)
            end,
        })

        configsBox:AddButton({
            Text = "Delete config",
            Tooltip = "Removes the config file.",
            Risky = true,
            DoubleClick = true,
            Func = function()
                local name = targetName()

                if name == nil then
                    notify("Pick a config to delete.")
                    return
                end

                local ok, err = configs:Delete(name)

                notify(ok and `Deleted "{name}"` or `Could not delete: {err}`, 5)

                if ok then
                    refresh()
                end
            end,
        })

        configsBox:AddDivider()

        configsBox:AddLabel(`Stored in {configs:Directory()}/`)
    end,
}
