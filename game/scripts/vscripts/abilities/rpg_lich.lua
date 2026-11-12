-- Способности Lich. Вся логика - в game/heroes/lich.lua (Lich:...), модификаторы - modifiers/modifier_rpg_lich.lua.
-- Файл исполняется и на клиенте (GetBehavior, GetManaCost, GetCastRange...), поэтому перки читаются через NetTable rpg_perks.

local function HasPerk(hero, id)
	if not hero or hero:IsNull() then return false end
	if IsServer() then return hero.rpg ~= nil and (hero.rpg.perk_count[id] or 0) > 0 end
	local t = CustomNetTables:GetTableValue("rpg_perks", tostring(hero:entindex()))
	return t ~= nil and (t[id] or 0) > 0
end

-- Любая ошибка внутри каста не теряется в консоли: печатается и показывается игроку сообщением
local function Guard(label, fn)
	return function(...)
		-- Dota's Lua runtime is Lua 5.1: xpcall does not forward arguments.
		-- Capture them and invoke the callback inside the protected closure.
		local args = { ... }
		local res = { xpcall(function() return fn(unpack(args)) end, debug.traceback) }
		if not res[1] then
			local err = tostring(res[2])
			print("[RPG][Lich] ОШИБКА в " .. label .. ":\n" .. err)
			if IsServer() then
				CustomGameEventManager:Send_ServerToAllClients("rpg_toast", { text = "Ошибка Lich (" .. label .. "): " .. (err:match("^[^\n]*") or err), color = "#ff5a4a" })
			end
			return true
		end
		return unpack(res, 2)
	end
end

local function Bonus(hero, key)
	if IsServer() and Lich then return Lich:Bonus(hero, key) end
	if not hero or hero:IsNull() then return 0 end
	local t = CustomNetTables:GetTableValue("rpg_perks", tostring(hero:entindex()))
	return t and (t["bonus_" .. key] or 0) or 0
end

-- ================= Frost Blast =================
rpg_lich_frost_blast = class({})

-- Мифик «Ледяной Архимаг»: нет перезарядки
function rpg_lich_frost_blast:GetCooldown(level)
	if HasPerk(self:GetCaster(), "m_archmage") then return 0 end
	return self.BaseClass.GetCooldown(self, level)
end

-- Мифик: каждый каст серии стоит на 20% больше (стак виден клиенту через модификатор серии)
function rpg_lich_frost_blast:GetManaCost(level)
	local caster = self:GetCaster()
	if caster:HasModifier("modifier_rpg_lich_overheat") or caster:HasModifier("modifier_rpg_lich_blood") then return 0 end
	local base = self:GetSpecialValueFor("mana_base")
	if HasPerk(caster, "m_archmage") then
		local m = caster:FindModifierByName("modifier_rpg_lich_series")
		local n = m and m:GetStackCount() or 0
		base = base * (1 + n * self:GetSpecialValueFor("series_mana_pct") / 100)
	end
	return base
end

function rpg_lich_frost_blast:GetCastRange(location, target)
	local caster = self:GetCaster()
	local r = self:GetSpecialValueFor("cast_range") + Bonus(caster, "blast_range")
	if HasPerk(caster, "l_horizon") then
		local m = caster:FindModifierByName("modifier_rpg_lich_series")
		r = r + (m and m:GetStackCount() or 0) * 50     -- Бесконечный Горизонт
	end
	return r
end

function rpg_lich_frost_blast:GetAOERadius()
	return self:GetSpecialValueFor("radius") + Bonus(self:GetCaster(), "blast_radius")
end

rpg_lich_frost_blast.OnSpellStart = Guard("frost_blast:OnSpellStart", function(self)
	local caster, target = self:GetCaster(), self:GetCursorTarget()
	if not target or target:TriggerSpellAbsorb(self) then return end
	Lich:CastBlast(caster, self, target, false)
end)

-- ================= Frost Shield =================
rpg_lich_frost_shield = class({})

function rpg_lich_frost_shield:GetManaCost(level)
	local caster = self:GetCaster()
	if caster:HasModifier("modifier_rpg_lich_overheat") or caster:HasModifier("modifier_rpg_lich_blood") then return 0 end
	return self.BaseClass.GetManaCost(self, level)
end

function rpg_lich_frost_shield:GetBehavior()
	local caster = self:GetCaster()
	local b = DOTA_ABILITY_BEHAVIOR_UNIT_TARGET
	if HasPerk(caster, "m_bastion") then b = DOTA_ABILITY_BEHAVIOR_NO_TARGET + DOTA_ABILITY_BEHAVIOR_AOE end
	if HasPerk(caster, "e_bloodfrost") then b = b + DOTA_ABILITY_BEHAVIOR_UNRESTRICTED end   -- «Кровавый мороз»: можно в стане/безмолвии
	return b
end

function rpg_lich_frost_shield:GetCastRange(location, target)
	if HasPerk(self:GetCaster(), "m_bastion") then return 0 end
	return self:GetSpecialValueFor("cast_range")
end

function rpg_lich_frost_shield:GetAOERadius()
	if HasPerk(self:GetCaster(), "m_bastion") then return self:GetSpecialValueFor("radius") end
	return 0
end

rpg_lich_frost_shield.OnSpellStart = Guard("frost_shield:OnSpellStart", function(self)
	local caster = self:GetCaster()
	if HasPerk(caster, "m_bastion") then
		Lich:CastShield(caster, self, caster)
		return
	end
	local target = self:GetCursorTarget()
	if not target then return end
	Lich:CastShield(caster, self, target)
end)

