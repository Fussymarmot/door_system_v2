--[[
    DOOR SYSTEM V2 — мини-игра во время взлома («руками»)

    У каждого инструмента своя игра (Config.MinigameKinds):
      clicker — кулаки: кликать по двери;
      crosses — топор: кликать по появляющимся крестикам;
      bar     — лом: удерживать separator на движущемся участке шкалы
                (зажат пробел — едет вправо, отпущен — влево);
      saw     — ножовка: зажать ползунок и водить его вправо-влево;
      debris  — лопата: схватить обломок и выбросить его в сторону;
      boom    — любая граната: звук взрыва + анимация из кадров;
      molotov — молотов: звук + анимация огня.
]]

local PANEL = {}

local SEPARATOR_MAT = "door_system_v2/minigame/separator.png"
local SAW_HANDLE_MAT = "door_system_v2/minigame/button_circle.png"
local DEBRIS_MATS = {
    brick = "door_system_v2/minigame/debris/brick.png",
    plank = "door_system_v2/minigame/debris/plank.png",
    stone = "door_system_v2/minigame/debris/stone.png",
}
local DEBRIS_TYPES = { "brick", "plank", "stone" }

-- Прямоугольник шкалы/дорожки внизу панели (для bar и saw).
local function TrackRect(w, h)
    local bw, bh = w * 0.74, 26
    return (w - bw) / 2, h - 104, bw, bh
end

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
    self.ripples = {}
    self.params = { level = 1, hitsRequired = 8 }
    self.nextSpawn = 0
    self.state = "breaking" -- breaking -> open
    self.openUntil = 0
    self.kind = "crosses"
    self.shakeUntil = 0

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
    self:MouseCapture(false)
    if DoorSystem.ActiveMinigame == self then
        DoorSystem.ActiveMinigame = nil
    end
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

-- Выбирает мини-игру по инструменту и готовит её состояние.
function PANEL:SetTool(toolId)
    self.toolId = toolId
    self.kind = DoorSystem.GetMinigameKind(toolId)
    self.params = DoorSystem.GetKindParams(toolId, self.door)
    DoorSystem.ActiveMinigame = self

    local now = CurTime()
    local cfg = DoorSystem.Config

    if self.kind == "bar" then
        self.sepMat = Material(SEPARATOR_MAT, "noclamp smooth")
        self.bar = {
            zone = 0.5,
            target = 0.5,
            nextTarget = 0,
            sep = 0.1,
            vel = 0,
            progress = 0,
            nextSend = 0,
            inZone = false,
        }

    elseif self.kind == "saw" then
        self.sawMat = Material(SAW_HANDLE_MAT, "noclamp smooth")
        self.saw = { pos = 0.5, lastEnd = nil, dragging = false, grabDX = 0 }

    elseif self.kind == "debris" then
        self.debrisMats = {}
        for id, path in pairs(DEBRIS_MATS) do
            self.debrisMats[id] = Material(path, "noclamp smooth")
        end
        self.debris = { items = {}, flying = {}, held = nil, nextSpawn = 0 }

    elseif self.kind == "boom" then
        local fx = cfg.Effects.boom
        self.fx = fx
        self.fxStart = now
        self.fxMats = {}
        for i = 1, fx.frames do
            self.fxMats[i] = Material(string.format(fx.framePath, i), "noclamp smooth")
        end

    elseif self.kind == "molotov" then
        local fx = cfg.Effects.molotov
        self.fx = fx
        self.fxStart = now
        self.fxMat = Material(fx.image, "noclamp smooth")
    end
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

-- Сообщает серверу о попадании (клик, крестик, проход ползунка).
local function SendHit()
    net.Start("DoorSystem_MinigameHit")
    net.SendToServer()
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
        expires = CurTime() + (self.params.crossLifetime or cfg.crossLifetime),
    })
end

