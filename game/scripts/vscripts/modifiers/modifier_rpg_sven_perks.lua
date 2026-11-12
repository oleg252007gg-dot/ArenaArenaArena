-- Sven perk logic: shared state and effects for cleave, warcry and God's Strength.
local function has(unit, id)
	if not unit or unit:IsNull() then return false end
	if unit.rpg and unit.rpg.perk_count then
		return (unit.rpg.perk_count[id] or 0) > 0
	end
	return false
end

local function clamp(v, min, max)
	if v < min then return min end
	if v > max then return max end
	return v
end

modifier_rpg_sven_perk_tracker = class({})
function modifier_rpg_sven_perk_tracker:IsHidden() return true end
function modifier_rpg_sven_perk_tracker:IsPurgable() return false end
function modifier_rpg_sven_perk_tracker:RemoveOnDeath() return false end
function modifier_rpg_sven_perk_tracker:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_DEATH,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_INCOMING_PHYSICAL_DAMAGE_PERCENTAGE,
	}
end

function modifier_rpg_sven_perk_tracker:OnCreated()
	self.cleave_as_stacks = 0
	self.cleave_as_expire = 0
	self.gs_speed_stacks = 0
	self.gs_speed_expire = 0
	self.gs_scars = 0
	self.gs_scars_expire = 0
	self.gs_fifth_hits = {}
	self.cleave_target_hits = {}
	self.warcry_absorb = 0
	self.next_resonance = 0
	if IsServer() then self:StartIntervalThink(0.2) end
end

function modifier_rpg_sven_perk_tracker:OnIntervalThink()
	if not IsServer() then return end
	local now = GameRules:GetGameTime()
	local hero = self:GetParent()
	if now >= (self.cleave_as_expire or 0) then self.cleave_as_stacks = 0; self.cleave_as_expire = 0 end
	if now >= (self.gs_speed_expire or 0) then self.gs_speed_stacks = 0; self.gs_speed_expire = 0 end
	if now >= (self.gs_scars_expire or 0) then self.gs_scars = 0; self.gs_scars_expire = 0 end
	if not hero:HasModifier("modifier_rpg_sven_gods_strength") then
		self.gs_speed_stacks = 0
		self.gs_scars = 0
		self.gs_fifth_hits = {}
	end
end

function modifier_rpg_sven_perk_tracker:GetModifierPreAttack_BonusDamage()
	local hero = self:GetParent()
	if not hero:HasModifier("modifier_rpg_sven_gods_strength") then return 0 end
	local total = 0
	local base = hero:GetBaseDamageMin()
	if has(hero, "m_sven_strength") then total = total + base * 0.08 end
	if has(hero, "l_sven_strength_rush") then total = total + base * 0.10 * math.min(5, self.gs_speed_stacks or 0) end
	if has(hero, "e_sven_strength_brutality") then total = total + base * 0.15 end
	return total
end

function modifier_rpg_sven_perk_tracker:GetModifierMoveSpeedBonus_Percentage()
	local hero = self:GetParent()
	local bonus = 0
	if hero:HasModifier("modifier_rpg_sven_gods_strength") then
		bonus = bonus + (self.gs_speed_stacks or 0) * 5
	end
	if has(hero, "e_sven_hammer_surge") then
		local surge_until = hero.rpg_sven_hammer_surge_until or 0
		if GameRules:GetGameTime() < surge_until then bonus = bonus + 20 end
	end
	return bonus
end

function modifier_rpg_sven_perk_tracker:GetModifierAttackSpeedBonus_Constant()
	local hero = self:GetParent()
	local bonus = 0
	if has(hero, "e_sven_cleave_hero_speed") then bonus = bonus + (self.cleave_as_stacks or 0) * 10 end
	if has(hero, "e_sven_strength_war_supremacy") then bonus = bonus + (self.gs_speed_stacks or 0) * 8 end
	return bonus
end

function modifier_rpg_sven_perk_tracker:GetModifierIncomingPhysicalDamage_Percentage()
	local hero = self:GetParent()
	if hero:HasModifier("modifier_rpg_sven_gods_strength") and has(hero, "e_sven_strength_scars") then
		return -(self.gs_scars or 0)
	end
	return 0
end

local function is_enemy(hero, unit)
	return unit and not unit:IsNull() and unit:IsAlive() and unit:GetTeamNumber() ~= hero:GetTeamNumber() and not unit:IsBuilding()
