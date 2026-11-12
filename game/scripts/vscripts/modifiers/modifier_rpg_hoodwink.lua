modifier_rpg_hoodwink = class({})
function modifier_rpg_hoodwink:IsHidden() return true end
function modifier_rpg_hoodwink:IsPurgable() return false end
function modifier_rpg_hoodwink:RemoveOnDeath() return false end
function modifier_rpg_hoodwink:OnCreated()
	if not IsServer() then return end
	local devil = self:GetParent():FindAbilityByName("rpg_hoodwink_sharpshooter_devil")
	if devil then devil:SetHidden(true); devil:SetActivated(false) end
	self:StartIntervalThink(0.2)
end
function modifier_rpg_hoodwink:OnIntervalThink() Hoodwink:UpdateDevilAbility(self:GetParent()) end
function modifier_rpg_hoodwink:DeclareFunctions() return { MODIFIER_EVENT_ON_ATTACK_LANDED, MODIFIER_EVENT_ON_TAKEDAMAGE, MODIFIER_EVENT_ON_DEATH, MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS } end
function modifier_rpg_hoodwink:GetModifierPhysicalArmorBonus()
	local hero, bonus = self:GetParent(), self:GetParent().rpg and self:GetParent().rpg.hoodwink_boss_armor or 0
	if Hoodwink:Has(hero, "e_bone_armor") then
		for _, enemy in ipairs(Hoodwink:Enemies(hero, hero:GetAbsOrigin(), 600)) do
			if enemy:FindModifierByNameAndCaster("modifier_rpg_hoodwink_bushwhack", hero) then return bonus + 20 end
		end
	end
	return bonus
end
function modifier_rpg_hoodwink:OnAttackLanded(p)
	if not IsServer() or p.attacker ~= self:GetParent() or not p.target or not p.target:IsAlive() then return end
	local hero, target = self:GetParent(), p.target
	if target:FindModifierByNameAndCaster("modifier_rpg_hoodwink_bushwhack", hero) then
		if Hoodwink:Has(hero, "l_pop") then ApplyDamage({ victim = target, attacker = hero, ability = hero:FindAbilityByName("rpg_hoodwink_bushwhack"), damage = target:GetMaxHealth() * 0.03, damage_type = DAMAGE_TYPE_PURE }) end
		if Hoodwink:Has(hero, "e_blood_energy") then hero:GiveMana(p.damage * 0.05) end
		if Hoodwink:Has(hero, "e_hunter_luck") and RandomFloat(0, 100) <= 15 then Hoodwink:FireAcorn(hero, hero:FindAbilityByName("rpg_hoodwink_acorn_shot"), target) end
	end
end
function modifier_rpg_hoodwink:OnTakeDamage(p)
	if not IsServer() or p.unit ~= self:GetParent() then return end
	local hero = self:GetParent()
	if hero:IsAlive() and Hoodwink:Has(hero, "e_survival") and hero:GetHealth() < hero:GetMaxHealth() * 0.25 and not hero:HasModifier("modifier_rpg_hoodwink_scurry") then
		local now = GameRules:GetGameTime()
		if now >= (hero.rpg.hoodwink_survival_ready or 0) then
			hero.rpg.hoodwink_survival_ready = now + 20
			local ability = hero:FindAbilityByName("rpg_hoodwink_scurry")
			if ability then Hoodwink:CastScurry(hero, ability, true) end
		end
	end
	if hero:IsAlive() and p.unit == hero and Hoodwink:Has(hero, "e_nuclear") and hero:GetHealth() <= hero:GetMaxHealth() * 0.15 then
		local now = GameRules:GetGameTime()
		if now >= (hero.rpg.hoodwink_nuclear_ready or 0) then
			hero.rpg.hoodwink_nuclear_ready = now + 30
			local target
			local enemies = Hoodwink:Enemies(hero, hero:GetAbsOrigin(), 1200)
			if #enemies > 0 then target = enemies[1] end
			local ability = hero:FindAbilityByName("rpg_hoodwink_acorn_shot")
			if ability and target then for _ = 1, 3 do Hoodwink:FireAcorn(hero, ability, target, { heal_pct = 25, blast = true, forced_blast = true }) end end
		end
	end
	if not p.attacker or p.attacker:IsNull() or p.attacker == hero then return end
	local scurry = hero:FindModifierByName("modifier_rpg_hoodwink_scurry")
	if scurry and Hoodwink:Has(hero, "l_thorny") and not p.damage_flags then
		local pct = 40 + hero:GetStrength() * 0.05
		ApplyDamage({ victim = p.attacker, attacker = hero, ability = scurry:GetAbility(), damage = p.damage * pct / 100, damage_type = DAMAGE_TYPE_PHYSICAL })
	end
