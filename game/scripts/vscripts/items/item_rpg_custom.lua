-- Custom shop items supplied by the Arena RPG design.
local MODIFIERS = {
	"modifier_rpg_bloodstone_core", "modifier_rpg_bloodstone_pact",
	"modifier_rpg_butterfly_blink", "modifier_rpg_butterfly_blink_buff",
	"modifier_rpg_crimson_vladimir", "modifier_rpg_vladimir_offering_aura", "modifier_rpg_vladimir_guard_buff",
	"modifier_rpg_crystall_blade",
	"modifier_rpg_eyes_of_hydra", "modifier_rpg_cold_miasma", "modifier_rpg_polycephaly",
	"modifier_rpg_slayer_of_madness", "modifier_rpg_slayer_debuff", "modifier_rpg_madness",
	"modifier_rpg_solar_cape", "modifier_rpg_shine",
}
for _, name in ipairs(MODIFIERS) do
	LinkLuaModifier(name, "items/item_rpg_custom", LUA_MODIFIER_MOTION_NONE)
end

local function can_hit(attacker, target)
	return attacker and target and not attacker:IsNull() and not target:IsNull()
		and target:IsAlive() and target:GetTeamNumber() ~= attacker:GetTeamNumber()
		and not target:IsBuilding()
end

local function heal_from_attack(attacker, target, damage, pct)
	if pct <= 0 or not can_hit(attacker, target) then return end
	attacker:Heal(math.max(0, damage) * pct / 100, nil)
end

local function find_allies(caster, radius)
	return FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
end

