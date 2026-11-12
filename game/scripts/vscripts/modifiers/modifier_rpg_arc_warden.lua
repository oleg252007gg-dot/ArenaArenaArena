modifier_rpg_arc_flux = class({})
function modifier_rpg_arc_flux:IsPurgable() return true end
function modifier_rpg_arc_flux:OnCreated()
	if IsServer() then
		self.fx = ParticleManager:CreateParticle("particles/units/heroes/hero_arc_warden/arc_warden_flux_tgt.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
		self:OnIntervalThink()
		self:StartIntervalThink(1)
	end
end
function modifier_rpg_arc_flux:OnIntervalThink()
	local caster, target = self:GetCaster(), self:GetParent()
	if not caster or caster:IsNull() or not target:IsAlive() then return end
	local bonus = caster.rpg and caster.rpg.arc_bonus or {}
	local damage = self:GetAbility():GetSpecialValueFor("damage") + (bonus.flux_damage or 0)
	if caster.rpg and (caster.rpg.perk_count.e_flux_int or 0) > 0 then damage = damage + math.floor(caster:GetIntellect()/50)*200 end
	if caster.rpg and (caster.rpg.perk_count.e_flux_boss_pct or 0) > 0 and target.rpg_boss then damage = damage + target:GetMaxHealth()*0.05/6 end
	if target.rpg_boss and caster.rpg and (caster.rpg.perk_count.l_flux_boss_stun or 0) > 0 then target:AddNewModifier(caster,self:GetAbility(),"modifier_stunned",{duration=0.2}) end
	local dealt = ApplyDamage({victim=target,attacker=caster,ability=self:GetAbility(),damage=damage,damage_type=DAMAGE_TYPE_MAGICAL})
	if dealt and dealt > 0 and caster:IsAlive() then
		if caster.rpg and (caster.rpg.perk_count.e_flux_heal or 0) > 0 then caster:Heal(dealt*0.015,self:GetAbility()) end
		if caster.rpg and (caster.rpg.perk_count.l_flux_barrier or 0) > 0 then caster:AddNewModifier(caster,self:GetAbility(),"modifier_rpg_barrier",{duration=2,amount=dealt*0.6}) end
	end
	if caster.rpg and (caster.rpg.perk_count.l_flux_grave or 0) > 0 then target:AddNewModifier(caster,self:GetAbility(),"modifier_rpg_slow",{duration=1,slow=75}) end
	if caster.rpg and (caster.rpg.perk_count.e_flux_wraith_amp or 0) > 0 then target:AddNewModifier(caster,self:GetAbility(),"modifier_rpg_arc_wraith_mark",{duration=2}) end
end
function modifier_rpg_arc_flux:DeclareFunctions() return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE} end
function modifier_rpg_arc_flux:GetModifierMoveSpeedBonus_Percentage()
	local p,c=self:GetParent(),self:GetCaster()
	return p.rpg_boss and c and c.rpg and (c.rpg.perk_count.l_flux_boss_stun or 0)>0 and 0 or -35
end
function modifier_rpg_arc_flux:OnDestroy()
	if IsServer() and self.fx then
		ParticleManager:DestroyParticle(self.fx, false)
		ParticleManager:ReleaseParticleIndex(self.fx)
	end
end

modifier_rpg_arc_field = class({})
function modifier_rpg_arc_field:IsHidden() return true end
function modifier_rpg_arc_field:IsPurgable() return false end
function modifier_rpg_arc_field:IsAura() return true end
function modifier_rpg_arc_field:GetAuraRadius() return self.radius or 500 end
function modifier_rpg_arc_field:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_FRIENDLY end
function modifier_rpg_arc_field:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO end
function modifier_rpg_arc_field:GetModifierAura() return "modifier_rpg_arc_field_aura" end
function modifier_rpg_arc_field:GetAuraSearchFlags() return DOTA_UNIT_TARGET_FLAG_NONE end
function modifier_rpg_arc_field:OnCreated(kv)
	self.radius=tonumber(kv.radius) or 500
	if IsServer() then
		local fx=ParticleManager:CreateParticle("particles/units/heroes/hero_arc_warden/arc_warden_magnetic.vpcf",PATTACH_WORLDORIGIN,nil)
		ParticleManager:SetParticleControl(fx,0,self:GetParent():GetAbsOrigin()); ParticleManager:SetParticleControl(fx,1,Vector(self.radius,0,0)); self.fx=fx
		self:StartIntervalThink(0.2)
	end
