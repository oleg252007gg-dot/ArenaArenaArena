-- Артефакты: выпадают только с боссов, у каждого уникальный эффект (см. modifiers/modifier_rpg_art.lua)
for _, name in ipairs({
	"modifier_rpg_art_golem_heart", "modifier_rpg_art_ogre_club", "modifier_rpg_art_troll_totem",
	"modifier_rpg_art_ghost_veil", "modifier_rpg_art_storm_shard", "modifier_rpg_art_war_horn", "modifier_rpg_art_aegis",
	"modifier_rpg_totem_stacks", "modifier_rpg_warhorn_buff", "modifier_rpg_art_boss_unique",
	"modifier_rpg_art_bone_guard", "modifier_rpg_art_infernal_amp", "modifier_rpg_art_moon_haste",
}) do
	LinkLuaModifier(name, "modifiers/modifier_rpg_art", LUA_MODIFIER_MOTION_NONE)
end

item_rpg_art_golem_heart = class({})
item_rpg_art_ogre_club   = class({})
item_rpg_art_troll_totem = class({})
item_rpg_art_ghost_veil  = class({})
item_rpg_art_storm_shard = class({})
item_rpg_art_war_horn    = class({})
item_rpg_art_aegis       = class({})
item_rpg_art_dragonheart = class({})
item_rpg_art_frostcrown = class({})
item_rpg_art_abyssallens = class({})
item_rpg_art_infernalcore = class({})
item_rpg_art_webspinner = class({})
item_rpg_art_tempestcoil = class({})
item_rpg_art_boneidol = class({})
item_rpg_art_venomheart = class({})
item_rpg_art_moonshard = class({})
item_rpg_art_plaguevial = class({})
item_rpg_art_ironmaul = class({})
item_rpg_art_starseed = class({})
item_rpg_art_sandglass = class({})
item_rpg_art_voidcrown = class({})


function item_rpg_art_golem_heart:GetIntrinsicModifierName() return "modifier_rpg_art_golem_heart" end
function item_rpg_art_ogre_club:GetIntrinsicModifierName()   return "modifier_rpg_art_ogre_club" end
function item_rpg_art_troll_totem:GetIntrinsicModifierName() return "modifier_rpg_art_troll_totem" end
function item_rpg_art_ghost_veil:GetIntrinsicModifierName()  return "modifier_rpg_art_ghost_veil" end
function item_rpg_art_storm_shard:GetIntrinsicModifierName() return "modifier_rpg_art_storm_shard" end
function item_rpg_art_war_horn:GetIntrinsicModifierName()    return "modifier_rpg_art_war_horn" end
function item_rpg_art_aegis:GetIntrinsicModifierName()       return "modifier_rpg_art_aegis" end
function item_rpg_art_dragonheart:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_frostcrown:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_abyssallens:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_infernalcore:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_webspinner:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_tempestcoil:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_boneidol:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_venomheart:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_moonshard:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_plaguevial:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_ironmaul:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_starseed:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_sandglass:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end
function item_rpg_art_voidcrown:GetIntrinsicModifierName() return "modifier_rpg_art_boss_unique" end


-- Осколок бури: ледяной взрыв вокруг героя
function item_rpg_art_storm_shard:OnSpellStart()
	local caster = self:GetCaster()
	local wave = (Waves and Waves.wave) or 1
	local damage = 200 + wave * 20 + caster:GetIntellect(false) * 2

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_crystal_maiden/maiden_crystal_nova.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:SetParticleControl(fx, 1, Vector(600, 2, 600))
	ParticleManager:ReleaseParticleIndex(fx)
	EmitSoundOn("Hero_Crystal.CrystalNova", caster)

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, 600, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, e in ipairs(enemies) do
		ApplyDamage({ victim = e, attacker = caster, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL, ability = self })
	end
end

-- Рог вождя: боевой клич для союзников рядом
function item_rpg_art_war_horn:OnSpellStart()
	local caster = self:GetCaster()
	local allies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, 900, DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, a in ipairs(allies) do
		a:AddNewModifier(caster, self, "modifier_rpg_warhorn_buff", { duration = 10 })
	end
end
