--[[
    DOOR SYSTEM V2 — блокировка открытия дверей со спецскином
]]

local lockedDoorMessageCooldown = {}

-- Блокирует обычное использование заблокированной двери.
hook.Add("PlayerUse", "DoorSystem_BlockLockedDoors", function(ply, ent)
    if not IsValid(ent) then return end
    if not IsValid(ply) then return end
    if not ent.DoorSystem_Locked then return end
    if ent.DoorSystem_Broken then return end

    local now = CurTime()
    local key = ply:EntIndex() .. ":" .. ent:EntIndex()

    if not lockedDoorMessageCooldown[key] or now - lockedDoorMessageCooldown[key] >= 0.25 then
        ply:ChatPrint("Дверь заблокирована. Её можно только выломать.")
        lockedDoorMessageCooldown[key] = now
    end

    return false
end)

-- Предотвращает урон по заблокированной двери, чтобы она не открывалась через триггеры.
hook.Add("EntityTakeDamage", "DoorSystem_BlockDamageOnLockedDoors", function(target, dmginfo)
    if not IsValid(target) then return end
    if not target.DoorSystem_Locked then return end
    if target.DoorSystem_Broken then return end

    dmginfo:SetDamage(0)
    return true
end)

-- Блокирует entity-инпуты на заблокированной двери.
hook.Add("AcceptInput", "DoorSystem_BlockInputsOnLockedDoors", function(ent, input, activator, caller)
    if not IsValid(ent) then return end
    if not ent.DoorSystem_Locked then return end
    if ent.DoorSystem_Broken then return end

    return true
end)

-- Поддерживает заблокированную дверь в закрытом состоянии.
hook.Add("Think", "DoorSystem_HoldLockedDoorsShut", function()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent.DoorSystem_Locked and not ent.DoorSystem_Broken then
            if not ent.DoorSystem_ClosedAngle then
                ent.DoorSystem_ClosedAngle = ent:GetAngles()
                ent.DoorSystem_ClosedPos = ent:GetPos()
            end

            if ent:GetAngles() ~= ent.DoorSystem_ClosedAngle then
                ent:SetAngles(ent.DoorSystem_ClosedAngle)
            end
            if ent:GetPos() ~= ent.DoorSystem_ClosedPos then
                ent:SetPos(ent.DoorSystem_ClosedPos)
            end
        end
    end
end)