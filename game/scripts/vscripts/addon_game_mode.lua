-- Load modifier classes explicitly before gameplay modules can apply them.
-- LinkLuaModifier registers the engine path; require also makes the Lua class
-- available immediately and reports script load failures in the console.
for _, path in ipairs({
    "modifiers/modifier_rpg_stats",
    "modifiers/modifier_rpg_item",
    "modifiers/modifier_rpg_axe",
    "modifiers/modifier_rpg_axe_abilities",
    "modifiers/modifier_rpg_misc",
    "modifiers/modifier_rpg_lich",
    "modifiers/modifier_rpg_hoodwink",
    "modifiers/modifier_rpg_arc_warden",
    "modifiers/modifier_rpg_sven",
}) do
    local ok, err = pcall(require, path)
    if not ok then print("[RPG] Failed to load " .. path .. ": " .. tostring(err)) end
end

-- Register modifier script paths before gameplay modules.
LinkLuaModifier("modifier_rpg_stats", "modifiers/modifier_rpg_stats", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_rpg_item", "modifiers/modifier_rpg_item", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_rpg_axe", "modifiers/modifier_rpg_axe", LUA_MODIFIER_MOTION_NONE)
for _, name in ipairs({ "modifier_rpg_axe_helix", "modifier_rpg_cull_charges", "modifier_rpg_call_taunt", "modifier_rpg_call_buff", "modifier_rpg_battle_hunger", "modifier_rpg_hunger_charges" }) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_axe_abilities", LUA_MODIFIER_MOTION_NONE)
end
for _, name in ipairs({ "modifier_rpg_axe_compensation", "modifier_rpg_axe_bleed", "modifier_rpg_rotten_blade", "modifier_rpg_helix_shred", "modifier_rpg_axe_attack_ramp", "modifier_rpg_cull_vitality" }) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_axe_abilities", LUA_MODIFIER_MOTION_NONE)
end
for _, name in ipairs({
	"modifier_rpg_slow", "modifier_rpg_dmg_reduction", "modifier_rpg_as_slow", "modifier_rpg_ms_buff",
	"modifier_rpg_armor_shred", "modifier_rpg_barrier", "modifier_rpg_shallow_grave", "modifier_rpg_fire_zone", "modifier_rpg_wave_rules", "modifier_rpg_boss_control", "modifier_rpg_boss_heal_block",
}) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_misc", LUA_MODIFIER_MOTION_NONE)
end
LinkLuaModifier("modifier_rpg_pull", "modifiers/modifier_rpg_misc", LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier("modifier_rpg_lich", "modifiers/modifier_rpg_lich", LUA_MODIFIER_MOTION_NONE)
for _, name in ipairs({
	"modifier_rpg_lich_series", "modifier_rpg_lich_icing", "modifier_rpg_lich_shield", "modifier_rpg_lich_glacier",
	"modifier_rpg_lich_pull_step", "modifier_rpg_lich_gaze_target", "modifier_rpg_lich_gaze_cone", "modifier_rpg_lich_freeze",
	"modifier_rpg_lich_root", "modifier_rpg_lich_break", "modifier_rpg_lich_mark", "modifier_rpg_lich_overheat",
	"modifier_rpg_lich_blood", "modifier_rpg_lich_comp", "modifier_rpg_lich_orbs", "modifier_rpg_lich_absorb",
	"modifier_rpg_lich_crystal", "modifier_rpg_lich_relentless", "modifier_rpg_lich_dome", "modifier_rpg_lich_haste",
	"modifier_rpg_lich_mr_shred", "modifier_rpg_lich_puddle",
}) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_lich", LUA_MODIFIER_MOTION_NONE)
end
for _, name in ipairs({
	"modifier_rpg_hoodwink", "modifier_rpg_hoodwink_scurry", "modifier_rpg_hoodwink_bushwhack",
	"modifier_rpg_hoodwink_weakspot", "modifier_rpg_hoodwink_blood_trail", "modifier_rpg_hoodwink_haste",
	"modifier_rpg_hoodwink_hunt", "modifier_rpg_hoodwink_euphoria", "modifier_rpg_hoodwink_bleed", "modifier_rpg_hoodwink_acid_zone",
}) do LinkLuaModifier(name, "modifiers/modifier_rpg_hoodwink", LUA_MODIFIER_MOTION_NONE) end
for _, name in ipairs({"modifier_rpg_arc_flux","modifier_rpg_arc_field","modifier_rpg_arc_field_aura","modifier_rpg_arc_field_enemy","modifier_rpg_arc_field_echo","modifier_rpg_arc_wraith","modifier_rpg_arc_wraith_mark","modifier_rpg_arc_wraith_burn","modifier_rpg_arc_tempest","modifier_rpg_arc_tempest_ghost","modifier_rpg_arc_tempest_runes","modifier_rpg_arc_friendly_buff","modifier_rpg_arc_master"}) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_arc_warden", LUA_MODIFIER_MOTION_NONE)
end
print("[RPG] addon_game_mode loaded; modifier registration v2 complete")

require("game/config")
require("game/stats")
require("game/loot")
require("game/perks")
require("game/heroes/axe")
require("game/heroes/lich")
require("game/heroes/hoodwink")
require("game/heroes/arc_warden")
require("game/heroes/sven")
require("game/enemies")
require("game/progression")
require("game/waves")

LinkLuaModifier("modifier_rpg_stats", "modifiers/modifier_rpg_stats", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_rpg_item", "modifiers/modifier_rpg_item", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_rpg_axe", "modifiers/modifier_rpg_axe", LUA_MODIFIER_MOTION_NONE)

-- Модификаторы способностей Axe
for _, name in ipairs({ "modifier_rpg_axe_helix", "modifier_rpg_cull_charges", "modifier_rpg_call_taunt", "modifier_rpg_call_buff", "modifier_rpg_battle_hunger", "modifier_rpg_hunger_charges" }) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_axe_abilities", LUA_MODIFIER_MOTION_NONE)
end

-- Общие модификаторы (замедления, барьер, зона огня, Shallow Grave и т.д.)
for _, name in ipairs({
	"modifier_rpg_slow", "modifier_rpg_dmg_reduction", "modifier_rpg_as_slow", "modifier_rpg_ms_buff",
	"modifier_rpg_armor_shred", "modifier_rpg_barrier", "modifier_rpg_shallow_grave", "modifier_rpg_fire_zone", "modifier_rpg_wave_rules", "modifier_rpg_boss_control", "modifier_rpg_boss_heal_block",
}) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_misc", LUA_MODIFIER_MOTION_NONE)
end
LinkLuaModifier("modifier_rpg_pull", "modifiers/modifier_rpg_misc", LUA_MODIFIER_MOTION_HORIZONTAL)
for _, name in ipairs({"modifier_rpg_sven","modifier_rpg_sven_cleave","modifier_rpg_sven_warcry","modifier_rpg_sven_gods_strength","modifier_rpg_sven_bleed"}) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_sven", LUA_MODIFIER_MOTION_NONE)
end

-- Модификаторы Lich
LinkLuaModifier("modifier_rpg_lich", "modifiers/modifier_rpg_lich", LUA_MODIFIER_MOTION_NONE)
for _, name in ipairs({
	"modifier_rpg_lich_series", "modifier_rpg_lich_icing", "modifier_rpg_lich_shield", "modifier_rpg_lich_glacier",
	"modifier_rpg_lich_pull_step", "modifier_rpg_lich_gaze_target", "modifier_rpg_lich_gaze_cone", "modifier_rpg_lich_freeze",
	"modifier_rpg_lich_root", "modifier_rpg_lich_break", "modifier_rpg_lich_mark", "modifier_rpg_lich_overheat",
	"modifier_rpg_lich_blood", "modifier_rpg_lich_comp", "modifier_rpg_lich_orbs", "modifier_rpg_lich_absorb",
	"modifier_rpg_lich_crystal", "modifier_rpg_lich_relentless", "modifier_rpg_lich_dome", "modifier_rpg_lich_haste",
	"modifier_rpg_lich_mr_shred", "modifier_rpg_lich_puddle",
}) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_lich", LUA_MODIFIER_MOTION_NONE)
end

if RPGArena == nil then RPGArena = class({}) end

function Precache(context)
	PrecacheResource("particle", "particles/items_fx/blink_dagger_start.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/blink_dagger_end.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/bloodstone_heal.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/bloodstone_heal_start.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/aoe_item_caster_additive_crimson_guard_base.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/aoe_item_caster_additive_crimson_guard_ring_burst.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/aoe_item_generic_caster_additive.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/generic_item_spell_caster_core_solar_crest.vpcf", context)
	PrecacheResource("particle", "particles/items2_fx/mask_of_madness.vpcf", context)
	PrecacheResource("particle", "particles/items2_fx/skadi_projectile_explosion.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_frost_nova.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_jakiro/jakiro_liquid_fire_explosion.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_jakiro/jakiro_macropyre.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_axe/axe_attack_blur_counterhelix.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_zuus/zuus_lightning_bolt_start.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_crystalmaiden.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ursa.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_axe.vsndevts", context)
	PrecacheResource("particle", "particles/units/heroes/hero_axe/axe_beserkers_call_start.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_axe/axe_beserkers_call_owner.vpcf", context)
	PrecacheResource("particle", "particles/status_fx/status_effect_beserkers_call.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_axe/axe_battle_hunger.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_sinister_gaze.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_axe/axe_culling_blade_kill.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_crystal_maiden/maiden_crystal_nova.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/bottle.vpcf", context)
	PrecacheUnitByNameSync("npc_dota_hero_axe", context)
	PrecacheUnitByNameSync("npc_dota_hero_lich", context)
	PrecacheUnitByNameSync("npc_dota_hero_hoodwink", context)
	PrecacheUnitByNameSync("npc_dota_hero_arc_warden", context)
	PrecacheUnitByNameSync("npc_dota_hero_sven", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sven.vsndevts", context)
	for _, particle in ipairs({
		"particles/units/heroes/hero_sven/sven_spell_storm_bolt.vpcf",
		"particles/units/heroes/hero_sven/sven_spell_great_cleave.vpcf",
		"particles/units/heroes/hero_sven/sven_spell_warcry.vpcf",
		"particles/units/heroes/hero_sven/sven_spell_gods_strength.vpcf",
		"particles/units/heroes/hero_bloodseeker/bloodseeker_rupture.vpcf",
	}) do PrecacheResource("particle", particle, context) end
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_arc_warden.vsndevts", context)
	for _, model in ipairs({
		"models/items/arc_warden/ti9_cache_aw_ancient_mechanism_arms/ti9_cache_aw_ancient_mechanism_arms.vmdl",
		"models/items/arc_warden/ti9_cache_aw_ancient_mechanism_back/ti9_cache_aw_ancient_mechanism_back.vmdl",
		"models/items/arc_warden/ti9_cache_aw_ancient_mechanism_head/ti9_cache_aw_ancient_mechanism_head.vmdl",
		"models/items/arc_warden/ti9_cache_aw_ancient_mechanism_shoulder/ti9_cache_aw_ancient_mechanism_shoulder.vmdl",
	}) do PrecacheResource("model", model, context) end
	for _, particle in ipairs({
		"particles/units/heroes/hero_arc_warden/arc_warden_flux_tgt.vpcf",
		"particles/units/heroes/hero_arc_warden/arc_warden_magnetic.vpcf",
		"particles/units/heroes/hero_arc_warden/arc_warden_magnetic_buff.vpcf",
		"particles/units/heroes/hero_arc_warden/arc_warden_wraith.vpcf",
		"particles/units/heroes/hero_arc_warden/arc_warden_wraith_cast.vpcf",
		"particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj.vpcf",
		"particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj_hit.vpcf",
		"particles/units/heroes/hero_zuus/zuus_lightning_bolt_start.vpcf",
	}) do PrecacheResource("particle", particle, context) end
	PrecacheResource("model", "models/heroes/arc_warden/mesh/spark_wraith.vmdl", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_hoodwink.vsndevts", context)

	for _, particle in ipairs({
		"particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot.vpcf",
		"particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_explosion.vpcf",
		"particles/units/heroes/hero_snapfire/snapfire_cookie_projectile.vpcf",
		"particles/units/heroes/hero_batrider/batrider_firefly.vpcf",
		"particles/units/heroes/hero_hoodwink/hoodwink_bushwhack_projectile.vpcf",
		"particles/units/heroes/hero_hoodwink/hoodwink_bushwhack_tree.vpcf",
		"particles/units/heroes/hero_hoodwink/hoodwink_bushwhack.vpcf",
		"particles/units/heroes/hero_hoodwink/hoodwink_sharpshooter_projectile.vpcf",
		"particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_calldown_marker.vpcf",
		"particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf",
	}) do PrecacheResource("particle", particle, context) end
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lich.vsndevts", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_chain_frost.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_frost_nova.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_frost_armor.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_frost_nova.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/generic_slowed_cold.vpcf", context)
	PrecacheResource("particle", "particles/status_fx/status_effect_frost.vpcf", context)
	for _, skill in pairs(Enemies.SPECIAL_SKILLS or {}) do
		if skill.particle then PrecacheResource("particle", skill.particle, context) end
		if skill.caster_particle then PrecacheResource("particle", skill.caster_particle, context) end
		if skill.impact_particle then PrecacheResource("particle", skill.impact_particle, context) end
	end
	for _, name in ipairs({
		"npc_rpg_arc_warden_tempest_clone",
		"npc_rpg_creep_melee", "npc_rpg_creep_ranged", "npc_rpg_creep_brute", "npc_rpg_wolf", "npc_rpg_satyr",
		"npc_rpg_kobold_healer", "npc_rpg_ghost", "npc_rpg_centaur", "npc_rpg_troll_summoner", "npc_rpg_golem",
		"npc_rpg_boss_golem", "npc_rpg_boss_ogre", "npc_rpg_boss_troll", "npc_rpg_boss_ghost", "npc_rpg_boss_centaur", "npc_rpg_boss_roshan",
		"npc_rpg_boss_dragon",
		"npc_rpg_boss_frost",
		"npc_rpg_boss_abyss",
		"npc_rpg_boss_ember",
		"npc_rpg_boss_web",
		"npc_rpg_boss_tempest",
		"npc_rpg_boss_bone",
		"npc_rpg_boss_emerald",
		"npc_rpg_boss_moon",
		"npc_rpg_boss_plague",
		"npc_rpg_boss_iron",
		"npc_rpg_boss_star",
		"npc_rpg_boss_sand",
		"npc_rpg_boss_void",
		"npc_rpg_miniboss_01",
		"npc_rpg_miniboss_02",
		"npc_rpg_miniboss_03",
		"npc_rpg_miniboss_04",
		"npc_rpg_miniboss_05",
		"npc_rpg_miniboss_06",
		"npc_rpg_miniboss_07",
		"npc_rpg_miniboss_08",
		"npc_rpg_miniboss_09",
		"npc_rpg_miniboss_10",
	}) do
		PrecacheUnitByNameSync(name, context)
	end
end

function Activate()
	GameRules.RPG = RPGArena()
	GameRules.RPG:InitGameMode()
end

function RPGArena:InitGameMode()
	local gm = GameRules:GetGameModeEntity()

	-- Команды: игроки против волн
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, RPG.CFG.MAX_PLAYERS)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 0)

	-- Тайминги и правила
	-- Выбор героя: Axe или Lich (список - scripts/npc/herolist.txt)
	GameRules:SetHeroSelectionTime(RPG.CFG.HERO_SELECT_TIME)
	GameRules:SetStrategyTime(0)
	GameRules:SetShowcaseTime(0)
	GameRules:SetPreGameTime(5)
	GameRules:SetPostGameTime(30)
	GameRules:SetStartingGold(500)
	GameRules:SetGoldPerTick(0)
	GameRules:SetFirstBloodActive(false)
	GameRules:SetSameHeroSelectionEnabled(true)
	GameRules:SetUseUniversalShopMode(true)

	gm:SetBuybackEnabled(false)
	gm:SetLoseGoldOnDeath(false)
	gm:SetFixedRespawnTime(20)
	gm:SetDaynightCycleDisabled(true)
	gm:SetFogOfWarDisabled(true)
	gm:SetRecommendedItemsDisabled(true)

	-- Свои уровни героя
	local xp = {}
	for lvl = 1, RPG.CFG.MAX_LEVEL do
		xp[lvl] = math.floor(30 * (lvl - 1) ^ 1.25)
	end
	gm:SetUseCustomHeroLevels(true)
	gm:SetCustomHeroMaxLevel(RPG.CFG.MAX_LEVEL)
	gm:SetCustomXPRequiredToReachNextLevel(xp)
	-- RPG progression is wave based; unit kills never award hero XP.
	gm:SetModifyExperienceFilter(function(keys)
		keys.experience = 0
		return true
	end, self)

	Stats:Init()
	Progression:Init()
	Waves:Init()

	ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(RPGArena, "OnStateChange"), self)
	ListenToGameEvent("npc_spawned", Dynamic_Wrap(RPGArena, "OnNpcSpawned"), self)
	ListenToGameEvent("entity_killed", Dynamic_Wrap(RPGArena, "OnEntityKilled"), self)
