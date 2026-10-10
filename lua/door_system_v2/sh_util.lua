--[[
    DOOR SYSTEM V2 — общие утилиты
    Используются как на клиенте, так и на сервере.
]]

DoorSystem = DoorSystem or {}

-- Находит конфиг инструмента по его идентификатору.
function DoorSystem.GetTool(id)
    for _, tool in ipairs(DoorSystem.Config.Tools) do
        if tool.id == id then
            return tool
        end
    end

    return nil
end

-- Преобразует секунды в строку формата mm:ss.
function DoorSystem.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60

    return string.format("%d:%02d", minutes, secs)
end

-- Проверяет, что сущность относится к классу дверей.
function DoorSystem.IsValidDoorClass(ent)
    return IsValid(ent) and DoorSystem.Config.ValidClasses[ent:GetClass()] == true
end

-- Проверяет, можно ли ломать дверь в текущий момент.
function DoorSystem.IsBreakable(ent, ply)
    if not DoorSystem.IsValidDoorClass(ent) then return false end
    if ent.DoorSystem_Broken then return false end
    if ent.DoorSystem_Opened then return false end
    if ent.DoorSystem_InProgress then return false end

    local override = hook.Run("DoorSystem_CanBreak", ent, ply)
    if override ~= nil then return override end

    return true
end

-- Проверяет, что игрок держит нужное оружие для выбранного инструмента.
function DoorSystem.CanUseTool(tool, ply)
    if not tool.requiredWeapons then return true end
    if not IsValid(ply) then return false end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return false end

    return tool.requiredWeapons[wep:GetClass()] == true
end

-- Возвращает тип двери по текущему скину.
function DoorSystem.GetDoorType(door)
    if not IsValid(door) then return "wood" end

    local skin = door:GetSkin() or 0
    return DoorSystem.Config.DoorTypes[skin] or "wood"
end

-- Возвращает список { {id=..., time=...}, ... } инструментов для двери.
function DoorSystem.GetDoorToolList(door)
    local cfg = DoorSystem.Config
    local skin = IsValid(door) and (door:GetSkin() or 0) or 0

    return cfg.DoorTools[skin]
        or cfg.DefaultDoorTools[DoorSystem.GetDoorType(door)]
        or cfg.DefaultDoorTools.wood
end

-- Возвращает конфиги инструментов двери в порядке меню, с полем time.
function DoorSystem.GetDoorTools(door)
    local result = {}

    for _, entry in ipairs(DoorSystem.GetDoorToolList(door)) do
        local tool = DoorSystem.GetTool(entry.id)
        if tool then
            table.insert(result, { tool = tool, time = entry.time })
        end
    end

    return result
end

-- Проверяет, подходит ли инструмент для этой двери.
function DoorSystem.ToolAllowedForDoor(tool, door)
    for _, entry in ipairs(DoorSystem.GetDoorToolList(door)) do
        if entry.id == tool.id then return true end
    end

    return false
end

-- Возвращает время взлома выбранным инструментом для этой двери.
function DoorSystem.GetToolTime(tool, door)
    for _, entry in ipairs(DoorSystem.GetDoorToolList(door)) do
        if entry.id == tool.id then return entry.time end
    end

    return 60
end


-- Возвращает тип мини-игры для инструмента (clicker, crosses, bar, saw, boom, molotov).
function DoorSystem.GetMinigameKind(toolId)
    return DoorSystem.Config.MinigameKinds[toolId] or "crosses"
end

-- Уровень сложности двери (1..5): по скину, иначе по типу двери.
function DoorSystem.GetDoorDifficulty(door)
    local cfg = DoorSystem.Config
    local skin = IsValid(door) and (door:GetSkin() or 0) or 0

    local level = cfg.DifficultyBySkin and cfg.DifficultyBySkin[skin]
        or (cfg.DefaultDifficulty and cfg.DefaultDifficulty[DoorSystem.GetDoorType(door)])
        or 1

    return math.Clamp(level, 1, 5)
end

-- Параметры мини-игры инструмента с учётом сложности двери.
-- Массивы из Config.Difficulty разворачиваются в значение нужного уровня.
function DoorSystem.GetKindParams(toolId, door)
    local cfg = DoorSystem.Config
    local kind = DoorSystem.GetMinigameKind(toolId)
    local level = DoorSystem.GetDoorDifficulty(door)

    local params = { kind = kind, level = level }

    for key, value in pairs(cfg.Difficulty[kind] or {}) do
        if istable(value) then
            params[key] = value[math.min(level, #value)]
        else
            params[key] = value
        end
    end

    params.hitsRequired = params.hitsRequired or (cfg.HandsMode and cfg.HandsMode.hitsRequired) or 8
    params.minHitInterval = params.minHitInterval or (cfg.HandsMode and cfg.HandsMode.minHitInterval) or 0.2

    return params
end

-- Настройки попаданий (hitsRequired / minHitInterval) для инструмента на этой двери.
function DoorSystem.GetHandsCfg(toolId, door)
    return DoorSystem.GetKindParams(toolId, door)
end

-- Подпись под инструментом в меню в режиме «руками».
function DoorSystem.GetHandsLabel(toolId, door)
    local kind = DoorSystem.GetMinigameKind(toolId)

    if kind == "bar" then return "шкала" end
    if kind == "boom" or kind == "molotov" then return "взрыв" end
    if kind == "saw" then return DoorSystem.GetHandsCfg(toolId, door).hitsRequired .. " движений" end
    if kind == "debris" then return DoorSystem.GetHandsCfg(toolId, door).hitsRequired .. " обломков" end
    if kind == "clicker" then return DoorSystem.GetHandsCfg(toolId, door).hitsRequired .. " кликов" end

    return DoorSystem.GetHandsCfg(toolId, door).hitsRequired .. " ударов"
end
