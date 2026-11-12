-- Модификаторы Lich (серверная логика - в game/heroes/lich.lua)

local function base_hidden(cls)
	function cls:IsHidden() return true end
	function cls:IsPurgable() return false end
end

local function talent(parent, key)
	local ab = parent:FindAbilityByName("special_bonus_rpg_lich_" .. key)
	if ab and ab:GetLevel() > 0 then return ab:GetSpecialValueFor("value") end
	return 0
end

-- ===================== Постоянный модификатор героя: таланты =====================
modifier_rpg_lich = class({})
base_hidden(modifier_rpg_lich)
function modifier_rpg_lich:RemoveOnDeath() return false end
function modifier_rpg_lich:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end
function modifier_rpg_lich:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MANA_BONUS,                -- 10 лево: +400 маны
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,  -- 10 право: +10% силы умений
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,       -- 15 лево: +4 регенерации маны
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,        -- 20 лево: +350 здоровья
	}
end
function modifier_rpg_lich:GetModifierManaBonus() return talent(self:GetParent(), "10_left") end
function modifier_rpg_lich:GetModifierSpellAmplify_Percentage() return talent(self:GetParent(), "10_right") end
function modifier_rpg_lich:GetModifierConstantManaRegen() return talent(self:GetParent(), "15_left") end
function modifier_rpg_lich:GetModifierExtraHealthBonus() return talent(self:GetParent(), "20_left") end

-- ===================== Серия Frost Blast (стаки = число кастов подряд) =====================
modifier_rpg_lich_series = class({})
function modifier_rpg_lich_series:IsHidden() return false end
function modifier_rpg_lich_series:IsPurgable() return false end
function modifier_rpg_lich_series:GetTexture() return "lich_frost_nova" end
function modifier_rpg_lich_series:OnDestroy()
	if IsServer() then Lich:EndSeries(self:GetParent()) end
end

-- ===================== Обледенение =====================
modifier_rpg_lich_icing = class({})
function modifier_rpg_lich_icing:IsHidden() return false end
function modifier_rpg_lich_icing:IsDebuff() return true end
function modifier_rpg_lich_icing:IsPurgable() return false end
function modifier_rpg_lich_icing:GetTexture() return "lich_frost_nova" end
function modifier_rpg_lich_icing:GetStatusEffectName() return "particles/status_fx/status_effect_frost.vpcf" end
function modifier_rpg_lich_icing:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_rpg_lich_icing:GetModifierMoveSpeedBonus_Percentage() return -8 * self:GetStackCount() end

-- ===================== Frost Shield (союзник) =====================
modifier_rpg_lich_shield = class({})
function modifier_rpg_lich_shield:IsHidden() return false end
function modifier_rpg_lich_shield:IsPurgable() return true end
function modifier_rpg_lich_shield:GetTexture() return "lich_frost_shield" end
function modifier_rpg_lich_shield:GetEffectName() return "particles/units/heroes/hero_lich/lich_frost_armor.vpcf" end
function modifier_rpg_lich_shield:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_rpg_lich_shield:OnCreated(kv)
	if not IsServer() then return end
	self.slow = kv.slow or 0
	self.slow_dur = kv.slow_dur or 2
	self.shard = tonumber(kv.shard) or 0
	self:SetStackCount(math.floor(kv.red or 0))      -- стаки = % снижения урона (виден клиенту)
end
function modifier_rpg_lich_shield:OnRefresh(kv) self:OnCreated(kv) end

function modifier_rpg_lich_shield:DeclareFunctions()
	return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE, MODIFIER_EVENT_ON_TAKEDAMAGE }
end
function modifier_rpg_lich_shield:GetModifierIncomingDamage_Percentage() return -self:GetStackCount() end

