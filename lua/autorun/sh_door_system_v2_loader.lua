--[[
    DOOR SYSTEM V2 — загрузчик аддона
    Подключает все файлы из lua/door_system_v2/.
]]

DoorSystem = DoorSystem or {}

local function IncludeShared(path)
    if SERVER then
        AddCSLuaFile(path)
    end

    include(path)
end

-- Общие файлы нужны как на сервере, так и на клиенте.
IncludeShared("door_system_v2/sh_config.lua")
IncludeShared("door_system_v2/sh_util.lua")

if SERVER then
    CreateConVar("door_system_skin_chance", "0.20", FCVAR_ARCHIVE + FCVAR_REPLICATED,
        "Шанс появления кастомной двери (0.0 - 1.0)")

    -- Вес каждого кастомного скина. Значения используются как доли
    -- внутри уже выпавшей кастомной двери и нормализуются автоматически.
    for _, skinId in ipairs(DoorSystem.Config.RandomSkin.pool or {}) do
        CreateConVar(
            "door_system_skin_weight_" .. skinId,
            tostring((DoorSystem.Config.RandomSkin.weights or {})[skinId] or 0),
            FCVAR_ARCHIVE + FCVAR_REPLICATED,
            "Вес кастомного скина двери " .. skinId .. " (0 - 100)"
        )
    end

    -- Клиентские файлы отправляются игрокам.
    AddCSLuaFile("door_system_v2/cl_ui.lua")
    AddCSLuaFile("door_system_v2/cl_breaking.lua")
    AddCSLuaFile("door_system_v2/cl_settings.lua")
    AddCSLuaFile("door_system_v2/cl_minigame.lua")

    -- Сетевые строки регистрируются один раз на сервере.
    util.AddNetworkString("DoorSystem_Start")
    util.AddNetworkString("DoorSystem_Progress")
    util.AddNetworkString("DoorSystem_Stop")
    util.AddNetworkString("DoorSystem_Cancel")
    util.AddNetworkString("DoorSystem_Hit")
    util.AddNetworkString("DoorSystem_Broken")
    util.AddNetworkString("DoorSystem_EasterEgg")
    util.AddNetworkString("DoorSystem_MinigameHit")
    util.AddNetworkString("DoorSystem_StartResult")
    util.AddNetworkString("DoorSystem_UpdateSkinSettings")

    include("door_system_v2/sv_breaking.lua")
    include("door_system_v2/sv_model_swap.lua")
    include("door_system_v2/sv_lock.lua")
    include("door_system_v2/sv_easter_egg.lua")

    -- Ресурсы добавляются в список для скачивания клиентам.
    resource.AddSingleFile("materials/door_system_v2/axe.png")
    resource.AddSingleFile("materials/door_system_v2/crowbar.png")
    resource.AddSingleFile("materials/door_system_v2/fist.png")
    resource.AddSingleFile("materials/door_system_v2/lock_method_bg.png")
    resource.AddSingleFile("materials/door_system_v2/timer.png")
    resource.AddSingleFile("materials/door_system_v2/menu_bg.png")
    resource.AddSingleFile("materials/door_system_v2/dynamite.png")
    resource.AddSingleFile("materials/door_system_v2/hacksaw.png")
    resource.AddSingleFile("materials/door_system_v2/grenade.png")
    resource.AddSingleFile("materials/door_system_v2/handmade_grenade.png")
    resource.AddSingleFile("materials/door_system_v2/shovel.png")
    resource.AddSingleFile("materials/door_system_v2/molotov.png")
    resource.AddSingleFile("materials/door_system_v2/mode_bg.png")
    resource.AddSingleFile("materials/door_system_v2/mode_timer.png")
    resource.AddSingleFile("materials/door_system_v2/mode_hands.png")

    resource.AddSingleFile("materials/door_system_v2/minigame/frame.png")
    resource.AddSingleFile("materials/door_system_v2/minigame/locked_door.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/locked_door_open.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/wood_door.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/wood_door_open.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/iron_door.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/iron_door_open.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/steel_door.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/steel_door_open.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/blocked_door.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/blocked_door_open.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/iron_door2.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/iron_door2_open.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/steel_door2.jpg")
    resource.AddSingleFile("materials/door_system_v2/minigame/steel_door2_open.jpg")

    resource.AddSingleFile("sound/door_system_v2/axe_hit.ogg")
    resource.AddSingleFile("sound/door_system_v2/crowbar_hit.ogg")
    resource.AddSingleFile("sound/door_system_v2/fist_hit.mp3")
    resource.AddSingleFile("sound/door_system_v2/explosion.ogg")
    resource.AddSingleFile("sound/door_system_v2/hacksaws.ogg")
else
    include("door_system_v2/cl_ui.lua")
    include("door_system_v2/cl_breaking.lua")
    include("door_system_v2/cl_settings.lua")
    include("door_system_v2/cl_minigame.lua")
end