-- Уникальные эффекты артефактов боссов
local function enemies_at(unit, pos, radius)
	return FindUnitsInRadius(unit:GetTeamNumber(), pos, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
end

-- Общие настройки для скрытых модификаторов-артефактов
local function base_hidden(cls)
	function cls:IsHidden() return true end
	function cls:IsPurgable() return false end
	function cls:RemoveOnDeath() return false end
	function cls:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end
end

-- ===== Сердце голема: живучесть + сотрясение при тяжёлом ударе =====
modifier_rpg_art_golem_heart = class({})
base_hidden(modifier_rpg_art_golem_heart)
function modifier_rpg_art_golem_heart:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS, MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS, MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
end
function modifier_rpg_art_golem_heart:GetModifierExtraHealthBonus() return 1500 end
function modifier_rpg_art_golem_heart:GetModifierConstantHealthRegen() return 12 end
function modifier_rpg_art_golem_heart:GetModifierPhysicalArmorBonus() return 12 end
function modifier_rpg_art_golem_heart:GetModifierIncomingDamage_Percentage() return -10 end
function modifier_rpg_art_golem_heart:OnTakeDamage(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if p.unit ~= parent or p.damage < parent:GetMaxHealth() * 0.2 then return end
	local now = GameRules:GetGameTime()
	if (self.next_quake or 0) > now then return end
	self.next_quake = now + 10
	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", PATTACH_ABSORIGIN, parent)
	ParticleManager:ReleaseParticleIndex(fx)
	for _, e in ipairs(enemies_at(parent, parent:GetAbsOrigin(), 400)) do
		ApplyDamage({ victim = e, attacker = parent, damage = parent:GetMaxHealth() * 0.05, damage_type = DAMAGE_TYPE_MAGICAL })
		e:AddNewModifier(parent, nil, "modifier_stunned", { duration = 0.6 })
	end
end

-- ===== Дубина вожака: каждая 5-я атака бьёт по области =====
modifier_rpg_art_ogre_club = class({})
base_hidden(modifier_rpg_art_ogre_club)
function modifier_rpg_art_ogre_club:DeclareFunctions()
	return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE, MODIFIER_EVENT_ON_ATTACK_LANDED }
end
function modifier_rpg_art_ogre_club:GetModifierPreAttack_BonusDamage() return 120 end
function modifier_rpg_art_ogre_club:OnAttackLanded(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if p.attacker ~= parent or p.target:IsBuilding() then return end
	self.count = (self.count or 0) + 1
	if self.count < 5 then return end
	self.count = 0
	local pos = p.target:GetAbsOrigin()
	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, pos)
	ParticleManager:ReleaseParticleIndex(fx)
	local dmg = parent:GetAverageTrueAttackDamage(p.target) * 1.5
	for _, e in ipairs(enemies_at(parent, pos, 300)) do
		ApplyDamage({ victim = e, attacker = parent, damage = dmg, damage_type = DAMAGE_TYPE_PURE })
	end
end

-- ===== Тотем короля троллей: стаки урона за убийства =====
modifier_rpg_art_troll_totem = class({})
base_hidden(modifier_rpg_art_troll_totem)
function modifier_rpg_art_troll_totem:DeclareFunctions() return { MODIFIER_EVENT_ON_DEATH } end
function modifier_rpg_art_troll_totem:OnDeath(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if p.attacker ~= parent or p.unit:GetTeamNumber() == parent:GetTeamNumber() then return end
	parent:AddNewModifier(parent, self:GetAbility(), "modifier_rpg_totem_stacks", { duration = 15 })
	parent:Heal(parent:GetMaxHealth() * 0.02, parent)
	local fx=ParticleManager:CreateParticle("particles/items_fx/bloodstone_heal.vpcf",PATTACH_ABSORIGIN_FOLLOW,parent); ParticleManager:ReleaseParticleIndex(fx)
end

modifier_rpg_totem_stacks = class({})
function modifier_rpg_totem_stacks:IsHidden() return false end
function modifier_rpg_totem_stacks:IsPurgable() return false end
function modifier_rpg_totem_stacks:GetTexture() return "item_necronomicon" end
function modifier_rpg_totem_stacks:OnCreated() if IsServer() then self:SetStackCount(1) end end
function modifier_rpg_totem_stacks:OnRefresh() if IsServer() then self:SetStackCount(math.min(self:GetStackCount() + 1, 40)) end end
function modifier_rpg_totem_stacks:DeclareFunctions() return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE } end
function modifier_rpg_totem_stacks:GetModifierPreAttack_BonusDamage() return self:GetStackCount() * 4 end

-- ===== Вуаль призрачного лорда: уклонение с контрударом =====
modifier_rpg_art_ghost_veil = class({})
base_hidden(modifier_rpg_art_ghost_veil)
function modifier_rpg_art_ghost_veil:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_EVASION_CONSTANT, MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS, MODIFIER_EVENT_ON_ATTACK_FAIL,
	}