end
function modifier_rpg_arc_field:OnIntervalThink()
	local c,p=self:GetCaster(),self:GetParent()
	for _,e in ipairs(FindUnitsInRadius(c:GetTeamNumber(),p:GetAbsOrigin(),nil,self.radius,DOTA_UNIT_TARGET_TEAM_ENEMY,DOTA_UNIT_TARGET_HERO+DOTA_UNIT_TARGET_BASIC,DOTA_UNIT_TARGET_FLAG_NONE,FIND_ANY_ORDER,false)) do
		e:AddNewModifier(c,self:GetAbility(),"modifier_rpg_arc_field_enemy",{duration=0.4})
	end
end
function modifier_rpg_arc_field:OnDestroy() if IsServer() and self.fx then ParticleManager:DestroyParticle(self.fx,false); ParticleManager:ReleaseParticleIndex(self.fx) end end

modifier_rpg_arc_field_aura = class({})
function modifier_rpg_arc_field_aura:IsPurgable() return false end
function modifier_rpg_arc_field_aura:OnCreated()
	if IsServer() then self:StartIntervalThink(0.2); self:OnIntervalThink() end
end
function modifier_rpg_arc_field_aura:DeclareFunctions() return {MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING,MODIFIER_PROPERTY_EVASION_CONSTANT,MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,MODIFIER_EVENT_ON_TAKEDAMAGE} end
function modifier_rpg_arc_field_aura:GetModifierAttackSpeedBonus_Constant() return self:GetCaster():HasModifier("modifier_item_aghanims_shard") and 30 or 0 end
function modifier_rpg_arc_field_aura:GetModifierIncomingDamage_Percentage(params)
	if params.damage_type ~= DAMAGE_TYPE_PHYSICAL then return 0 end
	local caster=self:GetCaster(); if not caster or not caster.rpg or (caster.rpg.perk_count.m_field_shield or 0)==0 then return 0 end
	local strength=caster:GetStrength(); local density=math.floor(strength/250)*10
	return -math.min(85,60+density)
end
function modifier_rpg_arc_field_aura:GetModifierEvasion_Constant()
	local c=self:GetCaster(); return c and c.rpg and (c.rpg.perk_count.m_field_shield or 0)==0 and 100 or 0
end
function modifier_rpg_arc_field_aura:GetModifierPhysicalArmorBonus()
	local c=self:GetCaster(); return c and c.rpg and (c.rpg.perk_count.e_field_armor or 0)>0 and 20 or 0
end
function modifier_rpg_arc_field_aura:GetModifierStatusResistanceStacking()
	local c=self:GetCaster(); return c and c.rpg and (c.rpg.perk_count.l_field_gravity or 0)>0 and 100 or 0
end
function modifier_rpg_arc_field_aura:GetModifierHealAmplify_PercentageTarget()
	local c=self:GetCaster(); return c==self:GetParent() and c.rpg and (c.rpg.perk_count.e_field_heal_amp or 0)>0 and 30 or 0
end
function modifier_rpg_arc_field_aura:CheckState()
	local c=self:GetCaster(); return c and c.rpg and (c.rpg.perk_count.l_field_gravity or 0)>0 and {[MODIFIER_STATE_DEBUFF_IMMUNE]=true,[MODIFIER_STATE_UNSLOWABLE]=true} or nil
end
function modifier_rpg_arc_field_aura:OnIntervalThink()
	local caster, parent=self:GetCaster(), self:GetParent()
	if not caster or not caster.rpg or (caster.rpg.perk_count.m_field_shield or 0)==0 then return end
	if not parent:IsHero() or parent:IsIllusion() then return end
	if not self.health_credit then self.health_credit=0 end
	-- Damage prevented is approximated from the field's 60% physical mitigation.
	if parent.rpg_field_last_health and parent:GetHealth()>parent.rpg_field_last_health then return end
	parent.rpg_field_last_health=parent:GetHealth()
