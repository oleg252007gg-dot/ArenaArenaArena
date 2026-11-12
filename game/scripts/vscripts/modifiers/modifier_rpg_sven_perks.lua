-- Additional Sven perk mechanics. Kept separate from the base Sven modifiers so
-- perk-specific state can be reset cleanly on death or ability expiration.
local function has(unit, id)
	return unit and unit.rpg and unit.rpg.perk_count and (unit.rpg.perk_count[id] or 0) > 0
end

local function fx(path, point)
	local p = ParticleManager:CreateParticle(path, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(p, 0, point)
	ParticleManager:ReleaseParticleIndex(p)
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
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
		MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING,
		MODIFIER_PROPERTY_INCOMING_PHYSICAL_DAMAGE_PERCENTAGE,
		MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
	}
end

function modifier_rpg_sven_perk_tracker:OnCreated()
	if not IsServer() then return end
	self.debt = {}
	self.debt_stacks = {}
	self.hero_hits = 0
	self.target_hit_counts = {}
	self.warcry_extend_ready = {}
	self.gs_kills = 0
	self.gs_kill_damage_stacks = 0
	self.gs_trophy_stacks = 0
	self.gs_fifth_hits = {}
	self.gs_attack_stacks = 0
	self.gs_scars = 0
	self.gs_speed_stacks = 0
	self.gs_speed_expiry = 0
	self.cleave_speed_expiry = 0
	self.cleave_as_stacks = 0
	self.cleave_as_expiry = 0
	self:StartIntervalThink(0.25)
end

function modifier_rpg_sven_perk_tracker:OnIntervalThink()
	if not IsServer() then return end
	local hero = self:GetParent()
	local now = GameRules:GetGameTime()
	if now >= (self.cleave_speed_expiry or 0) then self.cleave_speed_expiry = 0 end
	if now >= (self.cleave_as_expiry or 0) then self.cleave_as_stacks = 0; self.cleave_as_expiry = 0 end
	if now >= (self.gs_speed_expiry or 0) then self.gs_speed_stacks = 0; self.gs_speed_expiry = 0 end
	if not hero:HasModifier("modifier_rpg_sven_gods_strength") then
		self.gs_attack_stacks = 0
		self.gs_fifth_hits = {}
		self.gs_scars = 0
		self.gs_kill_damage_stacks = 0
	end
	for ent, stacks in pairs(self.debt_stacks) do
		local unit = EntIndexToHScript(tonumber(ent))
		if not unit or unit:IsNull() or not unit:IsAlive() or not unit:HasModifier("modifier_rpg_sven_cleave_debt") then
			self.debt_stacks[ent] = nil
		end
	end
end

function modifier_rpg_sven_perk_tracker:GetModifierPreAttack_BonusDamage()
	local hero = self:GetParent()
	if not hero:HasModifier("modifier_rpg_sven_gods_strength") then return 0 end
	local base = hero:GetBaseDamageMin()
	local amount = base * (self.gs_kill_damage_stacks or 0) * 0.10
	if has(hero, "m_sven_cleave") then amount = amount + base * 0.10 end
	return amount
end

function modifier_rpg_sven_perk_tracker:GetModifierMoveSpeedBonus_Percentage()
	local hero = self:GetParent()
	local value = 0
	if GameRules:GetGameTime() < (self.cleave_speed_expiry or 0) then value = value + 10 end
	if hero:HasModifier("modifier_rpg_sven_gods_strength") and GameRules:GetGameTime() < (self.gs_speed_expiry or 0) then
		value = value + (self.gs_speed_stacks or 0) * 5
	end
	return value
end

function modifier_rpg_sven_perk_tracker:GetModifierAttackSpeedBonus_Constant()
	local hero = self:GetParent()
	if GameRules:GetGameTime() < (self.cleave_as_expiry or 0) then return (self.cleave_as_stacks or 0) * 10 end
	return 0
end

function modifier_rpg_sven_perk_tracker:GetModifierMagicalResistanceBonus()
	local hero = self:GetParent()
	if hero:HasModifier("modifier_rpg_sven_gods_strength") and has(hero, "e_sven_strength_slow_resist") then return 0 end
	return 0
