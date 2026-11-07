--[[
    DOOR SYSTEM V2 — настройка клавиши через Q-меню
]]

CreateClientConVar("door_system_key", tostring(KEY_G), true, false, DoorSystem.L("cvar.key"))

local wasDown = false

-- Следит за нажатием назначенной клавиши и запускает нужную команду.
hook.Add("Think", "DoorSystem_KeyTrigger", function()
    local key = GetConVar("door_system_key"):GetInt()
    if key <= 0 then
        wasDown = false
        return
    end

    if gui.IsConsoleVisible() then
        wasDown = false
        return
    end

    -- Если меню открыто и курсор виден, клавиша не должна блокировать его.
    if not IsValid(DoorSystem.ActiveMenu) and vgui.CursorVisible() then
        wasDown = false
        return
    end

    local down = input.IsKeyDown(key)

    if down and not wasDown then
        RunConsoleCommand(DoorSystem.Config.Bind)
    end

    wasDown = down
end)

-- Отправляет серверу глобальные настройки.
-- Значения хранятся в локальной таблице, потому что server convar
-- нельзя напрямую изменять с клиента.
local function GetCurrentServerValue(name, fallback)
    local cvar = GetConVar(name)
    return cvar and cvar:GetFloat() or fallback
end

local function SendSkinSettings(values)
    net.Start("DoorSystem_UpdateSkinSettings")
        net.WriteFloat(math.Clamp(values.chance, 0, 100))

        for _, skinId in ipairs(DoorSystem.Config.RandomSkin.pool or {}) do
            net.WriteFloat(math.Clamp(values.weights[skinId] or 0, 0, 100))
        end
    net.SendToServer()
end

local function AddPercentSlider(panel, title, value, onChanged, tooltip)
    local slider = vgui.Create("DNumSlider", panel)
    slider:SetText(title)
    slider:SetMin(0)
    slider:SetMax(100)
    slider:SetDecimals(0)
    slider:SetValue(value)
    slider:SetTooltip(tooltip or "")
    slider.OnValueChanged = function(self, val)
        onChanged(self, math.Clamp(val, 0, 100))
    end
    panel:AddItem(slider)
    return slider
end

-- Добавляет настройки в панель Utilities.
hook.Add("PopulateToolMenu", "DoorSystem_SettingsTab", function()
    local function Build(panel)
        panel:ClearControls()

        -- Выбор языка / language selector
        panel:Help(DoorSystem.L("settings.language"))

        local langBox = vgui.Create("DComboBox", panel)
        langBox:SetSize(200, 24)

        local langCvar = GetConVar("door_system_language")
        local current = langCvar and langCvar:GetString() or "auto"
        local options = {
            { "auto", DoorSystem.L("settings.lang_auto") },
            { "ru",   DoorSystem.L("settings.lang_ru") },
            { "en",   DoorSystem.L("settings.lang_en") },
        }

        for _, opt in ipairs(options) do
            langBox:AddChoice(opt[2], opt[1], opt[1] == current)
        end

        langBox.OnSelect = function(_, _, _, code)
            RunConsoleCommand("door_system_language", code)
            -- Перестраиваем панель уже на новом языке.
            timer.Simple(0, function()
                if IsValid(panel) then Build(panel) end
            end)
        end

        panel:AddItem(langBox)

        panel:Help(DoorSystem.L("settings.key_title"))

        local binder = vgui.Create("DBinder", panel)
        binder:SetSize(200, 24)
        binder:SetValue(GetConVar("door_system_key"):GetInt())

        binder.OnChange = function(self, num)
            RunConsoleCommand("door_system_key", tostring(num))
        end

        panel:AddItem(binder)
        panel:Help(DoorSystem.L("settings.key_hint"))

        local rs = DoorSystem.Config.RandomSkin
        local values = {
            chance = GetCurrentServerValue(
                "door_system_skin_chance",
                rs.chance or 0
            ) * 100,
            weights = {},
        }

        for _, skinId in ipairs(rs.pool or {}) do
            values.weights[skinId] = GetCurrentServerValue(
                "door_system_skin_weight_" .. skinId,
                (rs.weights and rs.weights[skinId]) or 0
            )
        end

        panel:Help(DoorSystem.L("settings.chance_title"))

        AddPercentSlider(
            panel,
            DoorSystem.L("settings.chance_label"),
            values.chance,
            function(_, val)
                values.chance = val
                SendSkinSettings(values)
            end,
            DoorSystem.L("settings.chance_tip")
        )

        panel:Help(DoorSystem.L("settings.weights_title"))

        for _, skinId in ipairs(rs.pool or {}) do
            AddPercentSlider(
                panel,
                DoorSystem.GetSkinName(skinId),
                values.weights[skinId],
                function(_, val)
                    values.weights[skinId] = val
                    SendSkinSettings(values)
                end,
                DoorSystem.L("settings.weight_tip")
            )
        end

        panel:Help(DoorSystem.L("settings.example_1"))
        panel:ControlHelp(DoorSystem.L("settings.example_2"))
        panel:ControlHelp(DoorSystem.L("settings.example_3"))

        local refresh = panel:Button(DoorSystem.L("settings.apply"))
        refresh.DoClick = function()
            SendSkinSettings(values)
        end
    end

    spawnmenu.AddToolMenuOption("Utilities", "Door System", "DoorSystemSettings", DoorSystem.L("settings.tab"), "", "", Build)
end)
