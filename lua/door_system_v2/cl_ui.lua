--[[
    DOOR SYSTEM V2 — меню взлома

    По центру экрана: картинка двери с тремя инструментами.
    Справа — две большие квадратные кнопки способа взлома (только иконки):
      песочные часы — ломать по таймеру;
      молоток и ключ — ломать руками (кликать по крестикам в мини-игре).
    Порядок: сначала выбираешь способ справа, затем кликаешь по
    инструменту на двери — взлом стартует.
]]

local PANEL = {}

-- Рисует закрывающий крестик.
local function PaintCloseButton(s, w, h)
    local hover = s:IsHovered()
    draw.RoundedBox(6, 0, 0, w, h, hover and Color(120, 40, 40, 230) or Color(60, 30, 30, 220))
    surface.SetDrawColor(230, 220, 210, 255)
    surface.DrawLine(10, 10, w - 10, h - 10)
    surface.DrawLine(w - 10, 10, 10, h - 10)
end

-- Инициализирует меню и ставит его ровно по центру экрана.
function PANEL:Init()
    local cfg = DoorSystem.Config

    self.doorW = cfg.MenuWidth
    self.doorH = cfg.MenuHeight
    self.sideW = cfg.MenuSideWidth or 210
    self.sideGap = cfg.MenuSideGap or 16

    self:SetSize(self.doorW + self.sideGap + self.sideW, self.doorH)
    self:Center()

    local x, y = self:GetPos()
    self:SetPos(x + (cfg.MenuOffsetX or 0), y + (cfg.MenuOffsetY or 0))

    self:MakePopup()
    self:SetKeyboardInputEnabled(false)

    hook.Add("CreateMove", "DoorSystem_FreezeMenu", function(cmd)
        cmd:ClearMovement()
        cmd:ClearButtons()
    end)

    self.tools = {}
    self.mode = nil -- "timer" | "hands"; пока не выбран — инструменты неактивны
    self.noModeFlash = 0
    self.bgMaterial = Material(cfg.MenuBackground or "", "noclamp smooth")

    local mgCfg = cfg.MinigameMenu
    self.frameMat = mgCfg and mgCfg.frame and Material(mgCfg.frame, "noclamp smooth")

    self.btnClose = vgui.Create("DButton", self)
    self.btnClose:SetText("")
    self.btnClose:SetSize(34, 34)
    self.btnClose:SetPos(self.doorW - 35, 0)
    self.btnClose.Paint = PaintCloseButton
    self.btnClose.DoClick = function()
        surface.PlaySound("ui/buttonclickrelease.wav")
        self:Remove()
    end
end

-- Убирает временный хук при закрытии меню.
function PANEL:OnRemove()
    hook.Remove("CreateMove", "DoorSystem_FreezeMenu")
end

-- Рисует картинку двери и рамку (боковая колонка прозрачная).
function PANEL:Paint(w, h)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(self.bgMaterial)
    surface.DrawTexturedRect(0, 0, self.doorW, self.doorH)

    if DoorSystem.Config.MenuShowBorder then
        surface.SetDrawColor(110, 95, 65, 255)
        surface.DrawOutlinedRect(0, 0, self.doorW, self.doorH, 2)
    end

    if self.frameMat then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.frameMat)
        surface.DrawTexturedRect(0, 0, self.doorW, self.doorH)
    end
end

-- Привязывает меню к конкретной двери.
function PANEL:SetDoor(door)
    self.door = door

    local mgCfg = DoorSystem.Config.MinigameMenu
    local skin = IsValid(door) and (door:GetSkin() or 0) or 0
    local bgName = mgCfg and (mgCfg.backgroundsBySkin[skin] or mgCfg.backgroundsBySkin[0])

    if bgName then
        self.bgMaterial = Material("door_system_v2/minigame/" .. bgName .. ".jpg", "noclamp smooth")
    end

    self:BuildToolButtons()
    self:BuildModeButtons()
end

-- Положение кнопок инструментов внутри картинки двери.
local LAYOUT = {
    { x = 0.50, y = 0.24 }, -- верхний, по центру
    { x = 0.26, y = 0.68 }, -- нижний левый
    { x = 0.74, y = 0.68 }, -- нижний правый
}