end
function modifier_rpg_arc_field_aura:OnTakeDamage(params)
	local caster,parent=self:GetCaster(),self:GetParent()
	if params.unit~=parent or params.damage_type~=DAMAGE_TYPE_PHYSICAL or not caster or not caster.rpg or (caster.rpg.perk_count.m_field_shield or 0)==0 then return end
	local blocked=math.max(0,(params.original_damage or params.damage or 0)-(params.damage or 0))
	if blocked<=0 then return end
	caster.rpg_field_blocked=(caster.rpg_field_blocked or 0)+blocked
	local owner=caster.rpg_arc_owner or caster
	if owner:IsAlive() then
		owner:SetBaseMaxHealth(owner:GetBaseMaxHealth()+math.floor(blocked)); owner:SetMaxHealth(owner:GetBaseMaxHealth()); owner:SetHealth(math.min(owner:GetMaxHealth(),owner:GetHealth()+math.floor(blocked)))
		if (caster.rpg.perk_count.l_field_compensation or 0)>0 then owner:Heal(blocked*0.05,self:GetAbility()); owner:GiveMana(blocked*0.05) end
		if (caster.rpg.perk_count.l_field_reflect or 0)>0 then
			for _,e in ipairs(FindUnitsInRadius(owner:GetTeamNumber(),parent:GetAbsOrigin(),nil,600,DOTA_UNIT_TARGET_TEAM_ENEMY,DOTA_UNIT_TARGET_HERO+DOTA_UNIT_TARGET_BASIC,DOTA_UNIT_TARGET_FLAG_NONE,FIND_ANY_ORDER,false)) do ApplyDamage({victim=e,attacker=owner,ability=self:GetAbility(),damage=blocked*0.5,damage_type=DAMAGE_TYPE_PURE}) end
		end
	end
end
function modifier_rpg_arc_field_aura:GetEffectName() return "particles/units/heroes/hero_arc_warden/arc_warden_magnetic_buff.vpcf" end
function modifier_rpg_arc_field_aura:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
function modifier_rpg_arc_field_aura:OnDestroy()
	if not IsServer() then return end
	local c=self:GetCaster(); if c and c.rpg and (c.rpg.perk_count.e_field_echo or 0)>0 then self:GetParent():AddNewModifier(c,self:GetAbility(),"modifier_rpg_arc_field_echo",{duration=3}) end
end

modifier_rpg_arc_wraith = class({})
function modifier_rpg_arc_wraith:IsHidden() return true end
function modifier_rpg_arc_wraith:IsPurgable() return false end
function modifier_rpg_arc_wraith:OnCreated(kv)
	self.delay=tonumber(kv.delay) or 2
	self.elapsed=0
	self.lifetime=tonumber(kv.lifetime) or 12
	self.radius=tonumber(kv.radius) or 375
	if IsServer() then
		self.fx=ParticleManager:CreateParticle("particles/units/heroes/hero_arc_warden/arc_warden_wraith.vpcf",PATTACH_WORLDORIGIN,nil)
		ParticleManager:SetParticleControl(self.fx,0,self:GetParent():GetAbsOrigin())
		self:StartIntervalThink(0.2)
	end
