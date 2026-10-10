--[[
    DOOR SYSTEM V2 — клиентская логика взлома
]]

DoorSystem.Breaking = false
DoorSystem.BreakProgress = 0
DoorSystem.BreakToolId = nil
DoorSystem.BreakMode = nil
DoorSystem.LastHitTime = 0

-- Консольная команда, которую игрок назначает себе в bind.
concommand.Add(DoorSystem.Config.Bind, function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if DoorSystem.Breaking then return end

    -- Повторное нажатие при открытом меню закрывает его.
    if IsValid(DoorSystem.ActiveMenu) then
        DoorSystem.ActiveMenu:Remove()
        return
    end

    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:EyeAngles():Forward() * DoorSystem.Config.MaxUseDistance,
        filter = ply,
    })

    if not tr.Hit or not IsValid(tr.Entity) then return end
    if not DoorSystem.IsBreakable(tr.Entity, ply) then return end

    local panel = vgui.Create("DoorSystemMenu")
    panel:SetDoor(tr.Entity)
    DoorSystem.ActiveMenu = panel
end)

-- Подсказка при заходе на карту, один раз за сессию.
hook.Add("InitPostEntity", "DoorSystem_StartupHint", function()
    timer.Simple(3, function()
        chat.AddText(
            Color(255, 210, 90), "[Door System] ",
            color_white,
            "Чтобы использовать топор или лом — держи их в руках перед взломом. Клавишу можно поменять в Q-меню -> Utilities -> Door System."
        )
    end)
end)

-- Запрашивает у сервера старт взлома выбранным инструментом.
function DoorSystem.RequestBreak(door, toolId, mode)
    if not IsValid(door) then return end
    DoorSystem.EasterEggReady = true
    DoorSystem.PendingDoor = door
    DoorSystem.PendingTool = toolId

    net.Start("DoorSystem_Start")
        net.WriteEntity(door)
        net.WriteString(toolId)
        net.WriteString(mode or "timer")
    net.SendToServer()
end

net.Receive("DoorSystem_Progress", function()
    DoorSystem.Breaking = true
    DoorSystem.BreakProgress = net.ReadFloat()
    DoorSystem.BreakToolId = net.ReadString()
    DoorSystem.BreakMode = net.ReadString()
end)

net.Receive("DoorSystem_Stop", function()
    local completed = net.ReadBool()
    DoorSystem.Breaking = false
    DoorSystem.BreakProgress = 0
    DoorSystem.BreakToolId = nil
    DoorSystem.BreakMode = nil

    hook.Run("DoorSystem_ClientStopped", completed)
end)

net.Receive("DoorSystem_Hit", function()
    local attacker = net.ReadEntity()
    net.ReadString() -- id инструмента (клиенту не нужен)

    if not IsValid(attacker) then return end

    if attacker == LocalPlayer() then
        DoorSystem.LastHitTime = CurTime()
        LocalPlayer():ViewPunch(Angle(math.Rand(-1.4, 1.4), math.Rand(-1.6, 1.6), 0))
    end
end)

net.Receive("DoorSystem_StartResult", function()
    local success = net.ReadBool()

    if not success then
        DoorSystem.PendingDoor = nil
        DoorSystem.PendingTool = nil
        chat.AddText(Color(220, 90, 90), "[Door System] ", color_white, "Не удалось начать взлом.")
        return
    end

    local mode = net.ReadString()

    -- Мини-игра запускается только в режиме «руками».
    if mode == "hands" and DoorSystem.Config.MinigameMenu and DoorSystem.Config.MinigameMenu.enabled and IsValid(DoorSystem.PendingDoor) then
        local mg = vgui.Create("DoorSystemMinigame")
        if IsValid(mg) then
            mg:SetDoor(DoorSystem.PendingDoor)
            mg:SetTool(DoorSystem.PendingTool)
        end
    end

    DoorSystem.PendingDoor = nil
    DoorSystem.PendingTool = nil
end)

-- Отменяет взлом, если игрок начал двигаться или прыгать.
hook.Add("Think", "DoorSystem_CancelOnMove", function()
    if not DoorSystem.Breaking then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- В игре с ломом пробел — это управление, а не прыжок.
    local mg = DoorSystem.ActiveMinigame
    local spaceIsControl = IsValid(mg) and mg.kind == "bar"

    if ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK)
        or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT)
        or (not spaceIsControl and ply:KeyDown(IN_JUMP)) then
        net.Start("DoorSystem_Cancel")
        net.SendToServer()
    end
end)

-- Прогресс-бар внизу экрана (только в режиме «по таймеру»;
-- в режиме «руками» прогресс рисует сама мини-игра).
hook.Add("HUDPaint", "DoorSystem_ProgressBar", function()
    if not DoorSystem.Breaking then return end
    if DoorSystem.BreakMode ~= "timer" then return end

    local w, h = ScrW(), ScrH()
    local barW, barH = 380, 24
    local x, y = w / 2 - barW / 2, h - 150

    local pulse = math.max(0, 1 - (CurTime() - DoorSystem.LastHitTime) / 0.25)

    draw.RoundedBox(5, x - 3, y - 3, barW + 6, barH + 6, Color(0, 0, 0, 190))
    draw.RoundedBox(5, x, y, barW, barH, Color(35, 32, 28, 230))
    draw.RoundedBox(5, x, y, barW * DoorSystem.BreakProgress, barH, Color(220 + pulse * 30, 170 + pulse * 40, 40, 255))

    local tool = DoorSystem.GetTool(DoorSystem.BreakToolId)
    draw.SimpleText(
        tool and tool.name or "Взлом двери",
        "DermaDefaultBold",
        w / 2,
        y - 16,
        color_white,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_BOTTOM
    )

    draw.SimpleText(
        math.ceil(DoorSystem.BreakProgress * 100) .. "%",
        "DermaDefaultBold",
        w / 2,
        y + barH / 2,
        color_black,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )
end)

-- Проверяет пасхалку: триггер по нажатию колёсика мыши.
hook.Add("Think", "DoorSystem_EasterEggCheck", function()
    if not DoorSystem.Breaking then return end
    if not DoorSystem.EasterEggReady then return end
    if not input.IsButtonDown(MOUSE_MIDDLE) then return end

    DoorSystem.EasterEggReady = false
    net.Start("DoorSystem_EasterEgg")
    net.SendToServer()
end)

-- Обновляет состояние двери после её разрушения на сервере.
net.Receive("DoorSystem_Broken", function()
    local door = net.ReadEntity()
    local opened = net.ReadBool()

    if IsValid(door) then
        if opened then
            door.DoorSystem_Opened = true
        else
            door.DoorSystem_Broken = true
        end
    end
end)