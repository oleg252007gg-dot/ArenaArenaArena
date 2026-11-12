-- Враги: ростер по волнам + поведения (способности), которые крутятся на каждом юните
Enemies = Enemies or {}

-- min: с какой волны появляется, weight: частота. behaviors: список из Enemies.BEHAVIORS
Enemies.ROSTER = {
	{ unit = "npc_rpg_creep_melee",    min = 1,  weight = 26 },
	{ unit = "npc_rpg_creep_ranged",   min = 1,  weight = 17 },
	{ unit = "npc_rpg_wolf",           min = 1,  weight = 10, behaviors = { "leap" } },
	{ unit = "npc_rpg_creep_brute",    min = 1,  weight = 12 },
	{ unit = "npc_rpg_satyr",          min = 1,  weight = 12, behaviors = { "curse" } },
	{ unit = "npc_rpg_kobold_healer",  min = 5,  weight = 8,  behaviors = { "heal_pulse" } },
	{ unit = "npc_rpg_ghost",          min = 7,  weight = 12, behaviors = { "drain" } },
	{ unit = "npc_rpg_centaur",        min = 8,  weight = 10, behaviors = { "stomp" }, stomp = { radius = 330, mult = 1.5, stun = 1.0, cd = 8 } },
	{ unit = "npc_rpg_troll_summoner", min = 9,  weight = 7,  behaviors = { "summon" }, summon = "npc_rpg_creep_melee", summon_count = 2, summon_cd = 14 },
	{ unit = "npc_rpg_golem",          min = 11, weight = 6,  behaviors = { "shield" } },
}

-- Двадцать уникальных боссов выходят по одному на волнах 10, 20, ... 200.
Enemies.BOSSES = {
	{ name = "Каменный патриарх", unit = "npc_rpg_boss_golem", loot = { "item_rpg_art_golem_heart" }, behaviors = { "boss_quake" } },
	{ name = "Осадный вожак", unit = "npc_rpg_boss_ogre", loot = { "item_rpg_art_ogre_club" }, behaviors = { "boss_cleave" } },
	{ name = "Король красных топоров", unit = "npc_rpg_boss_troll", loot = { "item_rpg_art_troll_totem" }, behaviors = { "boss_bloodstorm" } },
	{ name = "Призрачный регент", unit = "npc_rpg_boss_ghost", loot = { "item_rpg_art_ghost_veil" }, behaviors = { "boss_soul_drain" } },
	{ name = "Кентавр-завоеватель", unit = "npc_rpg_boss_centaur", loot = { "item_rpg_art_war_horn" }, behaviors = { "boss_stampede" } },
	{ name = "Рошан-пожиратель", unit = "npc_rpg_boss_roshan", loot = { "item_rpg_art_aegis" }, behaviors = { "boss_earthbreak" } },
	{ name = "Пепельный дракон", unit = "npc_rpg_boss_dragon", loot = { "item_rpg_art_dragonheart" }, behaviors = { "boss_firebreath" } },
	{ name = "Ледяная матриарх", unit = "npc_rpg_boss_frost", loot = { "item_rpg_art_frostcrown" }, behaviors = { "boss_whiteout" } },
	{ name = "Страж Бездны", unit = "npc_rpg_boss_abyss", loot = { "item_rpg_art_abyssallens" }, behaviors = { "boss_gravity_well" } },
	{ name = "Угольный тиран", unit = "npc_rpg_boss_ember", loot = { "item_rpg_art_infernalcore" }, behaviors = { "boss_meteor" } },
	{ name = "Паучья царица", unit = "npc_rpg_boss_web", loot = { "item_rpg_art_webspinner" }, behaviors = { "boss_web_prison" } },
	{ name = "Громовой исполин", unit = "npc_rpg_boss_tempest", loot = { "item_rpg_art_tempestcoil" }, behaviors = { "boss_chain_lightning" } },
	{ name = "Костяной владыка", unit = "npc_rpg_boss_bone", loot = { "item_rpg_art_boneidol" }, behaviors = { "boss_bone_cage" } },
	{ name = "Изумрудный пожиратель", unit = "npc_rpg_boss_emerald", loot = { "item_rpg_art_venomheart" }, behaviors = { "boss_venom_bloom" } },
	{ name = "Лунный палач", unit = "npc_rpg_boss_moon", loot = { "item_rpg_art_moonshard" }, behaviors = { "boss_moonfall" } },
	{ name = "Вестник чумы", unit = "npc_rpg_boss_plague", loot = { "item_rpg_art_plaguevial" }, behaviors = { "boss_plague_wave" } },
	{ name = "Железный колосс", unit = "npc_rpg_boss_iron", loot = { "item_rpg_art_ironmaul" }, behaviors = { "boss_iron_fortress" } },
	{ name = "Пожиратель звёзд", unit = "npc_rpg_boss_star", loot = { "item_rpg_art_starseed" }, behaviors = { "boss_starfall" } },
	{ name = "Император песков", unit = "npc_rpg_boss_sand", loot = { "item_rpg_art_sandglass" }, behaviors = { "boss_sandstorm" } },
	{ name = "Король Пустоты", unit = "npc_rpg_boss_void", loot = { "item_rpg_art_voidcrown" }, behaviors = { "boss_voidcollapse" } },
}