end
function modifier_rpg_arc_wraith:OnIntervalThink()
	self.elapsed=self.elapsed+0.2
	self.delay=self.delay-0.2
	if self.delay>0 then return end
	local caster, thinker, ability=self:GetCaster(), self:GetParent(), self:GetAbility()
	if not caster or caster:IsNull() or not caster:IsAlive() or not ability or ability:IsNull() then self:Destroy(); return end
	local radius=self.radius
	local bonus=caster.rpg and caster.rpg.arc_bonus or {}
	local enemies=FindUnitsInRadius(caster:GetTeamNumber(),thinker:GetAbsOrigin(),nil,radius,DOTA_UNIT_TARGET_TEAM_ENEMY,DOTA_UNIT_TARGET_HERO+DOTA_UNIT_TARGET_BASIC,DOTA_UNIT_TARGET_FLAG_NONE,FIND_CLOSEST,false)
	local target=enemies[1]
	if target then
		local perks=caster.rpg and caster.rpg.perk_count or {}
		local hit={}
		local function apply_hit(victim)
			if not victim or not victim:IsAlive() or hit[victim:entindex()] then return end
			hit[victim:entindex()]=true
			local damage=ability:GetSpecialValueFor("damage")+(bonus.wraith_damage or 0)+caster:GetIntellect()*0.4
			if (perks.e_wraith_age or 0)>0 then damage=damage*(1+math.floor(GameRules:GetGameTime()/300)*0.1) end
			if victim:HasModifier("modifier_rpg_arc_wraith_mark") then damage=damage*1.2 end
			local dealt=ApplyDamage({victim=victim,attacker=caster,ability=ability,damage=damage,damage_type=DAMAGE_TYPE_MAGICAL})
			victim:AddNewModifier(caster,ability,"modifier_rpg_slow",{duration=ability:GetSpecialValueFor("slow_duration"),slow=ability:GetSpecialValueFor("movement_slow")})
			if (perks.e_wraith_int or 0)>0 then ApplyDamage({victim=victim,attacker=caster,ability=ability,damage=caster:GetIntellect()*0.4,damage_type=DAMAGE_TYPE_MAGICAL}) end
			if (perks.e_wraith_health or 0)>0 then caster:Heal(caster:GetMaxHealth()*0.02,ability) end
			if (perks.e_wraith_mana or 0)>0 and RandomFloat(0,1)<0.15 then caster:GiveMana(math.min(dealt or 0,caster:GetMaxMana()-caster:GetMana())) end
			if (perks.l_wraith_grave or 0)>0 then victim:AddNewModifier(caster,ability,"modifier_rpg_slow",{duration=6,slow=75}); victim:AddNewModifier(caster,ability,"modifier_rooted",{duration=2}) end
			if (perks.l_wraith_ghost or 0)>0 then victim:AddNewModifier(caster,ability,"modifier_rpg_arc_wraith_burn",{duration=3,damage=damage*0.5+caster:GetIntellect()}) end
			if (perks.e_wraith_inferno or 0)>0 then victim:AddNewModifier(caster,ability,"modifier_rpg_arc_wraith_burn",{duration=5,pct=3}) end
			local impact=ParticleManager:CreateParticle("particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj_hit.vpcf",PATTACH_ABSORIGIN_FOLLOW,victim)
			ParticleManager:ReleaseParticleIndex(impact)
			EmitSoundOn("Hero_ArcWarden.SparkWraith.Damage",victim)
		end
		apply_hit(target)
		if (perks.l_wraith_echo or 0)>0 then
			for _=1,2 do
				local nexts=FindUnitsInRadius(caster:GetTeamNumber(),target:GetAbsOrigin(),nil,radius,DOTA_UNIT_TARGET_TEAM_ENEMY,DOTA_UNIT_TARGET_HERO+DOTA_UNIT_TARGET_BASIC,DOTA_UNIT_TARGET_FLAG_NONE,FIND_CLOSEST,false)
				local next_target=nil
				for _,enemy in ipairs(nexts) do if enemy:IsAlive() and not hit[enemy:entindex()] then next_target=enemy; break end end
				if next_target then apply_hit(next_target) end
			end
		end
		self:Destroy()
	elseif self.elapsed>=self.lifetime then
		self:Destroy()
	end
end
function modifier_rpg_arc_wraith:OnDestroy() if IsServer() and self.fx then ParticleManager:DestroyParticle(self.fx,false); ParticleManager:ReleaseParticleIndex(self.fx) end end

modifier_rpg_arc_wraith_mark = class({})
function modifier_rpg_arc_wraith_mark:IsHidden() return true end
function modifier_rpg_arc_wraith_mark:IsPurgable() return false end

