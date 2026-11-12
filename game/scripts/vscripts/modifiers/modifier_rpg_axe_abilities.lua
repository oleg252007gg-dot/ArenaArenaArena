-- Модификаторы способностей Axe

-- ===================== Counter Helix (интринсик) =====================
modifier_rpg_axe_helix = class({})
function modifier_rpg_axe_helix:IsHidden() return true end
function modifier_rpg_axe_helix:IsPurgable() return false end
function modifier_rpg_axe_helix:RemoveOnDeath() return false end
function modifier_rpg_axe_helix:DeclareFunctions()
	return { MODIFIER_EVENT_ON_ATTACK_LANDED, MODIFIER_EVENT_ON_TAKEDAMAGE }
end

function modifier_rpg_axe_helix:Try()
	local ability, parent = self:GetAbility(), self:GetParent()
	if not ability or ability:GetLevel() < 1 or not parent:IsAlive() or parent:PassivesDisabled() then return end
	local now = GameRules:GetGameTime()
	if not Axe:Has(parent, "m_whirlwind") and (self.next or 0) > now then return end
	if RandomFloat(0, 100) >= Axe:HelixChance(parent, ability) then return end
	if not Axe:Has(parent, "m_whirlwind") then self.next = now + ability:GetSpecialValueFor("cooldown") end
	Axe:Helix(parent, ability)
end

-- Обычная атака по Аксу
function modifier_rpg_axe_helix:OnAttackLanded(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if Axe:Has(parent, "m_whirlwind") then
		if p.attacker == parent and p.target and p.target:GetTeamNumber() ~= parent:GetTeamNumber() then
			if Axe:Has(parent, "e_i_am_not_finished") then
				local ramp = parent:FindModifierByName("modifier_rpg_axe_attack_ramp")
				if ramp then ramp:AddHit(p.target) else
					parent:AddNewModifier(parent, self:GetAbility(), "modifier_rpg_axe_attack_ramp", { duration = 2, target = p.target:entindex() })
				end
			end
			self:Try()
		end
	elseif p.target == parent and p.attacker and p.attacker:GetTeamNumber() ~= parent:GetTeamNumber() then
		self:Try()
	end
end

modifier_rpg_helix_shred = class({})
function modifier_rpg_helix_shred:IsDebuff() return true end
function modifier_rpg_helix_shred:IsPurgable() return true end
function modifier_rpg_helix_shred:OnCreated() if IsServer() then self:SetStackCount(1) end end
function modifier_rpg_helix_shred:DeclareFunctions() return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS } end
function modifier_rpg_helix_shred:GetModifierPhysicalArmorBonus() return -2 * self:GetStackCount() end

modifier_rpg_axe_attack_ramp = class({})
function modifier_rpg_axe_attack_ramp:IsHidden() return false end
function modifier_rpg_axe_attack_ramp:IsPurgable() return false end
function modifier_rpg_axe_attack_ramp:OnCreated(kv)
	if IsServer() then self.target_idx = kv.target; self:SetStackCount(1) end
end
function modifier_rpg_axe_attack_ramp:AddHit(target)
	if not IsServer() then return end
	local idx = target:entindex()
	if self.target_idx ~= idx then self.target_idx = idx; self:SetStackCount(1)
	else self:SetStackCount(math.min(30, self:GetStackCount() + 1)) end
	self:SetDuration(2, true)
end
function modifier_rpg_axe_attack_ramp:DeclareFunctions() return { MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT } end
function modifier_rpg_axe_attack_ramp:GetModifierAttackSpeedBonus_Constant() return self:GetStackCount() * 5 end

