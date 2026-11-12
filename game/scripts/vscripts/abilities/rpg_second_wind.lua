rpg_second_wind = class({})

function rpg_second_wind:OnSpellStart()
	local caster = self:GetCaster()
	local pct = self:GetSpecialValueFor("heal_pct") / 100
	local allies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, self:GetSpecialValueFor("radius"),
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, a in ipairs(allies) do
		a:Heal(a:GetMaxHealth() * pct, caster)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, a, a:GetMaxHealth() * pct, nil)
	end
end