modifier_rpg_arc_field_enemy = class({})
function modifier_rpg_arc_field_enemy:IsDebuff() return true end
function modifier_rpg_arc_field_enemy:IsPurgable() return false end
function modifier_rpg_arc_field_enemy:OnCreated() local c=self:GetCaster(); if IsServer() and c and c.rpg and (c.rpg.perk_count.e_field_mana or 0)>0 then c:GiveMana(c:GetMaxMana()*0.02) end end
function modifier_rpg_arc_field_enemy:DeclareFunctions() return {MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE} end
function modifier_rpg_arc_field_enemy:GetModifierPhysicalArmorBonus() local c=self:GetCaster(); return c and c.rpg and (c.rpg.perk_count.e_field_guests or 0)>0 and not self:GetParent().rpg_boss and -self:GetParent():GetPhysicalArmorBaseValue()*0.5 or 0 end
function modifier_rpg_arc_field_enemy:GetModifierMagicalResistanceBonus() local c=self:GetCaster(); return c and c.rpg and (c.rpg.perk_count.e_field_guests or 0)>0 and not self:GetParent().rpg_boss and -50 or 0 end
function modifier_rpg_arc_field_enemy:GetModifierMoveSpeedBonus_Percentage() local c=self:GetCaster(); return c and c.rpg and (c.rpg.perk_count.e_field_slow or 0)>0 and -40 or 0 end
function modifier_rpg_arc_field_enemy:GetModifierDamageOutgoing_Percentage() local c=self:GetCaster(); return c and c.rpg and (c.rpg.perk_count.e_field_guests or 0)>0 and not self:GetParent().rpg_boss and -50 or 0 end

modifier_rpg_arc_field_echo = class({})
function modifier_rpg_arc_field_echo:IsPurgable() return false end
function modifier_rpg_arc_field_echo:DeclareFunctions() return {MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS} end
function modifier_rpg_arc_field_echo:GetModifierPhysicalArmorBonus() return 10 end

modifier_rpg_arc_wraith_burn = class({})
function modifier_rpg_arc_wraith_burn:IsPurgable() return true end
function modifier_rpg_arc_wraith_burn:OnCreated(kv) self.damage=tonumber(kv.damage) or 0; self.pct=tonumber(kv.pct) or 0; if IsServer() then self:OnIntervalThink(); self:StartIntervalThink(1) end end
function modifier_rpg_arc_wraith_burn:DeclareFunctions() return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE} end
function modifier_rpg_arc_wraith_burn:GetModifierMoveSpeedBonus_Percentage() return self.pct>0 and -30 or 0 end
function modifier_rpg_arc_wraith_burn:OnIntervalThink() local p=self:GetParent(); local dmg=self.pct>0 and p:GetMaxHealth()*self.pct/100 or self.damage/3; ApplyDamage({victim=p,attacker=self:GetCaster(),ability=self:GetAbility(),damage=dmg,damage_type=DAMAGE_TYPE_MAGICAL}) end

modifier_rpg_arc_tempest = class({})
function modifier_rpg_arc_tempest:IsHidden() return true end
function modifier_rpg_arc_tempest:IsPurgable() return false end
function modifier_rpg_arc_tempest:OnDestroy()
	if not IsServer() then return end
	local clone = self:GetParent()
	if clone and not clone:IsNull() and clone.rpg_is_tempest_double and not clone.rpg_tempest_permanent and clone:IsAlive() then
		clone:ForceKill(false)
	end
end
function modifier_rpg_arc_tempest:DeclareFunctions() return {MODIFIER_PROPERTY_MIN_HEALTH,MODIFIER_EVENT_ON_TAKEDAMAGE,MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,MODIFIER_PROPERTY_STATS_AGILITY_BONUS,MODIFIER_PROPERTY_STATS_INTELLECT_BONUS} end
local function extra_backpack_attributes(hero, key)
	if not hero or not hero.rpg_arc_owner then return 0 end
	local owner=hero.rpg_arc_owner
	if not owner.rpg or (owner.rpg.perk_count.l_tempest_autonomy or 0)==0 then return 0 end
	local total=0
	for slot=0,8 do
		local item=hero:GetItemInSlot(slot)
		if item then
			local ok, value=pcall(function() return item:GetSpecialValueFor("bonus_"..key)+item:GetSpecialValueFor("bonus_all_stats") end)
			if ok then total=total+(value or 0) end
		end
	end
	return total*0.5
end
function modifier_rpg_arc_tempest:GetModifierBonusStats_Strength() return extra_backpack_attributes(self:GetParent(),"strength") end
function modifier_rpg_arc_tempest:GetModifierBonusStats_Agility() return extra_backpack_attributes(self:GetParent(),"agility") end
function modifier_rpg_arc_tempest:GetModifierBonusStats_Intellect() return extra_backpack_attributes(self:GetParent(),"intellect") end
function modifier_rpg_arc_tempest:GetMinHealth()
	local c=self:GetParent().rpg_arc_owner
	return c and c.rpg and (c.rpg.perk_count.l_tempest_ghost or 0)>0 and not self:GetParent().rpg_arc_ghosting and 1 or 0
