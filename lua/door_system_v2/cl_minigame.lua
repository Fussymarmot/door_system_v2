--[[
    DOOR SYSTEM V2 — мини-игра во время взлома
    Показывает фон двери, крестики для дополнительных кликов и итоговую открытую дверь.
]]

local PANEL = {}

-- Инициализирует панель мини-игры и закрепляет её на месте меню.
function PANEL:Init()
    local cfg = DoorSystem.Config.MinigameMenu
    self:SetSize(cfg.width, cfg.height)
    self:Center() -- ровно по центру экрана

    local x, y = self:GetPos()
    self:SetPos(x + (DoorSystem.Config.MenuOffsetX or 0), y + (DoorSystem.Config.MenuOffsetY or 0))

    self:MakePopup()
    self:SetKeyboardInputEnabled(false)

    hook.Add("CreateMove", "DoorSystem_FreezeMinigame", function(cmd)
        cmd:ClearMovement()
        cmd:ClearButtons()
    end)

    self.crosses = {}
    self.nextSpawn = 0
    self.state = "breaking" -- breaking -> open
    self.openUntil = 0

    self.frameMat = Material(cfg.frame, "noclamp smooth")

    self.btnClose = vgui.Create("DButton", self)
    self.btnClose:SetText("")
    self.btnClose:SetSize(34, 34)
    self.btnClose:SetPos(self:GetWide() - 35, 0)
    self.btnClose.Paint = function(s, w, h)
        local hover = s:IsHovered()
        draw.RoundedBox(6, 0, 0, w, h, hover and Color(120, 40, 40, 230) or Color(60, 30, 30, 220))
        surface.SetDrawColor(230, 220, 210, 255)
        surface.DrawLine(10, 10, w - 10, h - 10)
        surface.DrawLine(w - 10, 10, 10, h - 10)
    end
    self.btnClose.DoClick = function()
        surface.PlaySound("ui/buttonclickrelease.wav")

        net.Start("DoorSystem_Cancel")
        net.SendToServer()

        self:Remove()
    end
end

-- Убирает временные хуки при удалении панели.
function PANEL:OnRemove()
    hook.Remove("CreateMove", "DoorSystem_FreezeMinigame")
    if self.hookName then
        hook.Remove("DoorSystem_ClientStopped", self.hookName)
    end
end

-- Привязывает панель к двери и подбирает картинки по её скину.
function PANEL:SetDoor(door)
    self.door = door

    local cfg = DoorSystem.Config.MinigameMenu
    local skin = IsValid(door) and (door:GetSkin() or 0) or 0
    local bgName = cfg.backgroundsBySkin[skin] or cfg.backgroundsBySkin[0] or "locked_door"

    self.bgMat = Material("door_system_v2/minigame/" .. bgName .. ".jpg", "noclamp smooth")
    self.openMat = Material("door_system_v2/minigame/" .. bgName .. "_open.jpg", "noclamp smooth")

    self.hookName = "DoorSystem_Minigame_" .. tostring(self)
    hook.Add("DoorSystem_ClientStopped", self.hookName, function(completed)
        if not IsValid(self) then return end
        self:OnBreakingStopped(completed)
    end)
end

-- Реагирует на завершение или отмену взлома с сервера.
function PANEL:OnBreakingStopped(completed)
    if self.state ~= "breaking" then return end

    if completed then
        self.state = "open"
        self.openUntil = CurTime() + (DoorSystem.Config.MinigameMenu.openHoldTime or 1.3)
    else
        self:Remove()
    end
end

-- Спавнит крестик в пределах зоны двери.
function PANEL:SpawnCross()
    local cfg = DoorSystem.Config.MinigameMenu
    local zone = cfg.hitZone

    local w, h = self:GetWide(), self:GetTall()
    local x = math.Rand(zone.x1, zone.x2) * w
    local y = math.Rand(zone.y1, zone.y2) * h

    table.insert(self.crosses, {
        x = x,
        y = y,
        expires = CurTime() + cfg.crossLifetime,
    })
end

-- Обновляет состояние мини-игры и убирает просроченные крестики.
function PANEL:Think()
    if not self.failsafeUntil then
        -- Абсолютный потолок на случай любого зависания (сервер режет раньше).
        self.failsafeUntil = CurTime() + ((DoorSystem.Config.HandsMode and DoorSystem.Config.HandsMode.timeout or 120) + 10)
    end
    if CurTime() > self.failsafeUntil then
        self:Remove()
        return
    end
    if self.state ~= "breaking" then
        if self.state == "open" and CurTime() > self.openUntil then
            self:Remove()
        end
        return
    end

    local cfg = DoorSystem.Config.MinigameMenu

    if CurTime() > self.nextSpawn then
        self:SpawnCross()
        self.nextSpawn = CurTime() + cfg.crossSpawnEvery
    end

    for i = #self.crosses, 1, -1 do
        if CurTime() > self.crosses[i].expires then
            table.remove(self.crosses, i)
        end
    end
end

-- Клик по кресту сообщает серверу о попадании — это двигает прогресс.
function PANEL:OnMousePressed(mcode)
    if mcode ~= MOUSE_LEFT then return end
    if self.state ~= "breaking" then return end

    local cfg = DoorSystem.Config.MinigameMenu
    local mx, my = self:CursorPos()

    for i = #self.crosses, 1, -1 do
        local c = self.crosses[i]
        if math.abs(mx - c.x) <= cfg.crossSize / 2 and math.abs(my - c.y) <= cfg.crossSize / 2 then
            table.remove(self.crosses, i)

            -- Звук удара проигрывает сервер (по инструменту).
            net.Start("DoorSystem_MinigameHit")
            net.SendToServer()

            break
        end
    end
end

-- Рисует фон, крестики и рамку панели.
function PANEL:Paint(w, h)
    local mat = (self.state == "open") and self.openMat or self.bgMat
    if mat then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(mat)
        surface.DrawTexturedRect(0, 0, w, h)
    end

    if self.state == "breaking" then
        local cfg = DoorSystem.Config.MinigameMenu

        for _, c in ipairs(self.crosses) do
            local size = cfg.crossSize
            local thickness = 4
            surface.SetDrawColor(220, 40, 40, 255)

            for i = -thickness / 2, thickness / 2 do
                surface.DrawLine(c.x - size / 2 + i, c.y + size / 2, c.x + size / 2 + i, c.y - size / 2)
            end

            for i = -thickness / 2, thickness / 2 do
                surface.DrawLine(c.x - size / 2 + i, c.y - size / 2, c.x + size / 2 + i, c.y + size / 2)
            end
        end

        -- Полоска прогресса внизу: растёт от попаданий по крестикам.
        local barW, barH = w * 0.7, 18
        local bx, by = w / 2 - barW / 2, h - 44

        draw.RoundedBox(5, bx - 3, by - 3, barW + 6, barH + 6, Color(0, 0, 0, 190))
        draw.RoundedBox(5, bx, by, barW, barH, Color(35, 32, 28, 230))
        draw.RoundedBox(5, bx, by, barW * math.Clamp(DoorSystem.BreakProgress, 0, 1), barH, Color(220, 170, 40, 255))

        draw.SimpleText(math.ceil(DoorSystem.BreakProgress * 100) .. "%", "DermaDefaultBold",
            w / 2, by + barH / 2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if self.frameMat then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.frameMat)
        surface.DrawTexturedRect(0, 0, w, h)
    end
end

vgui.Register("DoorSystemMinigame", PANEL, "DPanel")