-- Sven's four custom active/passive abilities.
local function perk(hero, id) return Sven and Sven:Has(hero, id) end
local function bonus(hero, id) return Sven and Sven:Bonus(hero, id) or 0 end

rpg_sven_storm_hammer = class({})
function rpg_sven_storm_hammer:GetCastRange(location, target)
	return self.BaseClass.GetCastRange(self, location, target) + bonus(self:GetCaster(),"hammer_range")
end
function rpg_sven_storm_hammer:GetCooldown(level)
	local cd=self.BaseClass.GetCooldown(self,level)
	return cd*(perk(self:GetCaster(),"e_sven_hammer_cooldown") and 0.8 or 1)
end
function rpg_sven_storm_hammer:OnSpellStart()
	if not IsServer() then return end
	local caster, target = self:GetCaster(), self:GetCursorTarget()
	if not target or target:IsNull() or not target:IsAlive() or target:TriggerSpellAbsorb(self) then return end
	caster:StartGesture(ACT_DOTA_CAST_ABILITY_1)
	ProjectileManager:CreateTrackingProjectile({Target=target,Source=caster,Ability=self,
		EffectName="particles/units/heroes/hero_sven/sven_spell_storm_bolt.vpcf",iMoveSpeed=1400,
		bDodgeable=true,bVisibleToEnemies=true,bProvidesVision=false})
	EmitSoundOn("Hero_Sven.StormBolt", caster)
	local delay = math.max(0.12, (target:GetAbsOrigin()-caster:GetAbsOrigin()):Length2D()/1400)
	RPG.After(delay, function()
		if not IsValidEntity(target) or target:IsNull() or not target:IsAlive() then return end
		local damage = self:GetSpecialValueFor("damage") + bonus(caster,"hammer_damage") + (perk(caster,"e_sven_hammer_damage") and 250 or 0)
		if perk(caster,"m_sven_hammer") or caster:HasScepter() then
			local victims = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, self:GetSpecialValueFor("blast_radius"), DOTA_UNIT_TARGET_TEAM_ENEMY,
				DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
			local n = 0
			for _, enemy in ipairs(victims) do
				if enemy:IsAlive() and n < (perk(caster,"l_sven_storm_chain") and 4 or 99) then
					n=n+1
					local impact_damage = damage
					if caster:HasScepter() and not perk(caster,"m_sven_hammer") and enemy ~= target then impact_damage = damage * 0.75 end
					ApplyDamage({victim=enemy,attacker=caster,ability=self,damage=impact_damage,damage_type=DAMAGE_TYPE_MAGICAL})
					local stun = self:GetSpecialValueFor("stun") + (perk(caster,"l_sven_storm_stun") and 1 or 0)
					if caster:HasScepter() and enemy ~= target then stun = stun * 0.5 end
					enemy:AddNewModifier(caster,self,"modifier_stunned",{duration=stun})
					if perk(caster,"e_sven_hammer_heal") then caster:Heal(caster:GetMaxHealth()*0.02,caster) end
				end
			end
			local fx=ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_spell_storm_bolt.vpcf",PATTACH_WORLDORIGIN,nil); ParticleManager:SetParticleControl(fx,0,target:GetAbsOrigin()); ParticleManager:ReleaseParticleIndex(fx)
		else
			ApplyDamage({victim=target,attacker=caster,ability=self,damage=damage,damage_type=DAMAGE_TYPE_MAGICAL})
			target:AddNewModifier(caster,self,"modifier_stunned",{duration=self:GetSpecialValueFor("stun")})
			if perk(caster,"e_sven_hammer_heal") then caster:Heal(caster:GetMaxHealth()*0.02,caster) end
		end
		EmitSoundOn("Hero_Sven.StormBoltImpact",target)
	end)
end

rpg_sven_great_cleave = class({})
function rpg_sven_great_cleave:GetIntrinsicModifierName() return "modifier_rpg_sven_cleave" end

rpg_sven_warcry = class({})
function rpg_sven_warcry:GetCooldown(level)
	local cd=self.BaseClass.GetCooldown(self,level)
	return cd*(perk(self:GetCaster(),"e_sven_warcry_cooldown") and 0.75 or 1)
end
function rpg_sven_warcry:OnSpellStart()
	if not IsServer() then return end
	local caster=self:GetCaster(); caster:StartGesture(ACT_DOTA_CAST_ABILITY_2)
	local duration=self:GetSpecialValueFor("duration")+bonus(caster,"warcry_duration")+(perk(caster,"l_sven_warcry_duration") and 3 or 0)
	local radius=self:GetSpecialValueFor("radius")
	local allies=FindUnitsInRadius(caster:GetTeamNumber(),caster:GetAbsOrigin(),nil,radius,DOTA_UNIT_TARGET_TEAM_FRIENDLY,DOTA_UNIT_TARGET_HERO,DOTA_UNIT_TARGET_FLAG_NONE,FIND_ANY_ORDER,false)
	for _,ally in ipairs(allies) do ally:AddNewModifier(caster,self,"modifier_rpg_sven_warcry",{duration=duration}) end
	EmitSoundOn("Hero_Sven.WarCry",caster)
	local fx=ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_spell_warcry.vpcf",PATTACH_ABSORIGIN_FOLLOW,caster); ParticleManager:ReleaseParticleIndex(fx)
end

rpg_sven_gods_strength = class({})
function rpg_sven_gods_strength:GetHeroLevelRequiredToUpgrade() return 6 + math.max(0,self:GetLevel())*6 end
function rpg_sven_gods_strength:OnUpgrade()
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
function rpg_sven_gods_strength:GetCooldown(level) return math.max(5,self.BaseClass.GetCooldown(self,level)-bonus(self:GetCaster(),"strength_cooldown")) end
function rpg_sven_gods_strength:OnSpellStart()
	if not IsServer() then return end
	local caster=self:GetCaster(); caster:StartGesture(ACT_DOTA_CAST_ABILITY_4)
	local duration=self:GetSpecialValueFor("duration")+(perk(caster,"e_sven_strength_duration") and 4 or 0)
	caster:AddNewModifier(caster,self,"modifier_rpg_sven_gods_strength",{duration=duration})
	if perk(caster,"e_sven_strength_heal") then caster:Heal(caster:GetMaxHealth()*0.2,caster) end
	EmitSoundOn("Hero_Sven.GodsStrength",caster)
	local fx=ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_spell_gods_strength.vpcf",PATTACH_ABSORIGIN_FOLLOW,caster); ParticleManager:ReleaseParticleIndex(fx)
end

function rpg_sven_storm_hammer:OnProjectileHit(target)
	-- The timed impact is authoritative; the projectile is only the visible travel cue.
	return true
end