end

function modifier_rpg_sven_perk_tracker:OnAttackLanded(params)
	if not IsServer() then return end
	local hero = self:GetParent()
	if params.attacker ~= hero or not is_enemy(hero, params.target) then return end
	local target = params.target
	local ability = hero:FindAbilityByName("rpg_sven_great_cleave")

	-- Great Cleave: per-hit scaling, speed gain and resonance.
	if ability and target and hero:GetAttackCapability() ~= DOTA_UNIT_CAP_RANGED_ATTACK then
		if has(hero, "e_sven_cleave_hero_speed") then
			self.cleave_as_stacks = clamp((self.cleave_as_stacks or 0) + 1, 0, 5)
			self.cleave_as_expire = GameRules:GetGameTime() + 3
		end
		if has(hero, "l_sven_cleave_resonance") then
			local users = FindUnitsInRadius(hero:GetTeamNumber(), target:GetAbsOrigin(), nil, 350,
				DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
				DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
			if #users >= 3 and GameRules:GetGameTime() >= (self.next_resonance or 0) then
				self.next_resonance = GameRules:GetGameTime() + 3
				hero:PerformAttack(target, true, true, true, false, false, false, false)
			end
		end
		if has(hero, "e_sven_cleave_hammer_cd") then
			local hammer = hero:FindAbilityByName("rpg_sven_storm_hammer")
			if hammer and hammer:GetCooldownTimeRemaining() > 0 then
				hammer:EndCooldown()
				hammer:StartCooldown(math.max(0, hammer:GetCooldownTimeRemaining() - 0.5))
			end
		end
	end

	-- God's Strength bonuses.
	if hero:HasModifier("modifier_rpg_sven_gods_strength") then
		if has(hero, "l_sven_strength_momentum") then
			self.gs_speed_stacks = clamp((self.gs_speed_stacks or 0) + 1, 0, 10)
			self.gs_speed_expire = GameRules:GetGameTime() + 3
		end
		if has(hero, "e_sven_strength_scars") then
			self.gs_scars = clamp((self.gs_scars or 0) + 2, 0, 30)
			self.gs_scars_expire = GameRules:GetGameTime() + 3
		end
		if has(hero, "e_sven_strength_fifth") then
			local key = tostring(target:entindex())
			self.gs_fifth_hits[key] = (self.gs_fifth_hits[key] or 0) + 1
			if self.gs_fifth_hits[key] >= 5 then
				self.gs_fifth_hits[key] = 0
				ApplyDamage({
					victim = target,
					attacker = hero,
					ability = hero:FindAbilityByName("rpg_sven_gods_strength"),
					damage = hero:GetAverageTrueAttackDamage(hero),
					damage_type = DAMAGE_TYPE_PHYSICAL,
					damage_flags = DOTA_DAMAGE_FLAG_NONE,
				})
			end
		end
	end

	-- Storm Hammer static-charge enhancer.
	if has(hero, "e_sven_hammer_static") then
		if not self.hammer_stack then self.hammer_stack = 0 end
		self.hammer_stack = math.min(6, self.hammer_stack + 1)
		hero.rpg_sven_hammer_bonus = (hero.rpg_sven_hammer_bonus or 0) + 25
	end

	-- Cleave debt marks.
	if has(hero, "l_sven_cleave_debt") then
		local mark = target:FindModifierByName("modifier_rpg_sven_cleave_debt")
		if mark then
			mark:SetStackCount(clamp(mark:GetStackCount() + 1, 1, 4))
			mark:SetDuration(8, true)
		else
			target:AddNewModifier(hero, ability, "modifier_rpg_sven_cleave_debt", { duration = 8 })
		end
	end
end

function modifier_rpg_sven_perk_tracker:OnDeath(params)
	if not IsServer() then return end
	local hero = self:GetParent()
	if params.attacker ~= hero then return end
	if hero:HasModifier("modifier_rpg_sven_gods_strength") then
		if has(hero, "l_sven_strength_rush") then
			self.gs_speed_stacks = clamp((self.gs_speed_stacks or 0) + 1, 0, 10)
			self.gs_speed_expire = GameRules:GetGameTime() + 3
		end
		if has(hero, "l_sven_strength_hammer_reset") then
			local hammer = hero:FindAbilityByName("rpg_sven_storm_hammer")
			if hammer then hammer:EndCooldown(); hammer:StartCooldown(math.max(0, hammer:GetCooldownTimeRemaining() - 20)) end
		end
		if has(hero, "e_sven_strength_second_wind") then hero:Heal(hero:GetMaxHealth() * 0.002, hero) end
	end
end

function modifier_rpg_sven_perk_tracker:OnTakeDamage(params)
	if not IsServer() then return end
	local hero = self:GetParent()
	if params.unit ~= hero or not hero:HasModifier("modifier_rpg_sven_gods_strength") then return end
	if has(hero, "e_sven_strength_scars") then
		self.gs_scars = clamp((self.gs_scars or 0) + 2, 0, 30)
		self.gs_scars_expire = GameRules:GetGameTime() + 3
	end
end

modifier_rpg_sven_cleave_debt = class({})
function modifier_rpg_sven_cleave_debt:IsDebuff() return true end
function modifier_rpg_sven_cleave_debt:IsPurgable() return true end
function modifier_rpg_sven_cleave_debt:GetTexture() return "sven_great_cleave" end
function modifier_rpg_sven_cleave_debt:OnCreated()
	if IsServer() then self:SetStackCount(1) end
end
function modifier_rpg_sven_cleave_debt:OnRefresh()
	if IsServer() then self:SetStackCount(clamp(self:GetStackCount() + 1, 1, 4)) end
end

modifier_rpg_sven_warcry_perks = class({})
function modifier_rpg_sven_warcry_perks:IsHidden() return false end
function modifier_rpg_sven_warcry_perks:IsPurgable() return true end
function modifier_rpg_sven_warcry_perks:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,
	}
