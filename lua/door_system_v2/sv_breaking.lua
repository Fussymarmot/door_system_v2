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
    ply.DoorSystem_Kind = nil
    ply.DoorSystem_BarProgress = nil
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
    -- Останавливаем звуки инструмента/эффекта до показа картинки открытой двери.
    -- Иначе длинные звуки продолжают играть уже после завершения мини-игры.
    if IsValid(door) and IsValid(ply) then
        local activeTool = ply.DoorSystem_Tool
        local activeKind = ply.DoorSystem_Kind
        if activeTool and activeTool.hitSound then
            door:StopSound(activeTool.hitSound)
        end
        local effects = DoorSystem.Config.Effects or {}
        local effect = activeKind and effects[activeKind]
        if effect and effect.sound then
            door:StopSound(effect.sound)
        end
        local debrisCfg = DoorSystem.GetKindParams and activeTool and DoorSystem.GetKindParams(activeTool.id, door)
        if debrisCfg and debrisCfg.endSound then
            door:StopSound(debrisCfg.endSound)
        end
    end

    StopTimerAndRelease(TimerName(ply), door)
    ClearPlayerState(ply)

    local modeCfg = DoorSystem.Config.Modes and DoorSystem.Config.Modes[mode]
    local result = modeCfg and modeCfg.result or "break"

    -- У некоторых дверей (завал) свой результат: дверь просто исчезает.
    local bySkin = DoorSystem.Config.DoorResultBySkin
    if bySkin and IsValid(door) and bySkin[door:GetSkin() or 0] then
        result = bySkin[door:GetSkin() or 0]
    end

    if result == "open" then
        DoorSystem.OpenDoor(door)
    elseif result == "remove" then
        DoorSystem.RemoveDoor(door)
    else
        DoorSystem.BreakDoor(door)
    end

    -- Сообщаем клиенту об успехе последним: открывающий/ломающий звук не
    -- должен начинаться уже после переключения панели на открытую дверь.
    net.Start("DoorSystem_Stop")
        net.WriteBool(true)
    net.Send(ply)
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
    ply.DoorSystem_BarProgress = 0
    ply.DoorSystem_BarLast = CurTime()
    ply.DoorSystem_BarSound = 0

    local kind = DoorSystem.GetMinigameKind(tool.id, door)
    ply.DoorSystem_Kind = (mode == "hands") and kind or nil

    -- Игры-эффекты (взрыв, молотов): без участия игрока, дверь открывается
    -- по окончании анимации, звук играет сервер.
    local effect = (mode == "hands") and DoorSystem.Config.Effects and DoorSystem.Config.Effects[kind] or nil

    local startTime = CurTime()
    local duration = math.max(DoorSystem.GetToolTime(tool, door) or 0, 1) -- защита от 0/nil
    if effect then
        duration = math.max(effect.duration or 1.3, 0.5)
        if effect.sound then
            door:EmitSound(effect.sound, 85, 100)
        end
    end
    local handsCfg = DoorSystem.Config.HandsMode or {}
    local hardTimeout = effect and (duration + 20) or ((mode == "hands") and (handsCfg.timeout or 120) or (duration + 20))
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

        -- В режиме «руками» прогресс двигают только попадания (см. ниже);
        -- исключение — игры-эффекты, у них прогресс идёт по времени анимации.
        if mode ~= "timer" and not effect then return end

        local elapsed = CurTime() - startTime
        local progress = math.Clamp(elapsed / duration, 0, 1)

        SendProgress(ply, progress, tool, mode)

        if not effect and tool.hitInterval and (elapsed - lastHitTime) >= tool.hitInterval then
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

    -- Сначала разблокируем, затем открываем (порядок важен для prop_door_rotating).
    door:Fire("Unlock", "", 0)
    door:Fire("Open", "", 0.1)

    BroadcastDoorState(door, true)
end