-- Лом: участок бродит по шкале, separator едет вправо при зажатом пробеле
-- и влево при отпущенном.
function PANEL:ThinkBar()
    local b, bc = self.bar, self.params
    local dt = FrameTime()
    local half = bc.zoneWidth / 2

    -- Участок плавно едет к случайной точке, время от времени выбирая новую.
    if CurTime() > b.nextTarget or math.abs(b.target - b.zone) < 0.01 then
        b.target = math.Rand(half, 1 - half)
        b.nextTarget = CurTime() + math.Rand(bc.retargetMin, bc.retargetMax)
    end

    local step = bc.zoneSpeed * dt
    b.zone = b.zone + math.Clamp(b.target - b.zone, -step, step)

    -- Separator: пробел — вправо, иначе влево, с небольшой инерцией.
    local wanted = input.IsKeyDown(KEY_SPACE) and bc.sepSpeed or -bc.sepSpeed
    local maxDelta = bc.sepAccel * bc.sepSpeed * dt
    b.vel = b.vel + math.Clamp(wanted - b.vel, -maxDelta, maxDelta)
    b.sep = b.sep + b.vel * dt

    if b.sep <= 0 then b.sep, b.vel = 0, math.max(b.vel, 0) end
    if b.sep >= 1 then b.sep, b.vel = 1, math.min(b.vel, 0) end

    b.inZone = math.abs(b.sep - b.zone) <= half

    local rate = dt / math.max(bc.fillTime, 0.5)
    if b.inZone then
        b.progress = b.progress + rate
    else
        b.progress = b.progress - rate * bc.drainMul
    end
    b.progress = math.Clamp(b.progress, 0, 1)

    -- Сервер не даёт прогрессу расти быстрее допустимого — подстраиваемся.
    if DoorSystem.Breaking then
        b.progress = math.min(b.progress, DoorSystem.BreakProgress + 0.25)
    end

    if CurTime() >= b.nextSend then
        b.nextSend = CurTime() + 0.1
        net.Start("DoorSystem_MinigameProgress")
            net.WriteFloat(b.progress)
        net.SendToServer()
    end
end

-- Ножовка: ползунок двигается, только пока он зажат; считаем проходы от края до края.
function PANEL:ThinkSaw()
    local s = self.saw
    local w, h = self:GetWide(), self:GetTall()
    local bx, _, bw = TrackRect(w, h)

    if s.dragging then
        if not input.IsMouseDown(MOUSE_LEFT) then
            s.dragging = false
            self:MouseCapture(false)
        else
            local mx = self:CursorPos()
            local desired = math.Clamp((mx - s.grabDX - bx) / bw, 0, 1)
            s.pos = Lerp(1 - math.exp(-FrameTime() * 30), s.pos, desired)
        end
    end

    local edgeZone = self.params.edgeZone or 0.08
    local edge
    if s.pos <= edgeZone then edge = "left" elseif s.pos >= 1 - edgeZone then edge = "right" end

    if edge and edge ~= s.lastEnd then
        if s.lastEnd ~= nil then
            SendHit() -- дошли до противоположного края: один ход пилы
        end
        s.lastEnd = edge
    end
end