end

function RPGArena:OnStateChange()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		self.startup_attempts = 0
		GameRules:GetGameModeEntity():SetContextThink("rpg_initialize_starting_heroes", function()
			local selected_count = 0
			for player_id = 0, (DOTA_MAX_TEAM_PLAYERS or 24) - 1 do
				local hero = PlayerResource:GetSelectedHeroEntity(player_id)
				if hero and not hero:IsNull() and hero:IsRealHero() and not hero:IsIllusion() then
					selected_count = selected_count + 1
					if not hero.rpg then Progression:InitHero(hero) end
					Progression:EnsureStartingLevel(hero)
				end
			end
			if selected_count > 0 or self.startup_attempts >= 100 then
				if selected_count == 0 then print("[RPG] No selected hero found before wave startup") end
				Waves:Start()
				return nil
			end
			self.startup_attempts = self.startup_attempts + 1
			return 0.1
		end, 0.1)
	end
end

function RPGArena:OnNpcSpawned(keys)
	local unit = EntIndexToHScript(keys.entindex)
	-- Temporary Tempest Doubles are hero entities so the engine may respawn
	-- them after death. Catch the respawn event as a second line of defense.
	if unit and not unit:IsNull() and unit.rpg_is_tempest_double and unit.rpg_tempest_permanent == false and unit.rpg_tempest_dead then
		unit:SetTimeUntilRespawn(999999)
		RPG.After(0.03, function()
			if IsValidEntity(unit) and not unit:IsNull() then UTIL_Remove(unit) end
		end)
		return
	end
	if unit and not unit:IsNull() and unit:IsRealHero() and not unit.rpg
		and not unit:IsIllusion() then
		local entindex = unit:entindex()
		local attempts = 0
		GameRules:GetGameModeEntity():SetContextThink("rpg_init_spawned_hero_" .. entindex, function()
			if not IsValidEntity(unit) or unit:IsNull() or unit.rpg then return nil end
			local player_id = unit:GetPlayerOwnerID()
			if player_id >= 0 and PlayerResource:GetSelectedHeroEntity(player_id) == unit then
				Progression:InitHero(unit)
				return nil
			end
			attempts = attempts + 1
			if attempts >= 25 then return nil end
			return 0.1
		end, 0.1)
	end
