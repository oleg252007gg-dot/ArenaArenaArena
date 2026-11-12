-- Sven: dependable frontline fighter with four independently upgradeable branches.
Sven = Sven or {}

local BUILDS = {
	hammer = "Громовой удар (Storm Hammer)",
	cleave = "Рассекающий меч (Great Cleave)",
	warcry = "Боевой клич (Warcry)",
	strength = "Божья сила (God's Strength)",
}
local function mythic(id, branch, name, desc) return {id=id,tier=5,build=branch,max=1,name=name,desc=desc} end
local function legend(id, branch, name, desc) return {id=id,tier=4,build=branch,requires_build=branch,max=1,name=name,desc=desc} end
local function epic(id, branch, name, desc) return {id=id,tier=3,build=branch,requires_build=branch,max=1,name=name,desc=desc} end

local PERKS = {
	mythic("m_sven_hammer","hammer","Штормовой разлом","Storm Hammer взрывается при попадании и поражает врагов вокруг основной цели."),
	mythic("m_sven_cleave","cleave","Раскол титанов","Great Cleave наносит полный урон по всей площади и дополнительно пробивает броню."),
	mythic("m_sven_warcry","warcry","Несокрушимый боевой клич","Warcry также даёт союзникам барьер и повышенное сопротивление эффектам."),
	mythic("m_sven_strength","strength","Аватар войны","God's Strength усиливает атаки Sven и даёт ему вампиризм на время действия."),
	legend("l_sven_storm_chain","hammer","Цепная молния","Взрыв Storm Hammer поражает до 4 врагов."),
	legend("l_sven_storm_stun","hammer","Сокрушительное оглушение","Storm Hammer оглушает на 1 секунду дольше."),
	legend("l_sven_cleave_range","cleave","Широкий размах","Радиус Great Cleave увеличен на 200."),
	legend("l_sven_cleave_bleed","cleave","Рассечённая плоть","Great Cleave вызывает кровотечение на 4 секунды."),
	legend("l_sven_warcry_duration","warcry","Несмолкающий клич","Длительность Warcry увеличена на 3 секунды."),
	legend("l_sven_warcry_resist","warcry","Стойкий строй","Warcry дополнительно даёт союзникам 20% сопротивления эффектам."),
	legend("l_sven_strength_crit","strength","Крушитель","God's Strength даёт 25% шанс нанести критический удар x2."),
	legend("l_sven_strength_haste","strength","Бешеный натиск","God's Strength дополнительно даёт 80 скорости атаки."),
	 epic("e_sven_hammer_damage","hammer","Удар грома","Storm Hammer наносит дополнительно 250 магического урона."),
	 epic("e_sven_hammer_cooldown","hammer","Быстрый возврат","Перезарядка Storm Hammer сокращена на 20%."),
	epic("e_sven_hammer_heal","hammer","Победный удар","Каждый враг, поражённый Storm Hammer, восстанавливает Sven 2% здоровья."),
	epic("e_sven_cleave_damage","cleave","Острый клинок","Урон Great Cleave увеличен на 25%."),
	epic("e_sven_cleave_slow","cleave","Подрубить ноги","Great Cleave замедляет задетых врагов на 30% на 2 секунды."),
	epic("e_sven_cleave_lifesteal","cleave","Кровавый размах","Great Cleave лечит Sven на 10% нанесённого урона."),
	epic("e_sven_warcry_armor","warcry","Железная воля","Warcry даёт ещё 12 брони."),
	epic("e_sven_warcry_speed","warcry","Бегущий строй","Warcry даёт ещё 15% скорости передвижения."),
	epic("e_sven_warcry_cooldown","warcry","Сигнал к атаке","Перезарядка Warcry сокращена на 25%."),
	epic("e_sven_strength_damage","strength","Сила великана","Бонус урона God's Strength увеличен на 30%."),
	epic("e_sven_strength_duration","strength","Долгая ярость","Длительность God's Strength увеличена на 4 секунды."),
	epic("e_sven_strength_heal","strength","Несгибаемый","Применение God's Strength восстанавливает 20% максимального здоровья."),
	{ id="r_sven_hammer_damage",tier=2,max=20,name="Тяжёлый молот",desc="+75 урона Storm Hammer",sven={hammer_damage=75} },
	{ id="r_sven_hammer_range",tier=2,max=8,name="Дальний удар",desc="+100 к дальности Storm Hammer",sven={hammer_range=100} },
	{ id="r_sven_cleave_damage",tier=2,max=20,name="Заточенный клинок",desc="+8% урона Great Cleave",sven={cleave_damage=8} },
	{ id="r_sven_cleave_radius",tier=2,max=10,name="Широкий замах",desc="+40 к радиусу Great Cleave",sven={cleave_radius=40} },
	{ id="r_sven_warcry_duration",tier=2,max=10,name="Долгий клич",desc="+0.5 с к Warcry",sven={warcry_duration=0.5} },
	{ id="r_sven_warcry_armor",tier=2,max=10,name="Крепкий строй",desc="+3 брони от Warcry",sven={warcry_armor=3} },
	{ id="r_sven_strength_damage",tier=2,max=20,name="Растущая сила",desc="+15% урона God's Strength",sven={strength_damage=15} },
	{ id="r_sven_strength_cooldown",tier=2,max=10,name="Короткая передышка",desc="−3 с перезарядки God's Strength",sven={strength_cooldown=3} },
	{ id="r_sven_stats",tier=2,max=20,name="Рыцарь силы",desc="+12 к урону и +4 брони",stats={damage=12,armor=4} },
}

RPG.HEROES["npc_dota_hero_sven"] = {
	modifier = "modifier_rpg_sven",
	builds = BUILDS,
	perks = PERKS,
}

function Sven:Has(hero, id)
	if not hero or hero:IsNull() then return false end
	if IsServer() then return hero.rpg and (hero.rpg.perk_count[id] or 0) > 0 or false end
	local t=CustomNetTables:GetTableValue("rpg_perks",tostring(hero:entindex()))
	return t and (t[id] or 0)>0 or false
end
function Sven:Bonus(hero, id)
	if not hero or hero:IsNull() then return 0 end
	if IsServer() then return hero.rpg and hero.rpg.sven_bonus and hero.rpg.sven_bonus[id] or 0 end
	local t=CustomNetTables:GetTableValue("rpg_perks",tostring(hero:entindex()))
	return t and t["bonus_sven_"..id] or 0
end
