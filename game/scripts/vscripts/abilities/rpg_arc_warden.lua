-- Arc Warden custom abilities. Server gameplay is implemented in compact Lua
-- modifiers so the wave mode can tune each skill through perk state.
local function bonus(caster, key)
	if not caster then return 0 end
	if IsServer() then return caster.rpg and caster.rpg.arc_bonus and caster.rpg.arc_bonus[key] or 0 end
	local t=CustomNetTables:GetTableValue("rpg_perks",tostring(caster:entindex()))
	return t and t["bonus_arc_"..key] or 0
end
local function has(caster, id)
	if not caster then return false end
	if IsServer() then return caster.rpg and (caster.rpg.perk_count[id] or 0)>0 end
	local t=CustomNetTables:GetTableValue("rpg_perks",tostring(caster:entindex()))
	return t and (t[id] or 0)>0 or false
end
local function setup_clone(caster, clone)
	clone.rpg_arc_owner=caster
	clone.rpg={perk_count=caster.rpg.perk_count,arc_bonus=caster.rpg.arc_bonus,perk_stats=caster.rpg.perk_stats,spent=caster.rpg.spent,axe_bonus={},hoodwink_bonus={}}
	clone:AddNewModifier(caster,nil,"modifier_rpg_stats",{})
	local stats=clone:FindModifierByName("modifier_rpg_stats")
	if stats then stats:SetStats(caster.rpg.perk_stats or {}) end
	while clone:GetLevel()<caster:GetLevel() do clone:HeroLevelUp(false) end
	clone:ModifyStrength(caster:GetStrength()-clone:GetStrength()); clone:ModifyAgility(caster:GetAgility()-clone:GetAgility()); clone:ModifyIntellect(caster:GetIntellect()-clone:GetIntellect())
	clone:CalculateStatBonus(true)
	Perks:Sync(clone)
end

local function setup_temporary_double(caster, clone)
	clone.rpg_arc_owner = caster
	clone.rpg = {
		perk_count = caster.rpg.perk_count,
		arc_bonus = caster.rpg.arc_bonus,
		perk_stats = caster.rpg.perk_stats,
		spent = caster.rpg.spent,
		axe_bonus = {},
		hoodwink_bonus = {},
	}
	clone:SetHasInventory(true)
	clone:SetOwner(caster)
	clone:SetControllableByPlayer(caster:GetPlayerOwnerID(), true)
	-- A normal Tempest Double is still an Arc Warden hero. Copy hero level
	-- before stats/abilities so it does not inherit the old level-5 creep stub.
	while clone:GetLevel() < caster:GetLevel() do clone:HeroLevelUp(false) end
	clone:SetAbilityPoints(0)
	clone:SetBaseMaxHealth(caster:GetBaseMaxHealth())
	clone:SetMaxHealth(caster:GetMaxHealth())
	clone:SetHealth(caster:GetHealth())
	clone:SetMana(caster:GetMana())
	clone:SetBaseDamageMin(caster:GetBaseDamageMin())
	clone:SetBaseDamageMax(caster:GetBaseDamageMax())
	clone:SetBaseMoveSpeed(caster:GetBaseMoveSpeed())
	clone:SetRenderColor(150, 195, 255)
	local stats = clone:AddNewModifier(caster, nil, "modifier_rpg_stats", {})
	if stats then stats:SetStats(caster.rpg.perk_stats or {}) end
	for _, attr in ipairs({"Strength", "Agility", "Intellect"}) do
		pcall(function() clone["Modify" .. attr](clone, caster["Get" .. attr](caster) - clone["Get" .. attr](clone)) end)
	end
	clone:CalculateStatBonus(true)
	clone:SetBaseMaxHealth(caster:GetBaseMaxHealth())
	clone:SetMaxHealth(caster:GetMaxHealth())
	clone:SetHealth(math.min(caster:GetHealth(), clone:GetMaxHealth()))
	clone:SetMaxMana(caster:GetMaxMana())
	clone:SetMana(math.min(caster:GetMana(), clone:GetMaxMana()))
	Perks:Sync(clone)