local function play_item_particle(path, target)
	local particle = ParticleManager:CreateParticle(path, PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:ReleaseParticleIndex(particle)
end

-- ==================== Bloodstone Core ====================
item_rpg_bloodstone_core = class({})
function item_rpg_bloodstone_core:GetIntrinsicModifierName() return "modifier_rpg_bloodstone_core" end
function item_rpg_bloodstone_core:OnSpellStart()
	local caster = self:GetCaster()
	play_item_particle("particles/items_fx/bloodstone_heal_start.vpcf", caster)
	play_item_particle("particles/items_fx/bloodstone_heal.vpcf", caster)
	caster:AddNewModifier(caster, self, "modifier_rpg_bloodstone_pact", { duration = 10 })
end

modifier_rpg_bloodstone_core = class({})
function modifier_rpg_bloodstone_core:IsHidden() return true end
function modifier_rpg_bloodstone_core:IsPurgable() return false end
function modifier_rpg_bloodstone_core:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_rpg_bloodstone_core:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS, MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
		MODIFIER_PROPERTY_MANA_BONUS, MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
end
function modifier_rpg_bloodstone_core:GetModifierBonusStats_Strength() return 45 end
function modifier_rpg_bloodstone_core:GetModifierBonusStats_Agility() return 45 end
function modifier_rpg_bloodstone_core:GetModifierBonusStats_Intellect() return 45 end
function modifier_rpg_bloodstone_core:GetModifierExtraHealthBonus() return 1500 end
function modifier_rpg_bloodstone_core:GetModifierManaBonus() return 2000 end
function modifier_rpg_bloodstone_core:GetModifierPercentageCooldown() return 50 end
function modifier_rpg_bloodstone_core:OnTakeDamage(p)
	if not IsServer() or p.attacker ~= self:GetParent() or not p.inflictor or p.damage <= 0 then return end
	if p.damage_type ~= DAMAGE_TYPE_MAGICAL and p.damage_type ~= DAMAGE_TYPE_PURE then return end
	if p.unit and p.unit:GetTeamNumber() == p.attacker:GetTeamNumber() then return end
	local pct = 40
	local pact = p.attacker:FindModifierByName("modifier_rpg_bloodstone_pact")
	if pact then pct = pct + 110 end
	p.attacker:Heal(p.damage * pct / 100, self:GetAbility())
end

modifier_rpg_bloodstone_pact = class({})
function modifier_rpg_bloodstone_pact:IsHidden() return false end
function modifier_rpg_bloodstone_pact:IsPurgable() return true end
function modifier_rpg_bloodstone_pact:GetTexture() return "item_rpg_bloodstone_core" end

-- ==================== Butterfly Blink ====================
item_rpg_butterfly_blink = class({})
function item_rpg_butterfly_blink:GetIntrinsicModifierName() return "modifier_rpg_butterfly_blink" end
function item_rpg_butterfly_blink:OnSpellStart()
	local caster = self:GetCaster()
	local from = caster:GetAbsOrigin()
	local point = self:GetCursorPosition()
	local delta = point - from
	if delta:Length2D() > 1600 then point = from + delta:Normalized() * 1600 end
	point.z = from.z
	play_item_particle("particles/items_fx/blink_dagger_start.vpcf", caster)
	FindClearSpaceForUnit(caster, point, true)
	play_item_particle("particles/items_fx/blink_dagger_end.vpcf", caster)
	caster:AddNewModifier(caster, self, "modifier_rpg_butterfly_blink_buff", { duration = 10 })
end

modifier_rpg_butterfly_blink = class({})
function modifier_rpg_butterfly_blink:IsHidden() return true end
function modifier_rpg_butterfly_blink:IsPurgable() return false end
function modifier_rpg_butterfly_blink:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_rpg_butterfly_blink:DeclareFunctions()
	return { MODIFIER_PROPERTY_STATS_AGILITY_BONUS, MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE, MODIFIER_PROPERTY_EVASION_CONSTANT }
end
function modifier_rpg_butterfly_blink:GetModifierBonusStats_Agility() return 100 end
function modifier_rpg_butterfly_blink:GetModifierPreAttack_BonusDamage() return 60 end
function modifier_rpg_butterfly_blink:GetModifierEvasion_Constant() return 50 end

modifier_rpg_butterfly_blink_buff = class({})
function modifier_rpg_butterfly_blink_buff:IsPurgable() return true end
function modifier_rpg_butterfly_blink_buff:GetTexture() return "item_rpg_butterfly_blink" end
function modifier_rpg_butterfly_blink_buff:DeclareFunctions()
	return { MODIFIER_PROPERTY_STATS_AGILITY_BONUS, MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end
function modifier_rpg_butterfly_blink_buff:GetModifierBonusStats_Agility() return 60 end
function modifier_rpg_butterfly_blink_buff:GetModifierMoveSpeedBonus_Percentage() return 65 end

-- ==================== Crimson Vladimir ====================
item_rpg_crimson_vladimir = class({})
function item_rpg_crimson_vladimir:GetIntrinsicModifierName() return "modifier_rpg_crimson_vladimir" end
function item_rpg_crimson_vladimir:OnSpellStart()
	local caster = self:GetCaster()
	play_item_particle("particles/items_fx/aoe_item_caster_additive_crimson_guard_ring_burst.vpcf", caster)
	play_item_particle("particles/items_fx/aoe_item_caster_additive_crimson_guard_base.vpcf", caster)
	for _, ally in ipairs(find_allies(caster, 1200)) do
		play_item_particle("particles/items_fx/aoe_item_generic_caster_additive.vpcf", ally)
		ally:AddNewModifier(caster, self, "modifier_rpg_vladimir_guard_buff", { duration = 15 })
	end
end

modifier_rpg_crimson_vladimir = class({})
function modifier_rpg_crimson_vladimir:IsHidden() return true end
function modifier_rpg_crimson_vladimir:IsPurgable() return false end
function modifier_rpg_crimson_vladimir:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_rpg_crimson_vladimir:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS, MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS, MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
	}
end
function modifier_rpg_crimson_vladimir:GetModifierBonusStats_Strength() return 20 end
function modifier_rpg_crimson_vladimir:GetModifierBonusStats_Agility() return 20 end
function modifier_rpg_crimson_vladimir:GetModifierBonusStats_Intellect() return 20 end
function modifier_rpg_crimson_vladimir:GetModifierExtraHealthBonus() return 500 end
function modifier_rpg_crimson_vladimir:GetModifierPhysicalArmorBonus() return 12 end
function modifier_rpg_crimson_vladimir:GetModifierConstantHealthRegen() return 25 end
function modifier_rpg_crimson_vladimir:GetModifierConstantManaRegen() return 5 end
function modifier_rpg_crimson_vladimir:IsAura() return true end
function modifier_rpg_crimson_vladimir:GetModifierAura() return "modifier_rpg_vladimir_offering_aura" end
function modifier_rpg_crimson_vladimir:GetAuraRadius() return 1200 end
function modifier_rpg_crimson_vladimir:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_FRIENDLY end
function modifier_rpg_crimson_vladimir:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function modifier_rpg_crimson_vladimir:GetAuraSearchFlags() return DOTA_UNIT_TARGET_FLAG_NONE end

modifier_rpg_vladimir_offering_aura = class({})
function modifier_rpg_vladimir_offering_aura:IsHidden() return false end
function modifier_rpg_vladimir_offering_aura:IsPurgable() return false end
function modifier_rpg_vladimir_offering_aura:GetTexture() return "item_rpg_crimson_vladimir" end
function modifier_rpg_vladimir_offering_aura:DeclareFunctions()
	return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS, MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE, MODIFIER_EVENT_ON_ATTACK_LANDED }
