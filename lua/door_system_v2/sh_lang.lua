--[[
    DOOR SYSTEM V2 — локализация / localization

    Поддерживаются языки: ru, en. / Supported languages: ru, en.

    Выбор языка / Language selection:
      клиент:  door_system_language  ("auto" | "ru" | "en"), также в Q-меню
      сервер:  door_system_language  (консоль сервера, для логов)
      "auto" — берётся из gmod_language: "ru" -> русский, всё остальное -> английский.

    Как добавить язык / How to add a language:
      DoorSystem.Lang.Strings.de = { ["key"] = "text", ... }
      и добавить "de" в DoorSystem.Lang.Available.
      Ненайденные ключи откатываются на английский, затем на русский.
]]

DoorSystem = DoorSystem or {}
DoorSystem.Lang = DoorSystem.Lang or {}

local Lang = DoorSystem.Lang

Lang.Available = { "ru", "en" }
Lang.Fallback = { "en", "ru" }

-- На клиенте convar создаётся как клиентский (сохраняется между сессиями),
-- на сервере — как обычный серверный.
if CLIENT then
    CreateClientConVar("door_system_language", "auto", true, false,
        "Door System language: auto / ru / en")
else
    CreateConVar("door_system_language", "auto", FCVAR_ARCHIVE,
        "Door System language (server console): auto / ru / en")
end

Lang.Strings = {}

Lang.Strings.ru = {
    -- Общие / common
    ["prefix"] = "[Door System] ",

    -- Сообщения / messages
    ["msg.startup_hint"] = "Чтобы использовать топор или лом — держи их в руках перед взломом. Клавишу можно поменять в Q-меню -> Utilities -> Door System.",
    ["msg.start_failed"] = "Не удалось начать взлом.",
    ["msg.door_locked"] = "Дверь заблокирована. Её можно только выломать.",
    ["msg.easter_egg"] = "Дверь. Ты. Всё.",

    -- Логи сервера / server logs
    ["log.rerolled"] = "%s, двери пересчитаны: %d",
    ["log.chance_changed"] = "Шанс кастомной двери изменён (%s -> %s)",
    ["log.weight_changed"] = "Вес скина %s изменён (%s -> %s)",
    ["log.admin_changed"] = "Настройки кастомных дверей изменены администратором",

    -- ConVar-описания / convar descriptions
    ["cvar.skin_chance"] = "Шанс появления кастомной двери (0.0 - 1.0)",
    ["cvar.skin_weight"] = "Вес кастомного скина двери %s (0 - 100)",
    ["cvar.key"] = "Клавиша для взлома дверей (Door System)",

    -- HUD / меню / menu
    ["ui.break_door"] = "Взлом двери",
    ["ui.no_tool"] = "нет инструмента",

    -- Подписи под инструментами / tool labels
    ["label.bar"] = "шкала",
    ["label.boom"] = "взрыв",
    ["label.moves"] = "%d движений",
    ["label.debris"] = "%d обломков",
    ["label.clicks"] = "%d кликов",
    ["label.hits"] = "%d ударов",

    -- Мини-игры / minigames
    ["mg.hold"] = "Держи!",
    ["mg.bar_hint"] = "ПРОБЕЛ — вправо, отпусти — влево",
    ["mg.saw_active"] = "Води вправо-влево",
    ["mg.saw_idle"] = "Зажми ползунок и води вправо-влево",
    ["mg.throw"] = "Выбрось в сторону!",
    ["mg.difficulty"] = "Сложность: %d/5",

    -- Инструменты / tools
    ["tool.fist"] = "Голые руки",
    ["tool.axe"] = "Топор",
    ["tool.crowbar"] = "Монтировка",
    ["tool.hacksaw"] = "Ножовка",
    ["tool.shovel"] = "Лопата",
    ["tool.handmade_grenade"] = "Самодельная граната",
    ["tool.grenade"] = "Граната",
    ["tool.dynamite"] = "Динамит",
    ["tool.molotov"] = "Молотов",

    -- Скины дверей / door skins
    ["skin.14"] = "Заколоченная",
    ["skin.15"] = "Железная квартирная",
    ["skin.16"] = "Деревянная",
    ["skin.17"] = "Бронированная",
    ["skin.18"] = "Завал",
    ["skin.19"] = "Решётка",
    ["skin.20"] = "Заражённая",
    ["skin.unknown"] = "Скин %s",

    -- Настройки Q-меню / settings
    ["settings.tab"] = "Настройки",
    ["settings.language"] = "Язык / Language:",
    ["settings.lang_auto"] = "Авто / Auto",
    ["settings.lang_ru"] = "Русский",
    ["settings.lang_en"] = "English",
    ["settings.key_title"] = "Клавиша для взлома дверей (Day R style):",
    ["settings.key_hint"] = "Нажми на поле выше, затем нужную клавишу — она сразу назначится.",
    ["settings.chance_title"] = "Вероятность появления кастомной двери",
    ["settings.chance_label"] = "Кастомная дверь",
    ["settings.chance_tip"] = "Шанс первого броска: станет ли дверь кастомной вообще.",
    ["settings.weights_title"] = "Если кастомная дверь выпала, выбирается один из скинов ниже по весам.",
    ["settings.weight_tip"] = "Вес этого типа среди выпавших кастомных дверей. Веса нормализуются автоматически.",
    ["settings.example_1"] = "Пример: кастомные двери 20%, железная 70%, деревянная 30%.",
    ["settings.example_2"] = "Тогда железная будет выпадать с вероятностью 14% от всех дверей.",
    ["settings.example_3"] = "Сумма весов может быть любой — 70 + 30, например, автоматически станет 70% / 30%.",
    ["settings.apply"] = "Применить настройки сейчас",
}

