-- Общие модификаторы: замедления, щиты, притяжение, зоны огня. Значения передаются через стаки (видны клиенту).

local function enemies_around(unit, pos, radius)
	return FindUnitsInRadius(unit:GetTeamNumber(), pos, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
end

-- ===== Замедление движения (враги: проклятие сатира и т.п.) kv: slow (%) =====
modifier_rpg_slow = class({})
function modifier_rpg_slow:IsDebuff() return true end
function modifier_rpg_slow:IsPurgable() return true end
function modifier_rpg_slow:OnCreated(kv) if IsServer() then self:SetStackCount(math.floor(kv.slow or 0)) end end
function modifier_rpg_slow:OnRefresh(kv) if IsServer() then self:SetStackCount(math.floor(kv.slow or 0)) end end
function modifier_rpg_slow:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_rpg_slow:GetModifierMoveSpeedBonus_Percentage() return -self:GetStackCount() end

-- ===== Снижение входящего урона (каменная кожа голема) kv: reduction (%) =====
modifier_rpg_dmg_reduction = class({})
function modifier_rpg_dmg_reduction:IsPurgable() return false end
function modifier_rpg_dmg_reduction:OnCreated(kv) if IsServer() then self:SetStackCount(math.floor(kv.reduction or 0)) end end
function modifier_rpg_dmg_reduction:OnRefresh(kv) if IsServer() then self:SetStackCount(math.floor(kv.reduction or 0)) end end
function modifier_rpg_dmg_reduction:DeclareFunctions() return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE } end
function modifier_rpg_dmg_reduction:GetModifierIncomingDamage_Percentage() return -self:GetStackCount() end

-- ===== Замедление скорости атаки kv: slow =====
modifier_rpg_as_slow = class({})
function modifier_rpg_as_slow:IsDebuff() return true end
function modifier_rpg_as_slow:IsPurgable() return true end
function modifier_rpg_as_slow:GetTexture() return "axe_berserkers_call" end
function modifier_rpg_as_slow:OnCreated(kv) if IsServer() then self:SetStackCount(math.floor(kv.slow or 0)) end end
function modifier_rpg_as_slow:OnRefresh(kv) if IsServer() then self:SetStackCount(math.floor(kv.slow or 0)) end end
function modifier_rpg_as_slow:DeclareFunctions() return { MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT } end
function modifier_rpg_as_slow:GetModifierAttackSpeedBonus_Constant() return -self:GetStackCount() end

-- ===== Бонус скорости передвижения в % (Culling Blade) kv: pct =====
modifier_rpg_ms_buff = class({})
function modifier_rpg_ms_buff:IsPurgable() return true end
function modifier_rpg_ms_buff:GetTexture() return "axe_culling_blade" end
function modifier_rpg_ms_buff:OnCreated(kv) if IsServer() then self:SetStackCount(math.floor(kv.pct or 0)) end end
function modifier_rpg_ms_buff:OnRefresh(kv) if IsServer() then self:SetStackCount(math.floor(kv.pct or 0)) end end
function modifier_rpg_ms_buff:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_rpg_ms_buff:GetModifierMoveSpeedBonus_Percentage() return self:GetStackCount() end

-- ===== Разгром легиона: потеря % брони kv: pct =====
modifier_rpg_armor_shred = class({})
function modifier_rpg_armor_shred:IsDebuff() return true end
function modifier_rpg_armor_shred:IsPurgable() return false end
function modifier_rpg_armor_shred:GetTexture() return "axe_berserkers_call" end
function modifier_rpg_armor_shred:OnCreated(kv)
	if not IsServer() then return end
	local armor = math.max(0, self:GetParent():GetPhysicalArmorValue(false))
	self:SetStackCount(math.floor(armor * (kv.pct or 0) / 100))
end
-- повторное наложение только продлевает длительность (иначе процент считался бы от уже сниженной брони)
function modifier_rpg_armor_shred:DeclareFunctions() return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS } end
function modifier_rpg_armor_shred:GetModifierPhysicalArmorBonus() return -self:GetStackCount() end

-- ===== Физический барьер (Ответственный генерал) kv: amount =====
modifier_rpg_barrier = class({})
function modifier_rpg_barrier:IsPurgable() return false end
function modifier_rpg_barrier:GetTexture() return "abaddon_aphotic_shield" end
function modifier_rpg_barrier:OnCreated(kv)
	self.max = tonumber(kv.amount) or 0
	if IsServer() then
		self.barrier = self.max
		self:SetStackCount(math.max(0, math.floor(self.barrier)))
	end