-- Кнопки инструментов этой двери. Клик = старт взлома выбранным способом.
function PANEL:BuildToolButtons()
    for _, b in ipairs(self.tools) do
        if IsValid(b) then
            b:Remove()
        end
    end

    self.tools = {}

    local ply = LocalPlayer()
    local size = 132
    local matBg = Material("door_system_v2/lock_method_bg.png", "noclamp smooth")
    local matTime = Material("door_system_v2/timer.png", "noclamp smooth")

    for i, entry in ipairs(DoorSystem.GetDoorTools(self.door)) do
        local toolCfg = entry.tool
        local pos = LAYOUT[i] or LAYOUT[#LAYOUT]
        local available = DoorSystem.CanUseTool(toolCfg, ply)

        local btn = vgui.Create("DButton", self)
        btn:SetText("")
        btn:SetSize(size, size)
        btn:SetPos(self.doorW * pos.x - size / 2, self.doorH * pos.y - size / 2)

        local matIcon = Material(toolCfg.icon, "noclamp smooth")

        btn.Paint = function(s, w, h)
            -- Без выбранного способа или без инструмента в руках — приглушено.
            local active = available and self.mode ~= nil
            local alpha = active and 255 or 90

            surface.SetDrawColor(255, 255, 255, alpha)
            surface.SetMaterial(matBg)
            surface.DrawTexturedRect(0, 0, w, h)

            if active and s:IsHovered() then
                surface.SetDrawColor(255, 210, 90, 255)
                surface.DrawOutlinedRect(4, 4, w - 8, h - 8, 3)
            end

            local iconSize = w * 0.46
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.SetMaterial(matIcon)
            surface.DrawTexturedRect(w / 2 - iconSize / 2, h * 0.16, iconSize, iconSize)

            local textCol = active and Color(255, 220, 90) or Color(170, 170, 170)
            local rowY = h * 0.74

            if self.mode == "hands" then
                -- Время тут не важно: сколько нужно попаданий.
                local hits = DoorSystem.Config.HandsMode and DoorSystem.Config.HandsMode.hitsRequired or 8
                draw.SimpleText(hits .. " ударов", "DermaDefaultBold", w / 2, rowY + 8,
                    textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                local tIconSize = 16
                local timeTxt = DoorSystem.FormatTime(entry.time)

                surface.SetFont("DermaDefaultBold")
                local realW = select(1, surface.GetTextSize(timeTxt))

                local totalW = tIconSize + 6 + realW
                local startX = w / 2 - totalW / 2

                surface.SetDrawColor(255, 210, 90, alpha)
                surface.SetMaterial(matTime)
                surface.DrawTexturedRect(startX, rowY, tIconSize, tIconSize)

                draw.SimpleText(timeTxt, "DermaDefaultBold", startX + tIconSize + 6, rowY + tIconSize / 2,
                    textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            if not available then
                draw.SimpleText("нет инструмента", "DermaDefault", w / 2, h * 0.93,
                    Color(200, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        btn.DoClick = function()
            if not available or not self.mode then
                surface.PlaySound("buttons/button10.wav")
                return
            end

            surface.PlaySound("ui/buttonclick.wav")
            DoorSystem.RequestBreak(self.door, toolCfg.id, self.mode)
            self:Remove()
        end

        table.insert(self.tools, btn)
    end
end

-- Две большие квадратные кнопки способа справа от двери: только иконка на
-- общем фоне, без текста.
function PANEL:BuildModeButtons()
    if self.modeButtons then
        for _, b in ipairs(self.modeButtons) do
            if IsValid(b) then b:Remove() end
        end
    end

    self.modeButtons = {}

    local gap = 15
    local side = math.min(self.sideW, math.floor((self.doorH - gap) / 2))
    local startY = (self.doorH - (side * 2 + gap)) / 2
    local x = self.doorW + self.sideGap + (self.sideW - side) / 2

    local matBg = Material("door_system_v2/mode_bg.png", "noclamp smooth")

    local modes = {
        { id = "timer", icon = Material("door_system_v2/mode_timer.png", "noclamp smooth") },
        { id = "hands", icon = Material("door_system_v2/mode_hands.png", "noclamp smooth") },
    }

    for i, m in ipairs(modes) do
        local btn = vgui.Create("DButton", self)
        btn:SetText("")
        btn:SetSize(side, side)
        btn:SetPos(x, startY + (i - 1) * (side + gap))

        btn.Paint = function(s, w, h)
            local selected = self.mode == m.id
            local hover = s:IsHovered()

            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(matBg)
            surface.DrawTexturedRect(0, 0, w, h)

            -- Иконка крупная: ~70% кнопки; выбранная — ярче, остальные приглушены.
            local iconSize = w * 0.7
            local c = selected and 255 or (hover and 230 or 170)
            if selected then
                surface.SetDrawColor(255, 225, 130, 255)
            else
                surface.SetDrawColor(c, c, c, 255)
            end
            surface.SetMaterial(m.icon)
            surface.DrawTexturedRect(w / 2 - iconSize / 2, h / 2 - iconSize / 2, iconSize, iconSize)

            if selected then
                surface.SetDrawColor(255, 210, 90, 255)
                surface.DrawOutlinedRect(6, 6, w - 12, h - 12, 3)
            end
        end

        btn.DoClick = function()
            surface.PlaySound("ui/buttonclick.wav")
            self.mode = m.id
        end

        table.insert(self.modeButtons, btn)
    end
end

vgui.Register("DoorSystemMenu", PANEL, "DPanel")
