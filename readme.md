# Door-system-v2
Аддон добавляющий возможность ломать двери в Garry's Mod как в Day r survival.

ФУНКЦИИ:

- С настраиваемым шансом (по умолчанию 10%, регулируется ползунком в
настройках) любая дверь при входе на карту может замениться на
закрытую, с одним из кастомных скинов.
- Дополнительные скины для обычной ванильной двери.
- Уникальные мини-игры в режиме «руками»: кулаки — кликер по двери, топор — крестики, лом — шкала (пробел двигает separator вправо), ножовка — зажатый ползунок, завал — выбрасывание камней и досок (одна игра для любого инструмента, после раскопок дверь убирается), гранаты/динамит — взрыв, молотов — огонь. Сложность каждой игры зависит от двери (Config.DifficultyBySkin / Config.Difficulty).
- Система взлома дверей с меню по центру экрана: выбираешь инструмент
и один из двух режимов — «Ломать по таймеру» (дверь открывается) или
«Ломать руками» (мини-игра с крестиками).
- У каждой кастомной двери свой набор инструментов и время взлома
(Config.DoorTools в sh_config.lua).
- Заблокированные двери нельзя открыть обычным способом — только
через систему взлома.
- Прикольная менюшка.
- Совместимость с оружиями из Day R.
- Анимация выбивания (замах инструментом + удар).
- Звуки.
- Все настройки (клавиша взлома, шанс появления кастомных дверей)
находятся в Q-меню -> Utilities -> Door System — бинд руками
через консоль больше не нужен.

---

# Door-system-v2 (English)

An addon that lets you break down doors in Garry's Mod, in the style of Day R Survival.

FEATURES:

- With a configurable chance (set with a slider in the settings), any door on map load can be replaced with a locked one that has one of the custom skins.
- Additional skins for the regular vanilla door.
- Unique minigames in "by hand" mode: fists — a door clicker, axe — crosses, crowbar — a meter (SPACE moves the separator to the right), hacksaw — a held slider, rubble — throwing away stones and planks (one game for any tool; the door is removed after digging), grenades/dynamite — an explosion, molotov — fire. The difficulty of each game depends on the door (Config.DifficultyBySkin / Config.Difficulty).
- A door-breaking system with a menu in the center of the screen: pick a tool and one of two modes — "Break on a timer" (the door opens) or "Break by hand" (a minigame).
- Each custom door has its own set of tools and breaking time (Config.DoorTools in sh_config.lua).
- Locked doors cannot be opened the usual way — only through the breaking system.
- A nice menu.
- Compatible with Day R weapons.
- Breaking animation (tool swing + hit).
- Sounds.
- All settings (breaking key, chance of custom doors, language) are in Q-menu -> Utilities -> Door System — no more binding through the console.

LOCALIZATION:

- Supported languages: Russian (ru) and English (en). Both are included.
- The language is chosen in Q-menu -> Utilities -> Door System -> "Язык / Language", or via the `door_system_language` console variable (`auto` / `ru` / `en`). `auto` follows the game language (`gmod_language`): Russian for `ru`, English for everything else.
- All texts are in `lua/door_system_v2/sh_lang.lua`. To add a language, add a new table to `DoorSystem.Lang.Strings` and list its code in `DoorSystem.Lang.Available`.
- Server console logs use the language set by `door_system_language` on the server.