-- Часть урона возвращается замедлением атакующего (движение + скорость атаки)
function modifier_rpg_lich_shield:OnTakeDamage(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if p.unit ~= parent or not p.attacker or p.attacker:IsNull() or p.damage <= 0 then return end
	if p.attacker:GetTeamNumber() == parent:GetTeamNumber() then return end
	local caster, ab = self:GetCaster(), self:GetAbility()
	p.attacker:AddNewModifier(caster, ab, "modifier_rpg_slow", { duration = self.slow_dur, slow = self.slow })
	p.attacker:AddNewModifier(caster, ab, "modifier_rpg_as_slow", { duration = self.slow_dur, slow = self.slow })
	if self.shard and self.shard > 0 and (self.shard_ready or 0) <= GameRules:GetGameTime() then
		self.shard_ready = GameRules:GetGameTime() + 1.5
		local pos = parent:GetAbsOrigin()
		local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_lich/lich_frost_nova.vpcf", PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(fx, 0, pos)
		ParticleManager:ReleaseParticleIndex(fx)
		for _, enemy in ipairs(FindUnitsInRadius(caster:GetTeamNumber(), pos, nil, 250, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)) do
			ApplyDamage({victim=enemy,attacker=caster,ability=ab,damage=75+caster:GetIntellect()*0.5,damage_type=DAMAGE_TYPE_MAGICAL})
		end
	end
end

-- ===================== Глыба (мифик «Ледяной Бастион») =====================
modifier_rpg_lich_glacier = class({})
function modifier_rpg_lich_glacier:IsHidden() return false end
function modifier_rpg_lich_glacier:IsPurgable() return false end
function modifier_rpg_lich_glacier:GetTexture() return "lich_frost_shield" end
function modifier_rpg_lich_glacier:GetStatusEffectName() return "particles/status_fx/status_effect_frost.vpcf" end
function modifier_rpg_lich_glacier:CheckState()
	return { [MODIFIER_STATE_ROOTED] = true, [MODIFIER_STATE_DISARMED] = true }   -- не двигается и не бьёт, но колдовать может
end
function modifier_rpg_lich_glacier:DeclareFunctions()
	return { MODIFIER_PROPERTY_INCOMING_PHYSICAL_DAMAGE_PERCENTAGE, MODIFIER_PROPERTY_TOTAL_CONSTANT_BLOCK }
end
function modifier_rpg_lich_glacier:GetModifierIncomingPhysicalDamage_Percentage() return -100 end

-- «Энергетический резонанс»: поглощаем весь урон (не только физический)
function modifier_rpg_lich_glacier:GetModifierTotal_ConstantBlock(p)
	if not IsServer() then return 0 end
	local parent = self:GetParent()
	if not Lich:Has(parent, "l_resonance") then return 0 end
	self.absorbed = (self.absorbed or 0) + p.damage
	return p.damage
end

function modifier_rpg_lich_glacier:OnCreated()
	if not IsServer() then return end
	self.wave_total = 0
	self.absorbed = 0
	local ab = self:GetAbility()
	self:StartIntervalThink(ab:GetSpecialValueFor("wave_interval"))
end
function modifier_rpg_lich_glacier:OnIntervalThink()
	local caster, ab = self:GetParent(), self:GetAbility()
	if not ab or ab:IsNull() or not caster:IsAlive() then self:Destroy() return end
	Lich:BastionWave(caster, ab, self)
end
function modifier_rpg_lich_glacier:OnDestroy()
	if not IsServer() then return end
	local caster, ab = self:GetParent(), self:GetAbility()
	if ab and not ab:IsNull() then Lich:BastionFinish(caster, ab, self) end
end

-- ===================== Притяжение (шаг к центру) kv: x, y, speed, stop, [stun] =====================
modifier_rpg_lich_pull_step = class({})
function modifier_rpg_lich_pull_step:IsHidden() return true end
function modifier_rpg_lich_pull_step:IsDebuff() return true end
function modifier_rpg_lich_pull_step:IsPurgable() return false end
function modifier_rpg_lich_pull_step:CheckState()
	if self.stun then return { [MODIFIER_STATE_STUNNED] = true } end
	return {}
end
function modifier_rpg_lich_pull_step:DeclareFunctions() return { MODIFIER_EVENT_ON_DEATH } end

function modifier_rpg_lich_pull_step:OnCreated(kv)
	if not IsServer() then return end
	self:Setup(kv)
	self:StartIntervalThink(0.03)
end
function modifier_rpg_lich_pull_step:OnRefresh(kv)
	if IsServer() then self:Setup(kv) end
end
function modifier_rpg_lich_pull_step:Setup(kv)
	self.x, self.y = kv.x, kv.y
	self.speed = (kv.speed or 200) * (self:GetParent().rpg_boss and 0.5 or 1)   -- боссов тянет вдвое медленнее
	self.stop = kv.stop or 100
	self.stun = kv.stun == 1
end
function modifier_rpg_lich_pull_step:OnIntervalThink()
	local p = self:GetParent()
	if not p:IsAlive() then return end
	local pos = p:GetAbsOrigin()
	local to = Vector(self.x, self.y, pos.z) - pos
	to.z = 0
	local dist = to:Length2D()
	if dist <= self.stop then return end
	local step = math.min(self.speed * 0.03, dist - self.stop)
	p:SetAbsOrigin(GetGroundPosition(pos + to:Normalized() * step, p))
end
function modifier_rpg_lich_pull_step:OnDeath(p)
	if not IsServer() or p.unit ~= self:GetParent() then return end
	Lich:OnPulledDeath(self:GetCaster(), p.unit)
end
function modifier_rpg_lich_pull_step:OnDestroy()
	if IsServer() then FindClearSpaceForUnit(self:GetParent(), self:GetParent():GetAbsOrigin(), true) end
end

-- ===================== Sinister Gaze на цель (без мифика) =====================
modifier_rpg_lich_gaze_target = class({})
function modifier_rpg_lich_gaze_target:IsHidden() return false end
function modifier_rpg_lich_gaze_target:IsDebuff() return true end
function modifier_rpg_lich_gaze_target:IsPurgable() return false end
function modifier_rpg_lich_gaze_target:GetTexture() return "lich_sinister_gaze" end
function modifier_rpg_lich_gaze_target:GetEffectName() return "particles/units/heroes/hero_lich/lich_sinister_gaze.vpcf" end
function modifier_rpg_lich_gaze_target:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_rpg_lich_gaze_target:OnCreated()
	if not IsServer() then return end
	self.acc = 0
	self:StartIntervalThink(0.03)
end
function modifier_rpg_lich_gaze_target:OnIntervalThink()
	local parent, caster, ab = self:GetParent(), self:GetCaster(), self:GetAbility()
	if not caster or caster:IsNull() or not ab or ab:IsNull() or not parent:IsAlive() then self:Destroy() return end
	-- притяжение к Личу
	local pos, cpos = parent:GetAbsOrigin(), caster:GetAbsOrigin()
	local to = cpos - pos
	to.z = 0
	local dist = to:Length2D()
	local speed = ab:GetSpecialValueFor("pull_speed") * (parent.rpg_boss and 0.5 or 1)
	if dist > 150 then
		parent:SetAbsOrigin(GetGroundPosition(pos + to:Normalized() * math.min(speed * 0.03, dist - 150), parent))
	end
	-- урон каждые 0.5 с: «урон в секунду» / 2
	self.acc = self.acc + 0.03
	if self.acc >= 0.5 then
		self.acc = self.acc - 0.5
		Lich:Hit(caster, parent, ab, Lich:GazeDps(caster, ab) * 0.5 * ((self.ctx and self.ctx.amp) or 1), self.ctx)
	end
end
function modifier_rpg_lich_gaze_target:OnDestroy()
	if IsServer() then FindClearSpaceForUnit(self:GetParent(), self:GetParent():GetAbsOrigin(), true) end
end

-- ===================== Sinister Gaze: конус (мифик) =====================
modifier_rpg_lich_gaze_cone = class({})
function modifier_rpg_lich_gaze_cone:IsHidden() return false end
function modifier_rpg_lich_gaze_cone:IsPurgable() return false end
function modifier_rpg_lich_gaze_cone:GetTexture() return "lich_sinister_gaze" end

function modifier_rpg_lich_gaze_cone:OnCreated()
	if not IsServer() then return end
	self.pulled = {}
	self.acc = 0
	local caster, ab = self:GetParent(), self:GetAbility()
	if Lich:Has(caster, "l_manaeater") then
		self.absorb = caster:AddNewModifier(caster, ab, "modifier_rpg_lich_absorb", { duration = 30, amount = 0 })
	end
	if Lich:Has(caster, "e_relentless") then
		caster:AddNewModifier(caster, ab, "modifier_rpg_lich_relentless", { duration = 30 })
	end
	self:StartIntervalThink(0.1)
end
function modifier_rpg_lich_gaze_cone:OnIntervalThink()
	local caster, ab = self:GetParent(), self:GetAbility()
	if not ab or ab:IsNull() or not caster:IsAlive() then self:Destroy() return end
	if not Lich:GazeConeTick(caster, ab, self, 0.1) then
		self.interrupted = true
		ab:EndChannel(true)       -- мана кончилась: канал прерывается
	end
end
function modifier_rpg_lich_gaze_cone:OnDestroy()
	if not IsServer() then return end
	local caster, ab = self:GetParent(), self:GetAbility()
	if ab and not ab:IsNull() then Lich:GazeFinish(caster, ab, self) end
end

-- ===================== Контроль: заморозка, root, break =====================
modifier_rpg_lich_freeze = class({})
function modifier_rpg_lich_freeze:IsHidden() return false end
function modifier_rpg_lich_freeze:IsDebuff() return true end
function modifier_rpg_lich_freeze:IsPurgable() return false end
function modifier_rpg_lich_freeze:GetTexture() return "lich_frost_nova" end
function modifier_rpg_lich_freeze:GetStatusEffectName() return "particles/status_fx/status_effect_frost.vpcf" end
function modifier_rpg_lich_freeze:CheckState() return { [MODIFIER_STATE_FROZEN] = true, [MODIFIER_STATE_STUNNED] = true } end

modifier_rpg_lich_root = class({})
function modifier_rpg_lich_root:IsDebuff() return true end
function modifier_rpg_lich_root:IsPurgable() return false end
function modifier_rpg_lich_root:GetTexture() return "lich_frost_shield" end
function modifier_rpg_lich_root:CheckState() return { [MODIFIER_STATE_ROOTED] = true } end

modifier_rpg_lich_break = class({})
function modifier_rpg_lich_break:IsDebuff() return true end
function modifier_rpg_lich_break:IsPurgable() return false end
function modifier_rpg_lich_break:GetTexture() return "lich_frost_shield" end
function modifier_rpg_lich_break:CheckState() return { [MODIFIER_STATE_PASSIVES_DISABLED] = true } end

-- ===================== Метка «Цепной детонации» =====================
modifier_rpg_lich_mark = class({})
function modifier_rpg_lich_mark:IsDebuff() return true end
function modifier_rpg_lich_mark:IsPurgable() return false end
function modifier_rpg_lich_mark:GetTexture() return "lich_frost_nova" end
function modifier_rpg_lich_mark:DeclareFunctions() return { MODIFIER_EVENT_ON_DEATH } end
function modifier_rpg_lich_mark:OnDeath(p)
	if not IsServer() or p.unit ~= self:GetParent() then return end
	Lich:MarkExplode(self:GetCaster(), self:GetAbility(), p.unit:GetAbsOrigin())
end

-- ===================== Перегрев / Жертвоприношение: касты без маны =====================
modifier_rpg_lich_overheat = class({})
function modifier_rpg_lich_overheat:IsPurgable() return false end
function modifier_rpg_lich_overheat:GetTexture() return "lich_frost_nova" end
function modifier_rpg_lich_overheat:DeclareFunctions() return { MODIFIER_PROPERTY_MANACOST_PERCENTAGE_STACKING } end
function modifier_rpg_lich_overheat:GetModifierPercentageManacostStacking() return 100 end

modifier_rpg_lich_blood = class({})
function modifier_rpg_lich_blood:IsPurgable() return false end
function modifier_rpg_lich_blood:GetTexture() return "lich_frost_nova" end
function modifier_rpg_lich_blood:DeclareFunctions() return { MODIFIER_PROPERTY_MANACOST_PERCENTAGE_STACKING } end
function modifier_rpg_lich_blood:GetModifierPercentageManacostStacking() return 100 end

-- ===================== Компенсация =====================
modifier_rpg_lich_comp = class({})
function modifier_rpg_lich_comp:IsPurgable() return true end
function modifier_rpg_lich_comp:GetTexture() return "lich_frost_nova" end
function modifier_rpg_lich_comp:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE }
end
function modifier_rpg_lich_comp:GetModifierMoveSpeedBonus_Percentage() return 10 end
function modifier_rpg_lich_comp:GetModifierPercentageCooldown() return 15 end