end
function modifier_rpg_sven_perk_tracker:GetModifierStatusResistanceStacking()
	return self:GetParent():HasModifier("modifier_rpg_sven_gods_strength") and has(self:GetParent(), "e_sven_strength_slow_resist") and 35 or 0
end
function modifier_rpg_sven_perk_tracker:GetModifierIncomingPhysicalDamage_Percentage()
	if self:GetParent():HasModifier("modifier_rpg_sven_gods_strength") then return -math.min(30, self.gs_scars or 0) end
	return 0
end
function modifier_rpg_sven_perk_tracker:GetModifierAttackRangeBonus()
	return has(self:GetParent(), "e_sven_warcry_range_active") and 150 or 0
end

local function is_enemy(hero, unit)
	return unit and not unit:IsNull() and unit:IsAlive() and unit:GetTeamNumber() ~= hero:GetTeamNumber() and not unit:IsBuilding()
end

local function apply_debt(hero, target, damage, ability)
	if not has(hero, "l_sven_cleave_debt") then return damage end
	local key = tostring(target:entindex())
	local mod = target:FindModifierByNameAndCaster("modifier_rpg_sven_cleave_debt", hero)
	local count = mod and mod:GetStackCount() or 0
	if count >= 3 then
		if mod then mod:Destroy() end
		ApplyDamage({victim=target, attacker=hero, ability=ability, damage=damage * 2, damage_type=DAMAGE_TYPE_PURE})
		fx("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", target:GetAbsOrigin())
		return damage * 2
	end
	if mod then mod:IncrementStackCount(); mod:SetDuration(8, true)
	else target:AddNewModifier(hero, ability, "modifier_rpg_sven_cleave_debt", {duration=8}) end
	return damage * (1 + 0.25 * count)
end