Lang.Strings.en = {
    -- Common
    ["prefix"] = "[Door System] ",

    -- Messages
    ["msg.startup_hint"] = "To use an axe or a crowbar, hold it in your hands before breaking in. You can change the key in Q-menu -> Utilities -> Door System.",
    ["msg.start_failed"] = "Failed to start breaking the door.",
    ["msg.door_locked"] = "The door is locked. It can only be broken down.",
    ["msg.easter_egg"] = "Door. You. Done.",

    -- Server logs
    ["log.rerolled"] = "%s, doors rerolled: %d",
    ["log.chance_changed"] = "Custom door chance changed (%s -> %s)",
    ["log.weight_changed"] = "Skin %s weight changed (%s -> %s)",
    ["log.admin_changed"] = "Custom door settings were changed by an administrator",

    -- ConVar descriptions
    ["cvar.skin_chance"] = "Chance of a custom door appearing (0.0 - 1.0)",
    ["cvar.skin_weight"] = "Weight of custom door skin %s (0 - 100)",
    ["cvar.key"] = "Key for breaking doors (Door System)",

    -- HUD / menu
    ["ui.break_door"] = "Breaking the door",
    ["ui.no_tool"] = "no tool",

    -- Tool labels
    ["label.bar"] = "meter",
    ["label.boom"] = "explosion",
    ["label.moves"] = "%d strokes",
    ["label.debris"] = "%d pieces of debris",
    ["label.clicks"] = "%d clicks",
    ["label.hits"] = "%d hits",

    -- Minigames
    ["mg.hold"] = "Hold it!",
    ["mg.bar_hint"] = "SPACE — move right, release — move left",
    ["mg.saw_active"] = "Move left and right",
    ["mg.saw_idle"] = "Grab the slider and move it left and right",
    ["mg.throw"] = "Throw it aside!",
    ["mg.difficulty"] = "Difficulty: %d/5",

    -- Tools
    ["tool.fist"] = "Bare hands",
    ["tool.axe"] = "Axe",
    ["tool.crowbar"] = "Crowbar",
    ["tool.hacksaw"] = "Hacksaw",
    ["tool.shovel"] = "Shovel",
    ["tool.handmade_grenade"] = "Homemade grenade",
    ["tool.grenade"] = "Grenade",
    ["tool.dynamite"] = "Dynamite",
    ["tool.molotov"] = "Molotov",

    -- Door skins
    ["skin.14"] = "Boarded-up",
    ["skin.15"] = "Iron apartment door",
    ["skin.16"] = "Wooden",
    ["skin.17"] = "Armored",
    ["skin.18"] = "Rubble",
    ["skin.19"] = "Grate",
    ["skin.20"] = "Infected",
    ["skin.unknown"] = "Skin %s",

    -- Q-menu settings
    ["settings.tab"] = "Settings",
    ["settings.language"] = "Язык / Language:",
    ["settings.lang_auto"] = "Авто / Auto",
    ["settings.lang_ru"] = "Русский",
    ["settings.lang_en"] = "English",
    ["settings.key_title"] = "Key for breaking doors (Day R style):",
    ["settings.key_hint"] = "Click the field above, then press the key you want — it is bound immediately.",
    ["settings.chance_title"] = "Chance of a custom door appearing",
    ["settings.chance_label"] = "Custom door",
    ["settings.chance_tip"] = "Chance of the first roll: whether a door becomes a custom one at all.",
    ["settings.weights_title"] = "If a custom door is rolled, one of the skins below is picked by weight.",
    ["settings.weight_tip"] = "Weight of this type among the rolled custom doors. Weights are normalized automatically.",
    ["settings.example_1"] = "Example: custom doors 20%, iron 70%, wooden 30%.",
    ["settings.example_2"] = "Then the iron door will appear with a 14% probability among all doors.",
    ["settings.example_3"] = "The weights can add up to anything — 70 + 30, for example, automatically becomes 70% / 30%.",
    ["settings.apply"] = "Apply settings now",
}