-- Убирает именно эту дверь (завал после раскопок): без открывания и без
-- физического обломка. Соседние двери не затрагиваются.
function DoorSystem.RemoveDoor(door)
    if not IsValid(door) then return end
    if door.DoorSystem_Broken then return end

    door.DoorSystem_Broken = true
    door.DoorSystem_Locked = false -- снимает блокировку из sv_lock.lua
    door.DoorSystem_ClosedAngle = nil
    door.DoorSystem_ClosedPos = nil

    door:SetSolid(SOLID_NONE)
    door:SetNotSolid(true)
    door:SetNoDraw(true)
    door:SetCollisionGroup(COLLISION_GROUP_WORLD)

    BroadcastDoorState(door, false)

    -- Модельные двери удаляем совсем; брашевые (func_*) только прячем,
    -- чтобы не ломать логику карты.
    local class = door:GetClass()
    if class == "prop_door_rotating" or class == "prop_dynamic" then
        timer.Simple(0.1, function()
            if IsValid(door) then
                door:Remove()
            end
        end)
    end
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

-- Попадание в мини-игре («руками»): клик/крестик/проход ползунка двигает прогресс.
net.Receive("DoorSystem_MinigameHit", function(_, ply)
    if not IsValid(ply) or not ply.DoorSystem_Active then return end
    if ply.DoorSystem_Mode ~= "hands" then return end

    -- Только игры, где прогресс считается по попаданиям.
    local kind = ply.DoorSystem_Kind
    if kind ~= "clicker" and kind ~= "crosses" and kind ~= "saw" and kind ~= "debris" then return end

    local door, tool = ply.DoorSystem_Door, ply.DoorSystem_Tool
    if not IsValid(door) or not tool then return end

    local cfg = DoorSystem.GetKindParams(tool.id, door)

    -- Антиспам: клиенту доверять нельзя.
    if CurTime() - (ply.DoorSystem_LastHit or 0) < cfg.minHitInterval then return end
    ply.DoorSystem_LastHit = CurTime()

    ply.DoorSystem_Hits = (ply.DoorSystem_Hits or 0) + 1
    local progress = math.Clamp(ply.DoorSystem_Hits / math.max(cfg.hitsRequired, 1), 0, 1)

    if tool.hitSound then
        door:EmitSound(tool.hitSound, 75, math.random(95, 105))
    end

    net.Start("DoorSystem_Hit")
        net.WriteEntity(ply)
        net.WriteString(tool.id)
    net.Broadcast()

    SendProgress(ply, progress, tool, "hands")

    if progress >= 1 then
        if kind == "debris" and cfg.endSound then
            door:EmitSound(cfg.endSound, 80, 100)
        end

        FinishBreaking(ply, door, "hands")
    end
end)

-- Прогресс мини-игры «шкала» (лом): клиент присылает текущее значение,
-- сервер не даёт ему расти быстрее допустимого.
net.Receive("DoorSystem_MinigameProgress", function(_, ply)
    if not IsValid(ply) or not ply.DoorSystem_Active then return end
    if ply.DoorSystem_Mode ~= "hands" or ply.DoorSystem_Kind ~= "bar" then return end

    local door, tool = ply.DoorSystem_Door, ply.DoorSystem_Tool
    if not IsValid(door) or not tool then return end

    local cfg = DoorSystem.GetKindParams(tool.id, door)
    local claimed = math.Clamp(net.ReadFloat(), 0, 1)

    local now = CurTime()
    local dt = math.Clamp(now - (ply.DoorSystem_BarLast or now), 0, 0.5)
    ply.DoorSystem_BarLast = now

    local old = ply.DoorSystem_BarProgress or 0
    local maxUp = old + dt / math.max((cfg.fillTime or 7) * 0.6, 1)
    local new = math.min(claimed, maxUp)

    ply.DoorSystem_BarProgress = new

    -- Звук работы ломом, пока шкала растёт.
    if new > old and tool.hitSound and now - (ply.DoorSystem_BarSound or 0) >= (tool.hitInterval or 0.5) then
        ply.DoorSystem_BarSound = now
        door:EmitSound(tool.hitSound, 75, math.random(95, 105))

        net.Start("DoorSystem_Hit")
            net.WriteEntity(ply)
            net.WriteString(tool.id)
        net.Broadcast()
    end

    SendProgress(ply, new, tool, "hands")

    if new >= 1 then
        FinishBreaking(ply, door, "hands")
    end
end)