end
function modifier_rpg_arc_tempest:OnTakeDamage(params)
	local clone=self:GetParent(); local c=clone.rpg_arc_owner
	if params.unit==clone and c and c.rpg and (c.rpg.perk_count.l_tempest_ghost or 0)>0 and clone:GetHealth()<=1 and not clone.rpg_arc_ghosting then
		clone.rpg_arc_ghosting=true; clone:AddNewModifier(c,self:GetAbility(),"modifier_rpg_arc_tempest_ghost",{duration=5})
	end
end
function modifier_rpg_arc_tempest:OnCreated()
	if IsServer() then
		local c=self:GetCaster(); self:GetParent().rpg_arc_owner=c; self:StartIntervalThink(1)
		if c and c.rpg and (c.rpg.perk_count.e_tempest_speed or 0)>0 then self:GetParent():SetBaseMoveSpeed(550) end
		if c and c.rpg and (c.rpg.perk_count.e_tempest_intro or 0)>0 then
			local damage=c:GetAgility()*0.5
			local fx=ParticleManager:CreateParticle("particles/units/heroes/hero_arc_warden/arc_warden_wraith_cast.vpcf",PATTACH_WORLDORIGIN,nil); ParticleManager:SetParticleControl(fx,0,self:GetParent():GetAbsOrigin()); ParticleManager:ReleaseParticleIndex(fx)
			for _,e in ipairs(FindUnitsInRadius(c:GetTeamNumber(),self:GetParent():GetAbsOrigin(),nil,500,DOTA_UNIT_TARGET_TEAM_ENEMY,DOTA_UNIT_TARGET_HERO+DOTA_UNIT_TARGET_BASIC,DOTA_UNIT_TARGET_FLAG_NONE,FIND_ANY_ORDER,false)) do ApplyDamage({victim=e,attacker=c,damage=damage,damage_type=DAMAGE_TYPE_MAGICAL}) end
		end
	end
end
function modifier_rpg_arc_tempest:OnIntervalThink()
	local clone,c=self:GetParent(),self:GetParent().rpg_arc_owner
	if c and c.rpg and clone.rpg then
		clone.rpg.perk_count=c.rpg.perk_count; clone.rpg.arc_bonus=c.rpg.arc_bonus; clone.rpg.perk_stats=c.rpg.perk_stats
		local mod=clone:FindModifierByName("modifier_rpg_stats"); if mod then mod:SetStats(c.rpg.perk_stats or {}); clone:CalculateStatBonus(true) end
	end
end

modifier_rpg_arc_master = class({})
function modifier_rpg_arc_master:IsHidden() return true end
function modifier_rpg_arc_master:IsPurgable() return false end
function modifier_rpg_arc_master:OnCreated()
	if IsServer() then self.seconds=0; self:StartIntervalThink(1) end
end
function modifier_rpg_arc_master:DeclareFunctions() return {MODIFIER_EVENT_ON_ATTACK_LANDED,MODIFIER_EVENT_ON_ATTACK_FAIL,MODIFIER_EVENT_ON_DEATH,MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT} end
function modifier_rpg_arc_master:GetModifierAttackSpeedBonus_Constant() return self:GetStackCount() end
function modifier_rpg_arc_master:GetModifierMoveSpeedBonus_Constant() local h=self:GetParent(); return h.rpg and (h.rpg.perk_count.e_wraith_speed or 0)>0 and 50 or 0 end
function modifier_rpg_arc_master:OnIntervalThink()
	local h=self:GetParent(); if h.rpg_arc_owner then return end; self.seconds=self.seconds+1
	if h.rpg and (h.rpg.perk_count.l_wraith_axiom or 0)>0 and self.seconds%60==0 then h:ModifyIntellect(20); if h.rpg_tempest_clone and not h.rpg_tempest_clone:IsNull() then h.rpg_tempest_clone:ModifyIntellect(20) end end
	if h.rpg and (h.rpg.perk_count.e_tempest_shard or 0)>0 then
		self.shard_seconds=(self.shard_seconds or 0)+1
		if self.shard_seconds>=60 then self.shard_seconds=0; h:ModifyStrength(5); h:ModifyAgility(5); h:ModifyIntellect(5); if h.rpg_tempest_clone and not h.rpg_tempest_clone:IsNull() then h.rpg_tempest_clone:ModifyStrength(10); h.rpg_tempest_clone:ModifyAgility(10); h.rpg_tempest_clone:ModifyIntellect(10) end end
	end
	if h.rpg and (h.rpg.perk_count.e_tempest_runes or 0)>0 and self.seconds%120==0 and h.rpg_tempest_clone and not h.rpg_tempest_clone:IsNull() and h.rpg_tempest_clone:IsAlive() then h.rpg_tempest_clone:AddNewModifier(h,nil,"modifier_rpg_arc_tempest_runes",{duration=40}) end