end
function modifier_rpg_vladimir_offering_aura:GetModifierPhysicalArmorBonus() return 10 end
function modifier_rpg_vladimir_offering_aura:GetModifierBaseDamageOutgoing_Percentage() return 35 end
function modifier_rpg_vladimir_offering_aura:OnAttackLanded(p)
	if not IsServer() or p.attacker ~= self:GetParent() then return end
	heal_from_attack(self:GetParent(), p.target, p.damage, 40)
end

modifier_rpg_vladimir_guard_buff = class({})
function modifier_rpg_vladimir_guard_buff:IsPurgable() return true end
function modifier_rpg_vladimir_guard_buff:GetTexture() return "item_rpg_crimson_vladimir" end
function modifier_rpg_vladimir_guard_buff:DeclareFunctions()
	return { MODIFIER_PROPERTY_PHYSICAL_CONSTANT_BLOCK, MODIFIER_EVENT_ON_ATTACK_LANDED }
end
function modifier_rpg_vladimir_guard_buff:GetModifierPhysical_ConstantBlock() return 200 end
function modifier_rpg_vladimir_guard_buff:OnAttackLanded(p)
	if not IsServer() or p.attacker ~= self:GetParent() then return end
	heal_from_attack(self:GetParent(), p.target, p.damage, 30)
end

-- ==================== CrystallBlade ====================
item_rpg_crystall_blade = class({})
function item_rpg_crystall_blade:GetIntrinsicModifierName() return "modifier_rpg_crystall_blade" end

modifier_rpg_crystall_blade = class({})
function modifier_rpg_crystall_blade:IsHidden() return true end
function modifier_rpg_crystall_blade:IsPurgable() return false end
function modifier_rpg_crystall_blade:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_rpg_crystall_blade:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE, MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING, MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,
		MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end
function modifier_rpg_crystall_blade:GetModifierPreAttack_BonusDamage() return 80 end
function modifier_rpg_crystall_blade:GetModifierBonusStats_Strength() return 60 end
function modifier_rpg_crystall_blade:GetModifierStatusResistanceStacking() return 40 end
function modifier_rpg_crystall_blade:GetModifierHealAmplify_PercentageTarget() return 30 end
function modifier_rpg_crystall_blade:GetModifierHPRegenAmplify_Percentage() return 30 end
function modifier_rpg_crystall_blade:OnAttackLanded(p)
	if not IsServer() or p.attacker ~= self:GetParent() or not can_hit(p.attacker, p.target) then return end
	if RandomFloat(0, 100) >= 30 then return end
	local parent, target = self:GetParent(), p.target
	ApplyDamage({ victim = target, attacker = parent, damage = parent:GetAverageTrueAttackDamage(target) * 5.4,
		damage_type = DAMAGE_TYPE_PHYSICAL, ability = self:GetAbility() })
	play_item_particle("particles/items_fx/aoe_item_generic_caster_additive.vpcf", target)
	target:AddNewModifier(parent, self:GetAbility(), "modifier_stunned", { duration = 1.5 })
end

-- ==================== Eye's of Hydra ====================
item_rpg_eyes_of_hydra = class({})
function item_rpg_eyes_of_hydra:GetIntrinsicModifierName() return "modifier_rpg_eyes_of_hydra" end
function item_rpg_eyes_of_hydra:OnSpellStart()
	local caster = self:GetCaster()
	play_item_particle("particles/items_fx/aoe_item_generic_caster_additive.vpcf", caster)
	caster:AddNewModifier(caster, self, "modifier_rpg_polycephaly", { duration = 7 })
end

modifier_rpg_eyes_of_hydra = class({})
function modifier_rpg_eyes_of_hydra:IsHidden() return true end
function modifier_rpg_eyes_of_hydra:IsPurgable() return false end
function modifier_rpg_eyes_of_hydra:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_rpg_eyes_of_hydra:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS, MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_ATTACK_RANGE_BONUS, MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end
function modifier_rpg_eyes_of_hydra:GetModifierBonusStats_Strength() return 100 end
function modifier_rpg_eyes_of_hydra:GetModifierBonusStats_Agility() return 100 end
function modifier_rpg_eyes_of_hydra:GetModifierBonusStats_Intellect() return 100 end
function modifier_rpg_eyes_of_hydra:GetModifierPreAttack_BonusDamage() return 75 end
function modifier_rpg_eyes_of_hydra:GetModifierAttackRangeBonus()
	return self:GetParent():IsRangedAttacker() and 450 or 0