-- Текущий язык: "ru" или "en" (или любой добавленный).
function Lang.Current()
    local setting = GetConVar("door_system_language")
    local code = setting and setting:GetString() or "auto"

    if code == "" or code == "auto" then
        local gm = GetConVar("gmod_language")
        code = gm and gm:GetString() or "en"
    end

    code = string.lower(code):sub(1, 2)

    if Lang.Strings[code] then return code end
    return "en"
end

-- Возвращает строку по ключу; дополнительные аргументы идут в string.format.
function Lang.Get(key, ...)
    local text = (Lang.Strings[Lang.Current()] or {})[key]

    if text == nil then
        for _, code in ipairs(Lang.Fallback) do
            text = (Lang.Strings[code] or {})[key]
            if text ~= nil then break end
        end
    end

    if text == nil then return key end

    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end

    return text
end

-- Короткий алиас: DoorSystem.L("key", ...)
DoorSystem.L = Lang.Get

-- Название инструмента (с откатом на поле name из конфига).
function DoorSystem.GetToolName(tool)
    if not tool then return DoorSystem.L("ui.break_door") end
    local key = "tool." .. tostring(tool.id)
    local text = DoorSystem.L(key)
    if text == key then return tool.name or tostring(tool.id) end
    return text
end

-- Название скина двери (с откатом на Config.RandomSkin.names).
function DoorSystem.GetSkinName(skinId)
    local key = "skin." .. tostring(skinId)
    local text = DoorSystem.L(key)
    if text ~= key then return text end

    local rs = DoorSystem.Config and DoorSystem.Config.RandomSkin
    local fallback = rs and rs.names and rs.names[skinId]
    return fallback or DoorSystem.L("skin.unknown", tostring(skinId))
end

-- Сервер -> клиент: показать локализованное сообщение в чате игрока.
-- Язык выбирается на стороне клиента, поэтому передаётся только ключ.
if SERVER then
    function DoorSystem.SendMessage(ply, key)
        if not IsValid(ply) then return end
        net.Start("DoorSystem_Msg")
            net.WriteString(key)
        net.Send(ply)
    end
else
    net.Receive("DoorSystem_Msg", function()
        local key = net.ReadString()
        chat.AddText(Color(255, 210, 90), DoorSystem.L("prefix"), color_white, DoorSystem.L(key))
    end)
end
