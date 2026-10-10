--[[
    DOOR SYSTEM V2 — конфиг
    Все настройки доступны в одном месте.
]]

DoorSystem = DoorSystem or {}

DoorSystem.Config = {
    -- Имя консольной команды, на которую игрок вешает bind.
    Bind = "door_system_use",

    -- С какой дистанции можно начать взлом.
    MaxUseDistance = 90,

    -- Если игрок отойдёт дальше этого расстояния, взлом прервётся.
    MaxBreakDistance = 130,

    -- Путь к фону меню выбора инструмента.
    MenuBackground = "door_system_v2/menu_bg.png",

    -- Размер картинки двери в меню (боковая колонка с кнопками режимов
    -- добавляется справа от неё, вся группа центрируется на экране).
    MenuWidth = 400,
    MenuHeight = 405,

    -- Боковая колонка с кнопками «по таймеру» / «руками».
    MenuSideWidth = 210,
    MenuSideGap = 16,

    -- Смещение меню от центра экрана (0 = ровно по центру).
    MenuOffsetX = 0,
    MenuOffsetY = 0,

    -- Показывать рамку вокруг меню.
    MenuShowBorder = false,

    -- Мини-игра во время взлома.
    MinigameMenu = {
        enabled = true,
        frame = "door_system_v2/minigame/frame.png",

        -- Фон в зависимости от скина двери.
        backgroundsBySkin = {
            [0] = "locked_door",
            [14] = "locked_door",
            [15] = "iron_door",
            [16] = "wood_door",
            [17] = "steel_door",
            [18] = "blocked_door",
            [19] = "iron_door2",
            [20] = "steel_door2",
        },

        width = 400,
        height = 405,

        -- Зона спавна крестиков в долях от размера изображения.
        hitZone = { x1 = 0.28, y1 = 0.08, x2 = 0.74, y2 = 0.88 },

        crossSize = 32,
        crossLifetime = 1.4,
        crossSpawnEvery = 0.9,
        openHoldTime = 1.3,
    },

    -- Режимы взлома.
    --   timer — обычный взлом по таймеру, без мини-игры;
    --   hands — мини-игра: прогресс растёт только от попаданий по крестикам.
    -- result: "open"  — дверь открывается (не выпадает);
    --         "break" — дверь выпадает из проёма (старое поведение).
    Modes = {
        timer = { result = "open" },
        hands = { result = "open" },
    },

    -- Параметры режима «ломать руками» (пока одинаковые для всех дверей).
    HandsMode = {
        hitsRequired = 8,      -- сколько попаданий нужно, чтобы сломать дверь
        minHitInterval = 0.2,  -- антиспам: минимальный интервал между попаданиями
        timeout = 120,         -- абсолютный потолок мини-игры, сек
    },

    -- Классы сущностей, которые считаются дверями.
    ValidClasses = {
        ["func_door"] = true,
        ["func_door_rotating"] = true,
        ["prop_dynamic"] = true,
        ["prop_door_rotating"] = true,
    },

    -- Через сколько секунд удалять сорванную дверь.
    RemoveBrokenAfter = 0,

    -- Подмена моделей на кастомные с дополнительными скинами.
    CustomModelReplacements = {
        ["models/props_c17/door01_left.mdl"] = "models/door_system_v2/door01_left_custom.mdl",
    },

    -- Случайный скин для дверей с заменённой моделью.
    RandomSkin = {
        -- Общая вероятность того, что дверь станет кастомной.
        chance = 0.20,

        -- Скины, которые участвуют в выборе.
        pool = { 14, 15, 16, 17, 18, 19, 20 },

        -- Начальные веса внутри кастомных дверей.
        -- Например, 70 для 15 и 30 для 16 означает:
        -- при выпадении кастомной двери 70% = железная, 30% = деревянная.
        -- Сумма не обязана быть 100: веса автоматически нормализуются.
        weights = {
            [14] = 25,  --Заколоченная
            [15] = 10, -- Железная квартирная
            [16] = 30, -- Деревянная
            [17] = 5,  -- Бронированная
            [18] = 15,  -- Завал
            [19] = 10,  -- Решётка
            [20] = 5,  -- Заражённая
        },

        -- Подписи для ползунков в Q-меню.
        names = {
            [14] = "Заколоченная",
            [15] = "Железная квартирная",
            [16] = "Деревянная",
            [17] = "Бронированная",
            [18] = "Завал",
            [19] = "Решётка",
            [20] = "Заражённая",
        },
    },

    -- Расстояние, при котором двери считаются двойными.
    DoubleDoorDetectRadius = 50,

    -- Тип двери по номеру скина.
    DoorTypes = {
        [0] = "wood",
        [1] = "wood",
        [2] = "wood",
        [3] = "wood",
        [4] = "wood",
        [5] = "wood",
        [6] = "wood",
        [7] = "iron",
        [8] = "iron",
        [9] = "iron",
        [10] = "iron",
        [11] = "wood",
        [12] = "iron",
        [13] = "wood",
        [14] = "wood",
        [15] = "iron",
        [16] = "wood",
        [17] = "iron",
        [18] = "wood",
        [19] = "iron",
        [20] = "iron",
    },

    -- Bodygroup ручки на кастомной модели двери.
    DoorHandleBodygroup = {
        group = 1,
        value = 0,
        skins = { 14, 15, 16, 17, 18, 19, 20 },
    },

    -- Список инструментов. Каких именно и за сколько секунд ломает конкретная
    -- дверь — в DoorTools ниже. requiredWeapons — классы оружия, которое
    -- игрок должен держать в руках (нет поля — инструмент всегда доступен).
    Tools = {
        {
            id = "fist",
            name = "Голые руки",
            icon = "door_system_v2/fist.png",
            hitSound = "door_system_v2/fist_hit.mp3",
            hitInterval = 0.6,
        },
        {
            id = "axe",
            name = "Топор",
            icon = "door_system_v2/axe.png",
            requiredWeapons = {
                ["tfa_dayr_axe_rust"] = true,
                ["tfa_dayr_axe_normal"] = true,
                ["tfa_dayr_axe_handmade"] = true,
                ["tfa_dayr_axe_steeltools"] = true,
                ["tfa_dayr_axe_irontool"] = true,
                ["tfa_dayr_axe_flint"] = true,
            },
            hitSound = "door_system_v2/axe_hit.ogg",
            hitInterval = 0.8,
            weaponSwingAnim = true,
            swingDuration = 0.38,
        },
        {
            id = "crowbar",
            name = "Монтировка",
            icon = "door_system_v2/crowbar.png",
            requiredWeapons = {
                ["weapon_crowbar"] = true,
            },
            hitSound = "door_system_v2/crowbar_hit.ogg",
            hitInterval = 0.5,
            weaponSwingAnim = true,
            swingDuration = 0.24,
        },
        {
            id = "hacksaw",
            name = "Ножовка",
            icon = "door_system_v2/hacksaw.png",
            requiredWeapons = {
                ["tfa_dayr_hacksaw_rusted"] = true,
                ["tfa_dayr_hacksaw"] = true,
            },
            hitSound = "door_system_v2/hacksaws.ogg",
            hitInterval = 0.5,
            weaponSwingAnim = true,
            swingDuration = 0.24,
        },
        {
            id = "shovel",
            name = "Лопата",
            icon = "door_system_v2/shovel.png",
            -- TODO: проверь классы лопаты из Day R, здесь стоят предположения.
            requiredWeapons = {
                ["tfa_dayr_shovel"] = true,
                ["tfa_dayr_shovel_rusted"] = true,
                ["tfa_dayr_shovel_handmade"] = true,
            },
            hitSound = "door_system_v2/axe_hit.ogg", -- заглушка
            hitInterval = 0.8,
            weaponSwingAnim = true,
            swingDuration = 0.38,
        },
        {
            id = "handmade_grenade",
            name = "Самодельная граната",
            icon = "door_system_v2/handmade_grenade.png",
            requiredWeapons = {
                ["dayr_handmade_grenade"] = true,
            },
            hitSound = "door_system_v2/explosion.ogg",
            hitInterval = 0.5,
            weaponSwingAnim = true,
            swingDuration = 0.24,
        },
        {
            id = "grenade",
            name = "Граната",
            icon = "door_system_v2/grenade.png",
            requiredWeapons = {
                ["weapon_frag"] = true,
            },
            hitSound = "door_system_v2/explosion.ogg",
            hitInterval = 0.5,
            weaponSwingAnim = true,
            swingDuration = 0.24,
        },
        {
            id = "dynamite",
            name = "Динамит",
            icon = "door_system_v2/dynamite.png",
            requiredWeapons = {
                ["tfa_dayr_dynamite"] = true,
            },
            hitSound = "door_system_v2/explosion.ogg",
            hitInterval = 0.5,
            weaponSwingAnim = true,
            swingDuration = 0.24,
        },
        {
            id = "molotov",
            name = "Молотов",
            icon = "door_system_v2/molotov.png", -- заглушка, пока нет настоящей иконки
            -- TODO: проверь класс молотова из Day R, здесь предположение.
            requiredWeapons = {
                ["tfa_dayr_molotov"] = true,
                ["dayr_molotov"] = true,
            },
            hitSound = "door_system_v2/explosion.ogg", -- заглушка
            hitInterval = 0.5,
            weaponSwingAnim = true,
            swingDuration = 0.24,
        },
    },

    -- Какими инструментами ломается дверь с данным скином и за сколько секунд
    -- (время для одного и того же инструмента на каждой двери своё).
    -- Порядок записей = порядок кнопок в меню (до трёх штук).
    DoorTools = {
        [14] = { -- Заколоченная
            { id = "axe", time = 60 },
            { id = "hacksaw", time = 90 },
            { id = "crowbar", time = 30 },
        },
        [15] = { -- Железная квартирная
            { id = "crowbar", time = 150 },
            { id = "hacksaw", time = 60 },
            { id = "handmade_grenade", time = 6 },
        },
        [16] = { -- Деревянная
            { id = "fist", time = 150 },
            { id = "axe", time = 45 },
            { id = "crowbar", time = 10 },
        },
        [17] = { -- Бронированная
            { id = "handmade_grenade", time = 3 },
            { id = "grenade", time = 2 },
            { id = "dynamite", time = 1 },
        },
        [18] = { -- Завал
            { id = "fist", time = 120 },
            { id = "shovel", time = 60 },
            { id = "crowbar", time = 90 },
        },
        [19] = { -- Решётка
            { id = "handmade_grenade", time = 5 },
            { id = "grenade", time = 4 },
            { id = "hacksaw", time = 75 },
        },
        [20] = { -- Заражённая
            { id = "molotov", time = 5 },
            { id = "grenade", time = 3 },
            { id = "dynamite", time = 2 },
        },
    },

    -- Набор для обычных (ванильных) скинов — по типу двери из DoorTypes.
    DefaultDoorTools = {
        wood = {
            { id = "fist", time = 150 },
            { id = "axe", time = 60 },
            { id = "crowbar", time = 10 },
        },
        iron = {
            { id = "crowbar", time = 150 },
            { id = "hacksaw", time = 60 },
            { id = "grenade", time = 1 },
        },
    },

    -- Пасхалка: во время взлома можно активировать удар дверью по игроку.
    EasterEgg = {
        enabled = true,
        model = "models/door_system_v2/door01_left_custom.mdl",
        spawnHeight = 220,
        cooldown = 5,
    },
}