end
function modifier_rpg_hoodwink:OnDeath(p)
	if not IsServer() then return end
	local hero = self:GetParent()
	if p.unit == hero then
		if Hoodwink:Has(hero, "e_farewell") then
			local ab = hero:FindAbilityByName("rpg_hoodwink_sharpshooter")
			if ab then for i = 1, 6 do Hoodwink:FireSharpshooter(hero, ab, hero:GetAbsOrigin() + RandomVector(1200), 1, false) end end
		end
	elseif p.attacker == hero and Hoodwink:IsBoss(p.unit) and Hoodwink:Has(hero, "e_lumber") then
		hero.rpg.hoodwink_boss_armor = (hero.rpg.hoodwink_boss_armor or 0) + 5
	end
end

modifier_rpg_hoodwink_scurry = class({})
function modifier_rpg_hoodwink_scurry:IsPurgable() return false end
function modifier_rpg_hoodwink_scurry:OnCreated()
	if not IsServer() then return end
	self:StartIntervalThink(0.1)
	self.previous = {}
	if Hoodwink:Has(self:GetParent(), "e_attention") then
		for _, enemy in ipairs(Hoodwink:Enemies(self:GetParent(), self:GetParent():GetAbsOrigin(), 700)) do enemy:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_rpg_call_taunt", { duration = 2 }) end
	end
end
function modifier_rpg_hoodwink_scurry:OnIntervalThink()
	local h = self:GetParent(); if not h:IsAlive() then return end
	if Hoodwink:Has(h, "l_make_room") then
		for _, enemy in ipairs(Hoodwink:Enemies(h, h:GetAbsOrigin(), 180)) do
			if not self.previous[enemy:entindex()] then
				self.previous[enemy:entindex()] = true
				ApplyDamage({ victim = enemy, attacker = h, ability = self:GetAbility(), damage = h:GetStrength() * 1.5, damage_type = DAMAGE_TYPE_PURE })
			end
		end
	end
end
function modifier_rpg_hoodwink_scurry:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, MODIFIER_PROPERTY_EVASION_CONSTANT, MODIFIER_PROPERTY_INCOMING_PHYSICAL_DAMAGE_PERCENTAGE, MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT, MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING, MODIFIER_PROPERTY_ATTACK_RANGE_BONUS, MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE, MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT }
end
function modifier_rpg_hoodwink_scurry:GetModifierMoveSpeedBonus_Percentage() if Hoodwink:Has(self:GetParent(), "m_mighty_oak") then return Hoodwink:Has(self:GetParent(), "e_dense_skin") and -82.5 or -75 end return 35 end
function modifier_rpg_hoodwink_scurry:GetModifierAttackSpeedBonus_Constant() if Hoodwink:Has(self:GetParent(), "m_mighty_oak") then return Hoodwink:Has(self:GetParent(), "e_dense_skin") and -82.5 or -75 end return 0 end
function modifier_rpg_hoodwink_scurry:GetModifierEvasion_Constant() if Hoodwink:Has(self:GetParent(), "m_mighty_oak") then return 0 end return 100 end
function modifier_rpg_hoodwink_scurry:GetModifierIncomingPhysicalDamage_Percentage() if Hoodwink:Has(self:GetParent(), "m_mighty_oak") then return Hoodwink:Has(self:GetParent(), "e_dense_skin") and -82.5 or -75 end return 0 end
function modifier_rpg_hoodwink_scurry:GetModifierHealthRegenConstant() return Hoodwink:Has(self:GetParent(), "m_mighty_oak") and 50 or 0 end
function modifier_rpg_hoodwink_scurry:GetModifierStatusResistanceStacking() return Hoodwink:Has(self:GetParent(), "l_thick_skull") and 65 or 0 end
function modifier_rpg_hoodwink_scurry:GetModifierAttackRangeBonus() return Hoodwink:Has(self:GetParent(), "e_artillery") and 350 or 0 end
function modifier_rpg_hoodwink_scurry:GetModifierPreAttack_BonusDamage() return Hoodwink:Has(self:GetParent(), "e_artillery") and self:GetParent():GetBaseDamageMax() * 2 or 0 end
function modifier_rpg_hoodwink_scurry:CheckState()
	local state = {}
	if Hoodwink:Has(self:GetParent(), "l_iron_grip") then state[MODIFIER_STATE_UNSLOWABLE] = true end
	return state
end
function modifier_rpg_hoodwink_scurry:OnDestroy()
	if IsServer() and Hoodwink:Has(self:GetParent(), "e_scurry_blast") then
		for _, enemy in ipairs(Hoodwink:Enemies(self:GetParent(), self:GetParent():GetAbsOrigin(), 700)) do ApplyDamage({ victim = enemy, attacker = self:GetParent(), ability = self:GetAbility(), damage = 300, damage_type = DAMAGE_TYPE_MAGICAL }) end
	end
end

modifier_rpg_hoodwink_bushwhack = class({})
function modifier_rpg_hoodwink_bushwhack:IsPurgable() return true end
function modifier_rpg_hoodwink_bushwhack:OnCreated()
	if IsServer() then self:GetParent():AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_stunned", { duration = self:GetDuration() }) end
end
function modifier_rpg_hoodwink_bushwhack:DeclareFunctions() return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE } end
function modifier_rpg_hoodwink_bushwhack:GetModifierIncomingDamage_Percentage()
	local p = self:GetParent()
	return Hoodwink:Has(self:GetCaster(), "e_easy_prey") and p:GetHealth() < p:GetMaxHealth() * 0.30 and 100 or 0
