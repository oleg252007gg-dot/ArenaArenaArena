modifier_rpg_sven = class({})
function modifier_rpg_sven:IsHidden() return true end
function modifier_rpg_sven:IsPurgable() return false end
function modifier_rpg_sven:RemoveOnDeath() return false end
function modifier_rpg_sven:DeclareFunctions() return {MODIFIER_EVENT_ON_ATTACK_LANDED} end
function modifier_rpg_sven:OnAttackLanded(p)
	if not IsServer() or p.attacker ~= self:GetParent() or not p.target or not p.target:IsAlive() then return end
	local hero,target=self:GetParent(),p.target
	if target:GetTeamNumber()==hero:GetTeamNumber() then return end
	if Sven:Has(hero,"m_sven_strength") and hero:HasModifier("modifier_rpg_sven_gods_strength") then hero:Heal(p.damage*0.2,hero) end
	if Sven:Has(hero,"l_sven_strength_crit") and hero:HasModifier("modifier_rpg_sven_gods_strength") and RandomFloat(0,100)<25 then
		ApplyDamage({victim=target,attacker=hero,ability=hero:FindAbilityByName("rpg_sven_gods_strength"),damage=p.damage,damage_type=DAMAGE_TYPE_PHYSICAL,damage_flags=DOTA_DAMAGE_FLAG_IGNORES_PHYSICAL_ARMOR})
	end
end

modifier_rpg_sven_cleave = class({})
function modifier_rpg_sven_cleave:IsHidden() return true end
function modifier_rpg_sven_cleave:IsPurgable() return false end
function modifier_rpg_sven_cleave:DeclareFunctions() return {MODIFIER_EVENT_ON_ATTACK_LANDED} end
function modifier_rpg_sven_cleave:OnAttackLanded(p)
	if not IsServer() then return end
	local hero=self:GetParent(); local target=p.target
	if p.attacker~=hero or not target or not target:IsAlive() or target:GetTeamNumber()==hero:GetTeamNumber() or target:IsBuilding() or p.no_attack_cooldown then return end
	local ability=self:GetAbility(); if not ability then return end
	local radius=ability:GetSpecialValueFor("radius")+(Sven:Has(hero,"l_sven_cleave_range") and 200 or 0)+Sven:Bonus(hero,"cleave_radius")
	local pct=ability:GetSpecialValueFor("cleave_percent")+Sven:Bonus(hero,"cleave_damage")+(Sven:Has(hero,"e_sven_cleave_damage") and 25 or 0)
	local enemies=FindUnitsInRadius(hero:GetTeamNumber(),target:GetAbsOrigin(),nil,radius,DOTA_UNIT_TARGET_TEAM_ENEMY,DOTA_UNIT_TARGET_HERO+DOTA_UNIT_TARGET_BASIC,DOTA_UNIT_TARGET_FLAG_NONE,FIND_ANY_ORDER,false)
	for _,enemy in ipairs(enemies) do
		if enemy~=target and enemy:IsAlive() then
			local fx=ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_spell_great_cleave.vpcf",PATTACH_ABSORIGIN_FOLLOW,enemy)
			ParticleManager:ReleaseParticleIndex(fx)
			local amount=p.damage*pct/100
			local flags=DOTA_DAMAGE_FLAG_NONE
			if Sven:Has(hero,"m_sven_cleave") then amount=p.damage; flags=DOTA_DAMAGE_FLAG_IGNORES_PHYSICAL_ARMOR end
			local dealt=ApplyDamage({victim=enemy,attacker=hero,ability=ability,damage=amount,damage_type=DAMAGE_TYPE_PHYSICAL,damage_flags=flags})
			if Sven:Has(hero,"e_sven_cleave_lifesteal") then hero:Heal((dealt or 0)*0.1,hero) end
			if Sven:Has(hero,"e_sven_cleave_slow") then enemy:AddNewModifier(hero,ability,"modifier_rpg_slow",{duration=2,slow=30}) end
			if Sven:Has(hero,"l_sven_cleave_bleed") then enemy:AddNewModifier(hero,ability,"modifier_rpg_sven_bleed",{duration=4,damage=hero:GetAverageTrueAttackDamage(hero)*0.1}) end
		end
	end