end
function modifier_rpg_arc_master:OnAttackLanded(params)
	local source=self:GetParent(); local h=source.rpg_arc_owner or source; local attacker=params.attacker; if attacker~=source then return end
	local c=h; local victim=params.target; if not victim or victim:IsNull() then return end
	local perks=c.rpg and c.rpg.perk_count or {}
	if attacker==h.rpg_tempest_clone and victim:GetTeamNumber()==h:GetTeamNumber() and (perks.e_tempest_friendly or 0)>0 then
		local buff=victim:FindModifierByName("modifier_rpg_arc_friendly_buff")
		if buff then buff:SetStackCount(math.min(10,buff:GetStackCount()+1)); buff:SetDuration(10,true)
		else victim:AddNewModifier(h,self:GetAbility(),"modifier_rpg_arc_friendly_buff",{duration=10}) end
		return
	end
	if (perks.l_tempest_thunder or 0)>0 then
		for _,e in ipairs(FindUnitsInRadius(c:GetTeamNumber(),victim:GetAbsOrigin(),nil,300,DOTA_UNIT_TARGET_TEAM_ENEMY,DOTA_UNIT_TARGET_HERO+DOTA_UNIT_TARGET_BASIC,DOTA_UNIT_TARGET_FLAG_NONE,FIND_ANY_ORDER,false)) do if e~=victim then ApplyDamage({victim=e,attacker=attacker,damage=params.damage,damage_type=DAMAGE_TYPE_PHYSICAL}) end end
		if RandomFloat(0,1)<0.45 then local dmg=c:GetAgility()*1.5; ApplyDamage({victim=victim,attacker=attacker,damage=dmg,damage_type=DAMAGE_TYPE_MAGICAL}); local fx=ParticleManager:CreateParticle("particles/units/heroes/hero_zuus/zuus_lightning_bolt_start.vpcf",PATTACH_WORLDORIGIN,nil); ParticleManager:SetParticleControl(fx,0,victim:GetAbsOrigin()); ParticleManager:ReleaseParticleIndex(fx) end
		if RandomFloat(0,1)<0.15 then victim:AddNewModifier(attacker,nil,"modifier_stunned",{duration=0.5}) end
	end
	if (perks.l_tempest_multishot or 0)>0 then
		local enemies=FindUnitsInRadius(c:GetTeamNumber(),victim:GetAbsOrigin(),nil,1200,DOTA_UNIT_TARGET_TEAM_ENEMY,DOTA_UNIT_TARGET_HERO+DOTA_UNIT_TARGET_BASIC,DOTA_UNIT_TARGET_FLAG_NONE,FIND_CLOSEST,false)
		local count=0; for _,e in ipairs(enemies) do if e~=victim and count<2 then ApplyDamage({victim=e,attacker=attacker,damage=params.damage,damage_type=DAMAGE_TYPE_PHYSICAL}); count=count+1 end end
	end
	if (perks.e_tempest_heal or 0)>0 and attacker==h and victim==h.rpg_tempest_clone then victim:Heal(victim:GetMaxHealth()*0.03,nil) end
	if (perks.e_flux_mana or 0)>0 and victim:HasModifier("modifier_rpg_arc_flux") then h:GiveMana(h:GetMaxMana()*0.02) end
end
function modifier_rpg_arc_master:OnAttackFail(params)
	local clone=self:GetParent(); local owner=clone.rpg_arc_owner
	if params.attacker~=clone or not owner or not owner.rpg or (owner.rpg.perk_count.l_tempest_multishot or 0)==0 then return end
	local target=params.target
	if target and not target:IsNull() and target:IsAlive() then ApplyDamage({victim=target,attacker=clone,damage=clone:GetAverageTrueAttackDamage(target),damage_type=DAMAGE_TYPE_PHYSICAL}) end