end
function modifier_rpg_eyes_of_hydra:OnAttackLanded(p)
	if not IsServer() or p.attacker ~= self:GetParent() or not can_hit(p.attacker, p.target) then return end
	p.target:AddNewModifier(p.attacker, self:GetAbility(), "modifier_rpg_cold_miasma", { duration = 5 })
end

modifier_rpg_cold_miasma = class({})
function modifier_rpg_cold_miasma:IsHidden() return false end
function modifier_rpg_cold_miasma:IsDebuff() return true end
function modifier_rpg_cold_miasma:IsPurgable() return true end
function modifier_rpg_cold_miasma:GetTexture() return "item_rpg_eyes_of_hydra" end
function modifier_rpg_cold_miasma:OnCreated()
	if not IsServer() then return end
	self.ticks_left = 5
	self.damage_per_tick = self:GetParent():GetMaxHealth() * 0.01
	self:StartIntervalThink(1)
end
function modifier_rpg_cold_miasma:OnRefresh()
	if not IsServer() then return end
	self.ticks_left = 5
	self.damage_per_tick = self:GetParent():GetMaxHealth() * 0.01
end
function modifier_rpg_cold_miasma:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,
	}
end
function modifier_rpg_cold_miasma:GetModifierMoveSpeedBonus_Percentage() return -75 end
function modifier_rpg_cold_miasma:GetModifierHPRegenAmplify_Percentage() return -75 end
function modifier_rpg_cold_miasma:GetModifierHealAmplify_PercentageTarget() return -75 end
function modifier_rpg_cold_miasma:OnIntervalThink()
	local target = self:GetParent()
	if not target:IsAlive() then self:Destroy() return end
	ApplyDamage({ victim = target, attacker = self:GetCaster(), ability = self:GetAbility(),
		damage = self.damage_per_tick, damage_type = DAMAGE_TYPE_MAGICAL })
	self.ticks_left = self.ticks_left - 1
	if self.ticks_left <= 0 then self:Destroy() end
end