end
function modifier_rpg_barrier:OnRefresh(kv)
	local amount = tonumber(kv.amount) or 0
	self.max = (self.max or 0) + amount
	if IsServer() then
		self.barrier = (self.barrier or 0) + amount
		self:SetStackCount(math.max(0, math.floor(self.barrier)))
	end
end
function modifier_rpg_barrier:DeclareFunctions() return { MODIFIER_PROPERTY_INCOMING_PHYSICAL_DAMAGE_CONSTANT } end
function modifier_rpg_barrier:GetModifierIncomingPhysicalDamageConstant(p)
	if IsClient() then
		if p.report_max then return self.max or 0 end
		return self:GetStackCount()
	end
	local absorb = math.min(p.damage, self.barrier)
	self.barrier = self.barrier - absorb
	self:SetStackCount(math.max(0, math.floor(self.barrier)))
	if self.barrier <= 0 then self:StartIntervalThink(0.01) end   -- удалить после обработки удара
	return -absorb
end
function modifier_rpg_barrier:OnIntervalThink() self:Destroy() end

-- ===== Shallow Grave (перк Ветеран): здоровье не падает ниже 1 =====
modifier_rpg_shallow_grave = class({})
function modifier_rpg_shallow_grave:IsPurgable() return false end
function modifier_rpg_shallow_grave:GetTexture() return "dazzle_shallow_grave" end
function modifier_rpg_shallow_grave:DeclareFunctions() return { MODIFIER_PROPERTY_MIN_HEALTH } end
function modifier_rpg_shallow_grave:GetMinHealth() return 1 end

-- ===== Притяжение (Неизбежная битва, крит Counter Helix) kv: x, y, stop, [max] =====
modifier_rpg_pull = class({})
function modifier_rpg_pull:IsHidden() return true end
function modifier_rpg_pull:IsDebuff() return true end
function modifier_rpg_pull:IsPurgable() return false end
function modifier_rpg_pull:CheckState() return { [MODIFIER_STATE_STUNNED] = true } end

function modifier_rpg_pull:OnCreated(kv)
	if not IsServer() then return end
	local parent = self:GetParent()
	local pos = parent:GetAbsOrigin()
	local diff = Vector(kv.x, kv.y, 0) - Vector(pos.x, pos.y, 0)
	local dist = diff:Length2D() - (kv.stop or 100)
	if kv.max then dist = math.min(dist, kv.max) end
	if dist <= 5 then
		self:StartIntervalThink(0.01)   -- нечего тянуть: удалить на следующем кадре
		self.idle = true
		return
	end
	self.dir = diff:Normalized()
	self.speed = dist / math.max(0.05, kv.duration or 0.3)
	if not self:ApplyHorizontalMotionController() then self:StartIntervalThink(0.01) self.idle = true end
end

function modifier_rpg_pull:OnIntervalThink() self:Destroy() end

function modifier_rpg_pull:UpdateHorizontalMotion(me, dt)
	if not self.dir then return end
	me:SetAbsOrigin(me:GetAbsOrigin() + self.dir * self.speed * dt)
end

function modifier_rpg_pull:OnHorizontalMotionInterrupted() self:Destroy() end

function modifier_rpg_pull:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	if not self.idle then parent:RemoveHorizontalMotionController(self) end
	FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), true)
end

-- ===== Выжженная земля (тинкер-зона) kv: radius, pct, follow (entindex), follow_time =====
modifier_rpg_fire_zone = class({})
function modifier_rpg_fire_zone:IsHidden() return true end
function modifier_rpg_fire_zone:IsPurgable() return false end

