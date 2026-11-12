-- Hoodwink custom ability wrappers; gameplay logic lives in game/heroes/hoodwink.lua.
local function perk(unit, id)
	return unit and unit.rpg and (unit.rpg.perk_count[id] or 0) > 0
end

rpg_hoodwink_acorn_shot = class({})
function rpg_hoodwink_acorn_shot:GetBehavior() return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET end
function rpg_hoodwink_acorn_shot:GetAbilityTargetTeam() return DOTA_UNIT_TARGET_TEAM_ENEMY end
function rpg_hoodwink_acorn_shot:GetAbilityTargetType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function rpg_hoodwink_acorn_shot:GetCastRange()
	local b = self:GetCaster().rpg and self:GetCaster().rpg.hoodwink_bonus or {}
	return self:GetSpecialValueFor("cast_range") + (b.acorn_range or 0)
end
function rpg_hoodwink_acorn_shot:OnSpellStart()
	if not IsServer() then return end
	local target = self:GetCursorTarget()
	if target and target:GetTeamNumber() ~= self:GetCaster():GetTeamNumber() then
		self:GetCaster():EmitSound("Hero_Hoodwink.AcornShot.Cast")
		Hoodwink:FireAcorn(self:GetCaster(), self, target)
	end
end
function rpg_hoodwink_acorn_shot:OnProjectileHit_ExtraData(target, _, extra) return Hoodwink:AcornHit(target, extra or {}) end

rpg_hoodwink_bushwhack = class({})
function rpg_hoodwink_bushwhack:GetBehavior() return DOTA_ABILITY_BEHAVIOR_POINT + DOTA_ABILITY_BEHAVIOR_AOE end
function rpg_hoodwink_bushwhack:GetAOERadius()
	local b = self:GetCaster().rpg and self:GetCaster().rpg.hoodwink_bonus or {}
	return self:GetSpecialValueFor("radius") + (b.bush_radius or 0) + (perk(self:GetCaster(), "e_wide_net") and 300 or 0)
end
function rpg_hoodwink_bushwhack:GetCastRange()
	local b = self:GetCaster().rpg and self:GetCaster().rpg.hoodwink_bonus or {}
	return self:GetSpecialValueFor("cast_range") + (b.bush_range or 0)
end
function rpg_hoodwink_bushwhack:OnSpellStart()
	if IsServer() then Hoodwink:CastBushwhack(self:GetCaster(), self, self:GetCursorPosition(), false) end
end
function rpg_hoodwink_bushwhack:OnProjectileHit_ExtraData(target, _, extra) return Hoodwink:BushwhackProjectileHit(target, extra or {}) end

rpg_hoodwink_scurry = class({})
function rpg_hoodwink_scurry:GetBehavior() return DOTA_ABILITY_BEHAVIOR_NO_TARGET end
function rpg_hoodwink_scurry:GetCooldown(level)
	local base = self.BaseClass.GetCooldown(self, level)
	return math.max(0, base - (self:GetCaster().rpg and self:GetCaster().rpg.hoodwink_bonus.scurry_cooldown or 0))
end
function rpg_hoodwink_scurry:OnSpellStart()
	if IsServer() then Hoodwink:CastScurry(self:GetCaster(), self, false) end
end

rpg_hoodwink_sharpshooter = class({})
function rpg_hoodwink_sharpshooter:GetHeroLevelRequiredToUpgrade()
	return 6 + math.max(0, self:GetLevel()) * 6
end
function rpg_hoodwink_sharpshooter:OnUpgrade()
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
function rpg_hoodwink_sharpshooter:GetBehavior() return DOTA_ABILITY_BEHAVIOR_POINT + DOTA_ABILITY_BEHAVIOR_CHANNELLED end
function rpg_hoodwink_sharpshooter:GetCooldown(level)
	local caster = self:GetCaster()
	local bonus = caster.rpg and caster.rpg.hoodwink_bonus.sharp_cooldown or 0
	return math.max(0, self.BaseClass.GetCooldown(self, level) - bonus)
end
function rpg_hoodwink_sharpshooter:OnSpellStart()
	if not IsServer() then return end
	self.channel_started_at = GameRules:GetGameTime()
	local caster = self:GetCaster()
	if perk(caster, "e_camouflage_shot") then
		local center = caster:GetAbsOrigin()
		for i = 1, 8 do
			local angle = (i - 1) * math.pi / 4
			CreateTempTree(center + Vector(math.cos(angle) * 140, math.sin(angle) * 140, 0), 4)
		end
	end
	caster:EmitSound("Hero_Hoodwink.Sharpshooter.Cast")