-- ================= Sinister Gaze =================
rpg_lich_sinister_gaze = class({})

function rpg_lich_sinister_gaze:GetManaCost(level)
	local caster = self:GetCaster()
	if caster:HasModifier("modifier_rpg_lich_overheat") or caster:HasModifier("modifier_rpg_lich_blood") then return 0 end
	return self.BaseClass.GetManaCost(self, level)
end

function rpg_lich_sinister_gaze:GetBehavior()
	if HasPerk(self:GetCaster(), "m_gravity") then
		return DOTA_ABILITY_BEHAVIOR_NO_TARGET + DOTA_ABILITY_BEHAVIOR_CHANNELED + DOTA_ABILITY_BEHAVIOR_AOE
	end
	return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET + DOTA_ABILITY_BEHAVIOR_CHANNELED
end

function rpg_lich_sinister_gaze:GetChannelTime()
	return self:GetSpecialValueFor("channel_time") + Bonus(self:GetCaster(), "gaze_channel")
end

function rpg_lich_sinister_gaze:GetCastRange(location, target)
	if HasPerk(self:GetCaster(), "m_gravity") then return 0 end
	return self:GetSpecialValueFor("cast_range")
end

function rpg_lich_sinister_gaze:GetAOERadius()
	if HasPerk(self:GetCaster(), "m_gravity") then
		local r = self:GetSpecialValueFor("cone_length")
		if HasPerk(self:GetCaster(), "l_eventhorizon") then r = r * 1.75 end
		return r
	end
	return 0
end

rpg_lich_sinister_gaze.OnSpellStart = Guard("sinister_gaze:OnSpellStart", function(self)
	local caster = self:GetCaster()
	if HasPerk(caster, "m_gravity") then
		Lich:CastGaze(caster, self, nil)
	else
		local target = self:GetCursorTarget()
		if not target then return end
		Lich:CastGaze(caster, self, target)
	end
end)

rpg_lich_sinister_gaze.OnChannelFinish = Guard("sinister_gaze:OnChannelFinish", function(self, interrupted)
	local caster = self:GetCaster()
	local cone = caster:FindModifierByName("modifier_rpg_lich_gaze_cone")
	if cone then
		cone.interrupted = interrupted
		cone:Destroy()
	end
	local t = self.gaze_target
	if t and not t:IsNull() then
		t:RemoveModifierByNameAndCaster("modifier_rpg_lich_gaze_target", caster)
	end
	self.gaze_target = nil
end)

-- ================= Chain Frost =================
rpg_lich_chain_frost = class({})

function rpg_lich_chain_frost:GetHeroLevelRequiredToUpgrade()
	return 6 + math.max(0, self:GetLevel()) * 6
end
function rpg_lich_chain_frost:OnUpgrade()
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

function rpg_lich_chain_frost:GetBehavior()
	if HasPerk(self:GetCaster(), "m_meteor") then
		return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET + DOTA_ABILITY_BEHAVIOR_AOE
	end
	return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET
end

function rpg_lich_chain_frost:GetCastRange(location, target)
	if HasPerk(self:GetCaster(), "m_meteor") then return self:GetSpecialValueFor("meteor_range") end
	return self:GetSpecialValueFor("cast_range")
end

function rpg_lich_chain_frost:GetAOERadius()
	local r = self:GetSpecialValueFor("meteor_radius")
	if HasPerk(self:GetCaster(), "l_epicenter_blast") then r = r * 1.5 end
	return r
end

-- «Кровавый метеор»: при нехватке маны каст идёт за 15% макс. ХП (стоимость маны при этом обнуляется)
function rpg_lich_chain_frost:GetManaCost(level)
	local caster = self:GetCaster()
	if caster:HasModifier("modifier_rpg_lich_overheat") or caster:HasModifier("modifier_rpg_lich_blood") then return 0 end
	local base = self:GetSpecialValueFor("mana_base")
	if base <= 0 then base = self.BaseClass.GetManaCost(self, level) end
	if HasPerk(caster, "m_meteor") and HasPerk(caster, "e_bloodmeteor") and caster:GetMana() < base then return 0 end
	return base
end

function rpg_lich_chain_frost:OnAbilityPhaseStart()
	local caster = self:GetCaster()
	self.hp_paid = false
	if HasPerk(caster, "m_meteor") and HasPerk(caster, "e_bloodmeteor") then
		local base = self:GetSpecialValueFor("mana_base")
		if base <= 0 then base = self.BaseClass.GetManaCost(self, -1) end
		if caster:GetMana() < base then
			if caster:GetHealth() <= caster:GetMaxHealth() * 0.15 + 1 then return false end   -- не хватает ни маны, ни здоровья
			self.hp_paid = true
		end
	end
	return true
end

rpg_lich_chain_frost.OnSpellStart = Guard("chain_frost:OnSpellStart", function(self)
	local caster = self:GetCaster()
	if HasPerk(caster, "m_meteor") then
		local target = self:GetCursorTarget()
		if not target or target:TriggerSpellAbsorb(self) then return end
		Lich:CastMeteor(caster, self, GetGroundPosition(target:GetAbsOrigin(), target), self.hp_paid)
		return
	end
	local target = self:GetCursorTarget()
	if not target or target:TriggerSpellAbsorb(self) then return end
	Lich:CastChain(caster, self, target)
end)

rpg_lich_chain_frost.OnProjectileHit_ExtraData = Guard("chain_frost:OnProjectileHit_ExtraData", function(self, target, location, extra)
	return Lich:OnBallHit(self, target, location, extra)
end)