modifier_rpg_polycephaly = class({})
function modifier_rpg_polycephaly:IsPurgable() return true end
function modifier_rpg_polycephaly:GetTexture() return "item_rpg_eyes_of_hydra" end
function modifier_rpg_polycephaly:DeclareFunctions() return { MODIFIER_EVENT_ON_ATTACK_LANDED } end
function modifier_rpg_polycephaly:OnAttackLanded(p)
	if not IsServer() or p.attacker ~= self:GetParent() or not self:GetParent():IsRangedAttacker()
		or not can_hit(p.attacker, p.target) then return end
	local parent, primary = p.attacker, p.target
	local splash = FindUnitsInRadius(parent:GetTeamNumber(), primary:GetAbsOrigin(), nil, 300,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	local damage = parent:GetAverageTrueAttackDamage(primary)
	for _, target in ipairs(splash) do
		if target ~= primary and can_hit(parent, target) then
			ApplyDamage({ victim = target, attacker = parent, ability = self:GetAbility(), damage = damage, damage_type = DAMAGE_TYPE_PHYSICAL })
			play_item_particle("particles/items2_fx/skadi_projectile_explosion.vpcf", target)
		end
	end
end

-- ==================== Slayer of Madness ====================
item_rpg_slayer_of_madness = class({})
function item_rpg_slayer_of_madness:GetIntrinsicModifierName() return "modifier_rpg_slayer_of_madness" end
function item_rpg_slayer_of_madness:OnSpellStart()
	local caster = self:GetCaster()
	play_item_particle("particles/items2_fx/mask_of_madness.vpcf", caster)
	caster:AddNewModifier(caster, self, "modifier_rpg_madness", { duration = 9 })
end

modifier_rpg_slayer_of_madness = class({})
function modifier_rpg_slayer_of_madness:IsHidden() return true end
function modifier_rpg_slayer_of_madness:IsPurgable() return false end
function modifier_rpg_slayer_of_madness:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_rpg_slayer_of_madness:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS, MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT, MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT, MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end
function modifier_rpg_slayer_of_madness:GetModifierBonusStats_Strength() return 20 end
function modifier_rpg_slayer_of_madness:GetModifierBonusStats_Agility() return 20 end
function modifier_rpg_slayer_of_madness:GetModifierBonusStats_Intellect() return 20 end
function modifier_rpg_slayer_of_madness:GetModifierPreAttack_BonusDamage() return 60 end
function modifier_rpg_slayer_of_madness:GetModifierAttackSpeedBonus_Constant() return 40 end
function modifier_rpg_slayer_of_madness:GetModifierMagicalResistanceBonus() return 35 end
function modifier_rpg_slayer_of_madness:GetModifierConstantHealthRegen() return 10 end
function modifier_rpg_slayer_of_madness:GetModifierConstantManaRegen() return 7 end
function modifier_rpg_slayer_of_madness:OnAttackLanded(p)
	if not IsServer() or p.attacker ~= self:GetParent() or not can_hit(p.attacker, p.target) then return end
	p.target:AddNewModifier(p.attacker, self:GetAbility(), "modifier_rpg_slayer_debuff", { duration = 3 })
	heal_from_attack(p.attacker, p.target, p.damage, 30)
end

modifier_rpg_slayer_debuff = class({})
function modifier_rpg_slayer_debuff:IsDebuff() return true end
function modifier_rpg_slayer_debuff:IsPurgable() return true end
function modifier_rpg_slayer_debuff:GetTexture() return "item_rpg_slayer_of_madness" end
function modifier_rpg_slayer_debuff:DeclareFunctions() return { MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE } end
function modifier_rpg_slayer_debuff:GetModifierDamageOutgoing_Percentage() return -40 end

modifier_rpg_madness = class({})
function modifier_rpg_madness:IsPurgable() return true end
function modifier_rpg_madness:GetTexture() return "item_rpg_slayer_of_madness" end
function modifier_rpg_madness:CheckState() return { [MODIFIER_STATE_SILENCED] = true } end
function modifier_rpg_madness:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end
function modifier_rpg_madness:GetModifierMoveSpeedBonus_Percentage() return 25 end
function modifier_rpg_madness:GetModifierStatusResistanceStacking() return 50 end
function modifier_rpg_madness:GetModifierAttackSpeedBonus_Constant() return 200 end
function modifier_rpg_madness:GetModifierPhysicalArmorBonus() return -20 end
function modifier_rpg_madness:OnAttackLanded(p)
	if not IsServer() or p.attacker ~= self:GetParent() then return end
	heal_from_attack(self:GetParent(), p.target, p.damage, 80)
end

-- ==================== Solar Cape ====================
item_rpg_solar_cape = class({})
function item_rpg_solar_cape:GetIntrinsicModifierName() return "modifier_rpg_solar_cape" end
function item_rpg_solar_cape:OnSpellStart()
	local caster, target = self:GetCaster(), self:GetCursorTarget()
	if not target or target:IsNull() or target:GetTeamNumber() ~= caster:GetTeamNumber() then return end
	target:AddNewModifier(caster, self, "modifier_rpg_shine", { duration = 12 })
	play_item_particle("particles/items_fx/generic_item_spell_caster_core_solar_crest.vpcf", target)
end

modifier_rpg_solar_cape = class({})
function modifier_rpg_solar_cape:IsHidden() return true end
function modifier_rpg_solar_cape:IsPurgable() return false end
function modifier_rpg_solar_cape:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_rpg_solar_cape:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS, MODIFIER_PROPERTY_MANA_BONUS,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS, MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
	}
end
function modifier_rpg_solar_cape:GetModifierExtraHealthBonus() return 1000 end
function modifier_rpg_solar_cape:GetModifierManaBonus() return 500 end
function modifier_rpg_solar_cape:GetModifierPhysicalArmorBonus() return 10 end
function modifier_rpg_solar_cape:GetModifierMoveSpeedBonus_Constant() return 70 end
function modifier_rpg_solar_cape:GetModifierMagicalResistanceBonus() return 25 end

modifier_rpg_shine = class({})
function modifier_rpg_shine:IsPurgable() return true end
function modifier_rpg_shine:GetTexture() return "item_rpg_solar_cape" end
function modifier_rpg_shine:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS, MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
	}
end
function modifier_rpg_shine:GetModifierBonusStats_Strength() return 50 end
function modifier_rpg_shine:GetModifierBonusStats_Agility() return 50 end
function modifier_rpg_shine:GetModifierBonusStats_Intellect() return 50 end
function modifier_rpg_shine:GetModifierAttackSpeedBonus_Constant() return 120 end
function modifier_rpg_shine:GetModifierMoveSpeedBonus_Percentage() return 35 end
function modifier_rpg_shine:GetModifierMagicalResistanceBonus() return 50 end