-- Десять мини-боссов повторяются парами на промежуточных волнах 5, 15, ... 195.
Enemies.MINIBOSSES = {
	{ name = "Багровый палач", unit = "npc_rpg_miniboss_01", behaviors = { "mini_rift" } },
	{ name = "Охотница Арканы", unit = "npc_rpg_miniboss_02", behaviors = { "mini_assassin" } },
	{ name = "Проклятый громила", unit = "npc_rpg_miniboss_03", behaviors = { "mini_slam" } },
	{ name = "Костяной охотник", unit = "npc_rpg_miniboss_04", behaviors = { "mini_mark" } },
	{ name = "Ядовитый жрец", unit = "npc_rpg_miniboss_05", behaviors = { "mini_poison" } },
	{ name = "Пепельный всадник", unit = "npc_rpg_miniboss_06", behaviors = { "mini_charge" } },
	{ name = "Штормовой голем", unit = "npc_rpg_miniboss_07", behaviors = { "mini_bolt" } },
	{ name = "Пустынный страж", unit = "npc_rpg_miniboss_08", behaviors = { "mini_sand" } },
	{ name = "Чумная матрона", unit = "npc_rpg_miniboss_09", behaviors = { "mini_bloom" } },
	{ name = "Осколочный зверь", unit = "npc_rpg_miniboss_10", behaviors = { "mini_shatter" } },
}

function Enemies:Pick(wave)
	local total = 0
	for _, e in ipairs(self.ROSTER) do
		if wave >= e.min then total = total + e.weight end
	end
	local r = RandomFloat(0, total)
	for _, e in ipairs(self.ROSTER) do
		if wave >= e.min then
			r = r - e.weight
			if r <= 0 then return e end
		end
	end
	return self.ROSTER[1]
end

function Enemies:NearestHero(unit, radius)
	local list = FindUnitsInRadius(unit:GetTeamNumber(), unit:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NO_INVIS, FIND_CLOSEST, false)
	return list[1]
end

-- Запуск поведений на юните (проверка раз в 0.5 с)
function Enemies:Attach(unit, def)
	if not def.behaviors then return end
	unit.rpg_cd = {}
	unit:SetContextThink("rpg_ai", function()
		if not IsValidEntity(unit) or not unit:IsAlive() then return nil end
		local now = GameRules:GetGameTime()
		for _, b in ipairs(def.behaviors) do
			local f = Enemies.BEHAVIORS[b]
			if f and (unit.rpg_cd[b] or 0) <= now then
				local cd = f(unit, def)           -- функция возвращает перезарядку, если сработала
				if cd then unit.rpg_cd[b] = now + cd end
			end
		end
		return 0.5
	end, RandomFloat(0.5, 2))
end