end

function modifier_rpg_sven_warcry_perks:OnCreated()
	self.stored = 0
end

function modifier_rpg_sven_warcry_perks:OnTakeDamage(params)
	if not IsServer() then return end
	local caster = self:GetCaster()
	if params.unit == caster or params.unit:GetTeamNumber() ~= caster:GetTeamNumber() then return end
	if (params.unit:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() > 900 then return end
	self.stored = self.stored + math.max(0, params.damage)
end

function modifier_rpg_sven_warcry_perks:GetModifierPreAttack_BonusDamage()
	local caster = self:GetCaster()
	if not has(caster, "l_sven_warcry_damage") then return 0 end
	local allies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, 900,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER, false)
	return caster:GetBaseDamageMin() * 0.15 * #allies
end

function modifier_rpg_sven_warcry_perks:GetModifierAttackSpeedBonus_Constant()
	return has(self:GetCaster(), "e_sven_warcry_as") and 25 or 0
end

function modifier_rpg_sven_warcry_perks:GetModifierHealAmplify_PercentageTarget()
	return has(self:GetCaster(), "e_sven_warcry_heal_amp") and 20 or 0
end

function modifier_rpg_sven_warcry_perks:OnDestroy()
	if not IsServer() then return end
	local caster = self:GetCaster()
	if not has(caster, "m_sven_warcry") or self.stored <= 0 then return end
	local center = caster:GetAbsOrigin()
	for _, enemy in ipairs(FindUnitsInRadius(caster:GetTeamNumber(), center, nil, 900,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)) do
		ApplyDamage({
			victim = enemy,
			attacker = caster,
			ability = self:GetAbility(),
			damage = self.stored,
			damage_type = DAMAGE_TYPE_PURE,
		})
	end
end

modifier_rpg_sven_war_supremacy = class({})
function modifier_rpg_sven_war_supremacy:IsHidden() return false end
function modifier_rpg_sven_war_supremacy:IsPurgable() return true end
function modifier_rpg_sven_war_supremacy:DeclareFunctions() return { MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT } end
function modifier_rpg_sven_war_supremacy:GetModifierAttackSpeedBonus_Constant()
	return (self:GetStackCount() or 0) * 10
end

modifier_rpg_sven_heal_suppress = class({})
function modifier_rpg_sven_heal_suppress:IsDebuff() return true end
function modifier_rpg_sven_heal_suppress:IsPurgable() return true end
function modifier_rpg_sven_heal_suppress:DeclareFunctions() return { MODIFIER_PROPERTY_DISABLE_HEALING } end
function modifier_rpg_sven_heal_suppress:GetDisableHealing() return 1 end