-- ===================== Кровавый разгон =====================
modifier_rpg_lich_haste = class({})
function modifier_rpg_lich_haste:IsPurgable() return true end
function modifier_rpg_lich_haste:GetTexture() return "lich_chain_frost" end
function modifier_rpg_lich_haste:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT }
end
function modifier_rpg_lich_haste:GetModifierMoveSpeedBonus_Percentage() return 20 end
function modifier_rpg_lich_haste:GetModifierAttackSpeedBonus_Constant() return 20 end

-- ===================== Огненные огни: вращающиеся сферы =====================
modifier_rpg_lich_orbs = class({})
function modifier_rpg_lich_orbs:IsPurgable() return false end
function modifier_rpg_lich_orbs:GetTexture() return "lich_frost_nova" end

function modifier_rpg_lich_orbs:OnCreated()
	if not IsServer() then return end
	self.fx, self.ang, self.t = {}, 0, 0
	self:StartIntervalThink(0.05)
end
function modifier_rpg_lich_orbs:OnIntervalThink()
	local parent, C = self:GetParent(), Lich.C
	local n = self:GetStackCount()
	while #self.fx < n do
		table.insert(self.fx, ParticleManager:CreateParticle("particles/generic_gameplay/generic_slowed_cold.vpcf", PATTACH_WORLDORIGIN, nil))
	end
	local origin = parent:GetAbsOrigin()
	self.ang = self.ang + 4
	local orbs = {}
	for i, fx in ipairs(self.fx) do
		local a = math.rad(self.ang + (i - 1) * 360 / math.max(1, #self.fx))
		local pos = origin + Vector(math.cos(a), math.sin(a), 0) * C.ORB_ORBIT + Vector(0, 0, 110)
		ParticleManager:SetParticleControl(fx, 0, pos)
		orbs[i] = pos
	end
	-- каждая сфера периодически стреляет по врагам ближе 400 от Лича
	self.t = self.t + 0.05
	if self.t >= C.ORB_SHOT_CD then
		self.t = 0
		local ab = parent:FindAbilityByName("rpg_lich_frost_blast")
		if ab then
			local dmg = Lich:BlastBase(parent, ab)
			local enemies = Lich:Enemies(parent, origin, C.ORB_RADIUS)
			for _, e in ipairs(enemies) do
				if e:IsAlive() then
					for _ = 1, #orbs do
						Lich.fx_world("particles/units/heroes/hero_lich/lich_frost_nova.vpcf", e:GetAbsOrigin())
						Lich:Hit(parent, e, ab, dmg)
					end
				end
			end
		end
	end
end
function modifier_rpg_lich_orbs:OnDestroy()
	if not IsServer() then return end
	for _, fx in ipairs(self.fx) do
		ParticleManager:DestroyParticle(fx, false)
		ParticleManager:ReleaseParticleIndex(fx)
	end
	self.fx = {}
end

-- ===================== Щит от любого урона (kv: amount) =====================
modifier_rpg_lich_absorb = class({})
function modifier_rpg_lich_absorb:IsPurgable() return false end
function modifier_rpg_lich_absorb:GetTexture() return "lich_frost_shield" end
function modifier_rpg_lich_absorb:OnCreated(kv)
	if IsServer() then self.amount = kv.amount or 0 end
end
function modifier_rpg_lich_absorb:OnRefresh(kv)
	if IsServer() then self.amount = (self.amount or 0) + (kv.amount or 0) end
end
function modifier_rpg_lich_absorb:AddAmount(v) self.amount = (self.amount or 0) + v end
function modifier_rpg_lich_absorb:DeclareFunctions() return { MODIFIER_PROPERTY_TOTAL_CONSTANT_BLOCK } end
function modifier_rpg_lich_absorb:GetModifierTotal_ConstantBlock(p)
	if not IsServer() then return 0 end
	local b = math.min(p.damage, self.amount or 0)
	self.amount = (self.amount or 0) - b
	return b
end

-- ===================== Кристаллическая броня (стаки = броня) =====================
modifier_rpg_lich_crystal = class({})
function modifier_rpg_lich_crystal:IsPurgable() return false end
function modifier_rpg_lich_crystal:GetTexture() return "lich_frost_shield" end
function modifier_rpg_lich_crystal:DeclareFunctions() return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS } end
function modifier_rpg_lich_crystal:GetModifierPhysicalArmorBonus() return self:GetStackCount() end

-- ===================== Неумолимый поток =====================
modifier_rpg_lich_relentless = class({})
function modifier_rpg_lich_relentless:IsPurgable() return false end
function modifier_rpg_lich_relentless:GetTexture() return "lich_sinister_gaze" end
function modifier_rpg_lich_relentless:DeclareFunctions()
	return { MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS, MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE_MIN }
end
function modifier_rpg_lich_relentless:GetModifierMagicalResistanceBonus() return 30 end
function modifier_rpg_lich_relentless:GetModifierMoveSpeed_AbsoluteMin() return self:GetParent():GetBaseMoveSpeed() end

-- ===================== Защитный купол (союзник; kv: x, y = направление взгляда Лича) =====================
modifier_rpg_lich_dome = class({})
function modifier_rpg_lich_dome:IsPurgable() return false end
function modifier_rpg_lich_dome:GetTexture() return "lich_frost_shield" end
function modifier_rpg_lich_dome:OnCreated(kv)
	if IsServer() then self.fx, self.fy = kv.x or 0, kv.y or 0 end
end
function modifier_rpg_lich_dome:OnRefresh(kv) self:OnCreated(kv) end
function modifier_rpg_lich_dome:DeclareFunctions() return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE } end
function modifier_rpg_lich_dome:GetModifierIncomingDamage_Percentage(p)
	if not IsServer() then return 0 end
	local caster = self:GetCaster()
	if not p.attacker or not caster or caster:IsNull() then return 0 end
	-- атака «спереди»: источник по ту же сторону от Лича, куда он смотрит
	local v = p.attacker:GetAbsOrigin() - caster:GetAbsOrigin()
	v.z = 0
	if v:Length2D() > 1 and v:Normalized():Dot(Vector(self.fx, self.fy, 0)) > 0 then return -25 end
	return 0
