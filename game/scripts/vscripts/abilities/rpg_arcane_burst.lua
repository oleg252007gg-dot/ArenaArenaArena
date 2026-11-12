rpg_arcane_burst = class({})

function rpg_arcane_burst:OnSpellStart()
	local caster = self:GetCaster()
	local radius = self:GetSpecialValueFor("radius")
	local damage = self:GetSpecialValueFor("damage") + caster:GetIntellect(false) * self:GetSpecialValueFor("int_scale")

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_crystal_maiden/maiden_crystal_nova.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:SetParticleControl(fx, 1, Vector(radius, 2, radius))
	ParticleManager:ReleaseParticleIndex(fx)
	EmitSoundOn("Hero_Crystal.CrystalNova", caster)

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, e in ipairs(enemies) do
		ApplyDamage({ victim = e, attacker = caster, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL, ability = self })
	end
end
