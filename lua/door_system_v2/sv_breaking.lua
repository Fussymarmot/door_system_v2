--[[
    DOOR SYSTEM V2 — серверная логика взлома

    Два режима:
      timer — взлом по таймеру, без мини-игры; по окончании дверь
              открывается или выпадает (Config.Modes.timer.result);
      hands — мини-игра: прогресс растёт от попаданий по крестикам,
              по заполнению дверь открывается или выпадает
              (Config.Modes.hands.result).
]]

-- Формирует уникальное имя таймера для игрока.
local function TimerName(ply)
    return "DoorSystem_" .. ply:SteamID64()
end

-- Останавливает таймер и снимает флаг активного взлома.
local function StopTimerAndRelease(tname, door)
    if timer.Exists(tname) then
        timer.Remove(tname)
    end

    if IsValid(door) then
        door.DoorSystem_InProgress = false
    end
end

-- Сбрасывает состояние взлома у игрока.
local function ClearPlayerState(ply)
    ply.DoorSystem_Active = false
    ply.DoorSystem_Door = nil
    ply.DoorSystem_Tool = nil
    ply.DoorSystem_Mode = nil
    ply.DoorSystem_Hits = 0
end

-- Отправляет клиенту текущий прогресс.
local function SendProgress(ply, progress, tool, mode)
    net.Start("DoorSystem_Progress")
        net.WriteFloat(progress)
        net.WriteString(tool.id)
        net.WriteString(mode)
    net.Send(ply)
end

-- Отменяет текущий взлом и очищает состояние игрока и двери.
function DoorSystem.CancelBreaking(ply, door)
    if IsValid(ply) then
        StopTimerAndRelease(TimerName(ply), door)
        ClearPlayerState(ply)

        net.Start("DoorSystem_Stop")
            net.WriteBool(false)
        net.Send(ply)
    elseif IsValid(door) then
        door.DoorSystem_InProgress = false
    end
end

-- Завершает взлом успешно и применяет результат режима (открыть / выломать).
local function FinishBreaking(ply, door, mode)
    StopTimerAndRelease(TimerName(ply), door)
    ClearPlayerState(ply)

    net.Start("DoorSystem_Stop")
        net.WriteBool(true)
    net.Send(ply)

    local modeCfg = DoorSystem.Config.Modes and DoorSystem.Config.Modes[mode]
    local result = modeCfg and modeCfg.result or "break"

    if result == "open" then
        DoorSystem.OpenDoor(door)
    else
        DoorSystem.BreakDoor(door)
    end
end

-- Запускает взлом выбранным инструментом в выбранном режиме.
function DoorSystem.StartBreaking(ply, door, tool, mode)
    mode = (mode == "hands") and "hands" or "timer"

    local tname = TimerName(ply)

    if timer.Exists(tname) then
        timer.Remove(tname)
    end

    door.DoorSystem_InProgress = true
    ply.DoorSystem_Active = true
    ply.DoorSystem_Door = door
    ply.DoorSystem_Tool = tool
    ply.DoorSystem_Mode = mode
    ply.DoorSystem_Hits = 0
    ply.DoorSystem_LastHit = 0

    local startTime = CurTime()
    local duration = math.max(DoorSystem.GetToolTime(tool, door) or 0, 1) -- защита от 0/nil
    local handsCfg = DoorSystem.Config.HandsMode or {}
    local hardTimeout = (mode == "hands") and (handsCfg.timeout or 120) or (duration + 20)
    local lastHitTime = 0

    -- Клиент узнаёт о старте и режиме сразу.
    SendProgress(ply, 0, tool, mode)

    timer.Create(tname, 0.1, 0, function()
        if not IsValid(ply) then
            StopTimerAndRelease(tname, door)
            return
        end

        if not IsValid(door) then
            StopTimerAndRelease(tname, door)
            ClearPlayerState(ply)
            return
        end

        if ply:GetPos():DistToSqr(door:GetPos()) > (DoorSystem.Config.MaxBreakDistance ^ 2) then
            DoorSystem.CancelBreaking(ply, door)
            return
        end

        if not ply:Alive() then
            DoorSystem.CancelBreaking(ply, door)
            return
        end

        if not DoorSystem.CanUseTool(tool, ply) then
            DoorSystem.CancelBreaking(ply, door)
            return
        end

        if CurTime() - startTime > hardTimeout then
            DoorSystem.CancelBreaking(ply, door)
            return
        end

        -- В режиме «руками» прогресс двигают только попадания (см. ниже).
        if mode ~= "timer" then return end

        local elapsed = CurTime() - startTime
        local progress = math.Clamp(elapsed / duration, 0, 1)

        SendProgress(ply, progress, tool, mode)

        if tool.hitInterval and (elapsed - lastHitTime) >= tool.hitInterval then
            lastHitTime = elapsed
            if tool.hitSound then
                door:EmitSound(tool.hitSound, 75, math.random(95, 105))
            end

            net.Start("DoorSystem_Hit")
                net.WriteEntity(ply)
                net.WriteString(tool.id)
            net.Broadcast()
        end

        if progress >= 1 then
            FinishBreaking(ply, door, mode)
        end
    end)
end

-- Сообщает клиентам, что дверь больше не ломается (выломана или открыта).
local function BroadcastDoorState(door, opened)
    net.Start("DoorSystem_Broken")
        net.WriteEntity(door)
        net.WriteBool(opened == true)
    net.Broadcast()