-- Лопата: обломки появляются на двери, лежат ограниченное время.
function PANEL:ThinkDebris()
    local d, p = self.debris, self.params
    local cfg = DoorSystem.Config.MinigameMenu
    local zone, w, h = cfg.hitZone, self:GetWide(), self:GetTall()
    local now = CurTime()

    for i = #d.items, 1, -1 do
        if now > d.items[i].expires then
            table.remove(d.items, i)
        end
    end

    for i = #d.flying, 1, -1 do
        if now - d.flying[i].t > 0.5 then
            table.remove(d.flying, i)
        end
    end

    local count = #d.items + (d.held and 1 or 0)
    if now >= d.nextSpawn and count < p.maxItems then
        d.nextSpawn = now + p.spawnEvery

        local half = p.itemSize / 2
        local x1, x2 = zone.x1 * w + half * 0.6, zone.x2 * w - half * 0.6
        local y1, y2 = zone.y1 * h + half * 0.6, zone.y2 * h - half * 0.6

        -- Несколько попыток найти место, не слишком накрывающее другие обломки.
        local x, y
        for _ = 1, 8 do
            x, y = math.Rand(x1, x2), math.Rand(y1, y2)
            local ok = true
            for _, it in ipairs(d.items) do
                if (it.x - x) ^ 2 + (it.y - y) ^ 2 < (p.itemSize * 0.8) ^ 2 then ok = false break end
            end
            if ok then break end
        end

        table.insert(d.items, {
            id = DEBRIS_TYPES[math.random(#DEBRIS_TYPES)],
            x = x, y = y,
            rot = math.Rand(-35, 35),
            born = now,
            expires = now + p.lifetime,
        })
    end
end

-- Обновляет состояние мини-игры.
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

    if self.kind == "crosses" then
        if CurTime() > self.nextSpawn then
            self:SpawnCross()
            self.nextSpawn = CurTime() + cfg.crossSpawnEvery
        end

        for i = #self.crosses, 1, -1 do
            if CurTime() > self.crosses[i].expires then
                table.remove(self.crosses, i)
            end
        end
    elseif self.kind == "bar" and self.bar then
        self:ThinkBar()
    elseif self.kind == "saw" and self.saw then
        self:ThinkSaw()
    elseif self.kind == "debris" and self.debris then
        self:ThinkDebris()
    end
end

-- Клики: по двери (кулаки) или по крестикам (топор/лопата).
function PANEL:OnMousePressed(mcode)
    if mcode ~= MOUSE_LEFT then return end
    if self.state ~= "breaking" then return end

    local cfg = DoorSystem.Config.MinigameMenu
    local mx, my = self:CursorPos()

    if self.kind == "clicker" then
        local z, w, h = cfg.hitZone, self:GetWide(), self:GetTall()
        if mx < z.x1 * w or mx > z.x2 * w or my < z.y1 * h or my > z.y2 * h then return end

        table.insert(self.ripples, { x = mx, y = my, t = CurTime() })
        self.shakeUntil = CurTime() + 0.08
        SendHit()

    elseif self.kind == "saw" and self.saw then
        -- Ползунок нужно зажать: двигать можно только схватив его.
        local w, h = self:GetWide(), self:GetTall()
        local bx, by, bw, bh = TrackRect(w, h)
        local hx, hy = bx + bw * self.saw.pos, by + bh / 2

        if (mx - hx) ^ 2 + (my - hy) ^ 2 <= 34 ^ 2 then
            self.saw.dragging = true
            self.saw.grabDX = mx - hx
            self:MouseCapture(true)
            surface.PlaySound("ui/buttonclick.wav")
        end

    elseif self.kind == "debris" and self.debris then
        local d = self.debris
        local half = self.params.itemSize / 2

        if d.held then return end

        -- Берём верхний (последний добавленный) обломок под курсором.
        for i = #d.items, 1, -1 do
            local it = d.items[i]
            if (mx - it.x) ^ 2 + (my - it.y) ^ 2 <= (half * 0.85) ^ 2 then
                table.remove(d.items, i)
                d.held = { id = it.id, rot = it.rot, x = it.x, y = it.y, dx = it.x - mx, dy = it.y - my }
                self:MouseCapture(true)
                surface.PlaySound(self.params.takeSound)
                break
            end
        end

    elseif self.kind == "crosses" then
        local size = self.params.crossSize or cfg.crossSize
        for i = #self.crosses, 1, -1 do
            local c = self.crosses[i]
            if math.abs(mx - c.x) <= size / 2 and math.abs(my - c.y) <= size / 2 then
                table.remove(self.crosses, i)

                -- Звук удара проигрывает сервер (по инструменту).
                SendHit()

                break
            end
        end
    end
end

-- Отпускание кнопки: бросок обломка лопатой, отпускание ползунка ножовки.
function PANEL:OnMouseReleased(mcode)
    if mcode ~= MOUSE_LEFT then return end

    if self.kind == "saw" and self.saw then
        self.saw.dragging = false
        self:MouseCapture(false)

    elseif self.kind == "debris" and self.debris and self.debris.held then
        local d, h = self.debris, self.debris.held
        local cfg = DoorSystem.Config.MinigameMenu
        local z, w, ph = cfg.hitZone, self:GetWide(), self:GetTall()
        local mx = self:CursorPos()
        d.held = nil
        self:MouseCapture(false)

        if self.state ~= "breaking" then return end

        if mx < z.x1 * w or mx > z.x2 * w then
            -- Выброшен за пределы двери — засчитываем и запускаем полёт в сторону.
            table.insert(d.flying, {
                id = h.id, x = h.x, y = h.y, rot = h.rot,
                dir = (mx < w / 2) and -1 or 1, t = CurTime(),
            })
            SendHit()
        else
            -- Отпущен над дверью — обломок остаётся лежать здесь.
            local half = self.params.itemSize / 2
            table.insert(d.items, {
                id = h.id,
                x = math.Clamp(h.x, z.x1 * w + half * 0.6, z.x2 * w - half * 0.6),
                y = math.Clamp(h.y, z.y1 * ph + half * 0.6, z.y2 * ph - half * 0.6),
                rot = h.rot,
                born = CurTime(),
                expires = CurTime() + self.params.lifetime,
            })
        end
    end
end

-- Рисует крестики.
function PANEL:PaintCrosses()
    local cfg = DoorSystem.Config.MinigameMenu

    for _, c in ipairs(self.crosses) do
        local size = self.params.crossSize or cfg.crossSize
        local thickness = 4
        surface.SetDrawColor(220, 40, 40, 255)

        for i = -thickness / 2, thickness / 2 do
            surface.DrawLine(c.x - size / 2 + i, c.y + size / 2, c.x + size / 2 + i, c.y - size / 2)
        end

        for i = -thickness / 2, thickness / 2 do
            surface.DrawLine(c.x - size / 2 + i, c.y - size / 2, c.x + size / 2 + i, c.y + size / 2)
        end
    end
end

-- Круги от кликов по двери.
function PANEL:PaintRipples()
    for i = #self.ripples, 1, -1 do
        local r = self.ripples[i]
        local k = (CurTime() - r.t) / 0.35

        if k >= 1 then
            table.remove(self.ripples, i)
        else
            local a = 255 * (1 - k)
            surface.DrawCircle(r.x, r.y, 6 + k * 26, 255, 210, 90, a)
            surface.DrawCircle(r.x, r.y, 3 + k * 14, 255, 255, 255, a)
        end
    end
end

-- Шкала лома: дорожка, участок, separator.
function PANEL:PaintBar(w, h)
    local b, bc = self.bar, self.params
    local bx, by, bw, bh = TrackRect(w, h)

    draw.RoundedBox(6, bx - 4, by - 4, bw + 8, bh + 8, Color(0, 0, 0, 200))
    draw.RoundedBox(4, bx, by, bw, bh, Color(35, 32, 28, 240))

    -- Движущийся участок.
    local zw = bw * bc.zoneWidth
    local zx = bx + bw * b.zone - zw / 2
    local col = b.inZone and Color(110, 220, 90, 255) or Color(220, 170, 40, 255)
    draw.RoundedBox(3, zx, by + 2, zw, bh - 4, col)

    -- Separator: тёмная линия в центре картинки совпадает с центром.
    local sh = bh + 28
    local sw = sh * 36 / 64
    local sx = bx + bw * b.sep
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(self.sepMat)
    surface.DrawTexturedRect(sx - sw / 2, by + bh / 2 - sh / 2, sw, sh)

    draw.SimpleText(b.inZone and "Держи!" or "ПРОБЕЛ — вправо, отпусти — влево", "DermaDefaultBold",
        w / 2, by - 12, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end

-- Дорожка ножовки: ползунок и подсвеченный целевой край.
function PANEL:PaintSaw(w, h)
    local s = self.saw
    local bx, by, bw, bh = TrackRect(w, h)

    draw.RoundedBox(6, bx - 4, by - 4, bw + 8, bh + 8, Color(0, 0, 0, 200))
    draw.RoundedBox(4, bx, by, bw, bh, Color(35, 32, 28, 240))

    -- Следующий край, до которого нужно дотянуться, мигает.
    local nextEdge = (s.lastEnd == "left") and "right" or ((s.lastEnd == "right") and "left" or nil)
    local pulse = 0.5 + 0.5 * math.sin(CurTime() * 8)
    local edgeZone = self.params.edgeZone or 0.08

    for _, e in ipairs({ "left", "right" }) do
        local ew = bw * edgeZone
        local ex = (e == "left") and bx or (bx + bw - ew)
        local a = (e == nextEdge) and (120 + pulse * 120) or ((nextEdge == nil) and 110 or 40)
        draw.RoundedBox(3, ex, by + 2, ew, bh - 4, Color(220, 170, 40, a))
    end

    local size = 58
    local hx = bx + bw * s.pos
    local c = s.dragging and 255 or 215
    surface.SetDrawColor(c, c, c, 255)
    surface.SetMaterial(self.sawMat)
    surface.DrawTexturedRect(hx - size / 2, by + bh / 2 - size / 2, size, size)

    draw.SimpleText(s.dragging and "Води вправо-влево" or "Зажми ползунок и води вправо-влево", "DermaDefaultBold",
        w / 2, by - 14, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end

-- Лопата: лежащие обломки, зажатый обломок и улетающие в сторону.
function PANEL:PaintDebris(w, h)
    local d, p = self.debris, self.params
    local size = p.itemSize
    local z = DoorSystem.Config.MinigameMenu.hitZone
    local now = CurTime()

    -- Пока обломок в руке, подсвечиваем зоны по бокам, куда его нужно выбросить.
    if d.held then
        local pulse = 0.5 + 0.5 * math.sin(now * 8)
        local a = 40 + pulse * 45
        draw.RoundedBox(0, 0, 0, z.x1 * w, h, Color(110, 220, 90, a))
        draw.RoundedBox(0, z.x2 * w, 0, w - z.x2 * w, h, Color(110, 220, 90, a))
        draw.SimpleText("Выбрось в сторону!", "DermaDefaultBold", w / 2, 14,
            color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    for _, it in ipairs(d.items) do
        -- Мигаем перед исчезновением.
        local left = it.expires - now
        local a = (left < 1) and (120 + 135 * (0.5 + 0.5 * math.sin(now * 20))) or 255
        local grow = math.min(1, (now - it.born) / 0.15)

        surface.SetDrawColor(255, 255, 255, a)
        surface.SetMaterial(self.debrisMats[it.id])
        surface.DrawTexturedRectRotated(it.x, it.y, size * grow, size * grow, it.rot)
    end

    -- Улетающие в сторону: дуга, вращение, затухание.
    for _, f in ipairs(d.flying) do
        local k = (now - f.t) / 0.5
        local fx = f.x + f.dir * k * 320
        local fy = f.y - 90 * k + 420 * k * k * 0.5
        surface.SetDrawColor(255, 255, 255, 255 * (1 - k))
        surface.SetMaterial(self.debrisMats[f.id])
        surface.DrawTexturedRectRotated(fx, fy, size, size, f.rot + f.dir * k * 540)
    end

    -- Зажатый обломок следует за курсором.
    if d.held then
        local mx, my = self:CursorPos()
        local hx = math.Clamp(mx + d.held.dx, 0, w)
        local hy = math.Clamp(my + d.held.dy, 0, h)
        d.held.x, d.held.y = hx, hy

        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.debrisMats[d.held.id])
        surface.DrawTexturedRectRotated(hx, hy, size * 1.12, size * 1.12, d.held.rot)
    end
end

-- Анимация взрыва из кадров (поверх двери).
function PANEL:PaintBoom(w, h)
    local fx = self.fx
    local e = CurTime() - self.fxStart
    if e >= fx.duration then return end

    local idx = math.Clamp(math.floor(e / fx.duration * fx.frames) + 1, 1, fx.frames)
    local a = 255 * math.min(1, e / 0.08, (fx.duration - e) / 0.25)

    surface.SetDrawColor(255, 255, 255, math.Clamp(a, 0, 255))
    surface.SetMaterial(self.fxMats[idx])
    surface.DrawTexturedRect(0, 0, w, h)
end

-- Огонь молотова: поднимается снизу, колышется, затухает.
function PANEL:PaintMolotov(w, h)
    local fx = self.fx
    local e = CurTime() - self.fxStart
    if e >= fx.duration then return end

    local a = 255 * math.min(1, e / 0.3, (fx.duration - e) / 0.45)
    local rise = 1 - math.min(1, e / 0.5)
    local sz = w * 1.3
    local flick = 1 + 0.05 * math.sin(CurTime() * 28) + 0.03 * math.sin(CurTime() * 17)
    local sh = sz * flick
    local x = (w - sz) / 2 + math.sin(CurTime() * 13) * 4
    local y = h - sh + rise * sh * 0.25

    -- Периодически отзеркаливаем, чтобы огонь не выглядел статичным.
    local flip = math.floor(CurTime() * 9) % 2 == 0
    local u0, u1 = flip and 1 or 0, flip and 0 or 1

    surface.SetDrawColor(255, 255, 255, math.Clamp(a, 0, 255))
    surface.SetMaterial(self.fxMat)
    surface.DrawTexturedRectUV(x, y, sz, sh, u0, 0, u1, 1)
end

-- Рисует фон, мини-игру и рамку панели.
function PANEL:Paint(w, h)
    local mat = (self.state == "open") and self.openMat or self.bgMat
    if mat then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(mat)

        -- Лёгкая тряска двери при ударе кулаком.
        local ox, oy = 0, 0
        if CurTime() < self.shakeUntil then
            ox, oy = math.random(-3, 3), math.random(-3, 3)
        end
        surface.DrawTexturedRect(ox, oy, w, h)
    end

    local kind = self.kind

    if kind == "boom" then
        self:PaintBoom(w, h)
    elseif kind == "molotov" then
        self:PaintMolotov(w, h)
    end

    if self.state == "breaking" then
        if kind == "crosses" then
            self:PaintCrosses()
        elseif kind == "clicker" then
            self:PaintRipples()
        elseif kind == "bar" and self.bar then
            self:PaintBar(w, h)
        elseif kind == "saw" and self.saw then
            self:PaintSaw(w, h)
        elseif kind == "debris" and self.debris then
            self:PaintDebris(w, h)
        end

        -- Эффекты идут сами — полоска и сложность им не нужны.
        if kind ~= "boom" and kind ~= "molotov" then
            draw.SimpleText("Сложность: " .. (self.params.level or 1) .. "/5", "DermaDefaultBold",
                14, 12, Color(255, 220, 90), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Полоска прогресса внизу. Для шкалы рисуем локальное значение, остальным — серверное.
            local value = (kind == "bar" and self.bar) and self.bar.progress or DoorSystem.BreakProgress
            local barW, barH = w * 0.7, 18
            local bx, by = w / 2 - barW / 2, h - 44

            draw.RoundedBox(5, bx - 3, by - 3, barW + 6, barH + 6, Color(0, 0, 0, 190))
            draw.RoundedBox(5, bx, by, barW, barH, Color(35, 32, 28, 230))
            draw.RoundedBox(5, bx, by, barW * math.Clamp(value, 0, 1), barH, Color(220, 170, 40, 255))

            draw.SimpleText(math.ceil(math.Clamp(value, 0, 1) * 100) .. "%", "DermaDefaultBold",
                w / 2, by + barH / 2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    if self.frameMat then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.frameMat)
        surface.DrawTexturedRect(0, 0, w, h)
    end
end

vgui.Register("DoorSystemMinigame", PANEL, "DPanel")
