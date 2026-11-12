Waves = Waves or {}

Waves.MODS = {
	swarm       = { name = "Рой",                    count = 1.35, hp = 0.8 },
	fast        = { name = "Быстрые",                ms = 75 },
	armored     = { name = "Бронированные",          armor = 8, hp = 1.2 },
	explosive   = { name = "Взрывные",               explode = true },
	melee_guard = { name = "Щит ближнего боя",       melee_resist = 100, ranged_bonus = 100 },
	death_burst = { name = "Посмертный взрыв",       explode = true },
	rune_bless  = { name = "Случайная руна",         rune_chance = 10 },
	regen       = { name = "Восстановление",         regen_pct = 2 },
}
Waves.MOD_IDS = { "swarm", "fast", "armored", "explosive", "melee_guard", "death_burst", "rune_bless", "regen" }


function Waves:Init()
	self.wave = 0
	self.state = "idle"       -- idle -> break -> active -> break ... -> done
	self.alive = {}
	self.alive_count = 0
	self.queue = {}
	self.lives = RPG.CFG.LIVES
	self.countdown = 0
	self.players = 1
	CustomGameEventManager:RegisterListener("rpg_next_wave", function(_, data) Waves:NextWave(data) end)
	GameRules:GetGameModeEntity():SetContextThink("rpg_waves", function() return Waves:Think() end, 1)
end

function Waves:NextWave(data)
	if self.state ~= "break" then return end
	local hero = PlayerResource:GetSelectedHeroEntity(data.PlayerID)
	if not hero or not hero:IsRealHero() or hero:GetTeamNumber() ~= DOTA_TEAM_GOODGUYS then return end
	self.countdown = 0
	self:StartWave()
end

-- Центр арены: info_target с именем "arena_center" или значение из конфига
function Waves:Center()
	if not self.center then
		local ent = Entities:FindByName(nil, "arena_center")
		self.center = ent and ent:GetAbsOrigin() or RPG.CFG.ARENA_CENTER
	end
	return self.center
end

-- Точки спавна: info_target с именами rpg_spawn_1 ... rpg_spawn_8 (необязательно)
function Waves:SpawnPoints()
	if not self.spawn_points then
		self.spawn_points = {}
		for i = 1, 8 do
			local ent = Entities:FindByName(nil, "rpg_spawn_" .. i)
			if ent then table.insert(self.spawn_points, ent:GetAbsOrigin()) end
		end
	end
	return self.spawn_points
end

function Waves:Heroes(only_alive)
	local out = {}
	for _, h in ipairs(HeroList:GetAllHeroes()) do
		local player_id = h:GetPlayerOwnerID()
		local is_selected_player_hero = player_id >= 0 and PlayerResource:GetSelectedHeroEntity(player_id) == h
		if h:GetTeamNumber() == DOTA_TEAM_GOODGUYS and h:IsRealHero() and is_selected_player_hero and not h.rpg_is_tempest_double and (not only_alive or h:IsAlive()) then
			table.insert(out, h)
		end
	end
	return out
end

function Waves:Toast(text, color)
	CustomGameEventManager:Send_ServerToAllClients("rpg_toast", { text = text, color = color or "#ffffff" })
end

function Waves:Broadcast()
	CustomGameEventManager:Send_ServerToAllClients("rpg_wave_update", {
		wave = self.wave,
		final = RPG.CFG.FINAL_WAVE,
		state = self.state,
		countdown = self.countdown,
	can_skip = self.state == "break" and self.wave > 0 and 1 or 0,
		left = self.alive_count + #self.queue,
		total = self.wave_total or 0,
		break_total = self.break_total or 0,
		boss = (self.state == "active" and self.wave % RPG.CFG.BOSS_EVERY == 0) and 1 or 0,
		miniboss = (self.state == "active" and self.wave % RPG.CFG.MINIBOSS_EVERY == 0 and self.wave % RPG.CFG.BOSS_EVERY ~= 0) and 1 or 0,
		boss_name = self.boss_name or "",
		next_boss = (RPG.CFG.BOSS_EVERY - (self.wave % RPG.CFG.BOSS_EVERY)),
		players = self.players,
		lives = self.lives,
		max_lives = RPG.CFG.LIVES,
		mod = self.mod and Waves.MODS[self.mod].name or "",
	})
end

