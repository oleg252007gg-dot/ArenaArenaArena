-- Axe: механики способностей, Aghanim's, таланты и ПЕРКИ героя.
-- Способности (KV) -> abilities/rpg_axe.lua, модификаторы -> modifiers/modifier_rpg_axe*.lua
Axe = Axe or {}

-- ======================= НАСТРОЙКИ (всё можно менять здесь) =======================
Axe.C = {
	-- Мифический перк «Взрывная Ярость»
	MYTHIC_DURATION   = 6,      -- длительность Berserker's Call (с)
	EXPLOSION_RADIUS  = 1200,
	EXPLOSION_MULT    = 1.5,    -- 150% накопленного урона

	-- Легендарные
	AEGIS_REDUCTION   = 65,     -- % снижения входящего урона во время Call
	CHAIN_RADIUS      = 750,
	CHAIN_PCT         = 0.35,   -- 35% урона волны
	LEECH_PCT         = 0.25,   -- 25% от нанесённого волной -> лечение
	BARRIER_PCT       = 1.0,    -- барьер = 100% нанесённого волной урона
	BARRIER_RADIUS    = 1200,
	BARRIER_DURATION  = 10,

	-- Эпические
	SHRED_PCT         = 30,     -- Разгром легиона: -30% брони
	PULL_RADIUS       = 1500,   -- Неизбежная битва
	PULL_TIME         = 0.35,
	PULL_STOP         = 120,    -- на каком расстоянии от Акса останавливаются притянутые
	FIRE_RADIUS       = 500,    -- Выжженная земля
	FIRE_PCT          = 2.5,    -- % макс. здоровья в секунду (магический)
	FIRE_AFTER        = 3,
	DASH_DIST         = 300,    -- Стремительность
	DASH_DAMAGE       = 500,
	DASH_WIDTH        = 150,
	VETERAN_HP        = 0.10,   -- Ветеран
	VETERAN_TIME      = 4,
	VETERAN_CD        = 60,
	IRON_MAX_ARMOR    = 70,     -- Броненосец: максимум при 10% здоровья
	IRON_HP_FLOOR     = 0.10,
	SACRIFICE_CD      = 300,    -- Жертвенник
	PERSIST_CD        = 180,    -- Упорство
	PERSIST_RADIUS    = 300,
	PERSIST_STUN      = 0.5,

	-- Culling Blade
	CULL_BASE_PCT     = { 12, 16, 20 },    -- дублирует KV; код читает KV, это справочно
	SCEPTER_AS_SLOW   = 50,
}

-- ======================= УТИЛИТЫ =======================
-- Сила с защитой от разницы сигнатур GetStrength в версиях Dota
function Axe:Str(c)
	local ok, v = pcall(c.GetStrength, c, false)
	if ok and type(v) == "number" then return v end
	ok, v = pcall(c.GetStrength, c)
	if ok and type(v) == "number" then return v end
	return 0
end

function Axe:Int(c)
	local ok, v = pcall(c.GetIntellect, c, false)
	if ok and type(v) == "number" then return v end
	ok, v = pcall(c.GetIntellect, c)
	return ok and type(v) == "number" and v or 0
end

function Axe:Has(hero, perk_id)
	return hero and hero.rpg and (hero.rpg.perk_count[perk_id] or 0) > 0
end

-- Накопительные бонусы редких перков: call_radius, call_armor, call_duration, cull_damage, cull_threshold,
-- helix_damage, helix_chance, hunger_dps, hunger_duration, hunger_slow
function Axe:Bonus(hero, key)
	return (hero and hero.rpg and hero.rpg.axe_bonus and hero.rpg.axe_bonus[key]) or 0
end

-- Запасной визуальный путь: эффекты способностей создаются напрямую, чтобы
-- они оставались видимыми даже при ошибке загрузки status-модификаторов.
function Axe:TimedParticle(path, unit, duration)
	if not IsServer() or not unit or unit:IsNull() then return end
	local fx = ParticleManager:CreateParticle(path, PATTACH_ABSORIGIN_FOLLOW, unit)
	ParticleManager:SetParticleControlEnt(fx, 0, unit, PATTACH_POINT_FOLLOW, "attach_hitloc", unit:GetAbsOrigin(), true)
	RPG.After(math.max(0.1, duration or 0.1), function()
		ParticleManager:DestroyParticle(fx, false)
		ParticleManager:ReleaseParticleIndex(fx)
	end)
end

function Axe:TalentAbility(hero, key)
	local ab = hero:FindAbilityByName("special_bonus_rpg_axe_" .. key)
	if ab and ab:GetLevel() > 0 then return ab end
	return nil
end

function Axe:Talent(hero, key)
	return self:TalentAbility(hero, key) ~= nil
end

function Axe:HasShard(hero)  return hero:HasModifier("modifier_item_aghanims_shard") end
function Axe:HasScepter(hero) return hero:HasScepter() end

function Axe:IsBoss(unit) return unit.rpg_boss == true end
function Axe:IsElite(unit)
	if self:IsBoss(unit) then return true end
	local name = unit:GetUnitName()
	return name == "npc_rpg_creep_brute" or name == "npc_rpg_centaur" or name == "npc_rpg_troll_summoner" or name == "npc_rpg_golem"
end

