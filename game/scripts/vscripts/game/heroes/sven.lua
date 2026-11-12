-- Sven: four distinct perk paths that change how his abilities play.
Sven = Sven or {}

local BUILDS = {
	hammer = "Громовой удар (Storm Hammer)",
	cleave = "Рассекающий меч (Great Cleave)",
	warcry = "Боевой клич (Warcry)",
	strength = "Божья сила (God's Strength)",
}
local function mythic(id, branch, name, desc) return { id=id, tier=5, build=branch, max=1, name=name, desc=desc } end
local function legend(id, branch, name, desc) return { id=id, tier=4, build=branch, requires_build=branch, max=1, name=name, desc=desc } end
local function epic(id, branch, name, desc) return { id=id, tier=3, build=branch, requires_build=branch, max=1, name=name, desc=desc } end

local PERKS = {
	-- Storm Hammer: electric field and returning hammer.
	mythic("m_sven_hammer", "hammer", "Молот и наковальня", "При попадании молот остаётся в точке столкновения на 3 с. Каждые 0,5 с молния поражает случайного врага в радиусе 700. Затем молот возвращается к Sven, нанося урон врагам на пути."),
	legend("l_sven_storm_chain", "hammer", "Громоотвод", "Враги, поражённые Storm Hammer, становятся проводниками: молния между ними наносит 50% урона молота."),
	legend("l_sven_storm_execution", "hammer", "Электрическая казнь", "Storm Hammer наносит цели ниже 20% здоровья дополнительный чистый урон в размере 15% её максимального здоровья."),
	legend("l_sven_storm_charge", "hammer", "Нестабильный заряд", "Каждый поражённый враг увеличивает урон следующего Storm Hammer на 10%, до 100%."),
	legend("l_sven_storm_echo", "hammer", "Гром среди ясного неба", "С вероятностью 25% Storm Hammer повторяется через 0,5 с с уменьшенным на 50% уроном."),
	epic("e_sven_hammer_bolts", "hammer", "Раскат грома", "При попадании Storm Hammer выпускает 3 молнии по ближайшим врагам."),
	epic("e_sven_hammer_surge", "hammer", "Громовой порыв", "После броска Storm Hammer Sven получает +20% к скорости передвижения на 3 с."),
	epic("e_sven_hammer_pierce", "hammer", "Пробивающий удар", "Storm Hammer игнорирует 30% сопротивления магии поражённых целей."),
	epic("e_sven_hammer_static", "hammer", "Статический накопитель", "Каждая атака Sven добавляет 25 урона следующему Storm Hammer, до 6 зарядов; заряды сбрасываются при применении."),
	epic("e_sven_hammer_aftershock", "hammer", "Электрическое эхо", "Через 1,5 с после попадания Storm Hammer вспыхивает повторно: 30% базового урона и оглушение на 0,1 с."),
	epic("e_sven_hammer_dispel", "hammer", "Снятие защиты", "Storm Hammer снимает положительные эффекты с основной цели обычным развеиванием."),
	epic("e_sven_hammer_mana", "hammer", "Заряд бодрости", "Попадание Storm Hammer восстанавливает 15 маны за каждого поражённого вражеского героя."),
	epic("e_sven_hammer_punish", "hammer", "Карающий разряд", "Storm Hammer наносит на 1,5% больше урона за каждые 5% недостающего здоровья цели."),

	-- Great Cleave: directional, front-facing cleaves with chained and mark-based payoff.
	mythic("m_sven_cleave", "cleave", "Цепное рассечение", "Great Cleave распространяется от каждого поражённого противника: до 4 дополнительных волн, каждая наносит на 20% меньше урона."),
	legend("l_sven_cleave_debt", "cleave", "Мясорубка", "Атаки Sven накладывают на врагов метки долга. Great Cleave усиливается на 25% за метку; при 4 метках они взрываются дополнительным уроном 200%."),
	legend("l_sven_cleave_execute", "cleave", "Смертельный размах", "Great Cleave наносит на 30% больше урона врагам ниже 40% здоровья."),
	legend("l_sven_cleave_bleed", "cleave", "Кровавый клинок", "Great Cleave накладывает кровотечение на 5 с."),
	legend("l_sven_cleave_resonance", "cleave", "Сейсмический резонанс", "Если Great Cleave задевает 3+ врагов, Sven совершает дополнительную атаку по основной цели (перезарядка эффекта 3 с)."),
	epic("e_sven_cleave_arc", "cleave", "Размашистый замах", "Угол Great Cleave увеличен на 20°, дальность — на 150."),
	epic("e_sven_cleave_damage", "cleave", "Острая кромка", "Урон Great Cleave увеличен на 15%."),
	epic("e_sven_cleave_kill_speed", "cleave", "Импульс разрыва", "Убийство Great Cleave даёт Sven +10% скорости передвижения на 3 с."),
	epic("e_sven_cleave_stagger", "cleave", "Сокрушительный вес", "Great Cleave с вероятностью 15% оглушает поражённых врагов на 0,1 с."),
	epic("e_sven_cleave_hero_speed", "cleave", "Вспышка ярости", "Каждый поражённый вражеский герой даёт Sven +10 скорости атаки на 3 с, до 5 зарядов."),
	epic("e_sven_cleave_lifesteal", "cleave", "Стальная жажда", "Sven восстанавливает здоровье в размере 5% урона Great Cleave."),
	epic("e_sven_cleave_hammer_cd", "cleave", "Кинетический замах", "Попадание Great Cleave по 2+ врагам снижает оставшуюся перезарядку Storm Hammer на 0,5 с."),
	epic("e_sven_cleave_healblock", "cleave", "Взрез по жилам", "Great Cleave снижает входящее лечение и регенерацию поражённых целей на 20% на 3 с."),

	-- Warcry: frontline team support that stores and returns pressure.
	mythic("m_sven_warcry", "warcry", "Последний бастион", "Warcry создаёт зону радиусом 900. Урон по союзникам внутри накапливается и по окончании клича возвращается врагам чистым уроном."),
	legend("l_sven_warcry_damage", "warcry", "Военный марш", "Каждый союзник под Warcry увеличивает урон Sven на 15%."),
	legend("l_sven_warcry_resist", "warcry", "Железная дисциплина", "Союзники под Warcry получают 30% сопротивления магии."),
	legend("l_sven_warcry_extend", "warcry", "Непоколебимый легион", "Если здоровье союзника падает ниже 20%, Warcry продлевается на 3 с. Для каждого союзника — раз в 15 с."),
	legend("l_sven_warcry_allies_damage", "warcry", "Взаимовыгодный союз", "Союзники под Warcry наносят на 30% больше урона."),
	epic("e_sven_warcry_lifesteal", "warcry", "Боевой азарт", "Атаки Sven под Warcry восстанавливают здоровье в размере 15% урона атаки."),
	epic("e_sven_warcry_range", "warcry", "Знамя победы", "Warcry увеличивает дальность атаки союзников дальнего боя на 150."),
	epic("e_sven_warcry_radius", "warcry", "Железный авторитет", "Радиус Warcry увеличен на 1000."),
	epic("e_sven_warcry_counter", "warcry", "Контрудар", "Sven и союзники под Warcry возвращают атакующим 15% полученного физического урона."),
	epic("e_sven_warcry_as", "warcry", "Штурмовой ритм", "Warcry увеличивает скорость атаки Sven и союзников на 25."),
	epic("e_sven_warcry_silence", "warcry", "Громогласный клич", "При применении Warcry накладывает безмолвие на врагов в радиусе 500 на 1 с."),
	epic("e_sven_warcry_heal_amp", "warcry", "Исцеляющий рёв", "Союзники под Warcry получают +20% входящего лечения и регенерации."),
	epic("e_sven_warcry_suppress", "warcry", "Подавляющее присутствие", "Базовый урон врагов в радиусе Warcry снижен на 15% на время действия."),

	-- God's Strength: sustained combat, kill streaks and execution.
	mythic("m_sven_strength", "strength", "Бесконечная война", "God's Strength длится 8 с вместо фиксированной длительности. Каждая атака продлевает эффект на 0,5 с, убийство — на 4 с."),
	legend("l_sven_strength_rush", "strength", "Азарт", "Каждое убийство во время God's Strength увеличивает его бонусный урон на 10%, до 5 раз за применение."),
	legend("l_sven_strength_momentum", "strength", "Натиск", "Каждая атака во время God's Strength даёт +5% скорости передвижения на 3 с, до 10 зарядов."),
	legend("l_sven_strength_trophy", "strength", "Коллекция трофеев", "Каждое убийство во время God's Strength добавляет 0,5 с длительности следующего применения, до 20 зарядов."),
	legend("l_sven_strength_hammer_reset", "strength", "Палач", "Убийство во время God's Strength сокращает оставшуюся перезарядку Storm Hammer на 20%."),
	epic("e_sven_strength_collector", "strength", "Коллекционер", "Каждые 50 убийств во время God's Strength увеличивают максимальное здоровье Sven на 1%."),
	epic("e_sven_strength_brutality", "strength", "Жестокость", "God's Strength наносит на 15% больше урона врагам ниже 50% здоровья."),
	epic("e_sven_strength_second_wind", "strength", "Второе дыхание", "Убийство во время God's Strength восстанавливает 0,2% максимального здоровья."),
	epic("e_sven_strength_war_supremacy", "strength", "Военное превосходство", "Убийство даёт +10% скорости атаки на 4 с, до 5 зарядов."),
	epic("e_sven_strength_slow_resist", "strength", "Уверенность", "God's Strength увеличивает сопротивление замедлению на 35%."),
	epic("e_sven_strength_armor_break", "strength", "Сокрушение", "Атаки по боссу во время God's Strength снижают его броню на 10 на 3 с, до 5 зарядов."),
	epic("e_sven_strength_scars", "strength", "Боевые шрамы", "Полученные атаки во время God's Strength дают до 30% сопротивления физическому урону (+2% за атаку) на 3 с."),
	epic("e_sven_strength_fifth", "strength", "Неотвратимая расправа", "Каждая пятая атака Sven по одной цели во время God's Strength наносит дополнительный урон в размере 100% урона атаки."),

	-- Rare perks stay stackable, but are specific to Sven's chosen kit.
	{ id="r_sven_hammer_damage", tier=2, max=20, name="Тяжёлый молот", desc="+75 урона Storm Hammer", sven={hammer_damage=75} },
	{ id="r_sven_hammer_range", tier=2, max=8, name="Дальний удар", desc="+100 к дальности Storm Hammer", sven={hammer_range=100} },
	{ id="r_sven_cleave_damage", tier=2, max=20, name="Заточенный клинок", desc="+8% урона Great Cleave", sven={cleave_damage=8} },
	{ id="r_sven_cleave_radius", tier=2, max=10, name="Широкий замах", desc="+40 к дальности Great Cleave", sven={cleave_radius=40} },
	{ id="r_sven_warcry_duration", tier=2, max=10, name="Долгий клич", desc="+0,5 с к Warcry", sven={warcry_duration=0.5} },
	{ id="r_sven_warcry_armor", tier=2, max=10, name="Крепкий строй", desc="+3 брони от Warcry", sven={warcry_armor=3} },
	{ id="r_sven_strength_damage", tier=2, max=20, name="Растущая сила", desc="+15% урона God's Strength", sven={strength_damage=15} },
	{ id="r_sven_strength_cooldown", tier=2, max=10, name="Короткая передышка", desc="−3 с перезарядки God's Strength", sven={strength_cooldown=3} },
	{ id="r_sven_stats", tier=2, max=20, name="Рыцарь силы", desc="+12 к урону и +4 брони", stats={damage=12, armor=4} },
}

RPG.HEROES["npc_dota_hero_sven"] = {
	modifier = "modifier_rpg_sven",
	builds = BUILDS,
	perks = PERKS,
}

function Sven:Has(hero, id)
	if not hero or hero:IsNull() then return false end
	if IsServer() then return hero.rpg and (hero.rpg.perk_count[id] or 0) > 0 or false end
	local t = CustomNetTables:GetTableValue("rpg_perks", tostring(hero:entindex()))
	return t and (t[id] or 0) > 0
end

function Sven:Bonus(hero, id)
	if not hero or hero:IsNull() then return 0 end
	if IsServer() then return hero.rpg and hero.rpg.sven_bonus and hero.rpg.sven_bonus[id] or 0 end
	local t = CustomNetTables:GetTableValue("rpg_perks", tostring(hero:entindex()))
	return t and t["bonus_sven_" .. id] or 0
end