local function cleave_wave(hero, ability, origin, forward, radius, angle, damage, wave, visited)
	if wave > 4 then return 0 end
	local victims = FindUnitsInRadius(hero:GetTeamNumber(), origin, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	local hit, count = {}, 0
	local half = math.cos(math.rad(angle * 0.5))
	for _, enemy in ipairs(victims) do
		local id = enemy:entindex()
		local delta = enemy:GetAbsOrigin() - origin
		delta.z = 0
		local dist = delta:Length2D()
		local in_cone = enemy == origin or dist < 1 or delta:Normalized():Dot(forward) >= half
		if is_enemy(hero, enemy) and not visited[id] and in_cone then
			visited[id] = true
			hit[#hit + 1] = enemy
			count = count + 1
			local dealt = damage * (0.8 ^ (wave - 1))
			if has(hero, "l_sven_cleave_execute") and enemy:GetHealth() < enemy:GetMaxHealth() * 0.40 then dealt = dealt * 1.30 end
			if has(hero, "e_sven_cleave_damage") then dealt = dealt * 1.15 end
			if has(hero, "e_sven_cleave_stagger") and RandomFloat(0, 1) < 0.15 then
				enemy:AddNewModifier(hero, ability, "modifier_stunned", {duration=0.1})
			end
			if has(hero, "e_sven_cleave_healblock") then enemy:AddNewModifier(hero, ability, "modifier_rpg_sven_heal_suppress", {duration=3}) end
			if has(hero, "l_sven_cleave_bleed") then enemy:AddNewModifier(hero, ability, "modifier_rpg_sven_bleed", {duration=5, damage=hero:GetAverageTrueAttackDamage(hero)*0.08}) end
			dealt = apply_debt(hero, enemy, dealt, ability)
			local before = enemy:GetHealth()
			local actual = ApplyDamage({victim=enemy, attacker=hero, ability=ability, damage=dealt,
				damage_type=DAMAGE_TYPE_PHYSICAL, damage_flags=has(hero,"m_sven_cleave") and DOTA_DAMAGE_FLAG_IGNORES_PHYSICAL_ARMOR or DOTA_DAMAGE_FLAG_NONE}) or 0
			if has(hero, "e_sven_cleave_lifesteal") then hero:Heal(actual * 0.05, ability) end
			if has(hero, "e_sven_cleave_kill_speed") and before > 0 and not enemy:IsAlive() then
				self = hero:FindModifierByName("modifier_rpg_sven_perk_tracker")
				if self then self.cleave_speed_expiry = GameRules:GetGameTime() + 3 end
			end
			local gore = target:FindModifierByNameAndCaster("modifier_rpg_sven_bleed", hero)
			if has(hero, "e_sven_cleave_hero_speed") and enemy:IsHero() then
				local tracker = hero:FindModifierByName("modifier_rpg_sven_perk_tracker")
				if tracker then tracker.cleave_as_stacks = math.min(5, (tracker.cleave_as_stacks or 0) + 1); tracker.cleave_as_expiry = GameRules:GetGameTime() + 3 end
			end
		end
	end
	if has(hero, "m_sven_cleave") and wave < 4 and #hit > 0 then
		for _, struck in ipairs(hit) do
			local next_origin = struck:GetAbsOrigin()
			local dir = next_origin - origin; dir.z = 0
			if dir:Length2D() > 0 then cleave_wave(hero, ability, next_origin, dir:Normalized(), radius, angle, damage, wave + 1, visited) end
		end
	end
	return count
end

function modifier_rpg_sven_perk_tracker:OnAttackLanded(params)
	if not IsServer() then return end
	local hero, target = self:GetParent(), params.target
	if params.attacker ~= hero or not is_enemy(hero, target) or params.no_attack_cooldown then return end
	local ability = hero:FindAbilityByName("rpg_sven_great_cleave")
	if not ability then return end

	if has(hero, "e_sven_hammer_static") then
		self.hammer_static_stacks = math.min(6, (self.hammer_static_stacks or 0) + 1)
	end
	if hero:HasModifier("modifier_rpg_sven_gods_strength") then
		if has(hero, "m_sven_strength") then
			local gs = hero:FindModifierByName("modifier_rpg_sven_gods_strength")
			if gs then gs:SetDuration(gs:GetRemainingTime() + 0.5, true) end
		end
		if has(hero, "l_sven_strength_momentum") then self.gs_speed_stacks = math.min(10, (self.gs_speed_stacks or 0) + 1); self.gs_speed_expiry = GameRules:GetGameTime() + 3 end
		if has(hero, "e_sven_strength_scars") then self.gs_scars = math.min(30, (self.gs_scars or 0) + 2); self.gs_scars_expiry = GameRules:GetGameTime() + 3 end
		if has(hero, "e_sven_strength_fifth") then
			local id = tostring(target:entindex())
			self.gs_fifth_hits[id] = (self.gs_fifth_hits[id] or 0) + 1
			if self.gs_fifth_hits[id] >= 5 then
				self.gs_fifth_hits[id] = 0
				ApplyDamage({victim=target, attacker=hero, ability=hero:FindAbilityByName("rpg_sven_gods_strength"),
					damage=hero:GetAverageTrueAttackDamage(hero), damage_type=DAMAGE_TYPE_PHYSICAL})
			end
		end
	end

	-- Cleave is a front-facing cone originating at Sven and aimed at the attack target.
	local radius = math.min(500, ability:GetSpecialValueFor("radius")) + Sven:Bonus(hero, "cleave_radius")
	if has(hero, "e_sven_cleave_arc") then radius = radius + 150 end
	local angle = 70 + (has(hero, "e_sven_cleave_arc") and 20 or 0)
	local direction = target:GetAbsOrigin() - hero:GetAbsOrigin(); direction.z = 0
	if direction:Length2D() < 1 then direction = hero:GetForwardVector(); direction.z = 0 end
	if direction:Length2D() < 1 then return end
	direction = direction:Normalized()
	local visited = {[target:entindex()] = true}
	local n = cleave_wave(hero, ability, hero:GetAbsOrigin(), direction, radius, angle, params.damage * (ability:GetSpecialValueFor("cleave_percent") + Sven:Bonus(hero, "cleave_damage")) / 100, 1, visited)
	if has(hero, "l_sven_cleave_resonance") and n >= 3 and GameRules:GetGameTime() >= (self.resonance_ready or 0) then
		self.resonance_ready = GameRules:GetGameTime() + 3
		self.processing_resonance = true
		hero:PerformAttack(target, true, true, true, false, false, false, false)
		self.processing_resonance = false
	end
	if has(hero, "e_sven_cleave_hammer_cd") and n >= 2 then
		local hammer = hero:FindAbilityByName("rpg_sven_storm_hammer")
		if hammer and hammer:GetCooldownTimeRemaining() > 0 then
			local remaining = hammer:GetCooldownTimeRemaining(); hammer:EndCooldown(); hammer:StartCooldown(math.max(0, remaining - 0.5))
		end
	end
	if has(hero, "l_sven_cleave_debt") then
		local id = tostring(target:entindex())
		local old = target:FindModifierByNameAndCaster("modifier_rpg_sven_cleave_debt", hero)
		if old then self.debt_stacks[id] = old:GetStackCount() else self.debt_stacks[id] = 1 end
	end
end

function modifier_rpg_sven_perk_tracker:OnDeath(params)
	if not IsServer() then return end
	local hero, victim = self:GetParent(), params.unit
	if params.attacker ~= hero or not victim or victim:GetTeamNumber() == hero:GetTeamNumber() then return end
	if hero:HasModifier("modifier_rpg_sven_gods_strength") then
		self.gs_kills = (self.gs_kills or 0) + 1
		if has(hero, "l_sven_strength_rush") then self.gs_kill_damage_stacks = math.min(5, (self.gs_kill_damage_stacks or 0) + 1) end
		if has(hero, "l_sven_strength_trophy") then self.gs_trophy_stacks = math.min(20, (self.gs_trophy_stacks or 0) + 1) end
		if has(hero, "l_sven_strength_hammer_reset") then
			local hammer = hero:FindAbilityByName("rpg_sven_storm_hammer")
			if hammer and hammer:GetCooldownTimeRemaining() > 0 then
				local remaining = hammer:GetCooldownTimeRemaining(); hammer:EndCooldown(); hammer:StartCooldown(remaining * 0.8)
			end
		end
		if has(hero, "e_sven_strength_second_wind") then hero:Heal(hero:GetMaxHealth() * 0.002, hero) end
		if has(hero, "e_sven_strength_war_supremacy") then
			local m = hero:FindModifierByName("modifier_rpg_sven_war_supremacy")
			if m then m:SetStackCount(math.min(5, m:GetStackCount() + 1)); m:SetDuration(4, true)
			else hero:AddNewModifier(hero, hero:FindAbilityByName("rpg_sven_gods_strength"), "modifier_rpg_sven_war_supremacy", {duration=4}) end
		end
	end
	if victim:IsHero() or victim.rpg_boss or victim.rpg_miniboss then
		if has(hero, "e_sven_strength_collector") then
			self.gs_kills = self.gs_kills or 0
			if self.gs_kills % 50 == 0 then hero:SetBaseMaxHealth(hero:GetBaseMaxHealth() + math.max(1, math.floor(hero:GetBaseMaxHealth() * 0.01))); hero:SetMaxHealth(hero:GetMaxHealth() + math.max(1, math.floor(hero:GetMaxHealth() * 0.01))) end
		end
	end
end

function modifier_rpg_sven_perk_tracker:OnTakeDamage(params)
	if not IsServer() then return end
	local hero = self:GetParent()
	if params.unit ~= hero or not hero:HasModifier("modifier_rpg_sven_gods_strength") or not has(hero, "e_sven_strength_scars") then return end
	if params.damage > 0 then self.gs_scars = math.min(30, (self.gs_scars or 0) + 2); self.gs_scars_expiry = GameRules:GetGameTime() + 3 end
end

modifier_rpg_sven_cleave_debt = class({})
function modifier_rpg_sven_cleave_debt:IsDebuff() return true end
function modifier_rpg_sven_cleave_debt:IsPurgable() return true end
function modifier_rpg_sven_cleave_debt:GetTexture() return "sven_great_cleave" end
function modifier_rpg_sven_cleave_debt:OnCreated() if IsServer() then self:SetStackCount(1) end end
function modifier_rpg_sven_cleave_debt:OnRefresh() if IsServer() then self:SetStackCount(math.min(4, self:GetStackCount() + 1)) end end

modifier_rpg_sven_heal_suppress = class({})
function modifier_rpg_sven_heal_suppress:IsDebuff() return true end
function modifier_rpg_sven_heal_suppress:IsPurgable() return true end
function modifier_rpg_sven_heal_suppress:DeclareFunctions() return {MODIFIER_PROPERTY_DISABLE_HEALING} end
function modifier_rpg_sven_heal_suppress:GetDisableHealing() return 1 end

modifier_rpg_sven_warcry_perks = class({})
function modifier_rpg_sven_warcry_perks:IsHidden() return false end
function modifier_rpg_sven_warcry_perks:IsPurgable() return true end
function modifier_rpg_sven_warcry_perks:DeclareFunctions()
	return {MODIFIER_EVENT_ON_TAKEDAMAGE, MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE, MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_ATTACK_RANGE_BONUS, MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET}
end
function modifier_rpg_sven_warcry_perks:OnCreated()
	self.stored = 0
	if IsServer() then self:StartIntervalThink(0.2) end
end
function modifier_rpg_sven_warcry_perks:OnIntervalThink()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then self:Destroy(); return end
	if has(caster, "l_sven_warcry_extend") then
		for _, ally in ipairs(FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, 900, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)) do
			if ally:GetHealth() < ally:GetMaxHealth() * 0.20 then
				local ready = self["extend_" .. ally:entindex()] or 0
				if GameRules:GetGameTime() >= ready then
					self["extend_" .. ally:entindex()] = GameRules:GetGameTime() + 15
					local buff = ally:FindModifierByName("modifier_rpg_sven_warcry")
					if buff then buff:SetDuration(buff:GetRemainingTime() + 3, true) end
				end
			end
		end
	end
end
function modifier_rpg_sven_warcry_perks:OnTakeDamage(params)
	if not IsServer() or not has(self:GetCaster(), "m_sven_warcry") then return end
	local caster, unit = self:GetCaster(), params.unit
	if not unit or unit:GetTeamNumber() ~= caster:GetTeamNumber() or unit == caster or params.damage <= 0 then return end
	if (unit:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() > 900 then return end
	self.stored = self.stored + params.damage
end
function modifier_rpg_sven_warcry_perks:GetModifierMagicalResistanceBonus()
	return has(self:GetCaster(), "l_sven_warcry_resist") and 30 or 0
end
function modifier_rpg_sven_warcry_perks:GetModifierPreAttack_BonusDamage()
	local caster = self:GetCaster()
	if not has(caster, "l_sven_warcry_damage") then return 0 end
	local allies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, 900, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	return caster:GetBaseDamageMin() * 0.15 * #allies
end
function modifier_rpg_sven_warcry_perks:GetModifierAttackSpeedBonus_Constant()
	return has(self:GetCaster(), "e_sven_warcry_as") and 25 or 0
end
function modifier_rpg_sven_warcry_perks:GetModifierAttackRangeBonus()
	return has(self:GetCaster(), "e_sven_warcry_range") and self:GetParent():IsRangedAttacker() and 150 or 0
end
function modifier_rpg_sven_warcry_perks:GetModifierHealAmplify_PercentageTarget()
	return has(self:GetCaster(), "e_sven_warcry_heal_amp") and 20 or 0
end
function modifier_rpg_sven_warcry_perks:OnDestroy()
	if not IsServer() or not has(self:GetCaster(), "m_sven_warcry") or (self.stored or 0) <= 0 then return end
	local caster = self:GetCaster()
	local center = caster:GetAbsOrigin()
	local radius = 900
	fx("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", center)
	for _, enemy in ipairs(FindUnitsInRadius(caster:GetTeamNumber(), center, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)) do
		ApplyDamage({victim=enemy, attacker=caster, ability=self:GetAbility(), damage=self.stored, damage_type=DAMAGE_TYPE_PURE})
	end
end

modifier_rpg_sven_war_supremacy = class({})
function modifier_rpg_sven_war_supremacy:IsPurgable() return true end
function modifier_rpg_sven_war_supremacy:DeclareFunctions() return {MODIFIER_PROPERTY_ATTACKSPEED_BONUS_PERCENTAGE} end
function modifier_rpg_sven_war_supremacy:GetModifierAttackSpeedBonus_Percentage() return self:GetStackCount() * 10 end