end

-- ===================== Морозная лужа (тинкер): kv radius =====================
modifier_rpg_lich_mr_shred = class({})
function modifier_rpg_lich_mr_shred:IsDebuff() return true end
function modifier_rpg_lich_mr_shred:IsPurgable() return false end
function modifier_rpg_lich_mr_shred:GetTexture() return "lich_frost_nova" end
function modifier_rpg_lich_mr_shred:DeclareFunctions() return { MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS } end
function modifier_rpg_lich_mr_shred:GetModifierMagicalResistanceBonus() return -20 end

modifier_rpg_lich_puddle = class({})
function modifier_rpg_lich_puddle:IsHidden() return true end
function modifier_rpg_lich_puddle:IsPurgable() return false end
function modifier_rpg_lich_puddle:OnCreated(kv)
	if not IsServer() then return end
	self.radius = kv.radius or 400
	self:StartIntervalThink(0.4)
	self:OnIntervalThink()
end
function modifier_rpg_lich_puddle:OnIntervalThink()
	local parent, caster = self:GetParent(), self:GetCaster()
	if not caster or caster:IsNull() then self:Destroy() return end
	local pos = parent:GetAbsOrigin()
	Lich.fx_world("particles/generic_gameplay/generic_slowed_cold.vpcf", pos)
	for _, e in ipairs(Lich:Enemies(caster, pos, self.radius)) do
		e:AddNewModifier(caster, self:GetAbility(), "modifier_rpg_slow", { duration = 0.6, slow = Lich.C.PUDDLE_SLOW })
		e:AddNewModifier(caster, self:GetAbility(), "modifier_rpg_as_slow", { duration = 0.6, slow = Lich.C.PUDDLE_SLOW })
		e:AddNewModifier(caster, self:GetAbility(), "modifier_rpg_lich_mr_shred", { duration = 0.6 })
	end
end
function modifier_rpg_lich_puddle:OnDestroy()
	if IsServer() then UTIL_Remove(self:GetParent()) end
end