function Axe:Enemies(caster, pos, radius)
	return FindUnitsInRadius(caster:GetTeamNumber(), pos, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
end

local function fx_world(path, pos, cp1)
	local fx = ParticleManager:CreateParticle(path, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, pos)
	if cp1 then ParticleManager:SetParticleControl(fx, 1, cp1) end
	ParticleManager:ReleaseParticleIndex(fx)
end

-- Урон «в % от макс. здоровья»: против боссов урезается (иначе боссы тают)
function Axe:PctOfMax(target, pct)
	local v = target:GetMaxHealth() * pct / 100
	if self:IsBoss(target) then v = v * RPG.CFG.BOSS_PCT_MULT end
	return v
end

-- ======================= BERSERKER'S CALL =======================
function Axe:CallRadius(caster, ability)
	local t20=self:TalentAbility(caster, "20_call_radius")
	local t35=self:TalentAbility(caster, "35_call_strength")
	local bonus=(t20 and t20:GetSpecialValueFor("value") or 0) + (t35 and self:Str(caster)*t35:GetSpecialValueFor("value") or 0)
	return ability:GetSpecialValueFor("radius") + self:Bonus(caster, "call_radius") + bonus
end

function Axe:CallDuration(caster, ability)
	if self:Has(caster, "m_explosive_rage") then return self.C.MYTHIC_DURATION end
	return ability:GetSpecialValueFor("duration") + self:Bonus(caster, "call_duration")
end

-- Применение способности игроком
function Axe:CastCall(caster, ability)
	-- Эпик «Стремительность»: рывок вперёд на 300, 500 физ. урона всем на пути
	if self:Has(caster, "e_rush") then
		local fwd = caster:GetForwardVector()
		fwd.z = 0
		fwd = fwd:Normalized()
		local from = caster:GetAbsOrigin()
		local to = from + fwd * self.C.DASH_DIST
		local hit = FindUnitsInLine(caster:GetTeamNumber(), from, to, nil, self.C.DASH_WIDTH, DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE)
		for _, e in ipairs(hit) do
			ApplyDamage({ victim = e, attacker = caster, damage = self.C.DASH_DAMAGE, damage_type = DAMAGE_TYPE_PHYSICAL, ability = ability })
		end
		fx_world("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", from)
		FindClearSpaceForUnit(caster, to, true)
	end
	self:DoCall(caster, ability, caster:GetAbsOrigin(), self:CallRadius(caster, ability), "full")
end

-- mode: "full"  - полноценный Call (насмешка, бафф брони Акса, перки)
--       "weak"  - только замедление скорости атаки (Scepter, цель Culling Blade не умерла)
function Axe:DoCall(caster, ability, center, radius, mode)
	EmitSoundOn("Hero_Axe.Berserkers_Call", caster)
	fx_world("particles/units/heroes/hero_axe/axe_beserkers_call_start.vpcf", center, Vector(radius, radius, radius))

	local dur = self:CallDuration(caster, ability)
	local enemies = self:Enemies(caster, center, radius)

	if mode == "weak" then
		for _, e in ipairs(enemies) do
			e:AddNewModifier(caster, ability, "modifier_rpg_as_slow", { duration = ability:GetSpecialValueFor("duration"), slow = self.C.SCEPTER_AS_SLOW })
		end
		return
	end

	local shred = self:Has(caster, "e_legion_break")
	self:TimedParticle("particles/units/heroes/hero_axe/axe_beserkers_call_owner.vpcf", caster, dur)
	for _, e in ipairs(enemies) do
		self:TimedParticle("particles/status_fx/status_effect_beserkers_call.vpcf", e, dur)
		e:AddNewModifier(caster, ability, "modifier_rpg_call_taunt", { duration = dur })
		if self:Has(caster, "e_hunger_roar") then
			local hunger = caster:FindAbilityByName("rpg_axe_battle_hunger")
			self:ApplyHunger(caster, hunger, e, false, true)
		end
		if shred then
			e:AddNewModifier(caster, ability, "modifier_rpg_armor_shred", { duration = dur, pct = self.C.SHRED_PCT })
		end
	end

	-- Бафф на Аксе: броня, (Эгида), накопление урона (Мифик)
	caster:AddNewModifier(caster, ability, "modifier_rpg_call_buff", {
		duration = dur,
		armor = ability:GetSpecialValueFor("bonus_armor") + self:Bonus(caster, "call_armor") + ((self:TalentAbility(caster, "10_call_armor") and self:TalentAbility(caster, "10_call_armor"):GetSpecialValueFor("value")) or 0),
		mythic = self:Has(caster, "m_explosive_rage") and 1 or 0,
		aegis = self:Has(caster, "l_aegis") and 1 or 0,
	})

	-- Эпик «Выжженная земля»
	if self:Has(caster, "e_scorched") then
		CreateModifierThinker(caster, ability, "modifier_rpg_fire_zone", {
			duration = dur + self.C.FIRE_AFTER,
			follow = caster:entindex(),
			follow_time = dur,
			radius = self.C.FIRE_RADIUS,
			pct = self.C.FIRE_PCT,
		}, caster:GetAbsOrigin(), caster:GetTeamNumber(), false)
	end
end

-- Конец Call (вызывается из modifier_rpg_call_buff:OnDestroy)
function Axe:EndCall(caster, ability, stored)
	if not caster or caster:IsNull() then return end
	local delay = 0
	if self:Has(caster, "e_inevitable") then
		local pos = caster:GetAbsOrigin()
		for _, e in ipairs(self:Enemies(caster, pos, self.C.PULL_RADIUS)) do
			e:AddNewModifier(caster, ability, "modifier_rpg_pull", { duration = self.C.PULL_TIME, x = pos.x, y = pos.y, stop = self.C.PULL_STOP })
		end
		delay = self.C.PULL_TIME + 0.05   -- сначала притягиваем, потом взрываем
	end
	if self:Has(caster, "m_explosive_rage") and stored and stored > 0 then
		if delay > 0 then
			RPG.After(delay, function() self:Explode(caster, ability, stored) end)
		else
			self:Explode(caster, ability, stored)
		end
	end
end

-- Взрывная волна мифика
function Axe:Explode(caster, ability, stored)
	if not caster or caster:IsNull() then return end
	local C = self.C
	local damage = stored * C.EXPLOSION_MULT
	local center = caster:GetAbsOrigin()
	fx_world("particles/units/heroes/hero_jakiro/jakiro_liquid_fire_explosion.vpcf", center)
	fx_world("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", center)
	EmitSoundOn("Hero_Axe.Berserkers_Call", caster)

	local total, dead_at = 0, {}
	local chain = self:Has(caster, "l_chain")
	for _, e in ipairs(self:Enemies(caster, center, C.EXPLOSION_RADIUS)) do
		local dealt = ApplyDamage({ victim = e, attacker = caster, damage = damage, damage_type = DAMAGE_TYPE_PURE, ability = ability })
		total = total + (dealt or 0)
		if chain and not e:IsAlive() then table.insert(dead_at, e:GetAbsOrigin()) end
	end

	-- Цепная реакция: от каждого погибшего от волны - 35% урона волны по всем в радиусе 750 (один уровень, без рекурсии)
	for _, pos in ipairs(dead_at) do
		fx_world("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", pos)
		for _, e in ipairs(self:Enemies(caster, pos, C.CHAIN_RADIUS)) do
			if e:IsAlive() then
				local dealt = ApplyDamage({ victim = e, attacker = caster, damage = damage * C.CHAIN_PCT, damage_type = DAMAGE_TYPE_PURE, ability = ability })
				total = total + (dealt or 0)
			end
		end
	end

	-- Сам себе Легион: 25% нанесённого урона -> лечение
	if self:Has(caster, "l_legion") and caster:IsAlive() and total > 0 then
		caster:Heal(total * C.LEECH_PCT, caster)
	end

	-- Ответственный генерал: нанесённый урон -> физический барьер Аксу и союзникам в радиусе
	if self:Has(caster, "l_general") and total > 0 then
		local allies = FindUnitsInRadius(caster:GetTeamNumber(), center, nil, C.BARRIER_RADIUS, DOTA_UNIT_TARGET_TEAM_FRIENDLY,
			DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
		for _, a in ipairs(allies) do
			if a:IsAlive() then
				a:AddNewModifier(caster, ability, "modifier_rpg_barrier", { duration = C.BARRIER_DURATION, amount = total * C.BARRIER_PCT })
			end
		end
	end
end

-- ======================= BATTLE HUNGER =======================
-- force_level1: Aghanim's Shard накладывает Battle Hunger ПЕРВОГО уровня
function Axe:ApplyHunger(caster, ability, target, force_level1, skip_recast_burst)
	if not ability or not target or target:IsNull() or not target:IsAlive() then return end
	local idx = force_level1 and 0 or math.max(0, ability:GetLevel() - 1)
	local dps  = ability:GetLevelSpecialValueFor("damage_per_second", idx) + self:Bonus(caster, "hunger_dps")
	-- масштабирование от Силы: иначе на поздних волнах (тысячи ХП у врагов) Battle Hunger ничего не значит
	dps = dps + self:Str(caster) * ability:GetLevelSpecialValueFor("str_scale", idx)
	local int_dps = self:Has(caster, "m_strategic") and self:Int(caster) * 0.25 or 0
	local ti=self:TalentAbility(caster, "25_hunger_int")
	if ti then dps=dps + dps*self:Int(caster)*ti:GetSpecialValueFor("value")/100 end
	local td=self:TalentAbility(caster, "10_hunger_damage")
	if td then dps=dps*(1+td:GetSpecialValueFor("value")/100) end
	local dur  = ability:GetLevelSpecialValueFor("duration", idx) + self:Bonus(caster, "hunger_duration")
	local slow = ability:GetLevelSpecialValueFor("slow", idx) + self:Bonus(caster, "hunger_slow")
	local t = self:TalentAbility(caster, "15_hunger_duration")
	if t then dur = dur + t:GetSpecialValueFor("value") end
	local old = target:FindModifierByNameAndCaster("modifier_rpg_battle_hunger", caster)
	if old and not skip_recast_burst and self:Has(caster, "l_deep_wounds") then
		local burst = self:Int(caster) * 0.25 * math.max(1, old:GetStackCount() + (self:Has(caster, "m_strategic") and 1 or 0))
		ApplyDamage({ victim = target, attacker = caster, damage = burst, damage_type = DAMAGE_TYPE_MAGICAL, ability = ability })
	end
	self:TimedParticle("particles/units/heroes/hero_axe/axe_battle_hunger.vpcf", target, dur)
	local add = (old and self:Has(caster, "m_strategic")) and 1 or 0
	if old then
		old:AddStack(dps, int_dps, slow, dur, add)
	else
		target:AddNewModifier(caster, ability, "modifier_rpg_battle_hunger", { duration = dur, dps = dps, int_dps = int_dps, slow = slow, stacks = 1 })
	end
end

function Axe:HungerStacksOnArena(caster)
	local total = 0
	for _, enemy in ipairs(self:Enemies(caster, caster:GetAbsOrigin(), 30000)) do
		local mod = enemy:FindModifierByNameAndCaster("modifier_rpg_battle_hunger", caster)
		if mod then total = total + mod:GetStackCount() end
	end
	return total
end

function Axe:TransferHunger(caster, ability, dead, stacks)
	if not self:Has(caster, "l_dread") or stacks < 3 then return end
	local pos = dead:GetAbsOrigin()
	local enemies = self:Enemies(caster, pos, 30000)
	local nearest, best = nil, 30000
	for _, enemy in ipairs(enemies) do
		if enemy ~= dead then
			local d = (enemy:GetAbsOrigin() - pos):Length2D()
			if d < best then nearest, best = enemy, d end
		end
	end
	if nearest then
		for _ = 1, stacks do self:ApplyHunger(caster, ability, nearest, false, true) end
	end
end

-- ======================= COUNTER HELIX =======================
function Axe:HelixChance(caster, ability)
	if self:Has(caster, "m_whirlwind") then
		if self:Has(caster, "e_not_done") and caster:GetHealth() < caster:GetMaxHealth() * 0.30 then return 70 end
		return 50
	end
	local c = ability:GetSpecialValueFor("trigger_chance") + self:Bonus(caster, "helix_chance")
	if self:HasShard(caster) then c = c + 5 end
	return c
end

function Axe:Helix(caster, ability, radius_scale, extra)
	if not ability or ability:GetLevel() < 1 then return end
	radius_scale = radius_scale or 1
	local radius = ability:GetSpecialValueFor("radius") * radius_scale
	if self:Has(caster, "l_mass_destruction") then radius = radius * 2 end
	local base = ability:GetSpecialValueFor("damage") + self:Bonus(caster, "helix_damage")
	local t25 = self:TalentAbility(caster, "25_helix_agi")
	if t25 then base = base + base*caster:GetAgility()*t25:GetSpecialValueFor("value")/100 end
	local t50=self:TalentAbility(caster, "50_helix_proc")
	local helix_bonus=false
	if t50 and GameRules:GetGameTime() >= (caster.rpg.helix_talent_ready or 0) then
		base=base*(t50:GetSpecialValueFor("value")/100); caster.rpg.helix_talent_ready=GameRules:GetGameTime()+7; helix_bonus=true
	end
	local mythic = self:Has(caster, "m_whirlwind")
	local center = caster:GetAbsOrigin()
	caster.rpg.helix_procs = (caster.rpg.helix_procs or 0) + 1
	local proc = caster.rpg.helix_procs
	if mythic then base = base + caster:GetAttackDamage() * 1.20 end
	if self:Has(caster, "e_critical_whirl") and proc % 5 == 0 then base = base + caster:GetAttackDamage() * 2 end

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_axe/axe_attack_blur_counterhelix.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(fx)
	EmitSoundOn("Hero_Axe.CounterHelix", caster)

	local hit_count = 0
	for _, e in ipairs(self:Enemies(caster, center, radius)) do
		local dmg, crit = base, false
		if self:Has(caster, "e_weak_link") and e:GetHealth() < e:GetMaxHealth() * 0.20 then dmg = dmg * 1.5 end
		if helix_bonus then dmg, crit=dmg, true end
		local was_alive = e:IsAlive()
		local dealt = ApplyDamage({ victim = e, attacker = caster, damage = dmg,
			damage_type = mythic and DAMAGE_TYPE_PHYSICAL or DAMAGE_TYPE_PURE, ability = ability }) or 0
		if was_alive and not e:IsAlive() then
			if self:Has(caster, "e_infinite_slaughter") then self:ReduceCull(caster, 0.5) end
		end
		hit_count = hit_count + 1
		if self:Has(caster, "l_vicious_authority") then
			if self:IsBoss(e) then caster:Heal(e:GetMaxHealth() * 0.05, ability) end
			local vamp = self:Has(caster, "e_persistence") and caster:GetHealth() < caster:GetMaxHealth() * 0.50 and 0.10 or 0.05
			caster:Heal(dealt * vamp, ability)
		end
		if self:Has(caster, "l_tendons") then
			e:AddNewModifier(caster, ability, "modifier_rpg_slow", { duration = 1.5, slow = 60 })
			e:AddNewModifier(caster, ability, "modifier_rpg_as_slow", { duration = 1.5, slow = 60 })
		end
		if self:Has(caster, "e_armor_off") then
			local shred = e:FindModifierByNameAndCaster("modifier_rpg_helix_shred", caster)
			if shred then shred:SetStackCount(math.min(10, shred:GetStackCount() + 1)); shred:SetDuration(5, true)
			else e:AddNewModifier(caster, ability, "modifier_rpg_helix_shred", { duration = 5 }) end
		end
		if self:Has(caster, "e_cut") then e:AddNewModifier(caster, ability, "modifier_rpg_axe_bleed", { duration = 5, pct = 5 / 3 }) end
		if self:Has(caster, "l_mass_destruction") and not e:IsHero() and not self:IsElite(e) then
			e:AddNewModifier(caster, ability, "modifier_rpg_pull", { duration = 0.25, x = center.x, y = center.y, stop = 120 })
		end
		if crit and e:IsAlive() then
			e:AddNewModifier(caster, ability, "modifier_rpg_pull", {
				duration = 0.2, x = center.x, y = center.y, stop = 0, max = t25:GetSpecialValueFor("pull_distance"),
			})
		end
	end
	if self:Has(caster, "e_explosive_inspiration") and hit_count >= 5 then
		fx_world("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", center)
		for _, e in ipairs(self:Enemies(caster, center, 300)) do
			ApplyDamage({ victim = e, attacker = caster, damage = base * 0.5, damage_type = DAMAGE_TYPE_PURE, ability = ability })
		end
	end
	if self:Has(caster, "e_flint_axe") and not extra then
		CreateModifierThinker(caster, ability, "modifier_rpg_fire_zone", { duration = 2, radius = 300, fixed_damage = 150,
			damage_type = DAMAGE_TYPE_MAGICAL, follow = caster:entindex(), follow_time = 2 }, center, caster:GetTeamNumber(), false)
	end
	if not extra and self:Has(caster, "l_repeat") and RandomFloat(0, 100) < 20 then
		RPG.After(0.12, function() if not caster:IsNull() then self:Helix(caster, ability, 0.70, true) end end)
	end
	if not extra and self:Has(caster, "e_chain_reaction") and RandomFloat(0, 100) < 15 then
		RPG.After(0.10, function()
			if caster:IsNull() then return end
			self:Helix(caster, ability, 1, true)
			RPG.After(0.10, function() if not caster:IsNull() then self:Helix(caster, ability, 1, true) end end)
		end)
	end

	-- Aghanim's Shard: волна крови -> Battle Hunger 1 уровня на всех задетых
	if self:HasShard(caster) then
		local hunger = caster:FindAbilityByName("rpg_axe_battle_hunger")
		local wr = ability:GetSpecialValueFor("shard_wave_radius")
		fx_world("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", center)
		for _, e in ipairs(self:Enemies(caster, center, wr)) do
			self:ApplyHunger(caster, hunger, e, true, true)
		end
	end
end

-- ======================= CULLING BLADE =======================
-- Сокращение перезарядки ульты на N секунд (талант 20 левый, возврат при убийстве)
function Axe:ReduceCull(caster, seconds)
	local ab = caster:FindAbilityByName("rpg_axe_culling_blade")
	if not ab or seconds <= 0 then return end
	local rem = ab:GetCooldownTimeRemaining()
	if rem > 0 then
		ab:EndCooldown()
		if rem > seconds then ab:StartCooldown(rem - seconds) end
	end
	local mod = caster:FindModifierByName("modifier_rpg_cull_charges")
	if mod then mod:Reduce(seconds) end
end

function Axe:CullingBlade(caster, ability, target, is_splash)
	local lvl = ability:GetLevel()
	local idx = lvl - 1
	local scepter = self:HasScepter(caster)

	-- Заряды (талант 25 левый)
	local ch = caster:FindModifierByName("modifier_rpg_cull_charges")
	if ch and not is_splash then ch:Consume() end

	-- Scepter: прыжок к цели
	if scepter and not is_splash then
		local from, to = caster:GetAbsOrigin(), target:GetAbsOrigin()
		local dir = to - from
		dir.z = 0
		if dir:Length2D() > 120 then
			dir = dir:Normalized()
			FindClearSpaceForUnit(caster, to - dir * 100, true)
			caster:FaceTowards(to)
		end
	end

	local pos = target:GetAbsOrigin()
	local flat = ability:GetLevelSpecialValueFor("boss_damage", idx) + self:Bonus(caster, "cull_damage")
	if self:IsBoss(target) then
		for _, key in ipairs({"45_boss_damage", "50_boss_damage"}) do
			local t=self:TalentAbility(caster,key)
			if t then flat=flat + math.floor(caster:GetMaxHealth()/100)*t:GetSpecialValueFor("value") end
		end
	end
	flat = flat + (caster.rpg.cull_perm_damage or 0)
	if self:Has(caster, "e_experienced") then flat = flat + math.floor(caster:GetLevel() / 6) * 100 end
	local hunger = target:FindModifierByNameAndCaster("modifier_rpg_battle_hunger", caster)
	if hunger and self:Has(caster, "e_omen") then flat = flat * 1.15 end
	local killed = false
	if self:Has(caster, "e_raskolnikov") and RandomFloat(0, 100) < 1 then
		ApplyDamage({ victim = target, attacker = caster, damage = 99999, damage_type = DAMAGE_TYPE_PURE, ability = ability })
		killed = not target:IsAlive()
	end

	if killed then
		EmitSoundOn("Hero_Axe.Culling_Blade_Success", target)
		fx_world("particles/units/heroes/hero_axe/axe_culling_blade_kill.vpcf", pos)
	elseif self:IsBoss(target) then
		-- Боссов процент не убивает: огромный чистый урон = плоский + 20% ТЕКУЩЕГО здоровья
		local dmg = flat + target:GetHealth() * ability:GetSpecialValueFor("boss_current_hp_pct") / 100
		ApplyDamage({ victim = target, attacker = caster, damage = dmg, damage_type = DAMAGE_TYPE_PURE, ability = ability })
		killed = not target:IsAlive()
		EmitSoundOn("Hero_Axe.Culling_Blade_Fail", target)
	else
		local pct = ability:GetLevelSpecialValueFor("kill_threshold_pct", idx) + self:Bonus(caster, "cull_threshold")
		if target:GetHealth() <= target:GetMaxHealth() * pct / 100 then
			target:Kill(ability, caster)
			killed = true
			EmitSoundOn("Hero_Axe.Culling_Blade_Success", target)
			fx_world("particles/units/heroes/hero_axe/axe_culling_blade_kill.vpcf", pos)
		else
			-- не добил: как в оригинале, наносим плоский урон
			ApplyDamage({ victim = target, attacker = caster, damage = flat, damage_type = DAMAGE_TYPE_PURE, ability = ability })
			killed = not target:IsAlive()
			EmitSoundOn("Hero_Axe.Culling_Blade_Fail", target)
		end
	end

	if target:IsAlive() then
		if self:Has(caster, "l_careless_butcher") then target:AddNewModifier(caster, ability, "modifier_rpg_axe_bleed", { duration = 5, pct = 5 }) end
		if self:Has(caster, "l_rotten_blade") then target:AddNewModifier(caster, ability, "modifier_rpg_rotten_blade", { duration = 5 }) end
		if not killed and self:Has(caster, "e_headshot") then target:AddNewModifier(caster, ability, "modifier_stunned", { duration = 1 }) end
	end
	if self:Has(caster, "l_inferno") then
		CreateModifierThinker(caster, ability, "modifier_rpg_fire_zone", { duration = 2, radius = 300, fixed_damage = 300, damage_type = DAMAGE_TYPE_PURE },
			pos, caster:GetTeamNumber(), false)
	end

	if killed then
		if self:Has(caster, "m_woodcutter") then caster.rpg.cull_perm_damage = (caster.rpg.cull_perm_damage or 0) + 15 end
		-- Не уходит на перезарядку (возврат 80% перезарядки) + 30% скорости на 6 с
		local cd = ability:GetCooldown(idx)
		self:ReduceCull(caster, cd * ability:GetSpecialValueFor("cooldown_refund_pct") / 100)
		caster:AddNewModifier(caster, ability, "modifier_rpg_ms_buff", {
			duration = ability:GetSpecialValueFor("ms_duration") + ((self:TalentAbility(caster, "15_cull_duration") and self:TalentAbility(caster, "15_cull_duration"):GetSpecialValueFor("value")) or 0), pct = ability:GetSpecialValueFor("ms_bonus_pct"),
		})
		if self:Has(caster, "e_living") then caster:AddNewModifier(caster, ability, "modifier_rpg_cull_vitality", { duration = 10 }) end
	end

	if not killed and self:Has(caster, "m_woodcutter") and not target:IsAlive() then caster.rpg.cull_perm_damage = (caster.rpg.cull_perm_damage or 0) + 15 end

	if not is_splash and self:Has(caster, "m_woodcutter") then
		for _, enemy in ipairs(self:Enemies(caster, pos, 750)) do
			if enemy ~= target then self:CullingBlade(caster, ability, enemy, true) end
		end
	end

	-- Scepter: бесплатный Berserker's Call (радиус 400) вокруг убитой цели.
	-- Цель выжила (босс) - тот же радиус, но вместо Call только -50% скорости атаки.
	if scepter and not is_splash then
		local call = caster:FindAbilityByName("rpg_axe_berserkers_call")
		if call then
			local r = ability:GetSpecialValueFor("scepter_call_radius")
			self:DoCall(caster, call, pos, r, killed and "full" or "weak")
		end
	end
end

-- ======================= ПЕРКИ ЗАСТАВКИ =======================
-- Жертвенник: при вайпе отряда (если этот герой ещё не использовал перк) жизнь отряда не тратится
function Axe:TrySacrifice()
	local now = GameRules:GetGameTime()
	for _, h in ipairs(HeroList:GetAllHeroes()) do
		if self:Has(h, "e_sacrifice") and (h.rpg.sacrifice_cd or 0) <= now then
			h.rpg.sacrifice_cd = now + self.C.SACRIFICE_CD
			return h
		end
	end
	return nil
end

-- ======================= ОПИСАНИЕ ГЕРОЯ ДЛЯ СИСТЕМЫ ПЕРКОВ =======================
-- Ветки (builds) - путь после выбора мифического перка
local BUILDS = {
	call   = "Ярость (Berserker's Call)",
	hunger = "Голод (Battle Hunger)",
	helix  = "Вихрь (Counter Helix)",
	cull   = "Палач (Culling Blade)",
}

-- tier: 1 обычное, 2 редкое, 3 эпическое, 4 легендарное, 5 мифическое
-- build: перк принадлежит ветке (выпадает втрое чаще после выбора ветки)
-- requires_build: перк доступен ТОЛЬКО после выбора этой ветки (мифика)
-- axe = { ключ = значение } - накопительные бонусы к способностям (см. Axe:Bonus)
local PERKS = {
	-- ================= МИФИЧЕСКИЕ =================
	{ id = "m_explosive_rage", tier = 5, build = "call", max = 1, name = "Взрывная Ярость",
	  desc = "Берсерк-клич длится 6 секунд. Весь полученный за это время урон копится и по окончании разносится взрывной волной: 150% урона в радиусе 1200." },

	{ id = "m_strategic", tier = 5, build = "hunger", max = 1, name = "Стратегический подход",
	  desc = "Battle Hunger становится AoE-заклинанием (радиус 400), накладывает неограниченные стаки и наносит за тик каждой стаки 25% интеллекта Axe дополнительным уроном." },
	{ id = "m_whirlwind", tier = 5, build = "helix", max = 1, name = "Вихрь",
	  desc = "Counter Helix срабатывает с шансом 50% при каждой атаке Axe, а не при получении атак. Урон физический: базовый урон способности +120% урона атаки." },
	{ id = "m_woodcutter", tier = 5, build = "cull", max = 1, name = "Дровосек",
	  desc = "Culling Blade поражает всех врагов в радиусе 750 от цели. Каждое убийство навсегда даёт +15 урона способности." },

	-- ================= ЛЕГЕНДАРНЫЕ (нужна ветка «Ярость», т.е. мифик) =================
	{ id = "l_aegis", tier = 4, build = "call", requires_build = "call", max = 1, name = "Эгида Мазохиста",
	  desc = "Во время Berserker's Call сопротивление урону 65%, но в волну урона идёт без учёта этого сопротивления." },
	{ id = "l_chain", tier = 4, build = "call", requires_build = "call", max = 1, name = "Цепная реакция",
	  desc = "Если враг погибает от взрывной волны, все враги в радиусе 750 от него получают 35% урона волны." },
	{ id = "l_legion", tier = 4, build = "call", requires_build = "call", max = 1, name = "Сам себе Легион",
	  desc = "Восстанавливает 25% здоровья от урона взрывной волны." },
	{ id = "l_general", tier = 4, build = "call", requires_build = "call", max = 1, name = "Ответственный генерал",
	  desc = "Урон взрыва превращается в физический барьер для Axe и союзников в радиусе 1200 (10 с)." },
	{ id = "l_inspiration", tier = 4, build = "hunger", requires_build = "hunger", max = 1, name = "Воодушевление",
	  desc = "Каждый активный стак Battle Hunger на врагах арены даёт Axe +5% к усилению заклинаний." },
	{ id = "l_dread", tier = 4, build = "hunger", requires_build = "hunger", max = 1, name = "Глубокий ужас",
	  desc = "Смерть врага с 3+ стаками переносит все стаки на ближайшего врага." },
	{ id = "l_deep_wounds", tier = 4, build = "hunger", requires_build = "hunger", max = 1, name = "Глубокие раны",
	  desc = "Повторный каст Battle Hunger мгновенно наносит за каждый активный стак урон в размере 25% текущего интеллекта Axe." },
	{ id = "l_hunger_vamp", tier = 4, build = "hunger", requires_build = "hunger", max = 1, name = "Голодный вампиризм",
	  desc = "Каждый тик Battle Hunger лечит Axe на 10% нанесённого урона." },
	{ id = "l_mass_destruction", tier = 4, build = "helix", requires_build = "helix", max = 1, name = "Массовое уничтожение",
	  desc = "Радиус Counter Helix увеличен на 100%; мелкие враги притягиваются к Axe." },
	{ id = "l_vicious_authority", tier = 4, build = "helix", requires_build = "helix", max = 1, name = "Порочный авторитет",
	  desc = "Попадание Counter Helix по боссу лечит Axe на 5% его максимального здоровья; также Counter Helix даёт 5% вампиризма." },
	{ id = "l_tendons", tier = 4, build = "helix", requires_build = "helix", max = 1, name = "Оторванные сухожилия",
	  desc = "Задетые Counter Helix враги теряют 60% скорости атаки и передвижения на 1.5 с." },
	{ id = "l_repeat", tier = 4, build = "helix", requires_build = "helix", max = 1, name = "Повторение",
	  desc = "Counter Helix с шансом 20% повторно срабатывает с радиусом, уменьшенным на 30%." },
	{ id = "l_careless_butcher", tier = 4, build = "cull", requires_build = "cull", max = 1, name = "Небрежный мясник",
	  desc = "Пережившая Culling Blade цель кровоточит: 5% максимального здоровья в секунду в течение 5 с." },
	{ id = "l_rotten_blade", tier = 4, build = "cull", requires_build = "cull", max = 1, name = "Гнилое лезвие",
	  desc = "Пережившая Culling Blade цель на 5 с не может лечиться, замедлена на 75% и получает 100 урона в секунду." },
	{ id = "l_inferno", tier = 4, build = "cull", requires_build = "cull", max = 1, name = "Инферно",
	  desc = "После Culling Blade под целью 2 с горит земля, нанося 300 чистого урона в секунду." },
	{ id = "l_sturdy_blade", tier = 4, build = "cull", requires_build = "cull", max = 1, name = "Прочное лезвие",
	  desc = "Максимум зарядов Culling Blade увеличен до трёх." },

	-- ================= ЭПИЧЕСКИЕ =================
	{ id = "e_legion_break", tier = 3, build = "call", max = 1, name = "Разгром легиона",
	  desc = "Все противники, задетые Berserker's Call, теряют 30% брони." },
	{ id = "e_inevitable", tier = 3, build = "call", max = 1, name = "Неизбежная битва",
	  desc = "По окончании Berserker's Call притягивает всех противников в радиусе 1500 к Axe." },
	{ id = "e_scorched", tier = 3, build = "call", max = 1, name = "Выжженная земля",
	  desc = "Во время Berserker's Call поджигает землю в радиусе 500: каждую секунду 2.5% магического урона (от макс. здоровья), ещё 3 с после окончания." },
	{ id = "e_rush", tier = 3, build = "call", max = 1, name = "Стремительность",
	  desc = "Перед Berserker's Call рывок вперёд на 300: 500 физического урона всем на пути." },
	{ id = "e_veteran", tier = 3, build = "call", max = 1, name = "Ветеран",
	  desc = "При здоровье 10% даёт Shallow Grave на 4 с (перезарядка 60 с)." },
	{ id = "e_ironclad", tier = 3, build = "call", max = 1, name = "Броненосец",
	  desc = "Чем ниже здоровье, тем выше броня: до +70 брони при 10% здоровья." },
	{ id = "e_sacrifice", tier = 3, build = "call", max = 1, name = "Жертвенник",
	  desc = "При гибели отряда не тратится жизнь команды (перезарядка 5 минут)." },
	{ id = "e_persist", tier = 3, build = "call", max = 1, name = "Упорство",
	  desc = "После смерти возрождается на месте гибели, оглушая врагов в радиусе 300 на 0.5 с (перезарядка 3 минуты)." },
	{ id = "e_hunger_roar", tier = 3, build = "hunger", requires_build = "hunger", max = 1, name = "Страшный Рёв",
	  desc = "Berserker's Call накладывает Battle Hunger на всех задетых врагов." },
	{ id = "e_blood_diet", tier = 3, build = "hunger", requires_build = "hunger", max = 1, name = "Кровавая диета",
	  desc = "Если маны недостаточно для Battle Hunger, Axe может заплатить 4% максимального здоровья." },
	{ id = "e_piercing_int", tier = 3, build = "hunger", requires_build = "hunger", max = 1, name = "Пробивной интеллект",
	  desc = "Интеллектуальная часть урона Battle Hunger наносится чистым уроном мелким мобам, игнорируя их сопротивление магии." },
	{ id = "e_explosive_metabolism", tier = 3, build = "hunger", requires_build = "hunger", max = 1, name = "Взрывной метаболизм",
	  desc = "Смерть или снятие Battle Hunger с цели при 10+ стаках вызывает AoE-взрыв, наносящий 4 секунды суммарного урона стаков." },
	{ id = "e_chain_impulse", tier = 3, build = "hunger", requires_build = "hunger", max = 1, name = "Цепной импульс",
	  desc = "Смерть врага под Battle Hunger оставляет огонь на 3 с, наносящий 100 магического урона в секунду." },
	{ id = "e_impulse", tier = 3, build = "hunger", requires_build = "hunger", max = 1, name = "Импульс",
	  desc = "Каждые 5 с бесплатный стак Battle Hunger автоматически накладывается на ближайшего врага." },
	{ id = "e_compensation", tier = 3, build = "hunger", requires_build = "hunger", max = 1, name = "Компенсация",
	  desc = "Когда здоровье Axe впервые падает до 60% или ниже, он получает +15% интеллекта на 4 с. Срабатывает снова после восстановления выше 60%." },
	{ id = "e_no_compromise", tier = 3, build = "hunger", requires_build = "hunger", max = 1, name = "Без компромиссов",
	  desc = "Враги с 10+ стаками Battle Hunger не могут лечиться и восстанавливать здоровье." },
	{ id = "e_armor_off", tier = 3, build = "helix", requires_build = "helix", max = 1, name = "Броню прочь",
	  desc = "Каждый удар Counter Helix отнимает 2 брони на 5 с, до 10 раз." },
	{ id = "e_not_done", tier = 3, build = "helix", requires_build = "helix", max = 1, name = "Ещё не сдался",
	  desc = "При здоровье Axe ниже 30% шанс Counter Helix от атак повышается с 50% до 70%." },
	{ id = "e_i_am_not_finished", tier = 3, build = "helix", requires_build = "helix", max = 1, name = "Я с тобой не закончил",
	  desc = "Непрерывные атаки повышают скорость атаки на 5 за удар, до 150; бонус спадает после паузы в 2 с." },
	{ id = "e_critical_whirl", tier = 3, build = "helix", requires_build = "helix", max = 1, name = "Критический вихрь",
	  desc = "Каждый пятый Counter Helix наносит дополнительно двойной текущий урон атаки." },
	{ id = "e_weak_link", tier = 3, build = "helix", requires_build = "helix", max = 1, name = "Слабое звено",
	  desc = "Counter Helix наносит в 1.5 раза больше урона врагам ниже 20% здоровья." },
	{ id = "e_explosive_inspiration", tier = 3, build = "helix", requires_build = "helix", max = 1, name = "Взрывное воодушевление",
	  desc = "Если Counter Helix задевает 5+ врагов, в центре наносится небольшой чистый урон." },
	{ id = "e_chain_reaction", tier = 3, build = "helix", requires_build = "helix", max = 1, name = "Цепная реакция",
	  desc = "С шансом 15% Counter Helix срабатывает три раза подряд." },
	{ id = "e_persistence", tier = 3, build = "helix", requires_build = "helix", requires_perk = "l_vicious_authority", max = 1, name = "Упорство",
	  desc = "При здоровье Axe ниже 50% вампиризм Counter Helix удваивается (нужен «Порочный авторитет»)." },
	{ id = "e_infinite_slaughter", tier = 3, build = "cull", requires_build = "cull", max = 1, name = "Бесконечная резня",
	  desc = "Убийство Counter Helix сокращает перезарядку Culling Blade на 0.5 с." },
	{ id = "e_cut", tier = 3, build = "cull", requires_build = "cull", max = 1, name = "Порез",
	  desc = "Counter Helix может наложить ослабленное втрое кровотечение «Небрежного мясника»." },
	{ id = "e_flint_axe", tier = 3, build = "cull", requires_build = "cull", max = 1, name = "Топор из кремня",
	  desc = "Counter Helix оставляет под Axe след Macropyre на 2 с, наносящий 150 магического урона в секунду." },
	{ id = "e_omen", tier = 3, build = "cull", requires_build = "cull", max = 1, name = "Дурное знамение",
	  desc = "Culling Blade наносит на 15% больше урона целям под Battle Hunger." },
	{ id = "e_experienced", tier = 3, build = "cull", requires_build = "cull", max = 1, name = "Опытный",
	  desc = "Culling Blade получает +100 урона за каждые 6 уровней Axe." },
	{ id = "e_raskolnikov", tier = 3, build = "cull", requires_build = "cull", max = 1, name = "Раскольников",
	  desc = "Culling Blade имеет 1% шанс мгновенно убить цель любым запасом здоровья." },
	{ id = "e_living", tier = 3, build = "cull", requires_build = "cull", max = 1, name = "Живучий",
	  desc = "Успешный Culling Blade даёт +2% максимального здоровья на 10 с, до 20 стаков." },
	{ id = "e_headshot", tier = 3, build = "cull", requires_build = "cull", max = 1, name = "В голову",
	  desc = "Если Culling Blade не казнит цель, она оглушается на 1 с." },

	-- ================= РЕДКИЕ: небольшие улучшения способностей (копятся) =================
	{ id = "r_call_radius",   tier = 2, max = 30, name = "Эхо клича",         desc = "+50 к радиусу Berserker's Call",            axe = { call_radius = 50 } },
	{ id = "r_call_armor",    tier = 2, max = 30, name = "Закалка в бою",     desc = "+4 к броне от Berserker's Call",            axe = { call_armor = 4 } },
	{ id = "r_call_duration", tier = 2, max = 20, name = "Затянувшаяся ярость", desc = "+0.3 с к длительности Berserker's Call",  axe = { call_duration = 0.3 } },
	{ id = "r_hunger_dps",    tier = 2, max = 30, name = "Острый голод",      desc = "+8 к урону в секунду Battle Hunger",        axe = { hunger_dps = 8 } },
	{ id = "r_hunger_dur",    tier = 2, max = 20, name = "Долгий голод",      desc = "+1.5 с к длительности Battle Hunger",       axe = { hunger_duration = 1.5 } },
	{ id = "r_hunger_slow",   tier = 2, max = 8,  name = "Ослабляющий голод", desc = "+3% к замедлению Battle Hunger",            axe = { hunger_slow = 3 } },
	{ id = "r_helix_dmg",     tier = 2, max = 30, name = "Вихрь",             desc = "+30 к урону Counter Helix",                 axe = { helix_damage = 30 } },
	{ id = "r_helix_chance",  tier = 2, max = 10, name = "Контрудар",         desc = "+2% к шансу Counter Helix",                 axe = { helix_chance = 2 } },
	{ id = "r_cull_dmg",      tier = 2, max = 30, name = "Жажда казни",       desc = "+100 к урону Culling Blade",                axe = { cull_damage = 100 } },
	{ id = "r_cull_pct",      tier = 2, max = 10, name = "Острое лезвие",     desc = "+0.5% к порогу казни Culling Blade",        axe = { cull_threshold = 0.5 } },
	{ id = "r_bloodlust",     tier = 2, max = 20, name = "Кровавый вкус",     desc = "+20 к урону, +3% вампиризм",                stats = { damage = 20, lifesteal = 3 } },
	{ id = "r_discipline",    tier = 2, max = 10, name = "Дисциплина",        desc = "+4% снижение перезарядки",                  stats = { cdr = 4 } },
}

RPG.HEROES["npc_dota_hero_axe"] = {
	modifier = "modifier_rpg_axe",
	builds = BUILDS,
	perks = PERKS,
}