end

modifier_rpg_sven_warcry = class({})
function modifier_rpg_sven_warcry:IsPurgable() return true end
function modifier_rpg_sven_warcry:GetEffectName() return "particles/units/heroes/hero_sven/sven_spell_warcry.vpcf" end
function modifier_rpg_sven_warcry:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
function modifier_rpg_sven_warcry:OnCreated()
	self.armor=self:GetAbility():GetSpecialValueFor("armor")+Sven:Bonus(self:GetCaster(),"warcry_armor")+(Sven:Has(self:GetCaster(),"e_sven_warcry_armor") and 12 or 0)
	self.speed=self:GetAbility():GetSpecialValueFor("move_speed")+(Sven:Has(self:GetCaster(),"e_sven_warcry_speed") and 15 or 0)
	self.barrier=self:GetParent():GetMaxHealth()*0.15
	if Sven:Has(self:GetCaster(),"m_sven_warcry") or self:GetCaster():HasModifier("modifier_item_aghanims_shard") then self:SetStackCount(math.floor(self.barrier)) end
end
function modifier_rpg_sven_warcry:DeclareFunctions() return {MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING} end
function modifier_rpg_sven_warcry:GetModifierPhysicalArmorBonus() return self.armor or 0 end
function modifier_rpg_sven_warcry:GetModifierMoveSpeedBonus_Percentage() return self.speed or 0 end
function modifier_rpg_sven_warcry:GetModifierStatusResistanceStacking() return Sven:Has(self:GetCaster(),"l_sven_warcry_resist") and 20 or 0 end
function modifier_rpg_sven_warcry:GetModifierIncomingDamageConstant(p)
	if IsServer() and (Sven:Has(self:GetCaster(),"m_sven_warcry") or self:GetCaster():HasModifier("modifier_item_aghanims_shard")) then
		local blocked=math.min(self:GetStackCount(),p.damage)
		self:SetStackCount(self:GetStackCount()-blocked)
		return blocked
	end
	return not IsServer() and self:GetStackCount() or 0
end

modifier_rpg_sven_gods_strength = class({})
function modifier_rpg_sven_gods_strength:IsPurgable() return true end
function modifier_rpg_sven_gods_strength:GetEffectName() return "particles/units/heroes/hero_sven/sven_spell_gods_strength.vpcf" end
function modifier_rpg_sven_gods_strength:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
function modifier_rpg_sven_gods_strength:DeclareFunctions() return {MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT} end
function modifier_rpg_sven_gods_strength:GetModifierPreAttack_BonusDamage()
	local caster=self:GetCaster(); local pct=self:GetAbility():GetSpecialValueFor("damage_pct")+Sven:Bonus(caster,"strength_damage")+(Sven:Has(caster,"e_sven_strength_damage") and 30 or 0)
	return caster:GetBaseDamageMin()*pct/100
end
function modifier_rpg_sven_gods_strength:GetModifierAttackSpeedBonus_Constant() return Sven:Has(self:GetCaster(),"l_sven_strength_haste") and 80 or 0 end

modifier_rpg_sven_bleed = class({})
function modifier_rpg_sven_bleed:IsHidden() return false end
function modifier_rpg_sven_bleed:IsDebuff() return true end
function modifier_rpg_sven_bleed:IsPurgable() return true end
function modifier_rpg_sven_bleed:GetEffectName() return "particles/units/heroes/hero_bloodseeker/bloodseeker_rupture.vpcf" end
function modifier_rpg_sven_bleed:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
function modifier_rpg_sven_bleed:OnCreated(kv)
	self.damage=tonumber(kv.damage) or 0
	if IsServer() then self:StartIntervalThink(1) end
end
function modifier_rpg_sven_bleed:OnIntervalThink()
	local parent,caster=self:GetParent(),self:GetCaster()
	if not parent:IsAlive() or not caster or caster:IsNull() then self:Destroy(); return end
	ApplyDamage({victim=parent,attacker=caster,ability=self:GetAbility(),damage=self.damage,damage_type=DAMAGE_TYPE_MAGICAL})
end
