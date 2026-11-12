-- Скрытый постоянный модификатор героя: сюда сведены ВСЕ бонусы (перки, экипировка, сеты).
-- Значения передаются клиенту через Custom Transmitter Data (надёжно), NetTable оставлена как запасной канал для HUD.
modifier_rpg_stats = class({})

local EMPTY = {}

function modifier_rpg_stats:IsHidden() return true end
function modifier_rpg_stats:IsPurgable() return false end
function modifier_rpg_stats:RemoveOnDeath() return false end
function modifier_rpg_stats:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end

function modifier_rpg_stats:OnCreated()
	self.s = {}
	if IsServer() then self:SetHasCustomTransmitterData(true) end
end

-- Сервер -> клиент (плоская таблица чисел)
function modifier_rpg_stats:AddCustomTransmitterData()
	return self.s or {}
end

function modifier_rpg_stats:HandleCustomTransmitterData(data)
	self.s = data or {}
end

function modifier_rpg_stats:S()
	if IsServer() then return self.s or EMPTY end
	if self.s and next(self.s) ~= nil then return self.s end
	return CustomNetTables:GetTableValue("rpg_stats", tostring(self:GetParent():entindex())) or EMPTY
end

function modifier_rpg_stats:SetStats(t)
	local copy = {}
	for k, v in pairs(t) do copy[k] = v end
	self.s = copy
	if IsServer() then self:SendBuffRefreshToClients() end
end

function modifier_rpg_stats:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
		MODIFIER_PROPERTY_MANA_BONUS,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_rpg_stats:GetModifierPreAttack_BonusDamage() return self:S().damage or 0 end
function modifier_rpg_stats:GetModifierPhysicalArmorBonus() return self:S().armor or 0 end
function modifier_rpg_stats:GetModifierExtraHealthBonus() return self:S().hp or 0 end
function modifier_rpg_stats:GetModifierManaBonus() return self:S().mana or 0 end
function modifier_rpg_stats:GetModifierMoveSpeedBonus_Constant() return self:S().ms or 0 end
function modifier_rpg_stats:GetModifierAttackSpeedBonus_Constant() return self:S().as or 0 end
function modifier_rpg_stats:GetModifierSpellAmplify_Percentage() return self:S().spellamp or 0 end
function modifier_rpg_stats:GetModifierConstantHealthRegen() return self:S().hpregen or 0 end
function modifier_rpg_stats:GetModifierPercentageCooldown() return self:S().cdr or 0 end
function modifier_rpg_stats:GetModifierConstantManaRegen() return self:S().manaregen or 0 end

function modifier_rpg_stats:GetModifierPreAttack_CriticalStrike()
	if IsServer() and RandomFloat(0, 100) < (self:S().crit or 0) then
		return 175
	end
	return 0
end

function modifier_rpg_stats:OnAttackLanded(params)
	if not IsServer() then return end
	local parent = self:GetParent()
	if params.attacker ~= parent then return end
	local ls = self:S().lifesteal or 0
	if ls <= 0 or params.target:IsBuilding() or params.target:GetTeamNumber() == parent:GetTeamNumber() then return end
	parent:Heal(params.damage * ls / 100, parent)
end