-- Функция возвращает перезарядку (сек) если способность использована, иначе nil
Enemies.BEHAVIORS = {
	-- Рывок к ближайшему герою с ударом
	leap = function(u)
		local h = Enemies:NearestHero(u, 800)
		if not h then return nil end
		local dir = h:GetAbsOrigin() - u:GetAbsOrigin()
		if dir:Length2D() < 250 then return nil end
		FindClearSpaceForUnit(u, h:GetAbsOrigin() - dir:Normalized() * 120, true)
		ApplyDamage({ victim = h, attacker = u, damage = u:GetAverageTrueAttackDamage(h) * 1.5, damage_type = DAMAGE_TYPE_PHYSICAL })
		return 9
	end,

	-- Проклятие: замедление и урон
	curse = function(u)
		local h = Enemies:NearestHero(u, 700)
		if not h then return nil end
		h:AddNewModifier(u, nil, "modifier_rpg_slow", { duration = 3, slow = 40 })
		ApplyDamage({ victim = h, attacker = u, damage = 30 + (u.rpg_wave or 1) * 6, damage_type = DAMAGE_TYPE_MAGICAL })
		return 8
	end,

	-- Лечение союзников вокруг
	heal_pulse = function(u)
		local allies = FindUnitsInRadius(u:GetTeamNumber(), u:GetAbsOrigin(), nil, 500, DOTA_UNIT_TARGET_TEAM_FRIENDLY,
			DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
		local healed = false
		for _, a in ipairs(allies) do
			if a:GetHealth() < a:GetMaxHealth() * 0.9 then
				a:Heal(a:GetMaxHealth() * 0.12, u)
				healed = true
			end
		end
		return healed and 6 or nil
	end,

	-- Высасывание здоровья у героя
	drain = function(u)
		local h = Enemies:NearestHero(u, 650)
		if not h then return nil end
		local dmg = h:GetMaxHealth() * 0.06
		ApplyDamage({ victim = h, attacker = u, damage = dmg, damage_type = DAMAGE_TYPE_MAGICAL })
		u:Heal(dmg * 2, u)
		return 7
	end,

	-- Топот: урон и оглушение вокруг
	stomp = function(u, def)
		local s = def.stomp or {}
		local radius = s.radius or 330
		if not Enemies:NearestHero(u, radius * 0.8) then return nil end
		Waves:Slam(u, radius, s.mult or 1.5, s.stun or 1.0)
		return s.cd or 8
	end,

	-- Призыв прислужников
	summon = function(u, def)
		if Waves.alive_count >= RPG.CFG.MAX_ALIVE or not Enemies:NearestHero(u, 1400) then return nil end
		for _ = 1, def.summon_count or 2 do
			Waves:SpawnMinion(def.summon or "npc_rpg_creep_melee", u:GetAbsOrigin() + RandomVector(150))
		end
		return def.summon_cd or 14
	end,

	-- Каменная кожа: -70% урона на 3 с, когда здоровье упало
	shield = function(u)
		if u:GetHealth() > u:GetMaxHealth() * 0.7 or not Enemies:NearestHero(u, 400) then return nil end
		u:AddNewModifier(u, nil, "modifier_rpg_dmg_reduction", { duration = 3, reduction = 70 })
		return 12
	end,
}

-- У каждого босса и мини-босса собственная атака, частица и боевой эффект.
Enemies.SPECIAL_SKILLS = {
	boss_quake = { particle = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", radius = 500, range = 650, cd = 10, mult = 2.2, effect = "stun", duration = 0.8 },
	boss_cleave = { particle = "particles/units/heroes/hero_axe/axe_attack_blur_counterhelix.vpcf", radius = 420, range = 500, cd = 8, mult = 2.5, effect = "armor", duration = 5 },
	boss_bloodstorm = { particle = "particles/units/heroes/hero_axe/axe_attack_blur_counterhelix.vpcf", caster_particle = "particles/items_fx/bloodstone_heal.vpcf", radius = 550, range = 700, cd = 12, mult = 1.8, effect = "drain", duration = 3 },
	boss_soul_drain = { particle = "particles/units/heroes/hero_lich/lich_frost_nova.vpcf", caster_particle = "particles/items_fx/bloodstone_heal.vpcf", radius = 650, range = 800, cd = 12, mult = 1.7, effect = "drain", duration = 3 },
	boss_stampede = { particle = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", radius = 500, range = 700, cd = 10, mult = 2.0, effect = "stun", duration = 0.6 },
	boss_earthbreak = { particle = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", radius = 480, range = 600, cd = 9, mult = 2.4, effect = "pull", duration = 0.35 },
	boss_firebreath = { particle = "particles/units/heroes/hero_jakiro/jakiro_macropyre.vpcf", shape = "line", radius = 600, range = 850, cd = 11, mult = 1.8, effect = "burn", duration = 3 },
	boss_whiteout = { particle = "particles/units/heroes/hero_lich/lich_frost_nova.vpcf", radius = 600, range = 800, cd = 10, mult = 1.7, effect = "slow", duration = 4 },
	boss_gravity_well = { particle = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", radius = 520, range = 800, cd = 14, mult = 1.4, effect = "pull", duration = 0.55 },
	boss_meteor = { particle = "particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_calldown_marker.vpcf", impact_particle = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", radius = 440, range = 900, cd = 11, mult = 2.6, effect = "stun", duration = 1.0 },
	boss_web_prison = { particle = "particles/units/heroes/hero_hoodwink/hoodwink_bushwhack.vpcf", radius = 520, range = 750, cd = 12, mult = 1.5, effect = "root", duration = 2.0 },
	boss_chain_lightning = { particle = "particles/units/heroes/hero_zuus/zuus_lightning_bolt_start.vpcf", shape = "line", radius = 220, range = 850, cd = 9, mult = 2.1, effect = "silence", duration = 1.5 },
	boss_bone_cage = { particle = "particles/units/heroes/hero_hoodwink/hoodwink_bushwhack.vpcf", radius = 460, range = 750, cd = 12, mult = 1.4, effect = "disarm", duration = 2.0 },
	boss_venom_bloom = { particle = "particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf", radius = 540, range = 750, cd = 10, mult = 1.5, effect = "poison", duration = 4 },
	boss_moonfall = { particle = "particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_calldown_marker.vpcf", impact_particle = "particles/units/heroes/hero_lich/lich_frost_nova.vpcf", radius = 560, range = 850, cd = 11, mult = 2.0, effect = "slow", duration = 3.5 },
	boss_plague_wave = { particle = "particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf", radius = 620, range = 800, cd = 13, mult = 1.8, effect = "heal_block", duration = 4 },
	boss_iron_fortress = { particle = "particles/items_fx/aoe_item_caster_additive_crimson_guard_base.vpcf", caster_particle = "particles/items_fx/aoe_item_caster_additive_crimson_guard_ring_burst.vpcf", radius = 400, range = 500, cd = 10, mult = 2.0, effect = "shield", duration = 3 },
	boss_starfall = { particle = "particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_calldown_marker.vpcf", impact_particle = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", radius = 650, range = 900, cd = 12, mult = 1.7, effect = "burn", duration = 3 },
	boss_sandstorm = { particle = "particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf", radius = 580, range = 750, cd = 10, mult = 1.9, effect = "slow", duration = 4 },
	boss_voidcollapse = { particle = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", radius = 500, range = 850, cd = 14, mult = 1.6, effect = "stun", duration = 1.2 },
	mini_rift = { particle = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", radius = 340, range = 480, cd = 9, mult = 1.4, effect = "slow", duration = 2.5 },
	mini_frost = { particle = "particles/units/heroes/hero_lich/lich_frost_nova.vpcf", radius = 360, range = 650, cd = 10, mult = 1.4, effect = "slow", duration = 3 },
	mini_assassin = { particle = "particles/econ/items/phantom_assassin/phantom_assassin_arcana/pa_arcana_attack_blink_blur.vpcf", radius = 360, range = 650, cd = 10, mult = 1.4, effect = "slow", duration = 3 },
	mini_slam = { particle = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", radius = 330, range = 450, cd = 8, mult = 1.6, effect = "stun", duration = 0.5 },
	mini_mark = { particle = "particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_calldown_marker.vpcf", impact_particle = "particles/units/heroes/hero_lich/lich_frost_nova.vpcf", radius = 300, range = 800, cd = 8, mult = 1.6, effect = "armor", duration = 4 },
	mini_poison = { particle = "particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf", radius = 380, range = 700, cd = 10, mult = 1.2, effect = "poison", duration = 3 },
	mini_charge = { particle = "particles/units/heroes/hero_axe/axe_beserkers_call_start.vpcf", radius = 320, range = 700, cd = 9, mult = 1.7, effect = "stun", duration = 0.5 },
	mini_bolt = { particle = "particles/units/heroes/hero_zuus/zuus_lightning_bolt_start.vpcf", radius = 320, range = 750, cd = 9, mult = 1.5, effect = "silence", duration = 1 },
	mini_sand = { particle = "particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf", radius = 380, range = 650, cd = 10, mult = 1.3, effect = "slow", duration = 3 },
	mini_bloom = { particle = "particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf", radius = 360, range = 700, cd = 10, mult = 1.3, effect = "heal_block", duration = 3 },
	mini_shatter = { particle = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", radius = 350, range = 500, cd = 9, mult = 1.6, effect = "stun", duration = 0.5 },
}

function Enemies:CastSpecialSkill(unit, key)
	local s = self.SPECIAL_SKILLS[key]
	if not s then return nil end
	local target = self:NearestHero(unit, s.range)
	if not target then return nil end
	local pos = target:GetAbsOrigin()
	local fx = ParticleManager:CreateParticle(s.particle, PATTACH_WORLDORIGIN, nil)
	if s.shape == "line" then
		ParticleManager:SetParticleControl(fx, 0, unit:GetAbsOrigin())
		ParticleManager:SetParticleControl(fx, 1, pos)
	else
		ParticleManager:SetParticleControl(fx, 0, pos)
	end
	ParticleManager:ReleaseParticleIndex(fx)
	if s.impact_particle then
		local impact=ParticleManager:CreateParticle(s.impact_particle,PATTACH_WORLDORIGIN,nil)
		ParticleManager:SetParticleControl(impact,0,pos)
		ParticleManager:ReleaseParticleIndex(impact)
	end
	if s.caster_particle then
		local caster_fx = ParticleManager:CreateParticle(s.caster_particle, PATTACH_ABSORIGIN_FOLLOW, unit)
		ParticleManager:ReleaseParticleIndex(caster_fx)
	end
	local damage = unit:GetAverageTrueAttackDamage(target) * s.mult + (unit.rpg_wave or 1) * 8
	local victims
	if s.shape == "line" then
		victims = FindUnitsInLine(unit:GetTeamNumber(), unit:GetAbsOrigin(), pos, nil, s.radius,
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE)
	else
		victims = FindUnitsInRadius(unit:GetTeamNumber(), pos, nil, s.radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	end
	for _, hero in ipairs(victims) do
		ApplyDamage({ victim = hero, attacker = unit, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL })
		if s.effect == "stun" or s.effect == "root" then
			hero:AddNewModifier(unit, nil, "modifier_stunned", { duration = s.duration })
		elseif s.effect == "slow" or s.effect == "poison" then
			hero:AddNewModifier(unit, nil, "modifier_rpg_slow", { duration = s.duration, slow = s.effect == "poison" and 35 or 45 })
			if s.effect == "poison" then hero:AddNewModifier(unit, nil, "modifier_rpg_axe_bleed", { duration = s.duration, pct = 1.5 }) end
		elseif s.effect == "silence" then
			hero:AddNewModifier(unit, nil, "modifier_rpg_boss_control", { duration = s.duration, silence = 1 })
		elseif s.effect == "disarm" then
			hero:AddNewModifier(unit, nil, "modifier_rpg_boss_control", { duration = s.duration, disarm = 1 })
		elseif s.effect == "pull" then
			local origin = unit:GetAbsOrigin()
			hero:AddNewModifier(unit, nil, "modifier_rpg_pull", { duration = s.duration, x = origin.x, y = origin.y, stop = 120 })
		elseif s.effect == "armor" then
			hero:AddNewModifier(unit, nil, "modifier_rpg_armor_shred", { duration = s.duration, pct = 25 })
		elseif s.effect == "heal_block" then
			hero:AddNewModifier(unit, nil, "modifier_rpg_slow", { duration = s.duration, slow = 30 })
			hero:AddNewModifier(unit, nil, "modifier_rpg_boss_heal_block", { duration = s.duration })
		elseif s.effect == "burn" then
			hero:AddNewModifier(unit, nil, "modifier_rpg_axe_bleed", { duration = s.duration, pct = 1.5 })
		end
	end
	if s.effect == "drain" then unit:Heal(damage * 0.6, unit)
	elseif s.effect == "shield" then unit:AddNewModifier(unit, nil, "modifier_rpg_dmg_reduction", { duration = s.duration, reduction = 40 }) end
	return s.cd
end

for key in pairs(Enemies.SPECIAL_SKILLS) do
	local skill_key = key
	Enemies.BEHAVIORS[skill_key] = function(unit) return Enemies:CastSpecialSkill(unit, skill_key) end
end
