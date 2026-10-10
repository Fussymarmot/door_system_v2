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