end

function RPGArena:OnEntityKilled(keys)
	local unit = EntIndexToHScript(keys.entindex_killed)
	if not unit or unit:IsNull() then return end
	if unit.rpg_wave then
		Waves:OnCreepKilled(unit)
		Perks:OnKill(keys, unit)
	elseif unit.rpg_is_tempest_double then
		local owner = unit.rpg_arc_owner
		if owner and not owner:IsNull() and owner.rpg_tempest_clone == unit then owner.rpg_tempest_clone = nil end
		if unit.rpg_tempest_permanent == false then
			-- Hero units normally respawn automatically; a regular Tempest Double
			-- must disappear permanently when killed or when its duration expires.
			unit.rpg_tempest_dead = true
			unit:SetTimeUntilRespawn(999999)
			unit:SetRespawnPosition(unit:GetAbsOrigin())
			RPG.After(0.01, function()
				if IsValidEntity(unit) and not unit:IsNull() then UTIL_Remove(unit) end
			end)
		end
		for _, wearable in ipairs(unit.rpg_dormant_oblivion_parts or {}) do
			if wearable and IsValidEntity(wearable) and not wearable:IsNull() then UTIL_Remove(wearable) end
		end
	elseif unit:IsRealHero() then
		local player_id = unit:GetPlayerOwnerID()
		if player_id >= 0 and PlayerResource:GetSelectedHeroEntity(player_id) == unit then
			Waves:CheckWipe()
		end
	end
end
