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

    -- Способ взлома, выбранный в меню по умолчанию (дальше запоминается
    -- последний выбранный): "hands" — руками, "timer" — по таймеру.
    DefaultMode = "hands",

    -- «Энергия» под иконками инструментов в режиме «руками» = сколько действий
    -- нужно сделать в мини-игре: ударов, кликов, нажатий, проходов ползунка,
    -- перетащенных обломков. Три инструмента двери получают значения по
    -- убыванию времени взлома: самый долгий — первое число и т.д.
    -- Для конкретной записи DoorTools можно задать своё: { id = "axe", time = 60, energy = 20 }.
    EnergyLevels = { 30, 15, 5 },

    -- Во сколько раз больше ударов нужно для инструмента в кликере по двери
    -- (кулак: 30 энергии = 60 ударов). На завале кулак — это 30 обломков, без множителя.
    EnergyHitMultiplier = { fist = 2 },
    EnergyIcon = "door_system_v2/energy.png",

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

    -- Параметры режима «ломать руками» (по умолчанию — для крестиков).
    HandsMode = {
        hitsRequired = 8,      -- сколько попаданий нужно, чтобы сломать дверь
        minHitInterval = 0.2,  -- антиспам: минимальный интервал между попаданиями
        timeout = 120,         -- абсолютный потолок мини-игры, сек
    },

    -- Какая мини-игра у какого инструмента (в режиме «руками»):
    --   clicker — кликать по двери;
    --   crosses — кликать по появляющимся крестикам;
    --   debris  — лопата: схватить обломок (камень/кирпич/доску) и выбросить в бок;
    --   bar     — удерживать separator на участке шкалы (пробел — вправо, отпустил — влево);
    --   saw     — зажать ползунок и водить вправо-влево;
    --   boom    — звук взрыва + анимация кадров;
    --   molotov — звук + анимация огня.
    MinigameKinds = {
        fist = "clicker",
        axe = "crosses",
        shovel = "debris",
        crowbar = "bar",
        hacksaw = "saw",
        grenade = "boom",
        handmade_grenade = "boom",
        dynamite = "boom",
        molotov = "molotov",
    },

    -- Сложность мини-игр зависит от двери. Уровень двери (1..5) берётся из
    -- DifficultyBySkin, а для обычных дверей — из DefaultDifficulty по типу.
    DifficultyBySkin = {
        [14] = 2, -- Заколоченная
        [15] = 3, -- Железная квартирная
        [16] = 1, -- Деревянная
        [17] = 5, -- Бронированная
        [18] = 3, -- Завал
        [19] = 4, -- Решётка
        [20] = 4, -- Заражённая
    },
    DefaultDifficulty = { wood = 1, iron = 3 },

    -- Двери, у которых мини-игра одна для любого инструмента. Количество
    -- обломков берётся из энергии инструмента (можно задать hitsRequired по
    -- id инструмента, hitsDefault — для остальных, это перекроет энергию).
    DoorMinigameOverride = {
        [18] = { -- Завал: всегда «раскидать камни и доски»
            kind = "debris",
        },
    },

    -- Что происходит с дверью после взлома (поверх Modes): "remove" — дверь
    -- просто исчезает (только она сама), без открывания и выпадения.
    DoorResultBySkin = {
        [18] = "remove", -- Завал: после раскопок убирается
    },

    -- Параметры мини-игр по уровням. Массив из 5 чисел = значения для уровней
    -- 1..5, одиночное значение одинаково для всех уровней.
    -- (boom и molotov — просто эффекты, сложности у них нет.)
    Difficulty = {
        -- Кулаки: кликать по двери.
        clicker = {
            minHitInterval = 0.08,
        },

        -- Топор: крестики.
        crosses = {
            minHitInterval = 0.2,
            crossLifetime = { 1.8, 1.4, 1.1, 0.9, 0.75 },
            crossSpawnEvery = { 1.1, 0.9, 0.75, 0.65, 0.55 },
            crossSize = { 38, 32, 28, 26, 24 },
        },

        -- Лом: separator едет вправо, пока зажат пробел, и влево, когда отпущен.
        bar = {
            secondsPerEnergy = 0.4,               -- секунд удержания на единицу энергии (5 → 2 с, 30 → 12 с)
            drainMul = 0,                          -- шкала не убывает мимо участка (0 = не убывает; >0 — доля скорости роста)
            zoneWidth = { 0.28, 0.22, 0.18, 0.14, 0.11 },
            zoneSpeed = { 0.25, 0.35, 0.45, 0.6, 0.75 },
            retargetMin = { 1.2, 1.0, 0.8, 0.6, 0.5 },
            retargetMax = { 2.2, 1.8, 1.5, 1.2, 1.0 },
            sepSpeed = 1.1,   -- скорость separator, долей шкалы в секунду
            sepAccel = 6,     -- «разгон» (меньше — separator инертнее)
        },

        -- Ножовка: ползунок нужно зажать и водить от края до края.
        saw = {
            minHitInterval = 0.15,
            edgeZone = { 0.14, 0.11, 0.09, 0.07, 0.06 }, -- насколько близко к краю засчитывается проход
        },

        -- Лопата: схватить обломок и выбросить за пределы двери в бок.
        debris = {
            minHitInterval = 0.15,
            maxItems = { 2, 3, 3, 4, 5 },          -- сколько обломков одновременно
            spawnEvery = { 1.4, 1.1, 0.9, 0.75, 0.6 },
            lifetime = { 7, 5.5, 4.5, 3.5, 2.8 },  -- через сколько обломок пропадёт сам
            itemSize = 84,

            -- Где появляются обломки (в долях панели мини-игры):
            -- камни и кирпичи — только внизу завала, доски — по всей площади двери.
            stoneZone = { y1 = 0.66, y2 = 0.86 },
            plankChance = 0.4,                 -- вероятность, что появится доска

            takeSound = "door_system_v2/oblomok_take.mp3",
            endSound = "door_system_v2/zaval_end.ogg",
        },
    },

    -- Игры-эффекты (взрыв, молотов): дверь открывается по окончании анимации.
    Effects = {
        boom = {
            duration = 1.3,
            frames = 15,
            framePath = "door_system_v2/minigame/boom/frame_%03d.jpg",
            sound = "door_system_v2/boom.mp3",
        },
        molotov = {
            duration = 1.6,
            image = "door_system_v2/minigame/molotov_fire.png",
            sound = "door_system_v2/molotov_fire.ogg",
        },
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
            hitSound = "door_system_v2/axe_hit.mp3",
            hitInterval = 0.8,
        },
        {
            id = "crowbar",
            name = "Монтировка",
            icon = "door_system_v2/crowbar.png",
            requiredWeapons = {
                ["weapon_crowbar"] = true,
            },
            hitSound = "door_system_v2/crowbar_loop.mp3",
            hitInterval = 0.5,
        },
        {
            id = "hacksaw",
            name = "Ножовка",
            icon = "door_system_v2/hacksaw.png",
            requiredWeapons = {
                ["tfa_dayr_hacksaw_rusted"] = true,
                ["tfa_dayr_hacksaw"] = true,
            },
            hitSound = "door_system_v2/hacksaw_loop.mp3",
            hitInterval = 0.5,
        },
        {
            id = "shovel",
            name = "Лопата",
            icon = "door_system_v2/shovel.png",
            -- TODO: проверь классы лопаты из Day R, здесь стоят предположения.
            requiredWeapons = {
                ["tfa_dayr_showel_rusted"] = true,
                ["tfa_dayr_showel_iron"] = true,
                ["tfa_dayr_showel_handmade"] = true,
                ["tfa_dayr_showel_steel"] = true,
                ["tfa_dayr_showel_normal"] = true,
            },
            hitSound = "door_system_v2/oblomok_drop.ogg",
            hitInterval = 0.8,
        },
        {
            id = "handmade_grenade",
            name = "Самодельная граната",
            icon = "door_system_v2/handmade_grenade.png",
            requiredWeapons = {
                ["dayr_handmade_grenade"] = true,
            },
            hitSound = "door_system_v2/boom.mp3",
            hitInterval = 0.5,
        },
        {
            id = "grenade",
            name = "Граната",
            icon = "door_system_v2/grenade.png",
            requiredWeapons = {
                ["weapon_frag"] = true,
            },
            hitSound = "door_system_v2/boom.mp3",
            hitInterval = 0.5,
        },
        {
            id = "dynamite",
            name = "Динамит",
            icon = "door_system_v2/dynamite.png",
            requiredWeapons = {
                ["tfa_dayr_dynamite"] = true,
            },
            hitSound = "door_system_v2/boom.mp3",
            hitInterval = 0.5,
        },
        {
            id = "molotov",
            name = "Молотов",
            icon = "door_system_v2/molotov.png", -- заглушка, пока нет настоящей иконки
            -- TODO: проверь класс молотова из Day R, здесь предположение.
            requiredWeapons = {
                ["tfa_dayr_molotov"] = true,
            },
            hitSound = "door_system_v2/boom.mp3", -- заглушка
            hitInterval = 0.5,
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