end

-- Разблокирует дверь и открывает её сама, не срывая с петель.
function DoorSystem.OpenDoor(door)
    if not IsValid(door) then return end
    if door.DoorSystem_Broken or door.DoorSystem_Opened then return end

    door.DoorSystem_Opened = true
    door.DoorSystem_Locked = false -- снимает блокировку из sv_lock.lua
    door.DoorSystem_ClosedAngle = nil
    door.DoorSystem_ClosedPos = nil

    door:EmitSound("doors/door_latch3.wav", 75, 100)

    -- Сначала разблокируем, затем открываем (порядок важен для prop_door_rotating).
    door:Fire("Unlock", "", 0)
    door:Fire("Open", "", 0.1)

    BroadcastDoorState(door, true)
end

-- Прячет оригинальную дверь и создаёт её физический сломанный аналог.
function DoorSystem.BreakDoor(door)
    if not IsValid(door) then return end
    if door.DoorSystem_Broken then return end
    door.DoorSystem_Broken = true

    local pos, ang = door:GetPos(), door:GetAngles()
    local model = door:GetModel()
    local skin = door:GetSkin()

    door:EmitSound("physics/wood/wood_furniture_break2.wav", 80, 100)

    door:SetSolid(SOLID_NONE)
    door:SetNotSolid(true)
    door:SetNoDraw(true)
    door:SetCollisionGroup(COLLISION_GROUP_WORLD)

    if model and model ~= "" then
        local broken = ents.Create("prop_physics")
        if IsValid(broken) then
            broken:SetModel(model)
            broken:SetPos(pos)
            broken:SetAngles(ang)
            broken:Spawn()
            broken:SetSkin(skin or 0)
            broken:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

            local phys = broken:GetPhysicsObject()
            if IsValid(phys) then
                phys:Wake()
                local dir = ang:Forward()
                phys:ApplyForceCenter(dir * phys:GetMass() * 200)
                phys:AddAngleVelocity(VectorRand() * 80)
            end

            if DoorSystem.Config.RemoveBrokenAfter and DoorSystem.Config.RemoveBrokenAfter > 0 then
                timer.Simple(DoorSystem.Config.RemoveBrokenAfter, function()
                    if IsValid(broken) then
                        broken:Remove()
                    end
                end)
            end
        end
    end

    BroadcastDoorState(door, false)
end

net.Receive("DoorSystem_Start", function(_, ply)
    if not IsValid(ply) then return end

    local door = net.ReadEntity()
    local toolId = net.ReadString()
    local mode = net.ReadString()

    local function Reject()
        net.Start("DoorSystem_StartResult")
            net.WriteBool(false)
        net.Send(ply)
    end

    if mode ~= "timer" and mode ~= "hands" then return Reject() end
    if ply.DoorSystem_Active then return Reject() end

    local tool = DoorSystem.GetTool(toolId)
    if not tool then return Reject() end
    if not IsValid(door) then return Reject() end
    if not DoorSystem.IsBreakable(door, ply) then return Reject() end
    if not DoorSystem.ToolAllowedForDoor(tool, door) then return Reject() end
    if door.DoorSystem_InProgress then return Reject() end
    if ply:GetPos():DistToSqr(door:GetPos()) > (DoorSystem.Config.MaxUseDistance ^ 2) then return Reject() end
    if not DoorSystem.CanUseTool(tool, ply) then return Reject() end

    net.Start("DoorSystem_StartResult")
        net.WriteBool(true)
        net.WriteString(mode)
    net.Send(ply)

    DoorSystem.StartBreaking(ply, door, tool, mode)
end)

net.Receive("DoorSystem_Cancel", function(_, ply)
    if not IsValid(ply) or not ply.DoorSystem_Active then return end
    DoorSystem.CancelBreaking(ply, ply.DoorSystem_Door)
end)

hook.Add("PlayerDisconnected", "DoorSystem_CleanupOnDisconnect", function(ply)
    local tname = TimerName(ply)
    local door = ply.DoorSystem_Door

    StopTimerAndRelease(tname, door)
end)

-- Попадание по крестику в мини-игре («руками»): двигает прогресс.
net.Receive("DoorSystem_MinigameHit", function(_, ply)
    if not IsValid(ply) or not ply.DoorSystem_Active then return end
    if ply.DoorSystem_Mode ~= "hands" then return end

    local door, tool = ply.DoorSystem_Door, ply.DoorSystem_Tool
    if not IsValid(door) or not tool then return end

    local cfg = DoorSystem.Config.HandsMode or {}

    -- Антиспам: клиенту доверять нельзя.
    if CurTime() - (ply.DoorSystem_LastHit or 0) < (cfg.minHitInterval or 0.2) then return end
    ply.DoorSystem_LastHit = CurTime()

    ply.DoorSystem_Hits = (ply.DoorSystem_Hits or 0) + 1
    local progress = math.Clamp(ply.DoorSystem_Hits / math.max(cfg.hitsRequired or 8, 1), 0, 1)

    if tool.hitSound then
        door:EmitSound(tool.hitSound, 75, math.random(95, 105))
    end

    net.Start("DoorSystem_Hit")
        net.WriteEntity(ply)
        net.WriteString(tool.id)
    net.Broadcast()

    SendProgress(ply, progress, tool, "hands")

    if progress >= 1 then
        FinishBreaking(ply, door, "hands")
    end
end)