end

modifier_rpg_arc_friendly_buff = class({})
function modifier_rpg_arc_friendly_buff:IsPurgable() return true end
function modifier_rpg_arc_friendly_buff:OnCreated() if IsServer() then self:SetStackCount(1) end end
function modifier_rpg_arc_friendly_buff:OnRefresh() if IsServer() then self:SetStackCount(math.min(10,self:GetStackCount()+1)) end end
function modifier_rpg_arc_friendly_buff:DeclareFunctions() return {MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT} end
function modifier_rpg_arc_friendly_buff:GetModifierPreAttack_BonusDamage() return self:GetStackCount()*25 end
function modifier_rpg_arc_friendly_buff:GetModifierAttackSpeedBonus_Constant() return self:GetStackCount()*25 end
function modifier_rpg_arc_master:OnDeath(params)
	local source=self:GetParent(); if source.rpg_arc_owner then return end
	local h=source; local killed=params.unit
	if killed and killed:HasModifier("modifier_rpg_arc_flux") and h.rpg and (h.rpg.perk_count.l_flux_jump or 0)>0 then
		local enemies=FindUnitsInRadius(h:GetTeamNumber(),killed:GetAbsOrigin(),nil,1200,DOTA_UNIT_TARGET_TEAM_ENEMY,DOTA_UNIT_TARGET_HERO+DOTA_UNIT_TARGET_BASIC,DOTA_UNIT_TARGET_FLAG_NONE,FIND_CLOSEST,false)
		local n=0; for _,e in ipairs(enemies) do if e~=killed and e:IsAlive() and n<3 then e:AddNewModifier(h,h:FindAbilityByName("rpg_arc_warden_flux"),"modifier_rpg_arc_flux",{duration=6}); n=n+1 end end
	end
	if (params.attacker==h or params.attacker==h.rpg_tempest_clone) and killed and killed.rpg_boss and h.rpg and (h.rpg.perk_count.e_tempest_boss or 0)>0 then
		local scale=params.attacker==h.rpg_tempest_clone and 1.5 or 1
		local winner=params.attacker
		winner:SetBaseDamageMin(winner:GetBaseDamageMin()+50*scale); winner:SetBaseDamageMax(winner:GetBaseDamageMax()+50*scale); winner:SetBaseMaxHealth(winner:GetBaseMaxHealth()+500*scale); winner:SetMaxHealth(winner:GetBaseMaxHealth()); winner:SetHealth(winner:GetHealth()+500*scale)
		local attack_mod=winner:FindModifierByName("modifier_rpg_arc_master"); if attack_mod then winner:SetModifierStackCount("modifier_rpg_arc_master",winner,attack_mod:GetStackCount()+math.floor(25*scale)) end
	end
end

modifier_rpg_arc_tempest_runes = class({})
function modifier_rpg_arc_tempest_runes:IsPurgable() return false end
function modifier_rpg_arc_tempest_runes:DeclareFunctions() return {MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE} end
function modifier_rpg_arc_tempest_runes:GetModifierIncomingDamage_Percentage() return -50 end
function modifier_rpg_arc_tempest_runes:GetModifierMoveSpeedBonus_Constant() return 550 end
function modifier_rpg_arc_tempest_runes:GetModifierConstantHealthRegen() return 40 end
function modifier_rpg_arc_tempest_runes:GetModifierConstantManaRegen() return 40 end
function modifier_rpg_arc_tempest_runes:GetModifierPercentageCooldown() return 40 end

modifier_rpg_arc_tempest_ghost = class({})
function modifier_rpg_arc_tempest_ghost:IsPurgable() return false end
function modifier_rpg_arc_tempest_ghost:CheckState() return {[MODIFIER_STATE_INVULNERABLE]=true,[MODIFIER_STATE_NO_UNIT_COLLISION]=true,[MODIFIER_STATE_DISARMED]=true} end
function modifier_rpg_arc_tempest_ghost:OnDestroy() if IsServer() and self:GetParent():IsAlive() then self:GetParent():ForceKill(false) end end