-- Aghanim's Shard: срабатывает и от магического урона
function modifier_rpg_axe_helix:OnTakeDamage(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if Axe:Has(parent, "m_whirlwind") or p.unit ~= parent or p.damage_type ~= DAMAGE_TYPE_MAGICAL then return end
	if not p.attacker or p.attacker == parent or p.attacker:GetTeamNumber() == parent:GetTeamNumber() then return end
	if not Axe:HasShard(parent) then return end
	self:Try()
end

-- ===================== Culling Blade: заряды (талант 25 левый) =====================
modifier_rpg_cull_charges = class({})
function modifier_rpg_cull_charges:IsHidden() return false end
function modifier_rpg_cull_charges:IsPurgable() return false end
function modifier_rpg_cull_charges:RemoveOnDeath() return false end
function modifier_rpg_cull_charges:GetTexture() return "axe_culling_blade" end

function modifier_rpg_cull_charges:OnCreated()
	if not IsServer() then return end
	self.max = 1
	self.charges = 1
	self.restore_at = nil
	self:StartIntervalThink(0.25)
end

function modifier_rpg_cull_charges:OnIntervalThink()
	local ability, parent = self:GetAbility(), self:GetParent()
	if not ability then return end
	local now = GameRules:GetGameTime()
	local max = 1 + (Axe:Talent(parent, "40_cull_charges") and 2 or 0) + (Axe:Talent(parent, "45_cull_charges") and 2 or 0)
	if Axe:Has(parent, "l_sturdy_blade") then max = math.max(max, 3) end

	if max ~= self.max then
		if max > self.max then
			-- талант только что выбран: если способность на перезарядке, она восстановится как заряд
			local ready = ability:IsCooldownReady()
			self.charges = ready and max or 1
			if not ready then self.restore_at = now + ability:GetCooldownTimeRemaining() end
		else
			self.charges = ability:IsCooldownReady() and 1 or 0
			self.restore_at = nil
		end
		self.max = max
	end

	if self.max > 1 then
		if self.restore_at and now >= self.restore_at then
			self.charges = math.min(self.max, self.charges + 1)
			self.restore_at = (self.charges < self.max) and (now + ability:GetCooldown(math.max(0, ability:GetLevel() - 1))) or nil
		end
		if self.charges > 0 and not ability:IsCooldownReady() then ability:EndCooldown() end
		self:SetStackCount(self.charges)
	else
		self:SetStackCount(0)
	end
end

-- Вызывается в начале каста ульты (перезарядка уже запущена движком)
function modifier_rpg_cull_charges:Consume()
	if self.max <= 1 then return end
	local ability = self:GetAbility()
	self.charges = math.max(0, self.charges - 1)
	if not self.restore_at then
		self.restore_at = GameRules:GetGameTime() + ability:GetCooldownTimeRemaining()
	end
	if self.charges > 0 then ability:EndCooldown() end
	self:SetStackCount(self.charges)
end

function modifier_rpg_cull_charges:Reduce(seconds)
	if self.restore_at then self.restore_at = self.restore_at - seconds end
end

-- ===================== Berserker's Call: насмешка =====================
modifier_rpg_call_taunt = class({})
function modifier_rpg_call_taunt:IsHidden() return false end
function modifier_rpg_call_taunt:IsDebuff() return true end
function modifier_rpg_call_taunt:IsPurgable() return false end
function modifier_rpg_call_taunt:GetTexture() return "axe_berserkers_call" end
function modifier_rpg_call_taunt:GetStatusEffectName() return "particles/status_fx/status_effect_beserkers_call.vpcf" end
function modifier_rpg_call_taunt:StatusEffectPriority() return 10 end
function modifier_rpg_call_taunt:CheckState() return { [MODIFIER_STATE_TAUNTED] = true } end

function modifier_rpg_call_taunt:OnCreated()
	if not IsServer() then return end
	self:GetParent():SetForceAttackTarget(self:GetCaster())
	self:StartIntervalThink(0.5)
end

function modifier_rpg_call_taunt:OnIntervalThink()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() or not caster:IsAlive() then self:Destroy() return end
	self:GetParent():SetForceAttackTarget(caster)
end

function modifier_rpg_call_taunt:OnDestroy()
	if IsServer() then self:GetParent():SetForceAttackTarget(nil) end
end

-- ===================== Berserker's Call: бафф Акса =====================
-- Броня; (Эгида Мазохиста) -65% входящего урона; (Взрывная Ярость) копит урон и взрывается в конце.
modifier_rpg_call_buff = class({})
function modifier_rpg_call_buff:IsHidden() return false end
function modifier_rpg_call_buff:IsPurgable() return false end
function modifier_rpg_call_buff:GetTexture() return "axe_berserkers_call" end
function modifier_rpg_call_buff:GetEffectName() return "particles/units/heroes/hero_axe/axe_beserkers_call_owner.vpcf" end
function modifier_rpg_call_buff:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_rpg_call_buff:OnCreated(kv)
	if not IsServer() then return end
	self.stored = 0
	self.mythic = kv.mythic == 1
	self.aegis = kv.aegis == 1
	self:SetStackCount(math.floor(kv.armor or 0))   -- стаки = бонус брони (синхронизируется клиенту)
end

-- Повторный Call обновляет длительность, накопленный урон не сбрасывается
function modifier_rpg_call_buff:OnRefresh(kv)
	if not IsServer() then return end
	self.mythic = kv.mythic == 1
	self.aegis = kv.aegis == 1
	self:SetStackCount(math.floor(kv.armor or 0))
end

function modifier_rpg_call_buff:DeclareFunctions()
	return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS, MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE, MODIFIER_EVENT_ON_TAKEDAMAGE }