end
function modifier_rpg_art_ghost_veil:GetModifierEvasion_Constant() return 25 end
function modifier_rpg_art_ghost_veil:GetModifierMoveSpeedBonus_Constant() return 40 end
function modifier_rpg_art_ghost_veil:GetModifierMagicalResistanceBonus() return 20 end
function modifier_rpg_art_ghost_veil:OnAttackFail(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if p.target ~= parent or not p.attacker or p.attacker:IsNull() or not p.attacker:IsAlive() then return end
	ApplyDamage({ victim = p.attacker, attacker = parent, damage = parent:GetAverageTrueAttackDamage(p.attacker) * 1.5, damage_type = DAMAGE_TYPE_PURE })
	local fx=ParticleManager:CreateParticle("particles/units/heroes/hero_axe/axe_attack_blur_counterhelix.vpcf",PATTACH_ABSORIGIN_FOLLOW,p.attacker); ParticleManager:ReleaseParticleIndex(fx)
end

-- ===== Осколок бури (пассив; активная способность в предмете) =====
modifier_rpg_art_storm_shard = class({})
base_hidden(modifier_rpg_art_storm_shard)
function modifier_rpg_art_storm_shard:DeclareFunctions()
	return { MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE, MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE }
end
function modifier_rpg_art_storm_shard:GetModifierSpellAmplify_Percentage() return 30 end
function modifier_rpg_art_storm_shard:GetModifierPercentageCooldown() return 20 end

-- ===== Рог вождя (пассив + бафф на союзников) =====
modifier_rpg_art_war_horn = class({})
base_hidden(modifier_rpg_art_war_horn)
function modifier_rpg_art_war_horn:DeclareFunctions() return { MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT } end
function modifier_rpg_art_war_horn:GetModifierAttackSpeedBonus_Constant() return 30 end

modifier_rpg_warhorn_buff = class({})
function modifier_rpg_warhorn_buff:IsHidden() return false end
function modifier_rpg_warhorn_buff:IsPurgable() return true end
function modifier_rpg_warhorn_buff:GetTexture() return "item_ancient_janggo" end
function modifier_rpg_warhorn_buff:DeclareFunctions()
	return { MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT, MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT, MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE }
end
function modifier_rpg_warhorn_buff:GetModifierAttackSpeedBonus_Constant() return 80 end
function modifier_rpg_warhorn_buff:GetModifierMoveSpeedBonus_Constant() return 40 end
function modifier_rpg_warhorn_buff:GetModifierDamageOutgoing_Percentage() return 20 end
function modifier_rpg_warhorn_buff:GetEffectName() return "particles/units/heroes/hero_axe/axe_beserkers_call_owner.vpcf" end
function modifier_rpg_warhorn_buff:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

-- ===== Эгида бессмертных: второй шанс =====
modifier_rpg_art_aegis = class({})
base_hidden(modifier_rpg_art_aegis)
function modifier_rpg_art_aegis:DeclareFunctions()
	return { MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS, MODIFIER_PROPERTY_MIN_HEALTH, MODIFIER_EVENT_ON_TAKEDAMAGE }
end
function modifier_rpg_art_aegis:OnCreated()
	if IsServer() then self.ready = true end
end
function modifier_rpg_art_aegis:GetModifierExtraHealthBonus() return 500 end
function modifier_rpg_art_aegis:GetMinHealth()
	if IsServer() and self.ready then return 1 end
	return 0
end
function modifier_rpg_art_aegis:OnTakeDamage(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if p.unit ~= parent or not self.ready or parent:GetHealth() > 1 then return end
	self.ready = false
	parent:SetHealth(parent:GetMaxHealth() * 0.6)
	local fx=ParticleManager:CreateParticle("particles/items_fx/bloodstone_heal.vpcf",PATTACH_ABSORIGIN_FOLLOW,parent); ParticleManager:ReleaseParticleIndex(fx)
	parent:AddNewModifier(parent, nil, "modifier_invulnerable", { duration = 2.5 })
	CustomGameEventManager:Send_ServerToAllClients("rpg_toast", { text = "Эгида бессмертных спасла героя!", color = "#ffd24a" })
	self:StartIntervalThink(90)
end
function modifier_rpg_art_aegis:OnIntervalThink()
	self.ready = true
	self:StartIntervalThink(-1)
end

-- Fourteen additional boss relics. Each keeps its damage/armor bonus and has
-- a separate gameplay proc; the hit particles are only the visual presentation.
modifier_rpg_art_boss_unique = class({})
function modifier_rpg_art_boss_unique:IsHidden() return true end
function modifier_rpg_art_boss_unique:IsPurgable() return false end
function modifier_rpg_art_boss_unique:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

local BOSS_RELICS = {
	item_rpg_art_dragonheart = { damage=65, armor=8, particle="particles/units/heroes/hero_jakiro/jakiro_liquid_fire_explosion.vpcf", proc="fire_fifth" },
	item_rpg_art_frostcrown = { damage=70, armor=9, particle="particles/units/heroes/hero_lich/lich_frost_nova.vpcf", proc="frost_chance" },
	item_rpg_art_abyssallens = { damage=75, armor=10, particle="particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", proc="spell_echo" },
	item_rpg_art_infernalcore = { damage=80, armor=11, particle="particles/units/heroes/hero_batrider/batrider_firefly.vpcf", proc="spell_amp" },
	item_rpg_art_webspinner = { damage=85, armor=12, particle="particles/units/heroes/hero_hoodwink/hoodwink_bushwhack.vpcf", proc="web_stun" },
	item_rpg_art_tempestcoil = { damage=90, armor=8, particle="particles/units/heroes/hero_zuus/zuus_lightning_bolt_start.vpcf", proc="lightning_third" },
	item_rpg_art_boneidol = { damage=95, armor=9, particle="particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", proc="bone_guard" },
	item_rpg_art_venomheart = { damage=100, armor=10, particle="particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf", proc="venom_fifth" },
	item_rpg_art_moonshard = { damage=105, armor=11, particle="particles/items2_fx/mask_of_madness.vpcf", proc="moon_haste" },
	item_rpg_art_plaguevial = { damage=110, armor=12, particle="particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf", proc="plague_death" },
	item_rpg_art_ironmaul = { damage=115, armor=8, particle="particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", proc="iron_sixth" },
	item_rpg_art_starseed = { damage=120, armor=9, particle="particles/units/heroes/hero_batrider/batrider_firefly.vpcf", proc="star_casts" },
	item_rpg_art_sandglass = { damage=125, armor=10, particle="particles/units/heroes/hero_alchemist/alchemist_acid_spray.vpcf", proc="sand_kills" },
	item_rpg_art_voidcrown = { damage=130, armor=11, particle="particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", proc="void_burst" },
}
local function relic_fx(path, unit)
	if not path or not unit or unit:IsNull() then return end
	local fx=ParticleManager:CreateParticle(path,PATTACH_WORLDORIGIN,nil)
	ParticleManager:SetParticleControl(fx,0,unit:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(fx)
end
local function relic_enemies(parent, pos, radius)
	return FindUnitsInRadius(parent:GetTeamNumber(),pos,nil,radius,DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO+DOTA_UNIT_TARGET_BASIC,DOTA_UNIT_TARGET_FLAG_NONE,FIND_ANY_ORDER,false)
end
function modifier_rpg_art_boss_unique:OnCreated()
	if not IsServer() then return end
	local item=self:GetAbility()
	self.profile=item and BOSS_RELICS[item:GetAbilityName()] or nil
	self.hits=0; self.spells=0; self.next_proc=0
end
function modifier_rpg_art_boss_unique:DeclareFunctions()
	return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE, MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_EVENT_ON_ATTACK_LANDED, MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_EVENT_ON_ABILITY_EXECUTED, MODIFIER_EVENT_ON_DEATH }
end
function modifier_rpg_art_boss_unique:GetModifierPreAttack_BonusDamage() return self.profile and self.profile.damage or 0 end
function modifier_rpg_art_boss_unique:GetModifierPhysicalArmorBonus() return self.profile and self.profile.armor or 0 end
function modifier_rpg_art_boss_unique:OnAttackLanded(p)
	if not IsServer() or not self.profile or p.attacker~=self:GetParent() or not p.target or p.target:IsNull() or p.target:GetTeamNumber()==p.attacker:GetTeamNumber() then return end
	local parent,target,proc=self:GetParent(),p.target,self.profile.proc
	self.hits=self.hits+1
	if proc=="fire_fifth" and self.hits%5==0 then
		local pos=target:GetAbsOrigin(); local dmg=parent:GetAverageTrueAttackDamage(target)*1.5
		for _,enemy in ipairs(relic_enemies(parent,pos,325)) do ApplyDamage({victim=enemy,attacker=parent,damage=dmg,damage_type=DAMAGE_TYPE_MAGICAL}) end
		relic_fx(self.profile.particle,target)
	elseif proc=="frost_chance" and RandomFloat(0,100)<25 then
		target:AddNewModifier(parent,self:GetAbility(),"modifier_rpg_slow",{duration=3,slow=35})
		target:AddNewModifier(parent,self:GetAbility(),"modifier_rpg_as_slow",{duration=3,slow=45})
		relic_fx(self.profile.particle,target)
	elseif proc=="web_stun" and self.hits%5==0 then
		target:AddNewModifier(parent,self:GetAbility(),"modifier_stunned",{duration=1.1})
		relic_fx(self.profile.particle,target)
	elseif proc=="lightning_third" and self.hits%3==0 then
		local pos=target:GetAbsOrigin(); local list=relic_enemies(parent,pos,525); local chained=0
		for _,enemy in ipairs(list) do if enemy~=target and chained<3 then
			chained=chained+1; ApplyDamage({victim=enemy,attacker=parent,damage=120+((Waves and Waves.wave or 1)*15)+parent:GetAttackDamage()*0.25,damage_type=DAMAGE_TYPE_MAGICAL})
			relic_fx(self.profile.particle,enemy)
		end end
	elseif proc=="venom_fifth" and self.hits%5==0 then
		target:AddNewModifier(parent,self:GetAbility(),"modifier_rpg_axe_bleed",{duration=4,pct=1.5})
		target:AddNewModifier(parent,self:GetAbility(),"modifier_rpg_slow",{duration=4,slow=25})
		relic_fx(self.profile.particle,target)
	elseif proc=="moon_haste" and GameRules:GetGameTime()>=(self.next_proc or 0) then
		self.next_proc=GameRules:GetGameTime()+12
		parent:AddNewModifier(parent,self:GetAbility(),"modifier_rpg_art_moon_haste",{duration=4})
		relic_fx(self.profile.particle,parent)
	elseif proc=="iron_sixth" and self.hits%6==0 then
		local pos=target:GetAbsOrigin(); local dmg=parent:GetAverageTrueAttackDamage(target)
		for _,enemy in ipairs(relic_enemies(parent,pos,300)) do
			ApplyDamage({victim=enemy,attacker=parent,damage=dmg,damage_type=DAMAGE_TYPE_PURE})
			if enemy==target then enemy:AddNewModifier(parent,self:GetAbility(),"modifier_stunned",{duration=0.65}) end
		end
		relic_fx(self.profile.particle,target)
	end
end
function modifier_rpg_art_boss_unique:OnTakeDamage(p)
	if not IsServer() or not self.profile then return end
	local parent,proc=self:GetParent(),self.profile.proc
	if proc=="spell_echo" and p.attacker==parent and p.unit and p.unit:GetTeamNumber()~=parent:GetTeamNumber() and p.inflictor and p.damage_type==DAMAGE_TYPE_MAGICAL and GameRules:GetGameTime()>=(self.next_proc or 0) then
		self.next_proc=GameRules:GetGameTime()+6
		ApplyDamage({victim=p.unit,attacker=parent,damage=p.damage*0.20,damage_type=DAMAGE_TYPE_MAGICAL})
		parent:Heal(p.damage*0.10,parent); relic_fx(self.profile.particle,p.unit)
	elseif proc=="bone_guard" and p.unit==parent and parent:IsAlive() and parent:GetHealth()<=parent:GetMaxHealth()*0.4 and GameRules:GetGameTime()>=(self.next_proc or 0) then
		self.next_proc=GameRules:GetGameTime()+30
		parent:AddNewModifier(parent,self:GetAbility(),"modifier_rpg_art_bone_guard",{duration=4})
		relic_fx(self.profile.particle,parent)
	elseif proc=="void_burst" and p.unit==parent and p.attacker and p.attacker:GetTeamNumber()~=parent:GetTeamNumber() and GameRules:GetGameTime()>=(self.next_proc or 0) then
		self.next_proc=GameRules:GetGameTime()+10
		local pos=parent:GetAbsOrigin()
		for _,enemy in ipairs(relic_enemies(parent,pos,450)) do
			ApplyDamage({victim=enemy,attacker=parent,damage=150+((Waves and Waves.wave or 1)*25),damage_type=DAMAGE_TYPE_MAGICAL})
			enemy:AddNewModifier(parent,self:GetAbility(),"modifier_rpg_boss_control",{duration=1.25,disarm=1})
		end
		relic_fx(self.profile.particle,parent)
	end
end
function modifier_rpg_art_boss_unique:OnAbilityExecuted(p)
	if not IsServer() or not self.profile or p.unit~=self:GetParent() or not p.ability or p.ability:IsItem() then return end
	local parent,proc=self:GetParent(),self.profile.proc
	if proc=="spell_echo" and GameRules:GetGameTime()>=(self.next_proc or 0) then
		-- Abyssal Lens's spell echo is handled on damage; no cast proc here.
	elseif proc=="spell_amp" and GameRules:GetGameTime()>=(self.next_proc or 0) then
		self.next_proc=GameRules:GetGameTime()+12
		parent:AddNewModifier(parent,self:GetAbility(),"modifier_rpg_art_infernal_amp",{duration=5})
		relic_fx(self.profile.particle,parent)
	elseif proc=="star_casts" then
		self.spells=self.spells+1
		if self.spells%4==0 then
			parent:GiveMana(parent:GetMaxMana()*0.10)
			parent:AddNewModifier(parent,self:GetAbility(),"modifier_rpg_art_infernal_amp",{duration=4})
			relic_fx(self.profile.particle,parent)
		end
	end
end
function modifier_rpg_art_boss_unique:OnDeath(p)
	if not IsServer() or not self.profile then return end
	local parent,dead,proc=self:GetParent(),p.unit,self.profile.proc
	if p.attacker~=parent or not dead or dead:GetTeamNumber()==parent:GetTeamNumber() then return end
	if proc=="sand_kills" then
		for index=0,23 do
			local ability=parent:GetAbilityByIndex(index)
			if ability and not ability:IsItem() and ability:GetLevel()>0 and not ability:IsCooldownReady() then
				local remaining=ability:GetCooldownTimeRemaining()
				ability:EndCooldown()
				if remaining>1 then ability:StartCooldown(remaining-1) end
			end
		end
		local pos=dead:GetAbsOrigin(); local fx=ParticleManager:CreateParticle(self.profile.particle,PATTACH_WORLDORIGIN,nil)
		ParticleManager:SetParticleControl(fx,0,pos); ParticleManager:ReleaseParticleIndex(fx)
	elseif proc=="plague_death" then
		local pos=dead:GetAbsOrigin(); local dmg=200+((Waves and Waves.wave or 1)*20)
		for _,enemy in ipairs(relic_enemies(parent,pos,375)) do
			ApplyDamage({victim=enemy,attacker=parent,damage=dmg,damage_type=DAMAGE_TYPE_MAGICAL})
			enemy:AddNewModifier(parent,self:GetAbility(),"modifier_rpg_slow",{duration=3,slow=35})
		end
		relic_fx(self.profile.particle,dead)
	end
end

modifier_rpg_art_bone_guard=class({})
function modifier_rpg_art_bone_guard:IsPurgable() return false end
function modifier_rpg_art_bone_guard:GetTexture() return "item_vanguard" end
function modifier_rpg_art_bone_guard:DeclareFunctions() return {MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE} end
function modifier_rpg_art_bone_guard:GetModifierIncomingDamage_Percentage() return -35 end
function modifier_rpg_art_bone_guard:GetEffectName() return "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf" end
function modifier_rpg_art_bone_guard:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

modifier_rpg_art_infernal_amp=class({})
function modifier_rpg_art_infernal_amp:IsPurgable() return true end
function modifier_rpg_art_infernal_amp:GetTexture() return "item_radiance" end
function modifier_rpg_art_infernal_amp:DeclareFunctions() return {MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE} end
function modifier_rpg_art_infernal_amp:GetModifierSpellAmplify_Percentage() return 15 end
function modifier_rpg_art_infernal_amp:GetEffectName() return "particles/units/heroes/hero_batrider/batrider_firefly.vpcf" end
function modifier_rpg_art_infernal_amp:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

modifier_rpg_art_moon_haste=class({})
function modifier_rpg_art_moon_haste:IsPurgable() return true end
function modifier_rpg_art_moon_haste:GetTexture() return "item_moon_shard" end
function modifier_rpg_art_moon_haste:DeclareFunctions() return {MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE} end
function modifier_rpg_art_moon_haste:GetModifierAttackSpeedBonus_Constant() return 100 end
function modifier_rpg_art_moon_haste:GetModifierMoveSpeedBonus_Percentage() return 20 end
function modifier_rpg_art_moon_haste:GetEffectName() return "particles/items2_fx/mask_of_madness.vpcf" end
function modifier_rpg_art_moon_haste:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