end
function modifier_rpg_hoodwink_bushwhack:OnDestroy()
	if IsServer() then
		if not self:GetParent():IsAlive() then Hoodwink:OnTrapDeath(self:GetCaster(), self:GetAbility(), self:GetParent())
		elseif Hoodwink:Has(self:GetCaster(), "e_blood_trail") then self:GetParent():AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_rpg_hoodwink_blood_trail", { duration = 5 }) end
	end
end

modifier_rpg_hoodwink_weakspot = class({})
function modifier_rpg_hoodwink_weakspot:IsPurgable() return true end
function modifier_rpg_hoodwink_weakspot:DeclareFunctions() return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS } end
function modifier_rpg_hoodwink_weakspot:GetModifierPhysicalArmorBonus() local p = self:GetParent(); return -p:GetPhysicalArmorBaseValue() * (Hoodwink:IsBoss(p) and 0.25 or 1) end

modifier_rpg_hoodwink_blood_trail = class({})
function modifier_rpg_hoodwink_blood_trail:IsHidden() return true end
function modifier_rpg_hoodwink_blood_trail:IsPurgable() return false end
function modifier_rpg_hoodwink_blood_trail:OnCreated() if IsServer() then self:OnIntervalThink(); self:StartIntervalThink(1) end end
function modifier_rpg_hoodwink_blood_trail:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_rpg_hoodwink_blood_trail:GetModifierMoveSpeedBonus_Percentage() return -50 end
function modifier_rpg_hoodwink_blood_trail:OnIntervalThink() ApplyDamage({ victim = self:GetParent(), attacker = self:GetCaster(), ability = self:GetAbility(), damage = 150, damage_type = DAMAGE_TYPE_PURE }) end

modifier_rpg_hoodwink_haste = class({})
function modifier_rpg_hoodwink_haste:IsPurgable() return true end
function modifier_rpg_hoodwink_haste:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_rpg_hoodwink_haste:GetModifierMoveSpeedBonus_Percentage() return 30 end

modifier_rpg_hoodwink_hunt = class({})
function modifier_rpg_hoodwink_hunt:IsPurgable() return false end
function modifier_rpg_hoodwink_hunt:DeclareFunctions() return { MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT, MODIFIER_PROPERTY_PREATTACK_LIFESTEAL } end
function modifier_rpg_hoodwink_hunt:GetModifierAttackSpeedBonus_Constant() return 120 end
function modifier_rpg_hoodwink_hunt:GetModifierPreAttack_LifeSteal() return 35 end

modifier_rpg_hoodwink_euphoria = class({})
function modifier_rpg_hoodwink_euphoria:IsPurgable() return true end
function modifier_rpg_hoodwink_euphoria:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT } end
function modifier_rpg_hoodwink_euphoria:GetModifierMoveSpeedBonus_Percentage() return 20 end
function modifier_rpg_hoodwink_euphoria:GetModifierAttackSpeedBonus_Constant() return 20 end

modifier_rpg_hoodwink_bleed = class({})
function modifier_rpg_hoodwink_bleed:IsPurgable() return true end
function modifier_rpg_hoodwink_bleed:OnCreated(kv) self.pct = tonumber(kv.pct) or 1; if IsServer() then self:OnIntervalThink(); self:StartIntervalThink(1) end end
function modifier_rpg_hoodwink_bleed:OnIntervalThink() ApplyDamage({ victim = self:GetParent(), attacker = self:GetCaster(), ability = self:GetAbility(), damage = self:GetParent():GetMaxHealth() * self.pct / 100, damage_type = DAMAGE_TYPE_MAGICAL }) end

modifier_rpg_hoodwink_acid_zone = class({})
function modifier_rpg_hoodwink_acid_zone:IsHidden() return true end
function modifier_rpg_hoodwink_acid_zone:IsPurgable() return false end
function modifier_rpg_hoodwink_acid_zone:OnCreated(kv)
	self.radius = tonumber(kv.radius) or 700
	if IsServer() then self.fx = ParticleManager:CreateParticle("particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf", PATTACH_WORLDORIGIN, nil); ParticleManager:SetParticleControl(self.fx, 0, self:GetParent():GetAbsOrigin()); ParticleManager:SetParticleControl(self.fx, 1, Vector(self.radius, 0, 0)); self:OnIntervalThink(); self:StartIntervalThink(1) end
end
function modifier_rpg_hoodwink_acid_zone:OnIntervalThink() for _, enemy in ipairs(Hoodwink:Enemies(self:GetCaster(), self:GetParent():GetAbsOrigin(), self.radius)) do ApplyDamage({ victim = enemy, attacker = self:GetCaster(), ability = self:GetAbility(), damage = 80, damage_type = DAMAGE_TYPE_MAGICAL }) end end
function modifier_rpg_hoodwink_acid_zone:OnDestroy() if IsServer() and self.fx then ParticleManager:DestroyParticle(self.fx, false); ParticleManager:ReleaseParticleIndex(self.fx) end end