end

function modifier_rpg_call_buff:GetModifierPhysicalArmorBonus() return self:GetStackCount() end

function modifier_rpg_call_buff:GetModifierIncomingDamage_Percentage()
	if IsServer() and self.aegis then return -Axe.C.AEGIS_REDUCTION end
	return 0
end

function modifier_rpg_call_buff:OnTakeDamage(p)
	if not IsServer() or not self.mythic or p.unit ~= self:GetParent() or p.damage <= 0 then return end
	local d = p.damage
	-- Эгида: в волну идёт урон БЕЗ учёта её сопротивления
	if self.aegis then d = d / (1 - Axe.C.AEGIS_REDUCTION / 100) end
	self.stored = self.stored + d
end

function modifier_rpg_call_buff:OnDestroy()
	if not IsServer() then return end
	Axe:EndCall(self:GetParent(), self:GetAbility(), self.stored)
end

-- ===================== Battle Hunger =====================
modifier_rpg_battle_hunger = class({})
function modifier_rpg_battle_hunger:IsHidden() return false end
function modifier_rpg_battle_hunger:IsDebuff() return true end
function modifier_rpg_battle_hunger:IsPurgable() return true end
function modifier_rpg_battle_hunger:GetTexture() return "axe_battle_hunger" end
function modifier_rpg_battle_hunger:GetEffectName() return "particles/units/heroes/hero_axe/axe_battle_hunger.vpcf" end
function modifier_rpg_battle_hunger:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_rpg_battle_hunger:OnCreated(kv)
	if not IsServer() then return end
	self.dps = kv.dps or 0
	self.int_dps = kv.int_dps or 0
	self.slow = kv.slow or 0
	self:SetStackCount(math.max(1, math.floor(kv.stacks or 1)))
	self:StartIntervalThink(1)
	self:OnIntervalThink()   -- первый тик сразу при наложении
end

function modifier_rpg_battle_hunger:OnRefresh(kv)
	if not IsServer() then return end
	self.dps = kv.dps or self.dps or 0
	self.int_dps = kv.int_dps or self.int_dps or 0
	self.slow = kv.slow or self.slow or 0
	self:SetStackCount(math.max(1, self:GetStackCount() + (kv.stacks or 0)))
end

function modifier_rpg_battle_hunger:AddStack(dps, int_dps, slow, duration, add)
	self.dps, self.int_dps, self.slow = dps, int_dps, slow
	if add <= 0 then
		self:SetDuration(duration, true)
		return
	end
	self:SetStackCount(self:GetStackCount() + add)
	self:SetDuration(duration, true)
end

function modifier_rpg_battle_hunger:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, MODIFIER_PROPERTY_DISABLE_HEALING, MODIFIER_EVENT_ON_DEATH }
end

function modifier_rpg_battle_hunger:GetModifierMoveSpeedBonus_Percentage() return -self.slow * self:GetStackCount() end
function modifier_rpg_battle_hunger:GetDisableHealing()
	local caster = self:GetCaster()
	return caster and caster.rpg and (caster.rpg.perk_count.e_no_compromise or 0) > 0 and self:GetStackCount() >= 10 and 1 or 0
end

