-- Постоянный скрытый модификатор Axe: таланты и пассивные эффекты перков.
-- (Значения, нужные клиенту, считаются из характеристик/способностей; перки читаются только на сервере.)
modifier_rpg_axe = class({})

function modifier_rpg_axe:IsHidden() return true end
function modifier_rpg_axe:IsPurgable() return false end
function modifier_rpg_axe:RemoveOnDeath() return false end
function modifier_rpg_axe:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end

local function talent(parent, key)
	local ab = parent:FindAbilityByName("special_bonus_rpg_axe_" .. key)
	if ab and ab:GetLevel() > 0 then return ab end
	return nil
end

local function has_perk(parent, id)
	return IsServer() and parent.rpg ~= nil and (parent.rpg.perk_count[id] or 0) > 0
end

function modifier_rpg_axe:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_MIN_HEALTH,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_EVENT_ON_DEATH,
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT, MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, MODIFIER_PROPERTY_STATS_AGILITY_BONUS, MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
	}
end

function modifier_rpg_axe:OnCreated()
	if IsServer() then self:StartIntervalThink(1) end
end

function modifier_rpg_axe:OnIntervalThink()
	local parent = self:GetParent()
	parent.rpg.inspiration_hunger_stacks = has_perk(parent, "l_inspiration") and Axe:HungerStacksOnArena(parent) or 0
	if has_perk(parent, "e_compensation") and parent:GetHealth() > parent:GetMaxHealth() * 0.60 then parent.rpg.compensation_ready = true end
	if not has_perk(parent, "e_impulse") then return end
	local now = GameRules:GetGameTime()
	if not parent.rpg.axe_impulse_next then parent.rpg.axe_impulse_next = now + 5; return end
	if now < parent.rpg.axe_impulse_next then return end
	parent.rpg.axe_impulse_next = now + 5
	local ability = parent:FindAbilityByName("rpg_axe_battle_hunger")
	if not ability or ability:GetLevel() < 1 then return end
	local enemies = Axe:Enemies(parent, parent:GetAbsOrigin(), 30000)
	local target, nearest = nil, 30000
	for _, enemy in ipairs(enemies) do
		local distance = (enemy:GetAbsOrigin() - parent:GetAbsOrigin()):Length2D()
		if distance < nearest then target, nearest = enemy, distance end
	end
	if target then Axe:ApplyHunger(parent, ability, target, false, true) end
end

function modifier_rpg_axe:GetModifierSpellAmplify_Percentage()
	local parent = self:GetParent()
	if not has_perk(parent, "l_inspiration") then return 0 end
	return (parent.rpg.inspiration_hunger_stacks or 0) * 5
end

-- Пассивные бонусы кастомного древа талантов Axe.
function modifier_rpg_axe:GetModifierAttackSpeedBonus_Constant()
	local t=talent(self:GetParent(), "5_as"); return t and self:GetParent():GetBaseAttackSpeed()*t:GetSpecialValueFor("value")/100 or 0
end
function modifier_rpg_axe:GetModifierMoveSpeedBonus_Percentage()
	local t=talent(self:GetParent(), "5_ms"); return t and t:GetSpecialValueFor("value") or 0
end
function modifier_rpg_axe:GetModifierBonusStats_Strength()
	local t=talent(self:GetParent(), "20_strength"); return t and t:GetSpecialValueFor("value") or 0
end
function modifier_rpg_axe:GetModifierBonusStats_Agility()
	local t=talent(self:GetParent(), "30_agi"); return t and t:GetSpecialValueFor("value") or 0
end
function modifier_rpg_axe:GetModifierBonusStats_Intellect()
	local t=talent(self:GetParent(), "30_int"); return t and t:GetSpecialValueFor("value") or 0
end
function modifier_rpg_axe:GetModifierMagicalResistanceBonus()
	local t=talent(self:GetParent(), "35_magic_armor")
	return t and math.floor(self:GetParent():GetPhysicalArmorValue(false)/5) * t:GetSpecialValueFor("value") or 0
end

-- Перк «Броненосец»: до +70 брони при 10% здоровья (линейно от 100% до 10%)
function modifier_rpg_axe:GetModifierPhysicalArmorBonus()
	local parent = self:GetParent()
	if not has_perk(parent, "e_ironclad") then return 0 end
	local C = Axe.C
	local pct = parent:GetHealth() / math.max(1, parent:GetMaxHealth())
	local f = (1 - pct) / (1 - C.IRON_HP_FLOOR)
	return C.IRON_MAX_ARMOR * math.min(1, math.max(0, f))
end

-- Перк «Ветеран»: пока перк готов, смертельный удар не убивает - успеет сработать Shallow Grave
function modifier_rpg_axe:GetMinHealth()
	local parent = self:GetParent()
	if has_perk(parent, "e_veteran") and (parent.rpg.vet_cd or 0) <= GameRules:GetGameTime() then return 1 end
	return 0
end

function modifier_rpg_axe:OnTakeDamage(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if p.unit == parent and has_perk(parent, "e_compensation") then
		local low = parent:GetHealth() <= parent:GetMaxHealth() * 0.60
		if not low then parent.rpg.compensation_ready = true end
		if low and parent.rpg.compensation_ready ~= false then
			parent.rpg.compensation_ready = false
			parent:AddNewModifier(parent, nil, "modifier_rpg_axe_compensation", { duration = 4 })
		end
	end

	-- Перк «Ветеран»
	if p.unit == parent and has_perk(parent, "e_veteran") and parent:IsAlive() then
		local C, now = Axe.C, GameRules:GetGameTime()
		if (parent.rpg.vet_cd or 0) <= now and parent:GetHealth() <= parent:GetMaxHealth() * C.VETERAN_HP then
			parent.rpg.vet_cd = now + C.VETERAN_CD
			parent:AddNewModifier(parent, nil, "modifier_rpg_shallow_grave", { duration = C.VETERAN_TIME })
			CustomGameEventManager:Send_ServerToAllClients("rpg_toast", { text = "Ветеран: Shallow Grave!", color = "#b050e0" })
		end
	end
end

-- Перк «Упорство»: воскрешение на месте гибели с оглушением вокруг
function modifier_rpg_axe:OnDeath(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if p.unit ~= parent or not has_perk(parent, "e_persist") then return end
	local C, now = Axe.C, GameRules:GetGameTime()
	if (parent.rpg.persist_cd or 0) > now then return end
	parent.rpg.persist_cd = now + C.PERSIST_CD
	parent.rpg.reviving = true
	local pos = parent:GetAbsOrigin()
	RPG.After(0.1, function()
		if parent:IsNull() then return end
		parent:RespawnHero(false, false)
		FindClearSpaceForUnit(parent, pos, true)
		parent:SetHealth(parent:GetMaxHealth())
		for _, e in ipairs(Axe:Enemies(parent, pos, C.PERSIST_RADIUS)) do
			e:AddNewModifier(parent, nil, "modifier_stunned", { duration = C.PERSIST_STUN })
		end
		parent.rpg.reviving = false
		CustomGameEventManager:Send_ServerToAllClients("rpg_toast", { text = "Упорство: герой возродился на месте гибели!", color = "#b050e0" })
	end)
end