function modifier_rpg_fire_zone:OnCreated(kv)
	if not IsServer() then return end
	self.radius = kv.radius or 500
	self.pct = kv.pct or 2.5
	self.fixed_damage = kv.fixed_damage or 0
	self.damage_type = kv.damage_type or DAMAGE_TYPE_MAGICAL
	self.visual_particle = kv.visual_particle
	self.follow = kv.follow and EntIndexToHScript(kv.follow) or nil
	self.follow_until = GameRules:GetGameTime() + (kv.follow_time or 0)
	local origin = self:GetParent():GetAbsOrigin()
	self.flame = ParticleManager:CreateParticle(self.visual_particle or "particles/units/heroes/hero_jakiro/jakiro_macropyre.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.flame, 0, origin + Vector(-self.radius, 0, 0))
	ParticleManager:SetParticleControl(self.flame, 1, origin + Vector(self.radius, 0, 0))
	self:StartIntervalThink(1)
	self:OnIntervalThink()
end

function modifier_rpg_fire_zone:OnIntervalThink()
	local parent = self:GetParent()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then self:Destroy() return end
	-- Во время Call зона следует за Аксом, потом остаётся там, где он стоял
	if self.follow and not self.follow:IsNull() and GameRules:GetGameTime() <= self.follow_until then
		parent:SetAbsOrigin(self.follow:GetAbsOrigin())
	end
	local pos = parent:GetAbsOrigin()
	if self.flame then
		ParticleManager:SetParticleControl(self.flame, 0, pos + Vector(-self.radius, 0, 0))
		ParticleManager:SetParticleControl(self.flame, 1, pos + Vector(self.radius, 0, 0))
	end
	if not self.visual_particle then
		local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_jakiro/jakiro_liquid_fire_explosion.vpcf", PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(fx, 0, pos)
		ParticleManager:ReleaseParticleIndex(fx)
	end
	for _, e in ipairs(enemies_around(parent, pos, self.radius)) do
		ApplyDamage({
			victim = e, attacker = caster, damage = self.fixed_damage > 0 and self.fixed_damage or Axe:PctOfMax(e, self.pct),
			damage_type = self.damage_type, ability = self:GetAbility(),
		})
	end
end

function modifier_rpg_fire_zone:OnDestroy()
	if IsServer() then
		if self.flame then ParticleManager:DestroyParticle(self.flame, false); ParticleManager:ReleaseParticleIndex(self.flame) end
		UTIL_Remove(self:GetParent())
	end
end


modifier_rpg_wave_rules = class({})
function modifier_rpg_wave_rules:IsHidden() return true end
function modifier_rpg_wave_rules:IsPurgable() return false end
function modifier_rpg_wave_rules:OnCreated(kv)
	self.melee_guard = tonumber(kv.melee_guard) or 0
	self.ranged_bonus = tonumber(kv.ranged_bonus) or 0
	self.regen_pct = tonumber(kv.regen_pct) or 0
	self.rune = tonumber(kv.rune) or 0
end
function modifier_rpg_wave_rules:DeclareFunctions() return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE, MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT, MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE, MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT, MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT } end
function modifier_rpg_wave_rules:GetModifierIncomingDamage_Percentage(p)
	if self.melee_guard <= 0 or not p or not p.attacker then return 0 end
	if p.attacker:IsRangedAttacker() then return self.ranged_bonus end
	return -self.melee_guard
end
function modifier_rpg_wave_rules:GetModifierConstantHealthRegen()
	local h=self:GetParent():GetMaxHealth()
	return h*self.regen_pct/100 + (self.rune==3 and 35 or 0)
end
function modifier_rpg_wave_rules:GetModifierPreAttack_BonusDamage() return self.rune==1 and 60 or 0 end
function modifier_rpg_wave_rules:GetModifierMoveSpeedBonus_Constant() return self.rune==2 and 90 or 0 end
function modifier_rpg_wave_rules:GetModifierAttackSpeedBonus_Constant() return self.rune==4 and 60 or 0 end
function modifier_rpg_wave_rules:GetEffectName()
	if self.rune==1 then return "particles/units/heroes/hero_axe/axe_attack_blur_counterhelix.vpcf" end
	if self.rune==2 then return "particles/units/heroes/hero_axe/axe_beserkers_call_owner.vpcf" end
	if self.rune==3 then return "particles/items_fx/bottle.vpcf" end
	if self.rune==4 then return "particles/units/heroes/hero_lich/lich_frost_nova.vpcf" end
end
function modifier_rpg_wave_rules:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end


modifier_rpg_boss_control = class({})
function modifier_rpg_boss_control:IsDebuff() return true end
function modifier_rpg_boss_control:IsPurgable() return true end
function modifier_rpg_boss_control:OnCreated(kv) self.silence=tonumber(kv.silence) or 0; self.disarm=tonumber(kv.disarm) or 0 end
function modifier_rpg_boss_control:CheckState()
	local state={}
	if self.silence>0 then state[MODIFIER_STATE_SILENCED]=true end
	if self.disarm>0 then state[MODIFIER_STATE_DISARMED]=true end
	return state
end

-- Boss plague fields suppress healing for their duration; keep this separate
-- from the existing slow so its gameplay is explicit and independently tunable.
modifier_rpg_boss_heal_block = class({})
function modifier_rpg_boss_heal_block:IsDebuff() return true end
function modifier_rpg_boss_heal_block:IsPurgable() return true end
function modifier_rpg_boss_heal_block:GetTexture() return "item_spirit_vessel" end
function modifier_rpg_boss_heal_block:DeclareFunctions() return { MODIFIER_PROPERTY_DISABLE_HEALING } end
function modifier_rpg_boss_heal_block:GetDisableHealing() return 1 end