function modifier_rpg_battle_hunger:OnIntervalThink()
	local parent = self:GetParent()
	local caster = self:GetCaster()
	if not parent or parent:IsNull() or not parent:IsAlive() then return end
	if not caster or caster:IsNull() then self:Destroy() return end
	local stacks = math.max(1, self:GetStackCount())
	local base = (self.dps or 0) * stacks
	local intDamage = (self.int_dps or 0) * stacks
	local dealt = ApplyDamage({ victim = parent, attacker = caster, damage = base, damage_type = DAMAGE_TYPE_MAGICAL, ability = self:GetAbility() }) or 0
	local pure_int = caster.rpg and (caster.rpg.perk_count.e_piercing_int or 0) > 0 and not parent:IsHero() and not Axe:IsElite(parent)
	if intDamage > 0 then
		dealt = dealt + (ApplyDamage({ victim = parent, attacker = caster, damage = intDamage,
			damage_type = pure_int and DAMAGE_TYPE_PURE or DAMAGE_TYPE_MAGICAL, ability = self:GetAbility() }) or 0)
	end
	if caster.rpg and (caster.rpg.perk_count.l_hunger_vamp or 0) > 0 and caster:IsAlive() then caster:Heal(dealt * 0.10, self:GetAbility()) end
end

-- Талант 20 левый: смерть врага под Battle Hunger сокращает перезарядку Culling Blade на 22 с
function modifier_rpg_battle_hunger:OnDeath(p)
	if not IsServer() or p.unit ~= self:GetParent() then return end
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return end
	if p.attacker == caster and p.inflictor == self:GetAbility() then self.died_to_hunger = true end
	Axe:TransferHunger(caster, self:GetAbility(), self:GetParent(), self:GetStackCount())
	local t = Axe:TalentAbility(caster, "20_left")
	if t then Axe:ReduceCull(caster, t:GetSpecialValueFor("value")) end
end

function modifier_rpg_battle_hunger:OnDestroy()
	if not IsServer() then return end
	local caster, parent = self:GetCaster(), self:GetParent()
	if not caster or caster:IsNull() or not parent or parent:IsNull() then return end
	local stacks = self:GetStackCount()
	if caster.rpg and (caster.rpg.perk_count.e_explosive_metabolism or 0) > 0 and stacks >= 10 then
		local pos = parent:GetAbsOrigin()
		local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_jakiro/jakiro_liquid_fire_explosion.vpcf", PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(fx, 0, pos); ParticleManager:ReleaseParticleIndex(fx)
		for _, enemy in ipairs(Axe:Enemies(caster, pos, 450)) do
			ApplyDamage({ victim = enemy, attacker = caster, damage = (self.dps or 0) * stacks * 4, damage_type = DAMAGE_TYPE_MAGICAL, ability = self:GetAbility() })
		end
	end
	if self.died_to_hunger and caster.rpg and (caster.rpg.perk_count.e_chain_impulse or 0) > 0 then
		CreateModifierThinker(caster, self:GetAbility(), "modifier_rpg_fire_zone", { duration = 3, radius = 300, fixed_damage = 100,
			damage_type = DAMAGE_TYPE_MAGICAL }, parent:GetAbsOrigin(), caster:GetTeamNumber(), false)
	end
end

-- Axe's timed intelligence surge.
modifier_rpg_axe_compensation = class({})
function modifier_rpg_axe_compensation:IsHidden() return false end
function modifier_rpg_axe_compensation:IsPurgable() return false end
function modifier_rpg_axe_compensation:DeclareFunctions() return { MODIFIER_PROPERTY_STATS_INTELLECT_BONUS } end
function modifier_rpg_axe_compensation:GetModifierBonusStats_Intellect() return Axe:Int(self:GetParent()) * 0.15 end

modifier_rpg_axe_bleed = class({})
function modifier_rpg_axe_bleed:IsDebuff() return true end
function modifier_rpg_axe_bleed:IsPurgable() return true end
function modifier_rpg_axe_bleed:GetEffectName() return "particles/units/heroes/hero_axe/axe_battle_hunger.vpcf" end
function modifier_rpg_axe_bleed:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
function modifier_rpg_axe_bleed:OnCreated(kv)
	if not IsServer() then return end
	self.pct = kv.pct or 5
	self.pure = kv.pure == 1
	self:StartIntervalThink(1)
	self:OnIntervalThink()