function Waves:Start()
	self.state = "break"
	self.countdown = RPG.CFG.FIRST_BREAK
	self.break_total = RPG.CFG.FIRST_BREAK
	self:Toast("Готовьтесь! Первая волна скоро начнётся.", "#ffffff")
end

function Waves:Think()
	if self.state == "break" then
		self.countdown = self.countdown - 1
		if self.countdown <= 0 then self:StartWave() end
	elseif self.state == "active" then
		self:PruneAlive()
		self:SpawnTick()
		-- Stall recovery only needs a coarse sample; scanning every living creep
		-- every frame of the wave was unnecessary work at 100+ enemies.
		local now = GameRules:GetGameTime()
		if now >= (self.next_stall_scan or 0) then
			self.next_stall_scan = now + 5
			self:RecoverStalledUnits(now)
		end
		self:IdleOrders()
		if #self.queue == 0 and self.alive_count <= 0 then self:EndWave() end
	end
	if self.state ~= "idle" then self:Broadcast() end
	return 1
end

-- Entity kill events can be missed when an NPC is removed by another system.
-- Rebuild the live count from tracked handles so one stale unit cannot hold a wave forever.
function Waves:PruneAlive()
	local live = 0
	for index, unit in pairs(self.alive) do
		if not IsValidEntity(unit) or unit:IsNull() or not unit:IsAlive() then
			self.alive[index] = nil
		else
			live = live + 1
		end
	end
	self.alive_count = live
end

