-- Способности Axe. Вся логика - в game/heroes/axe.lua (Axe:...), модификаторы - modifiers/modifier_rpg_axe_abilities.lua

local function HasAxePerk(hero, id)
	if IsServer() then return Axe:Has(hero, id) end
	local t = CustomNetTables:GetTableValue("rpg_perks", tostring(hero:entindex()))
	return t and (t[id] or 0) > 0 or false
end

-- ================= Berserker's Call =================
rpg_axe_berserkers_call = class({})

function rpg_axe_berserkers_call:GetAOERadius()
	if Axe then
		if IsServer() then return Axe:CallRadius(self:GetCaster(), self) end
		local r=self:GetSpecialValueFor("radius")
		local t=CustomNetTables:GetTableValue("rpg_perks",tostring(self:GetCaster():entindex()))
		return r+(t and t.bonus_call_radius or 0)
	end
	return self:GetSpecialValueFor("radius")
end

function rpg_axe_berserkers_call:OnSpellStart()
	Axe:CastCall(self:GetCaster(), self)
end

-- ================= Battle Hunger =================
rpg_axe_battle_hunger = class({})
function rpg_axe_battle_hunger:GetIntrinsicModifierName() return "modifier_rpg_hunger_charges" end

function rpg_axe_battle_hunger:GetBehavior()
	local behavior = self.BaseClass.GetBehavior(self)
	if HasAxePerk(self:GetCaster(), "m_strategic") then behavior = behavior + DOTA_ABILITY_BEHAVIOR_AOE end
	return behavior
end

function rpg_axe_battle_hunger:GetAOERadius()
	return HasAxePerk(self:GetCaster(), "m_strategic") and 400 or 0
end

function rpg_axe_battle_hunger:OnAbilityPhaseStart()
	local caster = self:GetCaster()
	local base = self.BaseClass.GetManaCost(self, self:GetLevel() - 1)
	self.pay_health = HasAxePerk(caster, "e_blood_diet") and caster:GetMana() < base
	if self.pay_health and caster:GetHealth() <= caster:GetMaxHealth() * 0.04 + 1 then return false end
	return true
end

function rpg_axe_battle_hunger:GetManaCost(level)
	local caster = self:GetCaster()
	local base = self.BaseClass.GetManaCost(self, level)
	self.pay_health = HasAxePerk(caster, "e_blood_diet") and caster:GetMana() < base
	if self.pay_health then return 0 end
	return base
end

function rpg_axe_battle_hunger:OnSpellStart()
	local caster, target = self:GetCaster(), self:GetCursorTarget()
	if not target or target:TriggerSpellAbsorb(self) then return end
	if self.pay_health then
		local hp = caster:GetMaxHealth() * 0.04
		if caster:GetHealth() <= hp + 1 then self.pay_health = false; return end
		caster:SetHealth(caster:GetHealth() - hp)
	end
	self.pay_health = false
	EmitSoundOn("Hero_Axe.Battle_Hunger", target)
	local targets = { target }
	if Axe:Has(caster, "m_strategic") then
		targets = Axe:Enemies(caster, target:GetAbsOrigin(), 400)
	end
	for _, enemy in ipairs(targets) do Axe:ApplyHunger(caster, self, enemy, false, false) end
	local charges=caster:FindModifierByName("modifier_rpg_hunger_charges")
	if charges then charges:Consume() end
end

-- ================= Counter Helix (пассивка) =================
rpg_axe_counter_helix = class({})

function rpg_axe_counter_helix:GetIntrinsicModifierName()
	return "modifier_rpg_axe_helix"
end

-- ================= Culling Blade =================
rpg_axe_culling_blade = class({})

function rpg_axe_culling_blade:GetHeroLevelRequiredToUpgrade()
	return 6 + math.max(0, self:GetLevel()) * 6
end
function rpg_axe_culling_blade:OnUpgrade()
	if not IsServer() or self.rpg_level_check_pending then return end
	local caster, rank = self:GetCaster(), self:GetLevel()
	local required = 6 + math.max(0, rank - 1) * 6
	if caster and caster:IsRealHero() and caster:GetLevel() < required then
		self.rpg_level_check_pending = true
		RPG.After(0.03, function()
			if not self or self:IsNull() then return end
			if self:GetLevel() >= rank and caster:IsRealHero() and caster:GetLevel() < required then self:SetLevel(rank - 1); caster:SetAbilityPoints(caster:GetAbilityPoints() + 1) end
			self.rpg_level_check_pending = false
		end)
	end
end

function rpg_axe_culling_blade:GetBehavior()
	local behavior = self.BaseClass.GetBehavior(self)
	if HasAxePerk(self:GetCaster(), "m_woodcutter") then behavior = behavior + DOTA_ABILITY_BEHAVIOR_AOE end
	return behavior
end

function rpg_axe_culling_blade:GetIntrinsicModifierName()
	LinkLuaModifier("modifier_rpg_cull_charges", "modifiers/modifier_rpg_axe_abilities", LUA_MODIFIER_MOTION_NONE)
	return "modifier_rpg_cull_charges"
end

-- Aghanim's Scepter: цель можно выбрать издалека, Axe прыгает к ней (дальность 400)
function rpg_axe_culling_blade:GetCastRange(location, target)
	if HasAxePerk(self:GetCaster(), "m_woodcutter") then return 750 end
	if self:GetCaster():HasScepter() then return self:GetSpecialValueFor("scepter_jump_range") end
	return 150
end

function rpg_axe_culling_blade:GetAOERadius()
	return HasAxePerk(self:GetCaster(), "m_woodcutter") and 750 or 0
end

function rpg_axe_culling_blade:OnSpellStart()
	local target = self:GetCursorTarget()
	if not target or target:TriggerSpellAbsorb(self) then return end
	Axe:CullingBlade(self:GetCaster(), self, target)
end