end
function modifier_rpg_axe_bleed:OnIntervalThink()
	local p = self:GetParent()
	ApplyDamage({ victim = p, attacker = self:GetCaster(), ability = self:GetAbility(), damage = Axe:PctOfMax(p, self.pct),
		damage_type = self.pure and DAMAGE_TYPE_PURE or DAMAGE_TYPE_MAGICAL })
end

modifier_rpg_rotten_blade = class({})
function modifier_rpg_rotten_blade:IsDebuff() return true end
function modifier_rpg_rotten_blade:IsPurgable() return true end
function modifier_rpg_rotten_blade:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, MODIFIER_PROPERTY_DISABLE_HEALING } end
function modifier_rpg_rotten_blade:GetModifierMoveSpeedBonus_Percentage() return -75 end
function modifier_rpg_rotten_blade:GetDisableHealing() return 1 end
function modifier_rpg_rotten_blade:OnCreated()
	if IsServer() then self:StartIntervalThink(1); self:OnIntervalThink() end
end

modifier_rpg_cull_vitality = class({})
function modifier_rpg_cull_vitality:IsPurgable() return false end
function modifier_rpg_cull_vitality:OnCreated() if IsServer() then self:SetStackCount(1) end end
function modifier_rpg_cull_vitality:OnRefresh() if IsServer() then self:SetStackCount(math.min(20, self:GetStackCount() + 1)) end end
function modifier_rpg_cull_vitality:DeclareFunctions() return { MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS } end
function modifier_rpg_cull_vitality:GetModifierExtraHealthBonus()
	local parent = self:GetParent()
	local base = parent.GetBaseMaxHealth and parent:GetBaseMaxHealth() or parent:GetMaxHealth()
	return base * self:GetStackCount() * 0.02
end
function modifier_rpg_rotten_blade:OnIntervalThink()
	ApplyDamage({ victim = self:GetParent(), attacker = self:GetCaster(), ability = self:GetAbility(), damage = 100, damage_type = DAMAGE_TYPE_MAGICAL })
end


-- Battle Hunger charges from the level-40 talent.
modifier_rpg_hunger_charges = class({})
function modifier_rpg_hunger_charges:IsPurgable() return false end
function modifier_rpg_hunger_charges:RemoveOnDeath() return false end
function modifier_rpg_hunger_charges:IsHidden() return not Axe:Talent(self:GetParent(), "40_hunger_charges") end
function modifier_rpg_hunger_charges:GetTexture() return "axe_battle_hunger" end
function modifier_rpg_hunger_charges:OnCreated()
	if not IsServer() then return end
	self.max=1; self.charges=1; self.restore_at=nil; self:StartIntervalThink(0.25)
end
function modifier_rpg_hunger_charges:OnIntervalThink()
	local parent, ability=self:GetParent(),self:GetAbility(); if not ability then return end
	local max=Axe:Talent(parent,"40_hunger_charges") and 4 or 1; local now=GameRules:GetGameTime()
	if max~=self.max then self.max=max; self.charges=ability:IsCooldownReady() and max or math.min(self.charges,max); if self.charges<max and not self.restore_at then self.restore_at=now+ability:GetCooldown(math.max(0,ability:GetLevel()-1)) end end
	if self.restore_at and now>=self.restore_at then self.charges=math.min(self.max,self.charges+1); self.restore_at=self.charges<self.max and now+ability:GetCooldown(math.max(0,ability:GetLevel()-1)) or nil end
	if self.max>1 and self.charges>0 and not ability:IsCooldownReady() then ability:EndCooldown() end
	self:SetStackCount(self.max>1 and self.charges or 0)
end
function modifier_rpg_hunger_charges:Consume()
	if self.max<=1 then return end
	local ability=self:GetAbility(); self.charges=math.max(0,self.charges-1)
	if not self.restore_at then self.restore_at=GameRules:GetGameTime()+ability:GetCooldownTimeRemaining() end
	if self.charges>0 then ability:EndCooldown() end
	self:SetStackCount(self.charges)
end