end
function rpg_hoodwink_sharpshooter:OnChannelThink()
	if not IsServer() then return end
	local caster, aim = self:GetCaster(), self:GetCursorPosition() - self:GetCaster():GetAbsOrigin()
	aim.z = 0
	if aim:Length2D() > 1 then caster:SetForwardVector(aim:Normalized()) end
end
function rpg_hoodwink_sharpshooter:OnChannelFinish(interrupted)
	if not IsServer() then return end
	local caster = self:GetCaster()
	caster:StopSound("Hero_Hoodwink.Sharpshooter.Cast")
	if not interrupted then
		local channel = GameRules:GetGameTime() - (self.channel_started_at or GameRules:GetGameTime())
		Hoodwink:CastSharpshooter(caster, self, self:GetCursorPosition(), channel)
	end
	RPG.After(0.05, function() if not caster:IsNull() then Hoodwink:UpdateDevilAbility(caster) end end)
end
function rpg_hoodwink_sharpshooter:OnProjectileHit_ExtraData(target, _, extra) return Hoodwink:SharpshooterHit(target, extra or {}) end
function rpg_hoodwink_sharpshooter:OnProjectileThink_ExtraData(location, extra) Hoodwink:SharpshooterThink(location, extra or {}) end

-- The Devil's Deal bypass lives in a separate ability slot so the normal
-- Sharpshooter can retain and display its real cooldown.
rpg_hoodwink_sharpshooter_devil = class({})
function rpg_hoodwink_sharpshooter_devil:GetHeroLevelRequiredToUpgrade()
	return 6 + math.max(0, self:GetLevel()) * 6
end
function rpg_hoodwink_sharpshooter_devil:GetBehavior() return DOTA_ABILITY_BEHAVIOR_POINT + DOTA_ABILITY_BEHAVIOR_CHANNELLED end
function rpg_hoodwink_sharpshooter_devil:GetCooldown() return 0 end
function rpg_hoodwink_sharpshooter_devil:OnAbilityPhaseStart()
	local caster = self:GetCaster()
	local main = caster:FindAbilityByName("rpg_hoodwink_sharpshooter")
	self.pay_health_on_finish = main and main:GetCooldownTimeRemaining() > 0
	return not self.pay_health_on_finish or caster:GetHealth() > 1
end
function rpg_hoodwink_sharpshooter_devil:OnSpellStart()
	if not IsServer() then return end
	self.channel_started_at = GameRules:GetGameTime()
	local caster = self:GetCaster()
	if perk(caster, "e_camouflage_shot") then
		local center = caster:GetAbsOrigin()
		for i = 1, 8 do
			local angle = (i - 1) * math.pi / 4
			CreateTempTree(center + Vector(math.cos(angle) * 140, math.sin(angle) * 140, 0), 4)
		end
	end
	caster:EmitSound("Hero_Hoodwink.Sharpshooter.Cast")
end
function rpg_hoodwink_sharpshooter_devil:OnChannelThink()
	if not IsServer() then return end
	local caster, aim = self:GetCaster(), self:GetCursorPosition() - self:GetCaster():GetAbsOrigin()
	aim.z = 0
	if aim:Length2D() > 1 then caster:SetForwardVector(aim:Normalized()) end
end
function rpg_hoodwink_sharpshooter_devil:OnChannelFinish(interrupted)
	if not IsServer() then return end
	local caster = self:GetCaster()
	caster:StopSound("Hero_Hoodwink.Sharpshooter.Cast")
	if not interrupted then
		if self.pay_health_on_finish then
			if caster:GetHealth() <= 1 then return end
			caster:SetHealth(math.max(1, caster:GetHealth() * 0.5))
		end
		local channel = GameRules:GetGameTime() - (self.channel_started_at or GameRules:GetGameTime())
		Hoodwink:CastSharpshooter(caster, self, self:GetCursorPosition(), channel)
	end
	RPG.After(0.05, function() if not caster:IsNull() then Hoodwink:UpdateDevilAbility(caster) end end)
end
function rpg_hoodwink_sharpshooter_devil:OnProjectileHit_ExtraData(target, _, extra) return Hoodwink:SharpshooterHit(target, extra or {}) end
function rpg_hoodwink_sharpshooter_devil:OnProjectileThink_ExtraData(location, extra) Hoodwink:SharpshooterThink(location, extra or {}) end
