-- Hoodwink: custom ability mechanics and four perk branches.
Hoodwink = Hoodwink or {}
Hoodwink.C = {
	ACORN_BLAST_PCT = 50, ACORN_BASE_RADIUS = 250, ACORN_BASE_BOUNCES = 4,
	HOWITZER_SHOTS = 5, HOWITZER_STEP = 0.5, BOSS_SHARPSHOOTER_PCT = 50,
	NUKE_CD = 30,
}
Hoodwink.shots = Hoodwink.shots or {}
Hoodwink.pending_traps = Hoodwink.pending_traps or {}
Hoodwink._id = Hoodwink._id or 0

function Hoodwink:Has(hero, id)
	return hero and hero.rpg and (hero.rpg.perk_count[id] or 0) > 0
end

function Hoodwink:NextId()
	self._id = self._id + 1
	return self._id
end

function Hoodwink:Enemies(caster, point, radius)
	return FindUnitsInRadius(caster:GetTeamNumber(), point, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
end

function Hoodwink:IsBoss(unit) return unit and unit.rpg_boss == true end

function Hoodwink:PlayFX(path, point, radius)
	local fx = ParticleManager:CreateParticle(path, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, point)
	if radius then ParticleManager:SetParticleControl(fx, 1, Vector(radius, 0, 0)) end
	ParticleManager:ReleaseParticleIndex(fx)
end

function Hoodwink:CreateFire(caster, ability, point, duration, radius, total_damage, damage_type, visual_particle)
	local ticks = math.max(1, math.floor(duration))
	CreateModifierThinker(caster, ability, "modifier_rpg_fire_zone", {
		duration = duration, radius = radius, fixed_damage = total_damage / ticks,
		damage_type = damage_type or DAMAGE_TYPE_MAGICAL, visual_particle = visual_particle,
	}, point, caster:GetTeamNumber(), false)
end

-- ---------------------------- Acorn Shot ----------------------------
function Hoodwink:FireAcorn(caster, ability, target, options)
	options = options or {}
	if not target or target:IsNull() or not target:IsAlive() then return end
	local id = self:NextId()
	local bonus = caster.rpg and caster.rpg.hoodwink_bonus or {}
	local modification = self:Has(caster, "e_modification") and math.floor(caster:GetAgility() / 50) * 10 or 0
	local base = ability:GetSpecialValueFor("damage") + caster:GetAgility() * ability:GetSpecialValueFor("agility_scale") + (bonus.acorn_damage or 0) + modification
	local shot = {
		caster = caster, ability = ability, hit = {}, kills = 0, last = target:GetAbsOrigin(),
		damage = base, multiplier = options.multiplier or 1, bounce = 0,
		max_bounces = options.bounces or ability:GetSpecialValueFor("bounce_count") + (bonus.acorn_bounces or 0),
		blast = options.blast or false, forced_blast = options.forced_blast or false,
		heal_pct = options.heal_pct or 0, no_extra = options.no_extra or false,
	}
	if caster:HasModifier("modifier_item_aghanims_shard") then shot.max_bounces = shot.max_bounces + 2 end
	local extra = false
	if not shot.no_extra and self:Has(caster, "e_kits") and RandomFloat(0, 100) < 25 then
		shot.max_bounces = 0
		shot.multiplier = shot.multiplier * 2
		shot.forced_blast = true
		shot.blast = true
		extra = true
	end
	if target:TriggerSpellAbsorb(ability) then return end
	self.shots[id] = shot
	self:LaunchAcorn(id, target)
	if not shot.no_extra and self:Has(caster, "l_carpet") and RandomFloat(0, 100) < 10 then
		RPG.After(0.08, function()
			if not caster:IsNull() and target:IsAlive() then
				self:FireAcorn(caster, ability, target, { no_extra = true, bounces = shot.max_bounces })
			end
		end)
	end
end

function Hoodwink:LaunchAcorn(id, target)
	local shot = self.shots[id]
	if not shot or not target or target:IsNull() then self:FinishAcorn(id); return end
	-- Use Snapfire's visible cookie projectile so Acorn Shot does not show
	-- Puck's Illusory Orb or Hoodwink's Sharpshooter bolt.
	local caster = shot.caster
	ProjectileManager:CreateTrackingProjectile({
		Target = target,
		Ability = shot.ability,
		EffectName = "particles/units/heroes/hero_snapfire/snapfire_cookie_projectile.vpcf",
		vSourceLoc = caster:GetAbsOrigin() + Vector(0, 0, 100),
		iMoveSpeed = shot.ability:GetSpecialValueFor("projectile_speed"),
		bDodgeable = false,
		bProvidesVision = false,
		ExtraData = { shot_id = id },
	})
end

function Hoodwink:AcornHit(target, extra)
	local shot = self.shots[tonumber(extra.shot_id)]
	if not shot then return true end
	if not target or target:IsNull() then self:FinishAcorn(tonumber(extra.shot_id)); return true end
	local id, caster, ability = tonumber(extra.shot_id), shot.caster, shot.ability
	if not target:IsAlive() or shot.hit[target:entindex()] then self:FinishAcorn(id); return true end
	shot.hit[target:entindex()] = true
	shot.last = target:GetAbsOrigin()
	target:EmitSound("Hero_Hoodwink.AcornShot.Projectile")
	local damage = shot.damage * shot.multiplier
	if self:Has(caster, "e_smart") and target:GetHealth() < target:GetMaxHealth() * 0.30 then damage = damage * 1.15 end
	local before = target:GetHealth()
	ApplyDamage({ victim = target, attacker = caster, ability = ability, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL })
	if self:Has(caster, "e_acorn_stun") and target:IsAlive() then target:AddNewModifier(caster, ability, "modifier_stunned", { duration = 0.5 }) end
	if self:Has(caster, "m_acorn") or shot.blast then
		local bonus = caster.rpg and caster.rpg.hoodwink_bonus or {}
		local radius = self.C.ACORN_BASE_RADIUS + (bonus.acorn_radius or 0)
		if self:Has(caster, "l_growing") then radius = radius * (1 + 0.05 * shot.bounce) end
		local blast_damage = damage * self.C.ACORN_BLAST_PCT / 100
		local victims = self:Enemies(caster, target:GetAbsOrigin(), radius)
		for _, victim in ipairs(victims) do
			local amount = blast_damage
			local trapped = victim:FindModifierByNameAndCaster("modifier_rpg_hoodwink_bushwhack", caster)
			if trapped and self:Has(caster, "e_dirty_trick") then amount = amount * 2 end
			if self:Has(caster, "e_smart") and victim:GetHealth() < victim:GetMaxHealth() * 0.30 then amount = amount * 1.15 end
			local old_health = victim:GetHealth()
			local dealt = ApplyDamage({ victim = victim, attacker = caster, ability = ability, damage = amount, damage_type = DAMAGE_TYPE_PURE }) or 0
			if shot.heal_pct > 0 then caster:Heal(dealt * shot.heal_pct / 100, ability) end
			if old_health > 0 and not victim:IsAlive() then shot.kills = shot.kills + 1 end
			if self:Has(caster, "e_shrapnel") then victim:AddNewModifier(caster, ability, "modifier_rpg_slow", { duration = 2, slow = 60 }) end
		end
		if self:Has(caster, "l_napalm") then
			self:CreateFire(caster, ability, target:GetAbsOrigin(), 3, 150, blast_damage * 0.25, DAMAGE_TYPE_MAGICAL,
				"particles/units/heroes/hero_batrider/batrider_firefly.vpcf")
		end
		self:PlayFX("particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_explosion.vpcf", target:GetAbsOrigin(), radius)
	end
	if before > 0 and not target:IsAlive() then shot.kills = shot.kills + 1 end

	local caught = target:FindModifierByNameAndCaster("modifier_rpg_hoodwink_bushwhack", caster)
	local max_bounces = shot.max_bounces
	if self:Has(caster, "l_cluster") then max_bounces = math.max(max_bounces, 20) end
	if caught and self:Has(caster, "e_stonework") then max_bounces = max_bounces + 6 end
	local next_target
	if not shot.forced_blast and shot.bounce < max_bounces then
		local candidates = self:Enemies(caster, target:GetAbsOrigin(), ability:GetSpecialValueFor("bounce_radius"))
		local best = ability:GetSpecialValueFor("bounce_radius")
		for _, enemy in ipairs(candidates) do
			if not shot.hit[enemy:entindex()] then
				local d = (enemy:GetAbsOrigin() - target:GetAbsOrigin()):Length2D()
				if d < best then next_target, best = enemy, d end
			end
		end
	end
	if next_target then
		shot.bounce = shot.bounce + 1
		if self:Has(caster, "m_acorn") then shot.multiplier = shot.multiplier * 1.10 end
		self:LaunchAcorn(id, next_target)
	else
		self:FinishAcorn(id)
	end
	return true
end

function Hoodwink:FinishAcorn(id)
	local shot = self.shots[id]
	if not shot then return end
	if shot.visual_fx then ParticleManager:DestroyParticle(shot.visual_fx, false); ParticleManager:ReleaseParticleIndex(shot.visual_fx); shot.visual_fx = nil end
	if self:Has(shot.caster, "e_rad") then
		local thinker = CreateModifierThinker(shot.caster, shot.ability, "modifier_rpg_hoodwink_acid_zone", { duration = 5, radius = 700 },
			shot.last, shot.caster:GetTeamNumber(), false)
	end
	if shot.kills >= 3 and self:Has(shot.caster, "e_euphoria") then
		shot.caster:AddNewModifier(shot.caster, shot.ability, "modifier_rpg_hoodwink_euphoria", { duration = 4 })
	end
	self.shots[id] = nil
end

-- ----------------------------- Bushwhack -----------------------------
function Hoodwink:CastBushwhack(caster, ability, point, mini)
	point = GetGroundPosition(point, caster)
	local from = caster:GetAbsOrigin()
	local delta = point - from; delta.z = 0
	local distance = math.min(delta:Length2D(), ability:GetSpecialValueFor("cast_range"))
	local direction = delta:Length2D() > 0 and delta:Normalized() or caster:GetForwardVector()
	local speed = ability:GetSpecialValueFor("projectile_speed")
	local travel = math.max(0.06, distance / speed)
	local id = self:NextId()
	local bonus = caster.rpg and caster.rpg.hoodwink_bonus or {}
	local duration = ability:GetSpecialValueFor("trap_duration") + (bonus.bush_duration or 0)
	if self:Has(caster, "e_net_duration") then duration = duration + 2 end
	if mini then duration = duration * 0.5 end
	local radius = ability:GetSpecialValueFor("radius") + (self:Has(caster, "e_wide_net") and 300 or 0) + (bonus.bush_radius or 0)
	local start = from + Vector(0, 0, 90)
	local finish = point + Vector(0, 0, 45)
	self.pending_traps[id] = {
		caster = caster, ability = ability, point = point, duration = duration, radius = radius,
		damage = ability:GetSpecialValueFor("damage") + (bonus.bush_damage or 0), mini = mini,
		visual_pos = start, visual_end = finish, speed = speed,
	}
	caster:EmitSound("Hero_Hoodwink.Bushwhack.Cast")
	RPG.After(math.max(0.01, travel - 0.07), function()
		if caster:IsNull() then return end
		CreateTempTree(point, duration + 2)
		self:PlayFX("particles/units/heroes/hero_hoodwink/hoodwink_bushwhack_tree.vpcf", point)
	end)
	local fx = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_hoodwink/hoodwink_bushwhack_projectile.vpcf", PATTACH_WORLDORIGIN, nil)
	self.pending_traps[id].visual_fx = fx
	ParticleManager:SetParticleControl(fx, 0, start)
	ParticleManager:SetParticleControl(fx, 1, start + direction * 100)
	ParticleManager:SetParticleControlForward(fx, 0, direction)
	self:MoveBushwhack(id)
end

function Hoodwink:MoveBushwhack(id)
	local trap = self.pending_traps[id]
	if not trap then return end
	local delta = trap.visual_end - trap.visual_pos
	local distance = delta:Length2D()
	local step = trap.speed * 0.03
	if distance <= step then
		if trap.visual_fx then ParticleManager:DestroyParticle(trap.visual_fx, false); ParticleManager:ReleaseParticleIndex(trap.visual_fx); trap.visual_fx = nil end
		self:BushwhackImpact(id)
		return
	end
	local forward = delta:Normalized()
	trap.visual_pos = trap.visual_pos + forward * step
	ParticleManager:SetParticleControl(trap.visual_fx, 0, trap.visual_pos)
	ParticleManager:SetParticleControl(trap.visual_fx, 1, trap.visual_pos + forward * 100)
	ParticleManager:SetParticleControlForward(trap.visual_fx, 0, forward)
	RPG.After(0.03, function() self:MoveBushwhack(id) end)
end

function Hoodwink:BushwhackProjectileHit(target, extra)
	if not target then self:BushwhackImpact(tonumber(extra.trap_id)) end
	return false
end

function Hoodwink:BushwhackImpact(id)
	local trap = self.pending_traps[id]
	if not trap then return end
	self.pending_traps[id] = nil
	local caster, ability, point = trap.caster, trap.ability, trap.point
	if trap.visual_fx then ParticleManager:DestroyParticle(trap.visual_fx, false); ParticleManager:ReleaseParticleIndex(trap.visual_fx); trap.visual_fx = nil end
	if caster:IsNull() then return end
	caster:EmitSound("Hero_Hoodwink.Bushwhack.Target")
	self:PlayFX("particles/units/heroes/hero_hoodwink/hoodwink_bushwhack.vpcf", point, trap.radius)
	for _, enemy in ipairs(self:Enemies(caster, point, trap.radius)) do
		local damage = trap.damage
		local duration = trap.duration
		if self:Has(caster, "e_easy_prey") and enemy:GetHealth() < enemy:GetMaxHealth() * 0.30 then damage = damage * 2 end
		ApplyDamage({ victim = enemy, attacker = caster, ability = ability, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL })
		enemy:AddNewModifier(caster, ability, "modifier_rpg_pull", { duration = 0.3, x = point.x, y = point.y, stop = 90 })
		enemy:AddNewModifier(caster, ability, "modifier_rpg_hoodwink_bushwhack", { duration = duration })
		if self:Has(caster, "l_weak_spot") then enemy:AddNewModifier(caster, ability, "modifier_rpg_hoodwink_weakspot", { duration = duration }) end
		if self:Has(caster, "l_hunter_haste") then caster:AddNewModifier(caster, ability, "modifier_rpg_hoodwink_haste", { duration = 4 + (self:Has(caster, "e_net_duration") and 2 or 0) }) end
		if self:Has(caster, "m_blood_hunt") and (enemy:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() <= 400 then
			caster:AddNewModifier(caster, ability, "modifier_rpg_hoodwink_hunt", { duration = duration })
		end
	end
end

function Hoodwink:OnTrapDeath(caster, ability, target)
	if not self:Has(caster, "l_cassette") then return end
	local point = target:GetAbsOrigin()
	local damage = ability:GetSpecialValueFor("damage") * 1.5
	for _, enemy in ipairs(self:Enemies(caster, point, 450)) do
		ApplyDamage({ victim = enemy, attacker = caster, ability = ability, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL })
	end
	self:PlayFX("particles/units/heroes/hero_hoodwink/hoodwink_bushwhack.vpcf", point, 450)
	for i = 1, 3 do
		local angle = (i - 1) * 2 * math.pi / 3
		local landing = point + Vector(math.cos(angle) * 250, math.sin(angle) * 250, 0)
		self:CastBushwhack(caster, ability, landing, true)
	end
end

-- ------------------------------- Scurry -------------------------------
function Hoodwink:CastScurry(caster, ability, automatic)
	local bonus = caster.rpg and caster.rpg.hoodwink_bonus or {}
	local duration = ability:GetSpecialValueFor("duration") + (bonus.scurry_duration or 0)
	if self:Has(caster, "m_mighty_oak") then duration = 10 end
	if self:Has(caster, "e_long_defense") then duration = duration + 2 end
	caster:AddNewModifier(caster, ability, "modifier_rpg_hoodwink_scurry", { duration = duration })
	-- Scurry has no guaranteed cast particle on custom hero models; show a brief
	-- woodland burst at activation, including the defensive Mighty Oak variant.
	self:PlayFX("particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_explosion.vpcf", caster:GetAbsOrigin(), 220)
	if self:Has(caster, "e_camouflage") then
		local center = caster:GetAbsOrigin()
		for i = 1, 6 do
			local a = i * math.pi / 3
			CreateTempTree(center + Vector(math.cos(a) * 160, math.sin(a) * 160, 0), 4)
		end
	end
end

-- ----------------------------- Sharpshooter ----------------------------
function Hoodwink:FireSharpshooter(caster, ability, point, shot_number, random_followup, charge_factor)
	local from = caster:GetAbsOrigin()
	local dir = point - from; dir.z = 0
	if dir:Length2D() < 1 then dir = caster:GetForwardVector() else dir = dir:Normalized() end
	local id = self:NextId()
	local bonus = caster.rpg and caster.rpg.hoodwink_bonus or {}
	local base = ability:GetSpecialValueFor("damage") + (bonus.sharp_damage or 0)
	local scale = (1 + (shot_number - 1) * 0.25) * (charge_factor or 1)
	if self:Has(caster, "l_caliber") then scale = scale * 1.15 end
	local radius = ability:GetSpecialValueFor("projectile_radius")
	if self:Has(caster, "l_marksman") then radius = radius * 1.2 end
	self.shots[id] = { caster = caster, ability = ability, damage = base * scale, damage_type = self:Has(caster, "m_howitzer") and DAMAGE_TYPE_PURE or DAMAGE_TYPE_MAGICAL, point = point, hit = {}, random_followup = random_followup,
		team_damage = 1, allied_hit = false }
	local team = self:Has(caster, "e_conscience") and DOTA_UNIT_TARGET_TEAM_BOTH or DOTA_UNIT_TARGET_TEAM_ENEMY
	ProjectileManager:CreateLinearProjectile({
		Ability = ability, EffectName = "particles/units/heroes/hero_hoodwink/hoodwink_sharpshooter_projectile.vpcf",
		vSpawnOrigin = from, vVelocity = dir * ability:GetSpecialValueFor("projectile_speed"),
		fDistance = ability:GetSpecialValueFor("range") + (bonus.sharp_range or 0), fStartRadius = radius, fEndRadius = radius,
		bDeleteOnHit = false, bVisibleToEnemies = true, bProvidesVision = false,
		iUnitTargetTeam = team, iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		ExtraData = { shot_id = id },
	})
	RPG.After(8, function() self.shots[id] = nil end)
end

function Hoodwink:SharpshooterHit(target, extra)
	local id = tonumber(extra.shot_id)
	local shot = self.shots[id]
	if not shot then return true end
	local caster, ability = shot.caster, shot.ability
	if not target or target:IsNull() then
		if shot.finished then self.shots[id] = nil; return true end
		if shot.random_followup and self:Has(caster, "e_fool_bullet") then
			local p = caster:GetAbsOrigin() + RandomVector(ability:GetSpecialValueFor("range"))
			self:FireSharpshooter(caster, ability, p, 1, false)
		end
		self.shots[id] = nil
		return true
	end
	if shot.finished then return true end
	if target == caster then return false end
	local damage = shot.damage * shot.team_damage * (caster:HasScepter() and 1.15 or 1)
	if target:GetTeamNumber() == caster:GetTeamNumber() then
		if self:Has(caster, "e_conscience") and not shot.hit[target:entindex()] then
			shot.hit[target:entindex()] = true
			ApplyDamage({ victim = target, attacker = caster, ability = ability, damage = damage * 0.15, damage_type = DAMAGE_TYPE_MAGICAL })
			shot.team_damage = shot.team_damage * 1.20
			shot.allied_hit = true
		end
		return false
	end
	if shot.hit[target:entindex()] then return false end
	shot.hit[target:entindex()] = true
	local was_boss = self:IsBoss(target)
	ApplyDamage({ victim = target, attacker = caster, ability = ability, damage = damage, damage_type = shot.damage_type })
	if was_boss then
		ApplyDamage({ victim = target, attacker = caster, ability = ability, damage = damage * self.C.BOSS_SHARPSHOOTER_PCT / 100, damage_type = DAMAGE_TYPE_PURE })
		target:AddNewModifier(caster, ability, "modifier_rpg_slow", { duration = 3, slow = 35 })
		if self:Has(caster, "l_anti_tank") then
			ApplyDamage({ victim = target, attacker = caster, ability = ability, damage = target:GetHealth() * 0.05, damage_type = DAMAGE_TYPE_PURE })
		end
	end
	if self:Has(caster, "e_toxic_stakes") then target:AddNewModifier(caster, ability, "modifier_rpg_slow", { duration = 3, slow = 50 }) end
	if self:Has(caster, "e_deep_wounds") then target:AddNewModifier(caster, ability, "modifier_rpg_hoodwink_bleed", { duration = 5, pct = 1 }) end
	if self:Has(caster, "e_explosive_ammo") then
		for _, enemy in ipairs(self:Enemies(caster, target:GetAbsOrigin(), 300)) do
			ApplyDamage({ victim = enemy, attacker = caster, ability = ability, damage = damage * 0.25, damage_type = DAMAGE_TYPE_MAGICAL })
		end
		self:PlayFX("particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_calldown_marker.vpcf", target:GetAbsOrigin(), 300)
	end
	if caster:HasScepter() then
		for _, enemy in ipairs(self:Enemies(caster, target:GetAbsOrigin(), 250)) do
			if enemy ~= target then ApplyDamage({victim=enemy,attacker=caster,ability=ability,damage=damage*0.25,damage_type=DAMAGE_TYPE_MAGICAL}) end
		end
		self:PlayFX("particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_explosion.vpcf", target:GetAbsOrigin(), 250)
	end
	if self:Has(caster, "l_reload") then
		local main = caster:FindAbilityByName("rpg_hoodwink_sharpshooter")
		if main then self:ReduceCooldown(main, 3) end
	end
	if target:IsHero() or was_boss then
		shot.finished = true
		return true
	end
	return false
end

function Hoodwink:SharpshooterThink(location, extra)
	local id = tonumber(extra.shot_id)
	local shot = self.shots[id]
	if not shot or shot.finished then return end
	local caster = shot.caster
	local team = self:Has(caster, "e_conscience") and DOTA_UNIT_TARGET_TEAM_BOTH or DOTA_UNIT_TARGET_TEAM_ENEMY
	local units = FindUnitsInRadius(caster:GetTeamNumber(), location, nil, 135, team,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, unit in ipairs(units) do
		if unit ~= caster and not shot.hit[unit:entindex()] then
			if self:SharpshooterHit(unit, { shot_id = id }) then return end
		end
	end
end

-- Linear-projectile hit callbacks can omit custom creep units on some game-mode
-- targets. Track the projectile lane as it travels so every creep is still hit.
function Hoodwink:ReduceCooldown(ability, amount)
	local remaining = ability:GetCooldownTimeRemaining()
	if remaining > 0 then
		ability:EndCooldown()
		if remaining > amount then ability:StartCooldown(remaining - amount) end
	end
end

function Hoodwink:UpdateDevilAbility(hero)
	if not hero or hero:IsNull() or not hero.rpg then return end
	local main = hero:FindAbilityByName("rpg_hoodwink_sharpshooter")
	local devil = hero:FindAbilityByName("rpg_hoodwink_sharpshooter_devil")
	if not main or not devil then return end
	if main:GetLevel() > 0 and devil:GetLevel() ~= main:GetLevel() then devil:SetLevel(main:GetLevel()) end
	local has_perk = self:Has(hero, "e_devil_deal")
	local cooldown = main:GetCooldownTimeRemaining()
	local devil_active = not devil:IsHidden()
	if has_perk and cooldown > 0 and not devil_active and not main:IsChanneling() then
		hero:SwapAbilities("rpg_hoodwink_sharpshooter", "rpg_hoodwink_sharpshooter_devil", false, true)
	elseif (not has_perk or cooldown <= 0) and devil_active and not devil:IsChanneling() then
		hero:SwapAbilities("rpg_hoodwink_sharpshooter_devil", "rpg_hoodwink_sharpshooter", false, true)
	end
end

function Hoodwink:CastSharpshooter(caster, ability, point, channel_time)
	caster:EmitSound("Hero_Hoodwink.Sharpshooter.Projectile")
	if not self:Has(caster, "m_howitzer") then
		local max_channel = math.max(0.1, ability:GetChannelTime())
		local charge = math.max(0.25, math.min(1, (channel_time or max_channel) / max_channel))
		self:FireSharpshooter(caster, ability, point, 1, true, charge)
		return
	end
	local count = self.C.HOWITZER_SHOTS
	for i = 1, count do
		local idx = i
		local fire = function()
			if caster:IsNull() then return end
			local aim = point
			if self:Has(caster, "e_conscience") then
				-- All custom projectiles still follow the chosen firing lane.
			end
			self:FireSharpshooter(caster, ability, aim, idx, idx == count)
		end
		if i == 1 then fire() else RPG.After((i - 1) * self.C.HOWITZER_STEP, fire) end
	end
end

-- ------------------------------ Perk table -----------------------------
local BUILDS = {
	acorn = "Орешник (Acorn Shot)",
	bushwhack = "Кровавая охотница (Bushwhack)",
	scurry = "Могучий дуб (Scurry)",
	sharpshooter = "Гаубица (Sharpshooter)",
}
local function mythic(id, build, name, desc) return { id = id, tier = 5, build = build, max = 1, name = name, desc = desc } end
local function legend(id, build, name, desc) return { id = id, tier = 4, build = build, requires_build = build, max = 1, name = name, desc = desc } end
local function epic(id, build, name, desc) return { id = id, tier = 3, build = build, requires_build = build, max = 1, name = name, desc = desc } end

local PERKS = {
	mythic("m_acorn", "acorn", "Орешник", "Каждый отскок Acorn Shot взрывается чистым уроном по области; урон снаряда растёт на 10% за каждый успешный отскок."),
	mythic("m_blood_hunt", "bushwhack", "Кровавая охотница", "Рядом с пойманными Bushwhack врагами Hoodwink получает 35% вампиризма и 120 скорости атаки."),
	mythic("m_mighty_oak", "scurry", "Могучий Дуб", "Scurry длится 10 с, замедляет Hoodwink на 75% и не даёт ускорение или уклонение, но снижает физический урон на 75% и даёт 50 регенерации здоровья."),
	mythic("m_howitzer", "sharpshooter", "Гаубица", "Sharpshooter выпускает 5 снарядов с интервалом 0.25 с. Каждый следующий наносит на 25% больше урона; урон чистый."),

	legend("l_cluster", "acorn", "Кассетный взрыв", "У Acorn Shot до 20 отскоков."),
	legend("l_carpet", "acorn", "Ковровая бомбардировка", "С шансом 10% Acorn Shot выпускает дополнительный снаряд."),
	legend("l_growing", "acorn", "Нарастающая мощь", "Радиус каждого последующего взрыва Acorn Shot растёт на 5% за отскок."),
	legend("l_napalm", "acorn", "Напалм", "Каждый взрыв поджигает радиус 150 на 3 с; огонь наносит суммарно 25% урона взрыва."),
	legend("l_pop", "bushwhack", "Попался", "Атаки Hoodwink по пойманной Bushwhack цели наносят дополнительно 3% её максимального здоровья чистым уроном."),
	legend("l_cassette", "bushwhack", "Кассетный заряд", "Смерть пойманной цели вызывает магический взрыв и три мини-Bushwhack с половинной длительностью."),
	legend("l_weak_spot", "bushwhack", "Слабое место", "Bushwhack снимает всю физическую броню цели; с боссов — 25%."),
	legend("l_hunter_haste", "bushwhack", "Охотничий азарт", "Попадание Bushwhack даёт Hoodwink +30% скорости передвижения на 4 с."),
	legend("l_iron_grip", "scurry", "Железная хватка", "Scurry защищает от замедлений, притягивания и принудительного перемещения."),
	legend("l_thick_skull", "scurry", "Толстая черепушка", "Scurry даёт 65% сопротивления эффектам."),
	legend("l_make_room", "scurry", "Разойдись", "Пробегая через врагов под Scurry, Hoodwink наносит чистый урон в размере 150% своей силы."),
	legend("l_thorny", "scurry", "Колючая броня", "Scurry отражает 40% полученного урона, плюс 0.05% за каждую единицу силы."),
	legend("l_caliber", "sharpshooter", "Крупный калибр", "Урон снарядов Sharpshooter увеличен на 15%."),
	legend("l_anti_tank", "sharpshooter", "Противотанковое ружьё", "Попадание Sharpshooter по боссу наносит дополнительно 5% его текущего здоровья чистым уроном."),
	legend("l_reload", "sharpshooter", "Перезарядка", "Каждое попадание Sharpshooter сокращает его текущую перезарядку на 3 с."),
	legend("l_marksman", "sharpshooter", "Меткий глаз", "Радиус снаряда Sharpshooter увеличен на 20%."),

	epic("e_shrapnel", "acorn", "Шрапнель", "Взрывы Acorn Shot замедляют врагов на 60% на 2 с."),
	epic("e_dirty_trick", "acorn", "Подлый приём", "Взрыв Acorn Shot наносит вдвое больше урона цели, пойманной сетью Bushwhack."),
	epic("e_nuclear", "acorn", "Ядерное сдерживание", "Когда здоровье падает до 15%, Hoodwink выпускает три Acorn Shot; каждый взрыв лечит на 25% нанесённого им урона (перезарядка 30 с)."),
	epic("e_rad", "acorn", "Грязная бомба", "После последнего отскока создаёт радиацию в радиусе 700 на 5 с с визуальным эффектом Acid Spray."),
	epic("e_smart", "acorn", "Умная бомба", "Взрывы Acorn Shot наносят на 15% больше урона целям ниже 30% здоровья."),
	epic("e_modification", "acorn", "Модификация", "Каждые 50 ловкости добавляют +10 базового урона Acorn Shot."),
	epic("e_kits", "acorn", "Кустарная сборка", "С шансом 25% Acorn Shot не отскакивает и сразу взрывается с 200% урона."),
	epic("e_euphoria", "acorn", "Эйфория", "Убийство 3+ врагов одним Acorn Shot даёт +20% скорости атаки и передвижения на 4 с."),
	epic("e_net_duration", "bushwhack", "Крепкая сеть", "Длительность Bushwhack и ускорения «Охотничьего азарта» увеличена на 2 с."),
	epic("e_wide_net", "bushwhack", "Массивная сеть", "Радиус Bushwhack увеличен на 300."),
	epic("e_bone_armor", "bushwhack", "Костяной доспех", "Находясь в радиусе 600 от пойманного врага, Hoodwink получает +20 брони."),
	epic("e_blood_trail", "bushwhack", "Острые путы", "После сети враг оставляет кровавый след: 50% замедления и 150 чистого урона в секунду на 5 с."),
	epic("e_easy_prey", "bushwhack", "Лёгкая добыча", "Цели ниже 30% здоровья получают вдвое больше урона Bushwhack."),
	epic("e_blood_energy", "bushwhack", "Энергия крови", "Вампиризм от атак по пойманным целям также восстанавливает ману в размере 5% нанесённого урона."),
	epic("e_stonework", "bushwhack", "Забить камнями", "Acorn Shot дополнительно отскакивает 6 раз, если попадает по пойманной цели."),
	epic("e_hunter_luck", "bushwhack", "Удача охотника", "Атаки по пойманным врагам имеют 15% шанс бесплатно выпустить в них Acorn Shot."),
	epic("e_scurry_blast", "scurry", "Кустарная сборка", "По окончании Scurry наносит магический урон врагам в радиусе 700."),
	epic("e_attention", "scurry", "Привлекая внимание", "При применении Scurry враги вокруг Hoodwink 2 с вынуждены атаковать её."),
	epic("e_artillery", "scurry", "Артиллерия", "Под Scurry дальность атаки +350 и базовый урон атак увеличен на 200%."),
	epic("e_lumber", "scurry", "Оторву кусочек", "За каждое убийство босса Hoodwink навсегда получает +5 брони."),
	epic("e_dense_skin", "scurry", "Плотная шкура", "Могучий Дуб снижает физический урон на 82.5%, но также замедляет скорость атаки и движения на 82.5%."),
	epic("e_survival", "scurry", "Инстинкт выживания", "При падении здоровья ниже 25% автоматически применяет Scurry (перезарядка 20 с)."),
	epic("e_long_defense", "scurry", "Долгосрочная оборона", "Длительность Scurry увеличена на 2 с."),
	epic("e_acorn_stun", "scurry", "По голове", "Acorn Shot оглушает цель при попадании на 0.5 с."),
	epic("e_explosive_ammo", "sharpshooter", "Разрывной боеприпас", "Попадание Sharpshooter взрывается и наносит вокруг 25% урона снаряда магическим уроном."),
	epic("e_toxic_stakes", "sharpshooter", "Токсичные колья", "Попадание Sharpshooter замедляет врага на 50% на 3 с."),
	epic("e_deep_wounds", "sharpshooter", "Глубокие раны", "Попадание Sharpshooter вызывает кровотечение: 5% максимального здоровья за 5 с."),
	epic("e_devil_deal", "sharpshooter", "Сделка с Дьяволом", "Можно применить Sharpshooter во время его перезарядки, заплатив половину текущего здоровья."),
	epic("e_conscience", "sharpshooter", "Сделка с Совестью", "Снаряд наносит союзникам 15% урона и получает +20% урона за каждого задетого союзника."),
	epic("e_camouflage_shot", "sharpshooter", "Маскировка", "При применении Sharpshooter вокруг Hoodwink появляются деревья на 4 с."),
	epic("e_farewell", "sharpshooter", "Прощальный выстрел", "После смерти Hoodwink выпускает шесть снарядов Sharpshooter вокруг себя."),
	epic("e_fool_bullet", "sharpshooter", "Пуля-дура", "Если снаряд Sharpshooter никого не задел, он улетает в случайном направлении."),

	-- накопительные улучшения способностей (редкие)
	{ id = "r_acorn_damage", tier = 2, max = 30, name = "Тяжёлые желуди", desc = "+25 к урону Acorn Shot", hoodwink = { acorn_damage = 25 } },
	{ id = "r_acorn_bounces", tier = 2, max = 10, name = "Дальний отскок", desc = "+1 отскок Acorn Shot", hoodwink = { acorn_bounces = 1 } },
	{ id = "r_acorn_radius", tier = 2, max = 12, name = "Широкий разлёт", desc = "+25 к радиусу взрыва Acorn Shot", hoodwink = { acorn_radius = 25 } },
	{ id = "r_acorn_range", tier = 2, max = 10, name = "Точный бросок", desc = "+75 к дальности Acorn Shot", hoodwink = { acorn_range = 75 } },
	{ id = "r_bush_damage", tier = 2, max = 30, name = "Острые шипы", desc = "+40 к урону Bushwhack", hoodwink = { bush_damage = 40 } },
	{ id = "r_bush_duration", tier = 2, max = 10, name = "Долгая сеть", desc = "+0.3 с к длительности Bushwhack", hoodwink = { bush_duration = 0.3 } },
	{ id = "r_bush_radius", tier = 2, max = 10, name = "Ловушка пошире", desc = "+20 к радиусу Bushwhack", hoodwink = { bush_radius = 20 } },
	{ id = "r_bush_range", tier = 2, max = 10, name = "Дальний силок", desc = "+75 к дальности Bushwhack", hoodwink = { bush_range = 75 } },
	{ id = "r_scurry_duration", tier = 2, max = 10, name = "Быстрый рывок", desc = "+0.3 с к длительности Scurry", hoodwink = { scurry_duration = 0.3 } },
	{ id = "r_scurry_cooldown", tier = 2, max = 10, name = "Частый рывок", desc = "−1 с к перезарядке Scurry", hoodwink = { scurry_cooldown = 1 } },
	{ id = "r_sharp_damage", tier = 2, max = 30, name = "Тяжёлый выстрел", desc = "+100 к урону Sharpshooter", hoodwink = { sharp_damage = 100 } },
	{ id = "r_sharp_range", tier = 2, max = 10, name = "Длинный ствол", desc = "+100 к дальности Sharpshooter", hoodwink = { sharp_range = 100 } },
	{ id = "r_sharp_cooldown", tier = 2, max = 10, name = "Быстрая перезарядка", desc = "−2 с к перезарядке Sharpshooter", hoodwink = { sharp_cooldown = 2 } },
	{ id = "r_hunter_stats", tier = 2, max = 20, name = "Лесная охотница", desc = "+15 к ловкости и +5 к скорости атаки", stats = { agi = 15, as = 5 } },
	{ id = "r_trapper", tier = 2, max = 20, name = "Следопыт", desc = "+2 брони и +2 к регенерации здоровья", stats = { armor = 2, hpregen = 2 } },
}

RPG.HEROES["npc_dota_hero_hoodwink"] = {
	modifier = "modifier_rpg_hoodwink",
	builds = BUILDS,
	perks = PERKS,
}