-- Recover enemies that remain alive in the tracker but stop moving or taking
-- damage (for example, when their attack-move path ends outside the arena).
function Waves:RecoverStalledUnits(now)
	now = now or GameRules:GetGameTime()
	local heroes = self:Heroes(true)
	if #heroes == 0 then return end
	for _, unit in pairs(self.alive) do
		if IsValidEntity(unit) and unit:IsAlive() then
			local pos, hp = unit:GetAbsOrigin(), unit:GetHealth()
			if not unit.rpg_progress_pos then
				unit.rpg_progress_pos = pos
				unit.rpg_progress_hp = hp
				unit.rpg_progress_time = now
			elseif math.abs(hp - unit.rpg_progress_hp) > 1 or (pos - unit.rpg_progress_pos):Length2D() > 64 then
				unit.rpg_progress_pos = pos
				unit.rpg_progress_hp = hp
				unit.rpg_progress_time = now
			elseif now - (unit.rpg_progress_time or now) >= 30 then
				unit.rpg_stall_recoveries = (unit.rpg_stall_recoveries or 0) + 1
				local hero = heroes[((unit:entindex() - 1) % #heroes) + 1]
				local rescue = hero:GetAbsOrigin() + RandomVector(240)
				FindClearSpaceForUnit(unit, rescue, true)
				unit.rpg_progress_pos = unit:GetAbsOrigin()
				unit.rpg_progress_hp = unit:GetHealth()
				unit.rpg_progress_time = now
				self:OrderAttack(unit, heroes)
				if unit.rpg_stall_recoveries >= 3 and not unit.rpg_boss then
					print("[RPG] Removing permanently stalled wave unit " .. tostring(unit:GetUnitName()))
					unit:ForceKill(false)
				end
			end
		end
	end
end

-- Состав волны (враги и боссы берутся из game/enemies.lua)
function Waves:Compose()
	local w = self.wave
	local list = {}
	local mod = self.mod and Waves.MODS[self.mod]

	if w % RPG.CFG.BOSS_EVERY == 0 then
		local idx = ((w / RPG.CFG.BOSS_EVERY) - 1) % #Enemies.BOSSES + 1
		local boss = Enemies.BOSSES[idx]
		table.insert(list, { def = boss, boss = true })
		self.boss_name = boss.name
		return list -- уникальный босс выходит на арену один
	end

	local n = (RPG.CFG.WAVE_COUNT_BASE + (w - 1) * RPG.CFG.WAVE_COUNT_STEP) * RPG.CFG.COUNT_MULT
	if mod and mod.count then n = n * mod.count end
	n = math.min(n, RPG.CFG.MAX_WAVE_UNITS)
	for _ = 1, math.floor(n) do table.insert(list, { def = Enemies:Pick(w) }) end

	if w % RPG.CFG.MINIBOSS_EVERY == 0 then
		-- Advance the pair once per non-boss mini wave so every template is used.
		local mini_wave_index = math.floor((w + RPG.CFG.MINIBOSS_EVERY) / RPG.CFG.BOSS_EVERY)
		local mini_index = ((mini_wave_index - 1) * 2) % #Enemies.MINIBOSSES + 1
		for i = 0, 1 do
			local def = Enemies.MINIBOSSES[((mini_index + i - 1) % #Enemies.MINIBOSSES) + 1]
			table.insert(list, { def = def, miniboss = true })
		end
		self.miniboss_name = Enemies.MINIBOSSES[mini_index].name
	end
	return list
end

function Waves:StartWave()
	Progression:CloseOffers()
	self.wave = self.wave + 1
	self.players = math.max(1, #self:Heroes(false))
	self.mod = nil
	local boss_wave = self.wave % RPG.CFG.BOSS_EVERY == 0
	if self.wave >= 2 and not boss_wave and RandomFloat(0, 1) < 0.4 then
		self.mod = Waves.MOD_IDS[RandomInt(1, #Waves.MOD_IDS)]
	end
	self.queue = self:Compose()
	self.wave_total = #self.queue
	self.state = "active"

	if boss_wave then
		self:Toast("Волна " .. self.wave .. ": БОСС — " .. self.boss_name .. "!", "#ff5a4a")
	elseif self.wave % RPG.CFG.MINIBOSS_EVERY == 0 then
		self:Toast("Волна " .. self.wave .. ": мини-боссы — " .. (self.miniboss_name or ""), "#ff9d43")
	elseif self.mod then
		self:Toast("Волна " .. self.wave .. ": " .. Waves.MODS[self.mod].name, "#ffd24a")
	else
		self:Toast("Волна " .. self.wave, "#ffffff")
	end
end

function Waves:SpawnTick()
	local per_tick = math.max(2, math.ceil((#self.queue + self.alive_count) / 8))
	for _ = 1, per_tick do
		local entry = table.remove(self.queue)
		if not entry then return end
		if not self:SpawnUnit(entry) then
			entry.spawn_failures = (entry.spawn_failures or 0) + 1
			if entry.spawn_failures == 3 and not entry.boss and not entry.miniboss then
				print("[RPG] Spawn fallback for " .. tostring(entry.def.unit))
				entry.def = Enemies.ROSTER[1]
			end
			if entry.spawn_failures >= 6 then
				self.wave_total = math.max(0, (self.wave_total or 1) - 1)
				print("[RPG] Skipping unit after repeated creation failures: " .. tostring(entry.def.unit))
				self:Toast("Не удалось создать одного врага; волна продолжится.", "#ffb347")
				return
			end
			table.insert(self.queue, 1, entry)
			return
		end
	end
end

function Waves:SpawnUnit(entry)
	local center = self:Center()
	local points = self:SpawnPoints()
	local pos
	if #points > 0 then
		pos = points[RandomInt(1, #points)] + RandomVector(RandomInt(0, 200))
	else
		local ang = RandomFloat(0, 2 * math.pi)
		pos = center + Vector(math.cos(ang), math.sin(ang), 0) * RPG.CFG.SPAWN_RADIUS
	end

	local unit = CreateUnitByName(entry.def.unit, pos, true, nil, nil, DOTA_TEAM_BADGUYS)
	if not unit then return false end
	unit.rpg_wave = self.wave
	unit.rpg_boss = entry.boss == true
	unit.rpg_miniboss = entry.miniboss == true
	unit.rpg_normal_creep = not unit.rpg_boss and not unit.rpg_miniboss
	unit.rpg_def = entry.def
	self:Scale(unit, entry)
	self.alive[unit:entindex()] = unit
	self.alive_count = self.alive_count + 1
	self:OrderAttack(unit)

	Enemies:Attach(unit, entry.def)
	return true
end

-- Прислужники, призванные в ходе волны
function Waves:SpawnMinion(name, pos)
	if self.alive_count >= RPG.CFG.MAX_ALIVE then return end
	local unit = CreateUnitByName(name, pos, true, nil, nil, DOTA_TEAM_BADGUYS)
	if not unit then return end
	unit.rpg_wave = self.wave
	self:Scale(unit, {})
	self.alive[unit:entindex()] = unit
	self.alive_count = self.alive_count + 1
	self:OrderAttack(unit)
end

function Waves:Scale(unit, entry)
	local w = self.wave
	local mod = self.mod and Waves.MODS[self.mod]
	local stage = w - 1
	local hpm = (1 + RPG.CFG.ENEMY_HP_GROWTH * stage + 0.00008 * stage * stage) * (1 + 0.10 * (self.players - 1))
	local dmgm = 1 + RPG.CFG.ENEMY_DMG_GROWTH * stage + 0.00002 * stage * stage
	if unit.rpg_normal_creep and mod and mod.hp then hpm = hpm * mod.hp end
	if entry.boss then hpm = hpm * RPG.CFG.BOSS_HP_MULT; dmgm = dmgm * 2.5
	elseif entry.miniboss then
		-- Early minibosses stay beatable; the quadratic tail lets later ones
		-- grow into proper 100k-class encounters without a huge wave-5 spike.
		hpm = (1 + 0.04 * stage + 0.0004 * stage * stage) * (1 + 0.10 * (self.players - 1))
		dmgm = dmgm * 1.25
	end

	local hp = math.floor(unit:GetMaxHealth() * hpm)
	unit:SetBaseMaxHealth(hp)
	unit:SetMaxHealth(hp)
	unit:SetHealth(hp)

	unit:SetBaseDamageMin(math.floor(unit:GetBaseDamageMin() * dmgm))
	unit:SetBaseDamageMax(math.floor(unit:GetBaseDamageMax() * dmgm))

	local armor = unit:GetPhysicalArmorBaseValue() + w * 0.18 + ((unit.rpg_normal_creep and mod and mod.armor) or 0)
	unit:SetPhysicalArmorBaseValue(armor)

	if unit.rpg_normal_creep and mod and mod.ms then unit:SetBaseMoveSpeed(unit:GetBaseMoveSpeed() + mod.ms) end
	if unit.rpg_normal_creep and mod and mod.explode then unit.rpg_explode = true end
	if unit.rpg_normal_creep and mod then
		unit.rpg_wave_mod = self.mod
		if mod.rune_chance and RandomFloat(0, 100) < mod.rune_chance then unit.rpg_rune_blessed = true end
		local rune = unit.rpg_rune_blessed and RandomInt(1, 4) or 0
		if mod.melee_resist or mod.regen_pct or rune > 0 then
			unit:AddNewModifier(unit, nil, "modifier_rpg_wave_rules", { melee_guard = mod.melee_resist or 0, ranged_bonus = mod.ranged_bonus or 0, regen_pct = mod.regen_pct or 0, rune = rune })
		end
	end

	local gold = math.floor(unit:GetGoldBounty() * (1 + 0.05 * w))
	unit:SetMinimumGoldBounty(gold)
	unit:SetMaximumGoldBounty(gold)
	unit:SetDeathXP(0)
end

-- Враги идут к ближайшему живому герою (а не в центр арены, где они бы просто стояли)
local function nearest_hero_pos(unit, heroes, fallback)
	local best, bd
	for _, h in ipairs(heroes) do
		local d = (h:GetAbsOrigin() - unit:GetAbsOrigin()):Length2D()
		if not bd or d < bd then best, bd = h, d end
	end
	return best and best:GetAbsOrigin() or fallback
end

function Waves:OrderAttack(unit, heroes)
	unit.rpg_last_attack_order = GameRules:GetGameTime()
	ExecuteOrderFromTable({
		UnitIndex = unit:entindex(),
		OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
		Position = nearest_hero_pos(unit, heroes or self:Heroes(true), self:Center()),
		Queue = false,
	})
end

-- Раз в секунду: кто простаивает или потерял цель, снова получает приказ идти к герою
function Waves:IdleOrders()
	local heroes = self:Heroes(true)
	if #heroes == 0 then return end
	local now = GameRules:GetGameTime()
	for _, unit in pairs(self.alive) do
		if IsValidEntity(unit) and unit:IsAlive() then
			local elapsed = now - (unit.rpg_last_attack_order or 0)
			if (unit:IsIdle() and elapsed >= 2) or (unit:GetAttackTarget() == nil and elapsed >= 5) then
				self:OrderAttack(unit, heroes)
			end
		end
	end
end

function Waves:OnCreepKilled(unit)
	local idx = unit:entindex()
	if not self.alive[idx] then return end
	self.alive[idx] = nil
	self.alive_count = self.alive_count - 1

	local pos = unit:GetAbsOrigin()
	if unit.rpg_explode then self:Explode(unit, pos) end

	-- Лут: только артефакты и только с боссов
	if unit.rpg_boss and unit.rpg_def and unit.rpg_def.loot then
		Loot:DropArtifacts(pos, unit.rpg_def.loot, 1)
	end
end

function Waves:Explode(unit, pos)
	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, pos)
	ParticleManager:ReleaseParticleIndex(fx)
	local targets = FindUnitsInRadius(DOTA_TEAM_BADGUYS, pos, nil, 260, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, t in ipairs(targets) do
		ApplyDamage({ victim = t, attacker = unit, damage = t:GetMaxHealth() * 0.08, damage_type = DAMAGE_TYPE_MAGICAL })
	end
end

-- Топот: урон и оглушение вокруг юнита
function Waves:Slam(unit, radius, mult, stun)
	local pos = unit:GetAbsOrigin()
	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", PATTACH_ABSORIGIN, unit)
	ParticleManager:ReleaseParticleIndex(fx)
	EmitSoundOn("Hero_Ursa.Earthshock", unit)
	local targets = FindUnitsInRadius(unit:GetTeamNumber(), pos, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, t in ipairs(targets) do
		ApplyDamage({ victim = t, attacker = unit, damage = unit:GetAverageTrueAttackDamage(unit) * mult, damage_type = DAMAGE_TYPE_MAGICAL })
		if stun and stun > 0 then t:AddNewModifier(unit, nil, "modifier_stunned", { duration = stun }) end
	end
end

function Waves:EndWave()
	local w = self.wave
	for _, hero in ipairs(self:Heroes(false)) do
		if hero:GetLevel() < RPG.CFG.MAX_LEVEL then hero:HeroLevelUp(false) end
	end
	if w >= RPG.CFG.FINAL_WAVE then
		self:Toast("Победа! Все волны отбиты!", "#ffd24a")
		self.state = "done"
		GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
		return
	end

	self.state = "break"
	self.countdown = RPG.CFG.BREAK_TIME
	self.break_total = RPG.CFG.BREAK_TIME
	self.mod = nil
	for _, hero in ipairs(self:Heroes(false)) do
		if not hero:IsAlive() then hero:RespawnHero(false, false) end
		hero:SetHealth(hero:GetMaxHealth())
		hero:SetMana(hero:GetMaxMana())
		PlayerResource:ModifyGold(hero:GetPlayerOwnerID(), RPG.CFG.GOLD_PER_WAVE + w * 20, true, DOTA_ModifyGold_GameTick)
		Progression:Offer(hero)
	end
	self:Toast("Волна " .. w .. " отбита! Выберите улучшение и закупитесь.", "#7dff9a")
end

function Waves:CheckWipe()
	if self.state ~= "active" or self.wipe_pending then return end
	self.wipe_pending = true
	-- Небольшая задержка: перк «Упорство» успевает возродить героя на месте гибели
	RPG.After(0.4, function()
		self.wipe_pending = false
		if self.state ~= "active" then return end
		local all = self:Heroes(false)
		local standing = 0
		for _, h in ipairs(all) do
			if h:IsAlive() or (h.rpg and h.rpg.reviving) then standing = standing + 1 end
		end
		if standing == 0 and #all > 0 then self:OnWipe() end
	end)
end

-- Вайпе: теряем жизнь, волна переигрывается
function Waves:OnWipe()
	-- Перк «Жертвенник»: жизнь отряда не тратится (у героя своя перезарядка)
	local saver = Axe:TrySacrifice()
	if saver then
		self:Toast("Жертвенник: жизнь отряда не потрачена!", "#b050e0")
	else
		self.lives = self.lives - 1
	end
	for _, unit in pairs(self.alive) do
		unit.rpg_wave = nil
		if IsValidEntity(unit) then UTIL_Remove(unit) end
	end
	self.alive = {}
	self.alive_count = 0
	self.queue = {}

	if self.lives <= 0 then
		self:Toast("Все жизни потрачены. Поражение.", "#ff5a4a")
		self.state = "done"
		GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)
		return
	end

	self.wave = self.wave - 1
	self.state = "break"
	self.countdown = RPG.CFG.BREAK_TIME
	self.break_total = RPG.CFG.BREAK_TIME
	self.mod = nil
	for _, hero in ipairs(self:Heroes(false)) do
		hero:RespawnHero(false, false)
		hero:SetHealth(hero:GetMaxHealth())
		hero:SetMana(hero:GetMaxMana())
	end
	self:Toast("Отряд повержен! Осталось жизней: " .. self.lives .. ". Волна повторится.", "#ff9a4a")
end