end

local DORMANT_OBLIVION_WEARABLES = {
	{"models/items/arc_warden/ti9_cache_aw_ancient_mechanism_arms/ti9_cache_aw_ancient_mechanism_arms.vmdl", "attach_arms"},
	{"models/items/arc_warden/ti9_cache_aw_ancient_mechanism_back/ti9_cache_aw_ancient_mechanism_back.vmdl", "attach_back"},
	{"models/items/arc_warden/ti9_cache_aw_ancient_mechanism_head/ti9_cache_aw_ancient_mechanism_head.vmdl", "attach_head"},
	{"models/items/arc_warden/ti9_cache_aw_ancient_mechanism_shoulder/ti9_cache_aw_ancient_mechanism_shoulder.vmdl", "attach_shoulder"},
}

local function dress_temporary_double(clone)
	if not clone or clone:IsNull() or clone.rpg_dormant_oblivion_applied then return end
	clone.rpg_dormant_oblivion_applied = true
	clone.rpg_dormant_oblivion_parts = {}
	for _, part in ipairs(DORMANT_OBLIVION_WEARABLES) do
		local wearable = SpawnEntityFromTableSynchronous("prop_dynamic", {model = part[1]})
		if wearable then
			wearable:SetParent(clone, part[2])
			wearable:SetModelScale(1.0)
			clone.rpg_dormant_oblivion_parts[#clone.rpg_dormant_oblivion_parts + 1] = wearable
		end
	end
end

local function spark_wraith_hit_effect(target)
	if not target or target:IsNull() then return end
	local impact = ParticleManager:CreateParticle("particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj_hit.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:ReleaseParticleIndex(impact)
	EmitSoundOn("Hero_ArcWarden.SparkWraith.Damage", target)
end

local function deal_spark_wraith_hit(caster, ability, target, radius)
	if not target or target:IsNull() or not target:IsAlive() then return end
	local state = caster.rpg or {}
	local perks = state.perk_count or {}
	local bonuses = state.arc_bonus or {}
	local level = math.max(1, math.min(4, ability:GetLevel()))
	local damage_by_level = {150, 225, 300, 375}
	local damage_value = ability:GetSpecialValueFor("damage")
	if not damage_value or damage_value <= 0 then damage_value = damage_by_level[level] end
	local damage = (damage_value + (bonuses.wraith_damage or 0) + caster:GetIntellect() * 0.4) * (caster:HasScepter() and 1.25 or 1)
	if (perks.e_wraith_age or 0) > 0 then damage = damage * (1 + math.floor(GameRules:GetGameTime() / 300) * 0.1) end
	if target:HasModifier("modifier_rpg_arc_wraith_mark") then damage = damage * 1.2 end
	local dealt = ApplyDamage({victim=target, attacker=caster, ability=ability, damage=damage, damage_type=DAMAGE_TYPE_MAGICAL})
	local slow_duration = ability:GetSpecialValueFor("slow_duration")
	local slow_amount = ability:GetSpecialValueFor("movement_slow")
	if not slow_duration or slow_duration <= 0 then slow_duration = ({0.7, 0.8, 0.9, 1})[level] end
	if not slow_amount or slow_amount <= 0 then slow_amount = 100 end
	target:AddNewModifier(caster, ability, "modifier_rpg_slow", {duration=slow_duration, slow=slow_amount})
	if (perks.e_wraith_int or 0) > 0 then ApplyDamage({victim=target, attacker=caster, ability=ability, damage=caster:GetIntellect()*0.4, damage_type=DAMAGE_TYPE_MAGICAL}) end
	if (perks.e_wraith_health or 0) > 0 and caster:IsAlive() then caster:Heal(caster:GetMaxHealth()*0.02, ability) end
	if (perks.e_wraith_mana or 0) > 0 and RandomFloat(0,1) < 0.15 then caster:GiveMana(math.min(dealt or 0, caster:GetMaxMana()-caster:GetMana())) end
	if (perks.l_wraith_grave or 0) > 0 then
		target:AddNewModifier(caster, ability, "modifier_rpg_slow", {duration=6, slow=75})
		target:AddNewModifier(caster, ability, "modifier_rooted", {duration=2})
	end
	if (perks.l_wraith_ghost or 0) > 0 then target:AddNewModifier(caster, ability, "modifier_rpg_arc_wraith_burn", {duration=3, damage=damage*0.5+caster:GetIntellect()}) end
	if (perks.e_wraith_inferno or 0) > 0 then target:AddNewModifier(caster, ability, "modifier_rpg_arc_wraith_burn", {duration=5, pct=3}) end
	if (perks.l_wraith_echo or 0) > 0 then
		local hit = {[target:entindex()] = true}
		for _ = 1, 2 do
			local nearby = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
				DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)
			for _, enemy in ipairs(nearby) do
				if enemy:IsAlive() and not hit[enemy:entindex()] then
					hit[enemy:entindex()] = true
					ApplyDamage({victim=enemy, attacker=caster, ability=ability, damage=damage, damage_type=DAMAGE_TYPE_MAGICAL})
					spark_wraith_hit_effect(enemy)
					break
				end
			end
		end
	end
	spark_wraith_hit_effect(target)
end

local SPARK_WRAITH_HIT_SEQUENCE = 0
local PENDING_SPARK_WRAITH_HITS = {}

local ACTIVE_SPARK_WRAITHS = {}
local PENDING_SPARK_PROJECTILES = {}
local SPARK_WRAITH_MANAGER_RUNNING = false

local function remove_spark_wraith(record)
	if record.marker then
		ParticleManager:DestroyParticle(record.marker, false)
		ParticleManager:ReleaseParticleIndex(record.marker)
		record.marker = nil
	end
	if record.unit and IsValidEntity(record.unit) and not record.unit:IsNull() then UTIL_Remove(record.unit) end
	if record.unit then record.unit = nil end
end

local function spark_wraith_manager()
	local now = GameRules:GetGameTime()
	for entindex, pending in pairs(PENDING_SPARK_PROJECTILES) do
		if now >= pending.expires_at then
			if pending.unit and IsValidEntity(pending.unit) and not pending.unit:IsNull() then UTIL_Remove(pending.unit) end
			PENDING_SPARK_PROJECTILES[entindex] = nil
		end
	end
	for i = #ACTIVE_SPARK_WRAITHS, 1, -1 do
		local record = ACTIVE_SPARK_WRAITHS[i]
		local caster, ability = record.caster, record.ability
		if not IsValidEntity(caster) or caster:IsNull() or not IsValidEntity(ability) or ability:IsNull()
			or now >= record.expires_at then
			remove_spark_wraith(record)
			table.remove(ACTIVE_SPARK_WRAITHS, i)
		elseif now >= record.activate_at and now >= record.next_scan then
			record.next_scan = now + 0.25
			if caster:IsAlive() then
				local enemies = FindUnitsInRadius(caster:GetTeamNumber(), record.position, nil, record.radius,
					DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
					DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)
				local target = enemies[1]
				if target and IsValidEntity(record.unit) then
				local origin = GetGroundPosition(record.position, caster)
				local direction = target:GetAbsOrigin() - origin
				local distance = direction:Length2D()
				if distance < 1 then direction = caster:GetForwardVector() else direction = direction:Normalized() end
				local projectile_source_index = record.unit:entindex()
				PENDING_SPARK_PROJECTILES[projectile_source_index] = {
					unit = record.unit, target = target, caster = caster, ability = ability,
					radius = record.radius, expires_at = now + 5, resolved = false,
				}
				-- Apply the hit when the wraith acquires its target. The projectile is
				-- presentation only: custom-game projectile callbacks can be omitted by
				-- the engine for these NPC sources, which previously lost the damage.
				deal_spark_wraith_hit(caster, ability, target, record.radius)
				PENDING_SPARK_PROJECTILES[projectile_source_index].resolved = true
				ProjectileManager:CreateLinearProjectile({
					Ability = ability, Source = caster, vSpawnOrigin = origin,
					vVelocity = direction * 550, fDistance = math.max(distance + 80, 100),
					fStartRadius = 48, fEndRadius = 48,
					EffectName = "particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj.vpcf",
					bDeleteOnHit = true, bProvidesVision = false, bVisibleToEnemies = true,
					iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
					iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
					iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
					ExtraData = { wraith_entindex = projectile_source_index, search_radius = record.radius },
				})
					if record.marker then
						ParticleManager:DestroyParticle(record.marker, false)
						ParticleManager:ReleaseParticleIndex(record.marker)
						record.marker = nil
					end
					record.unit = nil -- pending record owns cleanup of the invisible launch anchor
					table.remove(ACTIVE_SPARK_WRAITHS, i)
				end
			end
		end
	end
	if #ACTIVE_SPARK_WRAITHS > 0 or next(PENDING_SPARK_PROJECTILES) ~= nil then return 0.1 end
	SPARK_WRAITH_MANAGER_RUNNING = false
	return nil
end

local function launch_spark_wraith(caster, ability, point)
	point = GetGroundPosition(point, caster)
	local state = caster.rpg or {}
	local radius = ability:GetSpecialValueFor("burst_radius") + ((state.arc_bonus or {}).wraith_radius or 0)
	if (state.perk_count or {}).e_wraith_radius and (state.perk_count.e_wraith_radius or 0) > 0 then radius = radius + 700 end
	-- Reliable point-blast version: detonate at the selected spot immediately,
	-- rather than depending on an engine projectile or trigger callback.
	for _, particle in ipairs({
		"particles/units/heroes/hero_arc_warden/arc_warden_wraith_cast.vpcf",
		"particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj_hit.vpcf",
	}) do
		local fx = ParticleManager:CreateParticle(particle, PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(fx, 0, point)
		ParticleManager:ReleaseParticleIndex(fx)
	end
	local targets = FindUnitsInRadius(caster:GetTeamNumber(), point, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, target in ipairs(targets) do deal_spark_wraith_hit(caster, ability, target, radius) end
end

rpg_arc_warden_flux = class({})
function rpg_arc_warden_flux:GetBehavior() return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET end
function rpg_arc_warden_flux:GetAbilityTargetTeam() return DOTA_UNIT_TARGET_TEAM_ENEMY end
function rpg_arc_warden_flux:GetAbilityTargetType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function rpg_arc_warden_flux:GetCastRange()
	return self.BaseClass.GetCastRange(self, self:GetLevel()) + (has(self:GetCaster(), "l_flux_range") and 800 or 0)
end
function rpg_arc_warden_flux:GetCooldown(level)
	local cd = self.BaseClass.GetCooldown(self, level)
	return cd * (has(self:GetCaster(), "e_flux_cooldown") and 0.7 or 1)
end
function rpg_arc_warden_flux:OnSpellStart()
	if not IsServer() then return end
	local caster, target = self:GetCaster(), self:GetCursorTarget()
	if not target or target:TriggerSpellAbsorb(self) then return end
	local function apply(victim)
		if victim and victim:IsAlive() then
			victim:AddNewModifier(caster, self, "modifier_rpg_arc_flux", {duration = self:GetSpecialValueFor("duration") + bonus(caster, "flux_duration")})
			if has(caster, "e_flux_burst") then ApplyDamage({victim=victim, attacker=caster, ability=self, damage=500, damage_type=DAMAGE_TYPE_MAGICAL}) end
		end
	end
	apply(target)
	if has(caster, "m_flux_spread") then
		for _, enemy in ipairs(FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, 800,
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)) do
			if enemy ~= target then apply(enemy) end
		end
	end
end

rpg_arc_warden_magnetic_field = class({})
function rpg_arc_warden_magnetic_field:GetBehavior() return DOTA_ABILITY_BEHAVIOR_POINT end
function rpg_arc_warden_magnetic_field:GetAOERadius() return self:GetSpecialValueFor("radius") + bonus(self:GetCaster(), "field_radius") + (has(self:GetCaster(), "e_field_radius") and 400 or 0) end
function rpg_arc_warden_magnetic_field:OnSpellStart()
	if not IsServer() then return end
	local caster = self:GetCaster()
	caster:StartGesture(ACT_DOTA_CAST_ABILITY_2)
	local duration = self:GetSpecialValueFor("duration") + bonus(caster, "field_duration") + (has(caster, "e_field_duration") and 2 or 0)
	local point = self:GetCursorPosition()
	CreateModifierThinker(caster, self, "modifier_rpg_arc_field", {duration=duration, radius=self:GetAOERadius()}, point, caster:GetTeamNumber(), false)
	EmitSoundOnLocationWithCaster(point, "Hero_ArcWarden.MagneticField.Cast", caster)
end

rpg_arc_warden_spark_wraith = class({})
function rpg_arc_warden_spark_wraith:GetBehavior() return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET end
function rpg_arc_warden_spark_wraith:GetAbilityTargetTeam() return DOTA_UNIT_TARGET_TEAM_ENEMY end
function rpg_arc_warden_spark_wraith:GetAbilityTargetType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function rpg_arc_warden_spark_wraith:GetCastRange(level)
	return self.BaseClass.GetCastRange(self, level) + bonus(self:GetCaster(), "wraith_radius")
end
function rpg_arc_warden_spark_wraith:GetAOERadius() return self:GetSpecialValueFor("search_radius") + bonus(self:GetCaster(), "wraith_radius") + (has(self:GetCaster(), "e_wraith_radius") and 700 or 0) end
function rpg_arc_warden_spark_wraith:OnSpellStart()
	if not IsServer() then return end
	local caster, target = self:GetCaster(), self:GetCursorTarget()
	if not target or target:IsNull() or not target:IsAlive() then return end
	if target:TriggerSpellAbsorb(self) then return end
	local state = caster.rpg or {}
	local radius = self:GetSpecialValueFor("search_radius") + ((state.arc_bonus or {}).wraith_radius or 0)
	if has(caster, "e_wraith_radius") then radius = radius + 700 end
	local count = has(caster, "m_wraith_night") and 9 or 1
	if caster:HasScepter() then count = count + 1 end
	if has(caster, "e_wraith_legion") and RandomFloat(0, 1) < 0.25 then count = count + 1 end
	SPARK_WRAITH_HIT_SEQUENCE = SPARK_WRAITH_HIT_SEQUENCE + 1
	local hit_id = SPARK_WRAITH_HIT_SEQUENCE
	local pending = {
		caster = caster, ability = self, target = target,
		radius = radius, count = count, resolved = false,
	}
	PENDING_SPARK_WRAITH_HITS[hit_id] = pending
	pending.resolve = function(hit_target)
		if pending.resolved then return end
		local victim = hit_target
		if not victim or victim:IsNull() or not victim:IsAlive() then victim = pending.target end
		if victim and not victim:IsNull() and victim:IsAlive()
			and IsValidEntity(pending.caster) and not pending.caster:IsNull()
			and IsValidEntity(pending.ability) and not pending.ability:IsNull() then
			for _ = 1, pending.count do
				deal_spark_wraith_hit(pending.caster, pending.ability, victim, pending.radius)
			end
		end
		pending.resolved = true
		PENDING_SPARK_WRAITH_HITS[hit_id] = nil
	end
	-- Let the spirit travel visually; resolve damage and every attached perk after
	-- a short fixed travel window so gameplay never depends on projectile callbacks.
	for _ = 1, pending.count do
		ProjectileManager:CreateTrackingProjectile({
			Target = target, Source = caster, Ability = self,
			EffectName = "particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj.vpcf",
			iMoveSpeed = 1200, bDodgeable = false, bVisibleToEnemies = true,
			bProvidesVision = false, iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_ATTACK_1,
			ExtraData = { spark_wraith_hit_id = hit_id },
		})
	end
	local cast_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_arc_warden/arc_warden_wraith_cast.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(cast_fx)
	EmitSoundOn("Hero_ArcWarden.SparkWraith.Cast", caster)
	RPG.After(0.5, function()
		if not pending.resolved then pending.resolve(pending.target) end
	end)
end

function rpg_arc_warden_spark_wraith:OnProjectileHit_ExtraData(target, location, extra)
	-- The visual projectile can arrive before the fixed 0.5 s travel window.
	-- Damage is intentionally resolved only by the timer in OnSpellStart.
	return true
end
rpg_arc_warden_tempest_double = class({})
function rpg_arc_warden_tempest_double:GetBehavior() return DOTA_ABILITY_BEHAVIOR_POINT end
function rpg_arc_warden_tempest_double:GetCastRange()
	return self.BaseClass.GetCastRange(self, self:GetLevel())
end
function rpg_arc_warden_tempest_double:GetHeroLevelRequiredToUpgrade()
	return 6 + math.max(0, self:GetLevel()) * 6
end
function rpg_arc_warden_tempest_double:OnUpgrade()
	if not IsServer() or self.rpg_level_check_pending then return end
	local caster = self:GetCaster()
	local rank = self:GetLevel()
	local required_level = 6 + math.max(0, rank - 1) * 6
	if caster and caster:IsRealHero() and caster:GetLevel() < required_level then
		self.rpg_level_check_pending = true
		RPG.After(0.03, function()
			if not self or self:IsNull() then return end
			if self:GetLevel() >= rank and caster:IsRealHero() and caster:GetLevel() < required_level then
				self:SetLevel(rank - 1)
				caster:SetAbilityPoints(caster:GetAbilityPoints() + 1)
			end
			self.rpg_level_check_pending = false
		end)
	end
end
function rpg_arc_warden_tempest_double:GetCooldown(level)
	local cd=self.BaseClass.GetCooldown(self,level); return cd*(has(self:GetCaster(),"e_tempest_cooldown") and 0.7 or 1)
end
function rpg_arc_warden_tempest_double:OnSpellStart()
	if not IsServer() then return end
	local caster = self:GetCaster()
	if caster.rpg_tempest_clone and IsValidEntity(caster.rpg_tempest_clone) and caster.rpg_tempest_clone:IsAlive() then return end
	caster.rpg_tempest_clone = nil
	local required_level = 6 + math.max(0, self:GetLevel() - 1) * 6
	if caster:GetLevel() < required_level then
		return
	end
	local duration = self:GetSpecialValueFor("duration") + bonus(caster, "tempest_duration")
	local clone
	local pos = GetGroundPosition(self:GetCursorPosition(), caster)
	if has(caster,"m_tempest_identity") then
		clone=CreateUnitByName("npc_dota_hero_arc_warden",pos,true,caster,caster,caster:GetTeamNumber())
		if clone then
			clone.rpg_is_tempest_double = true
			clone.rpg_tempest_permanent = true
			clone:SetOwner(caster); clone:SetControllableByPlayer(caster:GetPlayerOwnerID(),true); clone:SetBaseMaxHealth(caster:GetMaxHealth()); clone:SetMaxHealth(caster:GetMaxHealth()); clone:SetHealth(caster:GetHealth()); clone:SetMana(caster:GetMana()); clone:SetBaseDamageMin(caster:GetBaseDamageMin()); clone:SetBaseDamageMax(caster:GetBaseDamageMax())
			setup_clone(caster,clone)
			for _,name in ipairs({"rpg_arc_warden_flux","rpg_arc_warden_magnetic_field","rpg_arc_warden_spark_wraith","rpg_arc_warden_tempest_double"}) do
				local src=caster:FindAbilityByName(name); local dst=clone:FindAbilityByName(name)
				if not dst then dst=clone:AddAbility(name) end
				if src and dst then
					if name == "rpg_arc_warden_tempest_double" then
						dst:SetLevel(0); dst:SetHidden(true); dst:SetActivated(false)
					else
						dst:SetLevel(src:GetLevel()); dst:SetHidden(true); dst:SetActivated(false)
					end
				end
			end
			local native_ult = clone:FindAbilityByName("arc_warden_tempest_double")
			if native_ult then native_ult:SetLevel(0); native_ult:SetHidden(true); native_ult:SetActivated(false) end
			clone:AddNewModifier(caster,self,"modifier_rpg_arc_tempest",{})
			clone:AddNewModifier(caster,self,"modifier_rpg_arc_master",{})
			caster.rpg_tempest_clone=clone
			if has(caster,"m_field_shield") then clone:ForceKill(false) end
			for _,name in ipairs({"rpg_arc_warden_flux","rpg_arc_warden_magnetic_field","rpg_arc_warden_spark_wraith"}) do local a=caster:FindAbilityByName(name); if a then a:SetHidden(true); a:SetActivated(false) end end
		end
	else
		-- Use a genuine hero unit for the temporary double, so it inherits Arc Warden's
		-- movement, attack behavior, level and hero ability system.
		clone = CreateUnitByName("npc_dota_hero_arc_warden", pos, true, caster, caster, caster:GetTeamNumber())
		if clone then
			clone.rpg_is_tempest_double = true
			clone.rpg_tempest_permanent = false
			setup_temporary_double(caster, clone)
			for _, name in ipairs({"rpg_arc_warden_flux", "rpg_arc_warden_magnetic_field", "rpg_arc_warden_spark_wraith"}) do
				local source = caster:FindAbilityByName(name)
				local ability = clone:FindAbilityByName(name) or clone:AddAbility(name)
				if source and ability then
					ability:SetLevel(source:GetLevel())
					ability:SetHidden(false)
					ability:SetActivated(true)
				end
			end
			for _, name in ipairs({"rpg_arc_warden_tempest_double", "arc_warden_tempest_double"}) do
				local ult = clone:FindAbilityByName(name)
				if ult then ult:SetLevel(0); ult:SetHidden(true); ult:SetActivated(false) end
			end
			clone:SetAbilityPoints(0)
			clone:AddNewModifier(caster, self, "modifier_rpg_arc_tempest", {duration = duration})
			clone:AddNewModifier(caster, self, "modifier_rpg_arc_master", {duration = duration})
			caster.rpg_tempest_clone = clone
		end
	end
	if clone then
		if clone:IsAlive() then dress_temporary_double(clone) end
		-- The double gets usable item copies, including backpack slots.
		for slot = 0, 8 do
			local item = caster:GetItemInSlot(slot)
			if item then
				local copy = CreateItem(item:GetAbilityName(), clone, clone)
				if copy then
					copy:SetCurrentCharges(item:GetCurrentCharges())
					clone:AddItem(copy)
				end
			end
		end
		local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_arc_warden/arc_warden_wraith_cast.vpcf", PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(fx, 0, pos)
		ParticleManager:ReleaseParticleIndex(fx)
		EmitSoundOnLocationWithCaster(pos, "Hero_ArcWarden.TempestDouble", caster)
	end
end
