-- Lich: механики способностей и ПЕРКИ героя.
-- Способности (KV) -> abilities/rpg_lich.lua, модификаторы -> modifiers/modifier_rpg_lich.lua
-- Все числа перков лежат в Lich.C (ниже).
Lich = Lich or {}

Lich.C = {
	-- Обледенение (Frost Blast и другие источники)
	ICING_MAX      = 3,        -- на 3-м стаке цель рассыпается
	ICING_TIME     = 8,
	SHATTER_RADIUS = 350,

	-- ===== ВЕТКА «Ледяной Архимаг» (Frost Blast) =====
	COLLAPSE_DIV   = 300,      -- Коллапс: +1% урона за каждые 3 маны стоимости каста
	CHAIN_SHARD_PCT = 0.7,     -- Цепной мороз: 70% урона
	CHAIN_SHARD_R  = 600,
	HORIZON_RANGE  = 50,       -- Бесконечный горизонт: +50 дальности за каст серии
	ORB_MAX        = 6,        -- Огненные огни
	ORB_RADIUS     = 400,
	ORB_ORBIT      = 170,
	ORB_SHOT_CD    = 0.8,
	OVERHEAT_TIME  = 3,        -- Морозная неожиданность
	OVERHEAT_CD    = 20,
	OVERHEAT_AMP   = 2.0,      -- +100% урона
	OVERHEAT_FREEZE = 1.0,
	CASCADE_EVERY  = 10,       -- Каскад: каждый 10-й каст
	CASCADE_PCT    = 20,       -- % макс. здоровья (против боссов урезается RPG.CFG.BOSS_PCT_MULT)
	PAIN_STEP      = 0.15,     -- Резонанс боли
	PAIN_MAX       = 1.5,
	PULSE_EVERY    = 4,        -- Леденящий импульс
	PULSE_RADIUS   = 700,
	PULSE_PCT      = 10,
	LUCK_CHANCE    = 25,       -- Морозная удача
	LUCK_DELAY     = 0.3,
	AUTH_EVERY     = 3,        -- Леденящий авторитет
	AUTH_CRIT      = 2.5,
	AUTH_FREEZE    = 1.5,
	COMP_MANA      = 500,      -- Компенсация
	COMP_TIME      = 5,
	BLOOD_CHARGES  = 5,        -- Жертвоприношение
	BLOOD_HP_PCT   = 5,
	BLOOD_AMP      = 1.5,
	BLOOD_HEAL     = 0.2,      -- % от нанесённого урона -> лечение
	BLOOD_TIME     = 12,

	-- ===== ВЕТКА «Ледяной Бастион» (Frost Shield) =====
	BASTION_PULL   = 420,      -- скорость притяжения
	CHAIN_BASTION_PCT = 0.4,   -- Цепной мороз (бастион): 40% финального взрыва по всей арене
	CHAIN_BASTION_CAP = 6,     -- не более N мини-взрывов за один тик волн
	MARK_PCT       = 0.2,      -- Цепная детонация
	MARK_RADIUS    = 350,
	MARK_TIME      = 8,
	STORM_DIST     = 400,      -- Непрекращающийся шторм
	STORM_DELAY    = 1.0,
	STORM_PCT      = 0.5,
	STORM_RADIUS   = 350,
	VAMP_PCT       = 5,        -- Энергетический вампиризм
	AURA_RADIUS    = 600,
	AURA_SLOW      = 30,
	PRISON_TIME    = 3,
	ECHO_DELAY     = 1.0,
	ECHO_PCT       = 0.4,
	BLOODFROST_PCT = 10,
	ICECASCADE_PCT = 0.3,
	ANCHOR_TIME    = 2,
	ARCHSHIELD_PCT = 0.25,
	ARCHSHIELD_TIME = 10,

	-- ===== ВЕТКА «Гравитационный Захват» (Sinister Gaze) =====
	HORIZON_GAZE   = 0.75,     -- Горизонт событий: +75%
	BLOODCH_PCT    = 4,        -- Кровавый канал: % макс. ХП в секунду
	EATER_PCT      = 10,       -- Пожиратель магии: % макс. маны в секунду
	EATER_SHIELD_TIME = 5,
	EPI_PCT        = 0.15,     -- Эпицентр смерти
	EPI_DEPTH      = 4,
	SHARDWAVE_RADIUS = 300,
	SHARDWAVE_MULT = 2.0,      -- урон = 2 секунды Sinister Gaze
	EXHAUST_PCT    = 40,
	EXHAUST_TIME   = 2,
	TRAP_TIME      = 1.5,
	TRAP_RADIUS    = 250,
	MIRROR_ANGLE   = 45,
	RELENT_MR      = 30,
	CRYSTAL_ARMOR  = 3,
	CRYSTAL_TIME   = 4,
	CRYSTAL_MAX    = 60,
	DOME_RADIUS    = 600,
	DOME_PCT       = 25,

	-- ===== ВЕТКА «Ледяной Метеор» (Chain Frost) =====
	METEOR_ARC     = 650,      -- высота дуги
	EPI_BLAST_MULT = 1.5,      -- Эпицентр взрыва: +50% радиуса
	STORM_BALLS    = 12,
	BALLS          = 6,
	MINE_DELAY     = 1.5,
	MINE_PCT       = 0.25,
	MINE_RADIUS    = 220,
	AZ_POWER       = 0.3,      -- Абсолютный Зеро: мини-метеор 30%
	AZ_RADIUS      = 0.6,
	AZ_DEPTH       = 3,
	PUDDLE_TIME    = 4,
	PUDDLE_SLOW    = 60,
	PUDDLE_MR      = 20,
	METEOR_ECHO_DELAY = 1.5,
	METEOR_ECHO_PCT = 0.4,
	HASTE_TIME     = 4,
	BLOODMETEOR_PCT = 15,      -- Кровавый метеор: % макс. ХП
	BLOODRES_HP    = 0.35,
	BLOODRES_AMP   = 1.75,
	EXCESS_PCT     = 3,        -- Энергетический избыток
	VAMP_METEOR_PCT = 5,       -- Энергетический вампиризм (метеор)
	RES_METEOR_HITS = 5,

	-- Chain Frost
	CHAIN_ESC_CAP  = 12,       -- потолок множителя повторных попаданий
}

-- ======================= УТИЛИТЫ =======================
local function fx_world(path, pos, cp1)
	local fx = ParticleManager:CreateParticle(path, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, pos)
	if cp1 then ParticleManager:SetParticleControl(fx, 1, cp1) end
	ParticleManager:ReleaseParticleIndex(fx)
end
Lich.fx_world = fx_world

local FX_NOVA   = "particles/units/heroes/hero_lich/lich_frost_nova.vpcf"
local FX_SHOCK  = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf"
-- lich_ice_age.vpcf is not a stock Dota particle and caused missing-particle errors.
local FX_ICEAGE = "particles/units/heroes/hero_lich/lich_frost_nova.vpcf"

-- Интеллект с защитой: в новых версиях Dota GetIntellect требует аргумент, в старых - нет
function Lich:Int(c)
	local ok, v = pcall(c.GetIntellect, c, false)
	if ok and type(v) == "number" then return v end
	ok, v = pcall(c.GetIntellect, c)
	if ok and type(v) == "number" then return v end
	return 0
end

function Lich:Has(hero, id)
	return hero ~= nil and hero.rpg ~= nil and (hero.rpg.perk_count[id] or 0) > 0
end

function Lich:Bonus(hero, key)
	return (hero and hero.rpg and hero.rpg.axe_bonus and hero.rpg.axe_bonus[key]) or 0
end

function Lich:TalentAbility(hero, key)
	local ab = hero:FindAbilityByName("special_bonus_rpg_lich_" .. key)
	if ab and ab:GetLevel() > 0 then return ab end
	return nil
end

function Lich:TalentValue(hero, key)
	local t = self:TalentAbility(hero, key)
	return t and t:GetSpecialValueFor("value") or 0
end

local ELITE = { npc_rpg_creep_brute = true, npc_rpg_centaur = true, npc_rpg_troll_summoner = true, npc_rpg_golem = true }
function Lich:IsBoss(u) return u.rpg_boss == true end
function Lich:IsElite(u) return u.rpg_boss == true or (u.rpg_def ~= nil and ELITE[u.rpg_def.unit] == true) end

function Lich:Enemies(caster, pos, radius)
	return FindUnitsInRadius(caster:GetTeamNumber(), pos, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
end

-- Урон «в % от макс. здоровья» (против боссов урезается так же, как у Axe)
function Lich:PctOfMax(target, pct)
	local v = target:GetMaxHealth() * pct / 100
	if self:IsBoss(target) then v = v * RPG.CFG.BOSS_PCT_MULT end
	return v
end

function Lich:Toast(text, color)
	CustomGameEventManager:Send_ServerToAllClients("rpg_toast", { text = text, color = color or "#b050e0" })
end

function Lich:NextId()
	self._id = (self._id or 0) + 1
	return self._id
end

-- Единая точка нанесения урона. ctx = { amp, blood, overheat } из BeginCast
function Lich:Hit(caster, target, ability, dmg, ctx, dtype, flags)
	if not target or target:IsNull() or not target:IsAlive() then return 0, false end
	local dealt = ApplyDamage({
		victim = target, attacker = caster, damage = dmg,
		damage_type = dtype or DAMAGE_TYPE_MAGICAL, damage_flags = flags or DOTA_DAMAGE_FLAG_NONE, ability = ability,
	}) or 0
	if ctx then
		if ctx.blood and dealt > 0 and caster:IsAlive() then caster:Heal(dealt * self.C.BLOOD_HEAL, caster) end
		if ctx.overheat and target:IsAlive() then self:Freeze(target, caster, ability, self.C.OVERHEAT_FREEZE) end
	end
	return dealt, not target:IsAlive()
end

function Lich:Freeze(target, caster, ability, dur)
	if not target or target:IsNull() or not target:IsAlive() then return end
	if self:IsBoss(target) then dur = dur * 0.5 end       -- боссы замерзают вдвое короче
	target:AddNewModifier(caster, ability, "modifier_rpg_lich_freeze", { duration = dur })
end

function Lich:Stun(target, caster, ability, dur)
	if not target or target:IsNull() or not target:IsAlive() then return end
	if self:IsBoss(target) then dur = dur * 0.5 end
	target:AddNewModifier(caster, ability, "modifier_stunned", { duration = dur })
end

-- Кулдаун способности -> 0 (перки, сбрасывающие перезарядку)
function Lich:ResetCooldown(caster, name)
	local ab = caster:FindAbilityByName(name)
	if ab then ab:EndCooldown() end
end

-- ======================= ОБЛЕДЕНЕНИЕ =======================
function Lich:BlastBase(caster, ab)
	local d = ab:GetSpecialValueFor("damage") + self:Bonus(caster, "blast_damage") + self:TalentValue(caster, "15_right")
	return d + self:Int(caster) * ab:GetSpecialValueFor("int_scale")
end

function Lich:ShatterDamage(caster)
	local ab = caster:FindAbilityByName("rpg_lich_frost_blast")
	if not ab or ab:GetLevel() < 1 then return 200 end
	return self:BlastBase(caster, ab) * ab:GetSpecialValueFor("shatter_pct") / 100
end

function Lich:AddIcing(caster, target, ability, n)
	if not target or target:IsNull() or not target:IsAlive() or (n or 1) <= 0 then return end
	local C = self.C
	local m = target:FindModifierByNameAndCaster("modifier_rpg_lich_icing", caster)
	local c = (m and m:GetStackCount() or 0) + (n or 1)
	m = target:AddNewModifier(caster, ability, "modifier_rpg_lich_icing", { duration = C.ICING_TIME })
	if not m then return end
	if c >= C.ICING_MAX then
		m:Destroy()
		self:Shatter(caster, target, ability)
	else
		m:SetStackCount(c)
	end
end

-- Цель рассыпается на осколки: АоЕ-урон вокруг (без новых стаков, чтобы не уйти в бесконечную цепочку)
function Lich:Shatter(caster, target, ability)
	local pos = target:GetAbsOrigin()
	fx_world(FX_NOVA, pos)
	local dmg = self:ShatterDamage(caster)
	for _, e in ipairs(self:Enemies(caster, pos, self.C.SHATTER_RADIUS)) do
		if e ~= target then self:Hit(caster, e, ability, dmg) end
	end
end

-- ======================= ОБЩИЕ ХУКИ КАСТА =======================
-- Вызывается в начале OnSpellStart любой способности Lich. Возвращает контекст каста.
-- Здесь же списываются заряды режимов «Перегрев» и «Жертвоприношение».
function Lich:BeginCast(caster, ability)
	local C = self.C
	local ctx = { amp = 1, blood = false, overheat = false }
	if caster:HasModifier("modifier_rpg_lich_overheat") then
		ctx.amp = ctx.amp * C.OVERHEAT_AMP
		ctx.overheat = true
	end
	local bl = caster:FindModifierByName("modifier_rpg_lich_blood")
	if bl then
		ctx.blood = true
		ctx.amp = ctx.amp * C.BLOOD_AMP
		-- заклинание за здоровье: 5% макс. ХП (не убивает)
		local cost = caster:GetMaxHealth() * C.BLOOD_HP_PCT / 100
		caster:SetHealth(math.max(1, caster:GetHealth() - cost))
		if bl:GetStackCount() <= 1 then bl:Destroy() else bl:DecrementStackCount() end
	end
	return ctx
end

function Lich:Ser(caster)
	if not caster.rpg.ser then caster.rpg.ser = { mana = 0, comp = 0 } end
	return caster.rpg.ser
end

function Lich:EndSeries(caster)
	if caster and not caster:IsNull() and caster.rpg then caster.rpg.ser = { mana = 0, comp = 0 } end
end

function Lich:SeriesCount(caster)
	local m = caster:FindModifierByName("modifier_rpg_lich_series")
	return m and m:GetStackCount() or 0
end

function Lich:SeriesAdvance(caster, ability)
	local m = caster:AddNewModifier(caster, ability, "modifier_rpg_lich_series", { duration = ability:GetSpecialValueFor("series_window") })
	if m then m:IncrementStackCount() end
	return m and m:GetStackCount() or 1
end

-- ======================= FROST BLAST =======================
function Lich:CastBlast(caster, ability, target, free, free_ctx)
	local C = self.C
	local ctx = free and (free_ctx or { amp = 1 }) or self:BeginCast(caster, ability)
	local n0 = self:SeriesCount(caster)
	local paid = free and 0 or ability:GetManaCost(-1)          -- стоимость, только что заплаченная за этот каст
	local n = free and n0 or self:SeriesAdvance(caster, ability)

	-- урон
	local dmg = self:BlastBase(caster, ability) * ctx.amp * (caster:HasScepter() and 1.2 or 1)
	if paid > 0 and self:Has(caster, "l_collapse") then dmg = dmg * (1 + paid / C.COLLAPSE_DIV) end
	local crit = false
	if self:Has(caster, "e_authority") and n % C.AUTH_EVERY == 0 then dmg = dmg * C.AUTH_CRIT; crit = true end

	-- радиус
	local radius = ability:GetSpecialValueFor("radius") + self:Bonus(caster, "blast_radius") + (caster:HasScepter() and 100 or 0)
	if self:Has(caster, "e_pain") then radius = radius * (1 + math.min(C.PAIN_MAX, C.PAIN_STEP * n)) end

	local pos = target:GetAbsOrigin()
	fx_world(FX_NOVA, pos, Vector(radius, 2, radius))
	EmitSoundOn("Hero_Lich.FrostBlast", target)
	EmitSoundOn("Hero_Crystal.CrystalNova", target)

	local hit = {}
	for _, e in ipairs(self:Enemies(caster, pos, radius)) do
		hit[e] = true
		self:Hit(caster, e, ability, dmg, ctx)
		if e:IsAlive() then self:AddIcing(caster, e, ability, 1) end
	end

	-- Леденящий авторитет: каждый 3-й каст - заморозка цели в глыбе (прерывает касты боссов)
	if crit and target:IsAlive() then self:Freeze(target, caster, ability, C.AUTH_FREEZE) end

	-- Каскад: каждый 10-й каст - 20% макс. здоровья любой задетой цели (чистый урон, мимо резистов)
	if self:Has(caster, "e_cascade") and n % C.CASCADE_EVERY == 0 then
		fx_world(FX_SHOCK, pos)
		for e in pairs(hit) do
			if e:IsAlive() then
				ApplyDamage({ victim = e, attacker = caster, damage = self:PctOfMax(e, C.CASCADE_PCT),
					damage_type = DAMAGE_TYPE_PURE, damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION, ability = ability })
			end
		end
	end

	-- Цепной мороз: осколки в радиусе 600 от цели - 70% урона
	if self:Has(caster, "l_chain_shards") then
		for _, e in ipairs(self:Enemies(caster, pos, C.CHAIN_SHARD_R)) do
			if not hit[e] then
				fx_world(FX_NOVA, e:GetAbsOrigin())
				self:Hit(caster, e, ability, dmg * C.CHAIN_SHARD_PCT, ctx)
			end
		end
	end

	-- Леденящий импульс: каждые 4 каста - волна, сжигающая 10% текущей маны
	if self:Has(caster, "e_pulse") and n % C.PULSE_EVERY == 0 then self:ChillPulse(caster, ability) end

	if not free then
		self:Spend(caster, ability, paid)

		-- Огненные огни: по сфере за каждый каст серии (до 6)
		if self:Has(caster, "l_orbs") then
			local m = caster:AddNewModifier(caster, ability, "modifier_rpg_lich_orbs", { duration = ability:GetSpecialValueFor("series_window") })
			if m then m:SetStackCount(math.min(C.ORB_MAX, n)) end
		end

		-- Морозная удача: 25% - бесплатный дубль через 0.3 с в ту же цель
		if self:Has(caster, "e_luck") and RandomFloat(0, 100) < C.LUCK_CHANCE then
			RPG.After(C.LUCK_DELAY, function()
				if caster:IsNull() or not caster:IsAlive() or target:IsNull() or not target:IsAlive() then return end
				Lich:CastBlast(caster, ability, target, true, ctx)
			end)
		end

		self:CheckExhaust(caster, ability, n)
	end
end

-- Компенсация: за каждые 500 потраченных маны серии - временный бонус
function Lich:Spend(caster, ability, paid)
	local C = self.C
	local st = self:Ser(caster)
	st.mana = st.mana + paid
	if self:Has(caster, "e_comp") then
		local steps = math.floor(st.mana / C.COMP_MANA)
		if steps > st.comp then
			st.comp = steps
			caster:AddNewModifier(caster, ability, "modifier_rpg_lich_comp", { duration = C.COMP_TIME })
		end
	end
end

-- Мана кончилась посреди серии: «Морозная неожиданность» (перегрев) или «Жертвоприношение» (касты за здоровье)
function Lich:CheckExhaust(caster, ability, n)
	local C = self.C
	if n < 2 then return end
	if caster:GetMana() >= ability:GetManaCost(-1) then return end
	local now = GameRules:GetGameTime()
	if self:Has(caster, "e_overheat") and (caster.rpg.oh_cd or 0) <= now and not caster:HasModifier("modifier_rpg_lich_overheat") then
		caster.rpg.oh_cd = now + C.OVERHEAT_CD
		caster:AddNewModifier(caster, ability, "modifier_rpg_lich_overheat", { duration = C.OVERHEAT_TIME })
		self:Toast("Перегрев! 3 с бесплатных заклинаний с +100% урона и заморозкой")
	elseif self:Has(caster, "e_blood") and not caster:HasModifier("modifier_rpg_lich_blood") then
		local m = caster:AddNewModifier(caster, ability, "modifier_rpg_lich_blood", { duration = C.BLOOD_TIME })
		if m then m:SetStackCount(C.BLOOD_CHARGES) end
		self:Toast("Жертвоприношение: следующие 5 заклинаний — за здоровье!", "#ff5a4a")
	end
end

function Lich:ChillPulse(caster, ability)
	local C = self.C
	local pos = caster:GetAbsOrigin()
	fx_world(FX_NOVA, pos, Vector(C.PULSE_RADIUS, 2, C.PULSE_RADIUS))
	for _, e in ipairs(self:Enemies(caster, pos, C.PULSE_RADIUS)) do
		local burn = e:GetMana() * C.PULSE_PCT / 100
		if burn > 0 then
			e:ReduceMana(burn)
			self:Hit(caster, e, ability, burn)    -- сожжённая мана превращается в урон
		end
	end
end

-- ======================= FROST SHIELD =======================
function Lich:CastShield(caster, ability, target)
	local ctx = self:BeginCast(caster, ability)
	if self:Has(caster, "m_bastion") then
		return self:CastBastion(caster, ability, ctx)
	end
	local dur = ability:GetSpecialValueFor("duration") + self:Bonus(caster, "shield_duration")
	local red = ability:GetSpecialValueFor("reduction") + self:Bonus(caster, "shield_red") + self:TalentValue(caster, "20_right")
	local slow = ability:GetSpecialValueFor("slow") + self:Bonus(caster, "shield_slow")
	EmitSoundOn("Hero_Lich.FrostArmor", target)
	target:AddNewModifier(caster, ability, "modifier_rpg_lich_shield", {
		duration = dur, red = math.min(90, red), slow = slow, slow_dur = ability:GetSpecialValueFor("slow_duration"),
		shard = caster:HasModifier("modifier_item_aghanims_shard") and 1 or 0,
	})
end

-- Мифик «Ледяной Бастион»
function Lich:FinalDamage(caster, ability)
	return ability:GetSpecialValueFor("final_damage") + self:Int(caster) * ability:GetSpecialValueFor("int_scale") * 2
end

function Lich:WaveDamage(caster, ability)
	return ability:GetSpecialValueFor("wave_damage") + self:Int(caster) * ability:GetSpecialValueFor("int_scale")
end

function Lich:CastBastion(caster, ability, ctx)
	local C = self.C
	-- «Кровавый мороз»: можно кастовать в стане/безмолвии, сбрасывает все негативные эффекты за 10% текущего ХП
	if self:Has(caster, "e_bloodfrost") then
		caster:Purge(false, true, false, true, true)
		caster:SetHealth(math.max(1, caster:GetHealth() * (1 - C.BLOODFROST_PCT / 100)))
	end
	EmitSoundOn("Hero_Lich.IceAge", caster)
	EmitSoundOn("Hero_Crystal.CrystalNova", caster)
	local m = caster:AddNewModifier(caster, ability, "modifier_rpg_lich_glacier", { duration = ability:GetSpecialValueFor("block_duration") })
	if m then m.ctx = ctx end
end

-- Волна глыбы (каждые 0.5 с): притяжение + колоссальный магический урон + стаки обледенения
function Lich:BastionWave(caster, ability, mod)
	local C = self.C
	local pos = caster:GetAbsOrigin()
	local radius = ability:GetSpecialValueFor("radius")
	local dmg = self:WaveDamage(caster, ability) * ((mod.ctx and mod.ctx.amp) or 1)
	local final = self:FinalDamage(caster, ability)
	fx_world(FX_NOVA, pos, Vector(radius, 2, radius))

	local mini = 0
	local aura = self:Has(caster, "e_aura")
	for _, e in ipairs(self:Enemies(caster, pos, radius)) do
		e:AddNewModifier(caster, ability, "modifier_rpg_lich_pull_step", { duration = 0.7, x = pos.x, y = pos.y, speed = C.BASTION_PULL, stop = 120, stun = 1 })
		local dealt, killed = self:Hit(caster, e, ability, dmg)
		mod.wave_total = (mod.wave_total or 0) + dealt
		if killed then
			-- Цепной мороз (бастион): смерть от волны - мини-взрыв по всем целям арены
			if self:Has(caster, "l_chain_bastion") and mini < C.CHAIN_BASTION_CAP then
				mini = mini + 1
				fx_world(FX_SHOCK, e:GetAbsOrigin())
				for _, t in ipairs(self:Enemies(caster, pos, 12000)) do
					self:Hit(caster, t, ability, final * C.CHAIN_BASTION_PCT)
				end
			end
		else
			self:AddIcing(caster, e, ability, 1)
			if e:IsAlive() then
				-- Цепная детонация: метка
				if self:Has(caster, "l_detonation") then
					e:AddNewModifier(caster, ability, "modifier_rpg_lich_mark", { duration = C.MARK_TIME })
				end
				-- Энергетический вампиризм: сжигаем 5% макс. маны врага и отдаём Личу
				if self:Has(caster, "e_vamp_b") then
					local burn = math.min(e:GetMana(), e:GetMaxMana() * C.VAMP_PCT / 100)
					if burn > 0 then e:ReduceMana(burn); caster:GiveMana(burn) end
				end
				-- Морозная аура замедления: -30% скорости атаки и передвижения
				if aura and (e:GetAbsOrigin() - pos):Length2D() <= C.AURA_RADIUS then
					e:AddNewModifier(caster, ability, "modifier_rpg_slow", { duration = 0.7, slow = C.AURA_SLOW })
					e:AddNewModifier(caster, ability, "modifier_rpg_as_slow", { duration = 0.7, slow = C.AURA_SLOW })
				end
			end
		end
	end
end

-- Взрыв: damage по радиусу; full = с заморозкой/Break/Root (только основной взрыв)
function Lich:FinalBlast(caster, ability, pos, radius, dmg, full)
	local C = self.C
	fx_world(FX_ICEAGE, pos)
	fx_world(FX_NOVA, pos, Vector(radius, 2, radius))
	local killed_elite = false
	for _, e in ipairs(self:Enemies(caster, pos, radius)) do
		local _, killed = self:Hit(caster, e, ability, dmg)
		if killed then
			if self:IsElite(e) then killed_elite = true end
		elseif full then
			self:Freeze(e, caster, ability, ability:GetSpecialValueFor("final_freeze"))
			if self:Has(caster, "e_prison") then e:AddNewModifier(caster, ability, "modifier_rpg_lich_break", { duration = C.PRISON_TIME }) end
			if self:Has(caster, "e_anchor") then e:AddNewModifier(caster, ability, "modifier_rpg_lich_root", { duration = C.ANCHOR_TIME + ability:GetSpecialValueFor("final_freeze") }) end
		end
	end
	return killed_elite
end

-- Конец глыбы
function Lich:BastionFinish(caster, ability, mod)
	local C = self.C
	if caster:IsNull() or not caster:IsAlive() then return end
	local pos = caster:GetAbsOrigin()
	local radius = ability:GetSpecialValueFor("radius")
	local final = self:FinalDamage(caster, ability) * ((mod.ctx and mod.ctx.amp) or 1)

	local elite = self:FinalBlast(caster, ability, pos, radius, final, true)

	-- Эхо взрыва
	if self:Has(caster, "e_echo_b") then
		RPG.After(C.ECHO_DELAY, function()
			if not caster:IsNull() then Lich:FinalBlast(caster, ability, pos, radius, final * C.ECHO_PCT, false) end
		end)
	end

	-- Непрекращающийся шторм: 4 малых осколка разлетаются на 400 и взрываются через 1 с
	if self:Has(caster, "l_storm") then
		for i = 0, 3 do
			local a = math.rad(45 + 90 * i)
			local p = pos + Vector(math.cos(a), math.sin(a), 0) * C.STORM_DIST
			fx_world(FX_NOVA, p)
			RPG.After(C.STORM_DELAY, function()
				if not caster:IsNull() then Lich:FinalBlast(caster, ability, p, C.STORM_RADIUS, final * C.STORM_PCT, false) end
			end)
		end
	end

	-- Энергетический резонанс: весь поглощённый урон -> здоровье и мана
	if self:Has(caster, "l_resonance") and (mod.absorbed or 0) > 0 then
		caster:Heal(mod.absorbed, caster)
		caster:GiveMana(mod.absorbed)
		self:Toast("Энергетический резонанс: +" .. math.floor(mod.absorbed) .. " здоровья и маны", "#8fd3ff")
	end

	-- Архимагический щит: 25% от урона волн
	if self:Has(caster, "e_archshield") and (mod.wave_total or 0) > 0 then
		caster:AddNewModifier(caster, ability, "modifier_rpg_lich_absorb", { duration = C.ARCHSHIELD_TIME, amount = mod.wave_total * C.ARCHSHIELD_PCT })
	end

	-- Ледяной каскад: убит элитный моб - перезарядка -30%
	if elite and self:Has(caster, "e_icecascade") then
		local rem = ability:GetCooldownTimeRemaining()
		if rem > 0 then
			ability:EndCooldown()
			ability:StartCooldown(rem * (1 - C.ICECASCADE_PCT))
		end
	end
end

-- Цепная детонация: умерла помеченная цель
function Lich:MarkExplode(caster, ability, pos)
	if not caster or caster:IsNull() or not ability or ability:IsNull() then return end
	local dmg = self:FinalDamage(caster, ability) * self.C.MARK_PCT
	fx_world(FX_SHOCK, pos)
	for _, e in ipairs(self:Enemies(caster, pos, self.C.MARK_RADIUS)) do
		self:Hit(caster, e, ability, dmg)
	end
end

-- ======================= SINISTER GAZE =======================
function Lich:GazeDps(caster, ab)
	return ab:GetSpecialValueFor("damage_per_second") + self:Bonus(caster, "gaze_dps") + self:TalentValue(caster, "25_right")
end

function Lich:CastGaze(caster, ability, target)
	local ctx = self:BeginCast(caster, ability)
	EmitSoundOn("Hero_Lich.SinisterGaze.Cast", caster)
	if self:Has(caster, "m_gravity") then
		local fwd = caster:GetForwardVector()
		fwd.z = 0
		local m = caster:AddNewModifier(caster, ability, "modifier_rpg_lich_gaze_cone", { duration = ability:GetChannelTime() + 0.5 })
		if m then m.ctx = ctx; m.fwd = fwd:Normalized() end
		return
	end
	if target and not target:TriggerSpellAbsorb(ability) then
		local m = target:AddNewModifier(caster, ability, "modifier_rpg_lich_gaze_target", { duration = ability:GetChannelTime() + 0.2 })
		if m then m.ctx = ctx end
		ability.gaze_target = target
	end
end

-- Геометрия конуса (мифик «Гравитационный Захват»)
function Lich:ConeParams(caster, ability)
	local C = self.C
	local len = ability:GetSpecialValueFor("cone_length")
	local ang = ability:GetSpecialValueFor("cone_angle")
	if self:Has(caster, "l_eventhorizon") then len = len * (1 + C.HORIZON_GAZE); ang = ang * (1 + C.HORIZON_GAZE) end
	if self:Has(caster, "e_mirror") then ang = ang + C.MIRROR_ANGLE end
	return len, math.min(ang, 340)
end

-- Тик конуса (каждые 0.1 с). Возвращает false, если канал надо оборвать
function Lich:GazeConeTick(caster, ability, mod, dt)
	local C = self.C
	local mythic_blood = false

	-- Поддержание канала стоит маны; «Кровавый канал» - здоровья
	local need = ability:GetSpecialValueFor("mana_per_sec") * dt
	if caster:GetMana() >= need then
		caster:SpendMana(need, ability)
	elseif self:Has(caster, "l_bloodchannel") then
		mythic_blood = true
		caster:SetHealth(math.max(1, caster:GetHealth() - caster:GetMaxHealth() * C.BLOODCH_PCT / 100 * dt))
	else
		return false
	end

	local origin = caster:GetAbsOrigin()
	local fwd = mod.fwd
	local len, ang = self:ConeParams(caster, ability)
	local half = math.rad(ang / 2)
	local speed = ability:GetSpecialValueFor("pull_speed") * (mythic_blood and 2 or 1)

	local list = {}
	for _, e in ipairs(self:Enemies(caster, origin, len)) do
		local d = e:GetAbsOrigin() - origin
		d.z = 0
		local dist = d:Length2D()
		local inside = dist < 100
		if not inside then
			local c = math.max(-1, math.min(1, d:Normalized():Dot(fwd)))
			inside = math.acos(c) <= half
		end
		if inside then table.insert(list, e) end
	end

	local dmg_now = false
	mod.acc = (mod.acc or 0) + dt
	if mod.acc >= 0.5 then mod.acc = mod.acc - 0.5; dmg_now = true end
	local dmg = self:GazeDps(caster, ability) * 0.5 * ((mod.ctx and mod.ctx.amp) or 1)

	local eater = self:Has(caster, "l_manaeater")
	for _, e in ipairs(list) do
		e:AddNewModifier(caster, ability, "modifier_rpg_lich_pull_step", { duration = 0.25, x = origin.x, y = origin.y, speed = speed, stop = 130 })
		mod.pulled[e] = true
		if dmg_now then self:Hit(caster, e, ability, dmg, mod.ctx) end
		if eater and e:IsAlive() and e:GetMana() > 0 then
			local burn = math.min(e:GetMana(), e:GetMaxMana() * C.EATER_PCT / 100 * dt)
			e:ReduceMana(burn)
			if mod.absorb and not mod.absorb:IsNull() then mod.absorb:AddAmount(burn) end
		end
	end

	-- Каждый притянутый враг восстанавливает Личу здоровье и ману
	local cnt = math.min(#list, ability:GetSpecialValueFor("max_targets"))
	if cnt > 0 then
		caster:Heal(caster:GetMaxHealth() * ability:GetSpecialValueFor("heal_hp_pct") / 100 * dt * cnt, caster)
		caster:GiveMana(ability:GetSpecialValueFor("heal_mana") * dt * cnt)
	end

	-- Кристаллическая броня: +3 брони за врага в конусе (держится ещё 4 с после канала)
	if self:Has(caster, "e_crystal") then
		local m = caster:AddNewModifier(caster, ability, "modifier_rpg_lich_crystal", { duration = C.CRYSTAL_TIME + 0.3 })
		if m then
			local unique = 0
			for _ in pairs(mod.pulled) do unique = unique + 1 end
			m:SetStackCount(math.min(C.CRYSTAL_MAX, C.CRYSTAL_ARMOR * unique))
		end
	end

	-- Защитный купол: союзники позади Лича получают -25% от атак спереди
	if self:Has(caster, "e_dome") then
		for _, a in ipairs(FindUnitsInRadius(caster:GetTeamNumber(), origin, nil, C.DOME_RADIUS, DOTA_UNIT_TARGET_TEAM_FRIENDLY,
			DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)) do
			if a ~= caster then
				local v = a:GetAbsOrigin() - origin
				v.z = 0
				if v:Length2D() > 1 and v:Normalized():Dot(fwd) < 0 then
					a:AddNewModifier(caster, ability, "modifier_rpg_lich_dome", { duration = 0.35, x = fwd.x, y = fwd.y })
				end
			end
		end
	end
	return true
end

-- Конец канала конуса
function Lich:GazeFinish(caster, ability, mod)
	local C = self.C
	if caster:IsNull() then return end
	local completed = not mod.interrupted
	local origin = caster:GetAbsOrigin()

	-- Пожиратель магии: щит висит ещё 5 с
	if mod.absorb and not mod.absorb:IsNull() then mod.absorb:SetDuration(C.EATER_SHIELD_TIME, true) end
	caster:RemoveModifierByName("modifier_rpg_lich_relentless")

	if self:Has(caster, "e_shardwave") then
		fx_world(FX_SHOCK, origin)
		local dmg = self:GazeDps(caster, ability) * C.SHARDWAVE_MULT
		for _, e in ipairs(self:Enemies(caster, origin, C.SHARDWAVE_RADIUS)) do
			self:Hit(caster, e, ability, dmg)
			if e:IsAlive() then self:AddIcing(caster, e, ability, 1) end
		end
	end

	for e in pairs(mod.pulled) do
		if e and not e:IsNull() and e:IsAlive() then
			if self:Has(caster, "e_exhaust") then
				e:AddNewModifier(caster, ability, "modifier_rpg_slow", { duration = C.EXHAUST_TIME, slow = C.EXHAUST_PCT })
				e:AddNewModifier(caster, ability, "modifier_rpg_as_slow", { duration = C.EXHAUST_TIME, slow = C.EXHAUST_PCT })
			end
			if self:Has(caster, "e_trap") and (e:GetAbsOrigin() - origin):Length2D() <= C.TRAP_RADIUS then
				e:AddNewModifier(caster, ability, "modifier_rpg_lich_root", { duration = C.TRAP_TIME })
			end
		end
	end

	if completed and self:Has(caster, "e_gazereset") then
		self:ResetCooldown(caster, "rpg_lich_frost_shield")
	end
end

-- Смерть притягиваемого врага («Эпицентр смерти»)
function Lich:OnPulledDeath(caster, unit)
	if not caster or caster:IsNull() or not self:Has(caster, "l_epicenter_death") then return end
	if (self._epi_depth or 0) >= self.C.EPI_DEPTH then return end
	self._epi_depth = (self._epi_depth or 0) + 1
	local pos = unit:GetAbsOrigin()
	local dmg = unit:GetMaxHealth() * self.C.EPI_PCT
	fx_world(FX_SHOCK, pos)
	local ab = caster:FindAbilityByName("rpg_lich_sinister_gaze")
	for _, e in ipairs(self:Enemies(caster, pos, 1500)) do
		if e ~= unit and e:IsAlive() and e:HasModifier("modifier_rpg_lich_pull_step") then
			self:Hit(caster, e, ab, dmg)
		end
	end
	self._epi_depth = self._epi_depth - 1
end

-- ======================= CHAIN FROST / ЛЕДЯНОЙ МЕТЕОР =======================
Lich.balls = Lich.balls or {}
local BALL_FX = "particles/units/heroes/hero_lich/lich_chain_frost.vpcf"

function Lich:NewBall(caster, ability, dmg, o)
	local b = {
		id = self:NextId(), caster = caster, ability = ability, dmg = dmg, born = GameRules:GetGameTime(),
		hits = {}, count = 0, delay = o.delay, max_time = o.max_time, bounce_radius = o.bounce_radius,
		esc = o.esc or 0, small = o.small, max_hits = o.max_hits, ctx = o.ctx, crit_elite = o.crit_elite,
		mine = o.mine, speed = o.speed,
	}
	self.balls[b.id] = b
	return b
end

function Lich:LaunchBall(b, from, target, source)
	local info = {
		Target = target, Ability = b.ability, EffectName = BALL_FX, iMoveSpeed = b.speed or 900,
		bDodgeable = false, bProvidesVision = false, ExtraData = { id = b.id },
	}
	if source then
		info.Source = source
		info.iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_ATTACK_1
	else
		info.vSourceLoc = from
	end
	ProjectileManager:CreateTrackingProjectile(info)
end

-- Цель следующего отскока: сначала враги с наименьшим числом попаданий (шар «растекается» по мобам),
-- если больше никого нет - та же цель (босс получает повторные попадания с растущим уроном)
function Lich:BallNext(b, pos)
	local best, bs
	for _, e in ipairs(self:Enemies(b.caster, pos, b.bounce_radius)) do
		if e:IsAlive() and e ~= b.last then
			local score = (b.hits[e] or 0) * 100000 + (e:GetAbsOrigin() - pos):Length2D()
			if not bs or score < bs then best, bs = e, score end
		end
	end
	if best then return best end
	local l = b.last
	if l and not l:IsNull() and l:IsAlive() and (l:GetAbsOrigin() - pos):Length2D() <= b.bounce_radius then return l end
	return nil
end

function Lich:BallStrike(b, target)
	local C = self.C
	local caster = b.caster
	local h = (b.hits[target] or 0) + 1
	b.hits[target] = h
	-- повторные попадания по одной цели усиливаются (против боссов это «огромный урон по одной цели»)
	local dmg = b.dmg * math.min(C.CHAIN_ESC_CAP, 1 + b.esc * (h - 1))
	if b.crit_elite and self:IsElite(target) then dmg = dmg * 2 end
	local pos = target:GetAbsOrigin()
	fx_world(FX_NOVA, pos)
	EmitSoundOn("Hero_Lich.ChainFrostImpact.Hero", target)
	EmitSoundOn("Hero_Crystal.CrystalNova", target)
	local _, killed = self:Hit(caster, target, b.ability, dmg, b.ctx)

	if b.small then
		-- Энергетический избыток
		if self:Has(caster, "e_excess") and target:IsAlive() then
			local burn = target:GetMana() * C.EXCESS_PCT / 100
			if burn > 0 then target:ReduceMana(burn); caster:GiveMana(burn) end
		end
		-- Осколочный шторм: мина под целью, взрыв через 1.5 с
		if b.mine then
			fx_world(FX_NOVA, pos)
			local mdmg = b.dmg * C.MINE_PCT
			RPG.After(C.MINE_DELAY, function()
				if caster:IsNull() then return end
				fx_world(FX_SHOCK, pos)
				for _, e in ipairs(Lich:Enemies(caster, pos, C.MINE_RADIUS)) do Lich:Hit(caster, e, b.ability, mdmg) end
			end)
		end
		if killed then
			-- Кровавый разгон
			if self:Has(caster, "e_haste") then caster:AddNewModifier(caster, b.ability, "modifier_rpg_lich_haste", { duration = C.HASTE_TIME }) end
			-- Абсолютный Зеро: смерть от первичного отскока
			if b.count == 0 and self:Has(caster, "l_absolute_zero") then
				RPG.After(0.05, function()
					if not caster:IsNull() then Lich:MeteorImpact(caster, b.ability, pos, { amp = 1 }, C.AZ_POWER, 1) end
				end)
			end
		end
	end
end

-- Попадание шара (вызывается из OnProjectileHit_ExtraData способности)
function Lich:OnBallHit(ability, target, loc, extra)
	local b = self.balls[extra and extra.id or -1]
	if not b then return true end
	local caster = b.caster
	if not caster or caster:IsNull() then self.balls[b.id] = nil; return true end

	local pos = loc
	if target and not target:IsNull() and target:IsAlive() then
		pos = target:GetAbsOrigin()
		self:BallStrike(b, target)
	end
	b.last = target
	b.count = b.count + 1

	if (b.max_hits and b.count >= b.max_hits) or (GameRules:GetGameTime() - b.born) > b.max_time then
		self.balls[b.id] = nil
		return true
	end
	RPG.After(b.delay, function()
		if caster:IsNull() then Lich.balls[b.id] = nil return end
		local nxt = Lich:BallNext(b, pos)
		if nxt then Lich:LaunchBall(b, pos, nxt, nil) else Lich.balls[b.id] = nil end
	end)
	return true
end

-- Обычный Chain Frost: шар с неограниченным числом отскоков (ограничен лишь временем жизни)
function Lich:CastChain(caster, ability, target)
	local ctx = self:BeginCast(caster, ability)
	local dmg = (ability:GetSpecialValueFor("damage") + self:Bonus(caster, "chain_damage") + self:TalentValue(caster, "25_left")
		+ self:Int(caster) * ability:GetSpecialValueFor("int_scale")) * ctx.amp * (caster:HasScepter() and 1.2 or 1)
	local b = self:NewBall(caster, ability, dmg, {
		ctx = ctx, delay = ability:GetSpecialValueFor("bounce_delay"), max_time = ability:GetSpecialValueFor("max_time") + self:Bonus(caster, "chain_time"),
		bounce_radius = ability:GetSpecialValueFor("bounce_radius") + self:Bonus(caster, "chain_radius") + (caster:HasScepter() and 150 or 0),
		esc = ability:GetSpecialValueFor("boss_stack_pct") / 100, speed = ability:GetSpecialValueFor("speed"),
	})
	EmitSoundOn("Hero_Lich.ChainFrost", caster)
	self:LaunchBall(b, caster:GetAbsOrigin(), target, caster)
end

-- ---- Мифик «Ледяной Метеор» ----
function Lich:MeteorRadius(caster, ability)
	local r = ability:GetSpecialValueFor("meteor_radius")
	if caster:HasScepter() then r = r + 100 end
	if self:Has(caster, "l_epicenter_blast") then r = r * self.C.EPI_BLAST_MULT end
	return r
end

function Lich:CastMeteor(caster, ability, point, hp_paid)
	local C = self.C
	local ctx = self:BeginCast(caster, ability)
	if hp_paid then
		caster:SetHealth(math.max(1, caster:GetHealth() - caster:GetMaxHealth() * C.BLOODMETEOR_PCT / 100))
	end
	local from = caster:GetAbsOrigin()
	local dist = (point - from):Length2D()
	local T = math.max(0.6, dist / ability:GetSpecialValueFor("arc_speed"))
	local start = GetGroundPosition(from, caster) + Vector(0, 0, 250)
	local ground = GetGroundPosition(point, caster)
	local fx = ParticleManager:CreateParticle(BALL_FX, PATTACH_WORLDORIGIN, nil)
	local t0 = GameRules:GetGameTime()
	EmitSoundOn("Hero_Lich.ChainFrost", caster)

	GameRules:GetGameModeEntity():SetContextThink("rpg_meteor_" .. self:NextId(), function()
		local t = (GameRules:GetGameTime() - t0) / T
		if t >= 1 then
			ParticleManager:DestroyParticle(fx, false)
			ParticleManager:ReleaseParticleIndex(fx)
			if not caster:IsNull() then Lich:MeteorImpact(caster, ability, ground, ctx, 1, 0) end
			return nil
		end
		local p = start + (ground - start) * t
		p.z = start.z + (ground.z - start.z) * t + 4 * C.METEOR_ARC * t * (1 - t)
		ParticleManager:SetParticleControl(fx, 0, p)
		ParticleManager:SetParticleControl(fx, 1, p)
		return 0.03
	end, 0)
end

-- depth 0 - основной метеор, depth >= 1 - мини-метеоры «Абсолютного Зеро» (без оглушения и шаров)
function Lich:MeteorImpact(caster, ability, point, ctx, power, depth)
	local C = self.C
	local main = depth == 0
	local radius = self:MeteorRadius(caster, ability) * (main and 1 or C.AZ_RADIUS)
	local dmg = (ability:GetSpecialValueFor("meteor_damage") + self:Bonus(caster, "chain_damage") * 2 + self:TalentValue(caster, "25_left")
		+ self:Int(caster) * ability:GetSpecialValueFor("int_scale")) * ctx.amp * power * (caster:HasScepter() and 1.2 or 1)

	-- Кровавый резонанс: HP < 35% -> +75% урона
	if self:Has(caster, "e_bloodres") and caster:GetHealth() < caster:GetMaxHealth() * C.BLOODRES_HP then dmg = dmg * C.BLOODRES_AMP end

	local enemies = self:Enemies(caster, point, radius)

	-- Критический осколок: упал на цель с максимумом стаков (2 - предел, дальше цель рассыпается) -> +100% урона, шары критуют по элитам
	local crit_main = false
	if main and self:Has(caster, "l_crit_shard") then
		for _, e in ipairs(enemies) do
			local m = e:FindModifierByNameAndCaster("modifier_rpg_lich_icing", caster)
			if m and m:GetStackCount() >= C.ICING_MAX - 1 then crit_main = true; break end
		end
		if crit_main then dmg = dmg * 2 end
	end

	fx_world(FX_SHOCK, point)
	fx_world(FX_NOVA, point, Vector(radius, 2, radius))
	fx_world(FX_ICEAGE, point)
	EmitSoundOn("Hero_Lich.ChainFrostImpact.Hero", caster)
	EmitSoundOn("Hero_Ursa.Earthshock", caster)

	local killed_pos, hits = {}, 0
	for _, e in ipairs(enemies) do
		hits = hits + 1
		local _, killed = self:Hit(caster, e, ability, dmg, ctx)
		if killed then
			table.insert(killed_pos, e:GetAbsOrigin())
		elseif main then
			self:Stun(e, caster, ability, ability:GetSpecialValueFor("meteor_stun"))
		end
		-- Энергетический вампиризм: +5% макс. маны за каждого задетого
		if self:Has(caster, "e_vamp_m") then caster:GiveMana(caster:GetMaxMana() * C.VAMP_METEOR_PCT / 100) end
	end

	-- Абсолютный Зеро: погибшие от взрыва детонируют мини-метеорами (цепная реакция, ограничена глубиной)
	if self:Has(caster, "l_absolute_zero") and depth < C.AZ_DEPTH then
		for _, pos in ipairs(killed_pos) do
			RPG.After(0.15, function()
				if not caster:IsNull() then Lich:MeteorImpact(caster, ability, pos, ctx, C.AZ_POWER, depth + 1) end
			end)
		end
	end

	if not main then return end

	-- Ледяной резонанс: 5+ врагов - обнуляет Frost Shield
	if self:Has(caster, "e_resmeteor") and hits >= C.RES_METEOR_HITS then self:ResetCooldown(caster, "rpg_lich_frost_shield") end

	-- Морозная лужа
	if self:Has(caster, "e_puddle") then
		CreateModifierThinker(caster, ability, "modifier_rpg_lich_puddle", { duration = C.PUDDLE_TIME, radius = radius },
			point, caster:GetTeamNumber(), false)
	end

	-- Эхо удара
	if self:Has(caster, "e_echo_m") then
		RPG.After(C.METEOR_ECHO_DELAY, function()
			if caster:IsNull() then return end
			fx_world(FX_SHOCK, point)
			for _, e in ipairs(Lich:Enemies(caster, point, radius)) do Lich:Hit(caster, e, ability, dmg * C.METEOR_ECHO_PCT) end
		end)
	end

	-- Эпицентр взрыва: воронка стягивает всех к центру до вылета осколков
	local delay = 0.05
	if self:Has(caster, "l_epicenter_blast") then
		delay = 0.5
		for _, e in ipairs(self:Enemies(caster, point, radius)) do
			if e:IsAlive() then
				local d = (e:GetAbsOrigin() - point):Length2D()
				e:AddNewModifier(caster, ability, "modifier_rpg_lich_pull_step", { duration = 0.45, x = point.x, y = point.y, speed = math.max(300, d / 0.4), stop = 0, stun = 1 })
			end
		end
	end

	-- Рассыпается на малые отскакивающие шары
	local count = self:Has(caster, "l_storm_shards") and C.STORM_BALLS or C.BALLS
	local ball_dmg = dmg * ability:GetSpecialValueFor("ball_damage_pct") / 100
	RPG.After(delay, function()
		if caster:IsNull() then return end
		local cands = Lich:Enemies(caster, point, 900)
		for i = #cands, 2, -1 do
			local j = RandomInt(1, i)
			cands[i], cands[j] = cands[j], cands[i]
		end
		if #cands == 0 then return end
		for i = 1, count do
			local tgt = cands[((i - 1) % #cands) + 1]
			local b = Lich:NewBall(caster, ability, ball_dmg, {
				small = true, ctx = ctx, max_hits = ability:GetSpecialValueFor("ball_bounces"), delay = 0.15, max_time = 8,
				bounce_radius = 500, crit_elite = crit_main, mine = Lich:Has(caster, "l_storm_shards"), speed = 1100,
			})
			Lich:LaunchBall(b, point, tgt, nil)
		end
	end)
end

-- ======================= ОПИСАНИЕ ГЕРОЯ ДЛЯ СИСТЕМЫ ПЕРКОВ =======================
local BUILDS = {
	blast   = "Архимаг (Frost Blast)",
	bastion = "Бастион (Frost Shield)",
	gaze    = "Захват (Sinister Gaze)",
	meteor  = "Метеор (Chain Frost)",
}

-- tier: 1 обычное, 2 редкое, 3 эпическое, 4 легендарное, 5 мифическое
-- Эпические и легендарные выпадают ТОЛЬКО после мифика и только своей ветки (см. Perks:Eligible)
-- bonus = { ключ = значение } - накопительные бонусы к способностям (см. Lich:Bonus)
local function mythic(id, build, name, desc)  return { id = id, tier = 5, build = build, max = 1, name = name, desc = desc } end
local function legend(id, build, name, desc)  return { id = id, tier = 4, build = build, requires_build = build, max = 1, name = name, desc = desc } end
local function epic(id, build, name, desc)    return { id = id, tier = 3, build = build, requires_build = build, max = 1, name = name, desc = desc } end

local PERKS = {
	-- ===================== ВЕТКА 1: ЛЕДЯНОЙ АРХИМАГ (Frost Blast) =====================
	mythic("m_archmage", "blast", "Ледяной Архимаг",
		"Frost Blast полностью теряет перезарядку, но каждый последовательный каст в течение 4 с стоит на 20% больше маны (стак сбрасывается, если не кастовать 4 с)."),
	legend("l_chain_shards", "blast", "Цепной мороз",
		"Каждый Frost Blast выпускает осколки в радиусе 600 от цели, нанося 70% урона способности."),
	legend("l_collapse", "blast", "Коллапс",
		"Чем больше маны стоит каст Frost Blast, тем больше его урон (+1% за каждые 3 маны стоимости)."),
	legend("l_horizon", "blast", "Бесконечный Горизонт",
		"Каждый каст Frost Blast в серии увеличивает дальность применения на 50 (без ограничений, пока идёт серия)."),
	legend("l_orbs", "blast", "Огненные огни",
		"С каждым кастом серии вокруг Лича вращается ледяная сфера (до 6). Сферы стреляют по врагам ближе 400, нанося текущий урон Frost Blast."),
	epic("e_overheat", "blast", "Морозная неожиданность",
		"Если мана кончается посреди серии, Лич входит в перегрев на 3 с: заклинания бесплатны, наносят на 100% больше урона и замораживают цель (перезарядка 20 с)."),
	epic("e_cascade", "blast", "Каскад",
		"Каждый 10-й каст серии наносит всем задетым 20% их макс. здоровья чистым уроном, игнорируя резисты (боссы получают урон со множителем BOSS_PCT_MULT)."),
	epic("e_pain", "blast", "Резонанс боли",
		"Каждый каст серии увеличивает радиус Frost Blast на 15% (суммируется до +150%)."),
	epic("e_pulse", "blast", "Леденящий импульс",
		"Каждые 4 каста серии вокруг Лича проходит волна, сжигающая 10% текущей маны врагов (сожжённое наносится уроном)."),
	epic("e_luck", "blast", "Морозная удача",
		"25% шанс, что Frost Blast бесплатно повторится через 0.3 с в ту же цель, не увеличивая стоимость маны."),
	epic("e_authority", "blast", "Леденящий авторитет",
		"Каждый 3-й каст серии наносит критический урон (x2.5) и замораживает цель на 1.5 с, прерывая касты боссов (у боссов заморозка вдвое короче)."),
	epic("e_comp", "blast", "Компенсация",
		"За каждые 500 маны, потраченные за серию, Лич получает +10% к скорости передвижения и +15% к снижению перезарядок на 5 с."),
	epic("e_blood", "blast", "Жертвоприношение",
		"Если мана кончается посреди серии, следующие 5 заклинаний тратят здоровье (5% макс. ХП), наносят на 50% больше урона и лечат Лича."),

	-- ===================== ВЕТКА 2: ЛЕДЯНОЙ БАСТИОН (Frost Shield) =====================
	mythic("m_bastion", "bastion", "Ледяной Бастион",
		"Frost Shield больше не снижает урон. Лич на 5 с заковывает себя в глыбу: 100% сопротивление физ. урону, но нельзя двигаться и атаковать. Глыба стягивает всех в радиусе 700 (как Black Hole) и каждые 0.5 с бьёт ледяными волнами, накладывая обледенение. В конце глыба взрывается и замораживает выживших на 2 с."),
	legend("l_resonance", "bastion", "Энергетический Резонанс",
		"Весь урон, который Лич получил бы во время глыбы, поглощается и по окончании полностью превращается в здоровье и ману."),
	legend("l_chain_bastion", "bastion", "Цепной мороз",
		"Если враг погибает от ледяных волн, это вызывает мини-взрыв глыбы (40% финального урона) по всем целям на арене."),
	legend("l_detonation", "bastion", "Цепная детонация",
		"Каждая волна оставляет на врагах ледяную метку. Смерть меченого вызывает взрыв на 20% урона финальной глыбы."),
	legend("l_storm", "bastion", "Непрекращающийся Шторм",
		"В конце глыба раскалывается на 4 малых осколка, которые разлетаются на 400 и взрываются через 1 с (по 50% финального урона)."),
	epic("e_vamp_b", "bastion", "Энергетический вампиризм",
		"Ледяные волны выжигают у врагов 5% макс. маны и отдают её Личу."),
	epic("e_aura", "bastion", "Морозная аура замедления",
		"Вокруг глыбы (радиус 600) враги теряют ещё 30% скорости атаки и передвижения."),
	epic("e_prison", "bastion", "Кристаллическая тюрьма",
		"Финальный взрыв глыбы накладывает Break на 3 с (отключает пассивные способности)."),
	epic("e_echo_b", "bastion", "Эхо взрыва",
		"Через 1 с после финального взрыва происходит эхо-взрыв на 40% силы."),
	epic("e_bloodfrost", "bastion", "Кровавый мороз",
		"Глыбу можно активировать даже в оглушении и безмолвии, сняв с себя все негативные эффекты ценой 10% текущего здоровья."),
	epic("e_icecascade", "bastion", "Ледяной каскад",
		"Если финальный взрыв убивает хотя бы одного элитного моба, перезарядка глыбы сокращается на 30%."),
	epic("e_anchor", "bastion", "Пространственный якорь",
		"Притянутые враги после стяжки получают Root на 2 с (сверх заморозки)."),
	epic("e_archshield", "bastion", "Архимагический щит",
		"После глыбы Лич получает щит на 25% от общего урона, нанесённого волнами."),

	-- ===================== ВЕТКА 3: ГРАВИТАЦИОННЫЙ ЗАХВАТ (Sinister Gaze) =====================
	mythic("m_gravity", "gaze", "Гравитационный Захват",
		"Sinister Gaze больше не бьёт по одной цели: потоковый канал до 3 с создаёт перед Личем широкий конус притяжения. Все враги в секторе (включая элиту) ползут к Личу, а каждый притянутый враг непрерывно восстанавливает ему здоровье и ману."),
	legend("l_eventhorizon", "gaze", "Горизонт Событий",
		"Радиус и ширина конуса притяжения +75%."),
	legend("l_bloodchannel", "gaze", "Кровавый Канал",
		"Если мана кончается во время канала, он не прерывается: Лич тратит по 4% макс. ХП в секунду, а притяжение вдвое быстрее."),
	legend("l_manaeater", "gaze", "Пожиратель Магии",
		"Враги в конусе теряют 10% макс. маны в секунду. Сожжённая мана превращается в щит Лича, который держится ещё 5 с."),
	legend("l_epicenter_death", "gaze", "Эпицентр Смерти",
		"Моб, погибший во время притяжения, взрывается и наносит 15% своего макс. здоровья остальным стягиваемым целям."),
	epic("e_shardwave", "gaze", "Осколочная волна",
		"В конце канала под Личем происходит взрыв по стянутым вплотную врагам и накладывает по 1 стаку обледенения."),
	epic("e_exhaust", "gaze", "Морозное истощение",
		"Притянутые враги теряют 40% скорости атаки и передвижения на 2 с после канала."),
	epic("e_gazereset", "gaze", "Ледяной резонанс",
		"Успешное завершение канала мгновенно обнуляет перезарядку Frost Shield."),
	epic("e_trap", "gaze", "Пространственная ловушка",
		"Враги, стянутые вплотную, получают Root на 1.5 с."),
	epic("e_mirror", "gaze", "Зеркальный конус",
		"Угол захвата конуса +45 градусов."),
	epic("e_relentless", "gaze", "Неумолимый поток",
		"Во время канала Лич получает 30% сопротивления магии и его нельзя замедлить ниже базовой скорости."),
	epic("e_crystal", "gaze", "Кристаллическая броня",
		"+3 брони за каждого врага в конусе во время канала (держится ещё 4 с после него)."),
	epic("e_dome", "gaze", "Защитный купол",
		"Союзники позади Лича во время канала получают на 25% меньше урона от атак спереди."),

	-- ===================== ВЕТКА 4: ЛЕДЯНОЙ МЕТЕОР (Chain Frost) =====================
	mythic("m_meteor", "meteor", "Ледяной Метеор",
		"Chain Frost становится способностью по выбранному врагу: метеор падает в его позицию, оглушает врагов вокруг на 2 с и рассыпается на 6 мелких отскакивающих шаров."),
	legend("l_epicenter_blast", "meteor", "Эпицентр Взрыва",
		"Радиус метеора +50%, в эпицентре создаётся воронка, стягивающая врагов к центру перед вылетом осколков."),
	legend("l_storm_shards", "meteor", "Осколочный Шторм",
		"Малых шаров 12 вместо 6; каждый шар оставляет под целью ледяную мину, взрывающуюся через 1.5 с."),
	legend("l_crit_shard", "meteor", "Критический Осколок",
		"Если метеор падает на цель с максимумом стаков обледенения (2 — выше цель рассыпается), урон метеора +100%, а все шары критуют (x2) по элите и боссам."),
	legend("l_absolute_zero", "meteor", "Абсолютный Зеро",
		"Враг, убитый взрывом метеора или первичными отскоками шаров, детонирует мини-метеором (30% мощности) и запускает цепную реакцию."),
	epic("e_vamp_m", "meteor", "Энергетический вампиризм",
		"Каждый враг, задетый взрывом метеора, восстанавливает Личу 5% макс. маны."),
	epic("e_puddle", "meteor", "Морозная лужа",
		"Лужа на месте падения (4 с) замедляет скорость атаки и передвижения на 60% и снижает сопротивление магии на 20%."),
	epic("e_bloodmeteor", "meteor", "Кровавый метеор",
		"Если маны не хватает, метеор можно призвать за здоровье: 15% макс. ХП на каст."),
	epic("e_resmeteor", "meteor", "Ледяной резонанс",
		"Попадание метеора по 5+ врагам мгновенно обновляет перезарядку Frost Shield."),
	epic("e_echo_m", "meteor", "Эхо удара",
		"Через 1.5 с после падения в эпицентре происходит эхо-взрыв на 40% урона."),
	epic("e_haste", "meteor", "Кровавый разгон",
		"Убийство врага осколками даёт Личу +20% скорости передвижения и атаки на 4 с."),
	epic("e_bloodres", "meteor", "Кровавый резонанс",
		"Если у Лича меньше 35% здоровья, урон метеора +75%."),
	epic("e_excess", "meteor", "Энергетический избыток",
		"Каждый отскок малых шаров сжигает 3% текущей маны врага и возвращает её Личу."),

	-- ===================== РЕДКИЕ: небольшие улучшения способностей (копятся) =====================
	{ id = "r_blast_dmg",    tier = 2, max = 30, name = "Острые льдинки",       desc = "+35 к урону Frost Blast",              bonus = { blast_damage = 35 } },
	{ id = "r_blast_radius", tier = 2, max = 12, name = "Широкий взрыв",        desc = "+25 к радиусу Frost Blast",            bonus = { blast_radius = 25 } },
	{ id = "r_blast_range",  tier = 2, max = 10, name = "Дальний холод",        desc = "+40 к дальности Frost Blast",          bonus = { blast_range = 40 } },
	{ id = "r_shield_red",   tier = 2, max = 10, name = "Толстый лёд",          desc = "+2% к снижению урона Frost Shield",    bonus = { shield_red = 2 } },
	{ id = "r_shield_slow",  tier = 2, max = 10, name = "Хватка мороза",        desc = "+3% к замедлению атакующих Frost Shield", bonus = { shield_slow = 3 } },
	{ id = "r_shield_dur",   tier = 2, max = 10, name = "Долгая защита",        desc = "+0.5 с к длительности Frost Shield",   bonus = { shield_duration = 0.5 } },
	{ id = "r_gaze_dps",     tier = 2, max = 30, name = "Тяжёлый взгляд",       desc = "+35 к урону в секунду Sinister Gaze",  bonus = { gaze_dps = 35 } },
	{ id = "r_gaze_chan",    tier = 2, max = 10, name = "Долгий взгляд",        desc = "+0.2 с к длительности канала Sinister Gaze", bonus = { gaze_channel = 0.2 } },
	{ id = "r_chain_dmg",    tier = 2, max = 30, name = "Звенья цепи",          desc = "+45 к урону Chain Frost",              bonus = { chain_damage = 45 } },
	{ id = "r_chain_rad",    tier = 2, max = 10, name = "Дальний отскок",       desc = "+40 к радиусу отскока Chain Frost",    bonus = { chain_radius = 40 } },
	{ id = "r_chain_time",   tier = 2, max = 10, name = "Вечная цепь",          desc = "+1 с к времени жизни шара Chain Frost", bonus = { chain_time = 1 } },
	{ id = "r_spellamp",     tier = 2, max = 25, name = "Чародейская мощь",     desc = "+4% к силе умений",                    stats = { spellamp = 4 } },
	{ id = "r_cdr",          tier = 2, max = 10, name = "Холодный расчёт",      desc = "+4% снижение перезарядки",             stats = { cdr = 4 } },
	{ id = "r_manaflow",     tier = 2, max = 20, name = "Ледяной источник",     desc = "+150 к мане, +2 к регенерации маны",   stats = { mana = 150, manaregen = 2 } },
}

RPG.HEROES["npc_dota_hero_lich"] = {
	modifier = "modifier_rpg_lich",
	builds = BUILDS,
	perks = PERKS,
}

-- ======================= ДИАГНОСТИКА =======================
-- Консоль: rpg_lich_diag - состояние способностей/модификаторов всех Lich (пришлите вывод, если что-то не работает)
Convars:RegisterCommand("rpg_lich_diag", function()
	for _, hero in ipairs(HeroList:GetAllHeroes()) do
		if hero:GetUnitName() == "npc_dota_hero_lich" then
			print("== Lich, level " .. hero:GetLevel() .. ", int=" .. Lich:Int(hero) .. ", rpg=" .. tostring(hero.rpg ~= nil))
			for i = 0, 17 do
				local ab = hero:GetAbilityByIndex(i)
				if ab then
					print(string.format("  [%d] %s lvl=%d cd=%.1f", i, ab:GetAbilityName(), ab:GetLevel(), ab:GetCooldownTimeRemaining()))
				end
			end
			print("  modifier_rpg_stats: " .. tostring(hero:HasModifier("modifier_rpg_stats")) .. ", modifier_rpg_lich: " .. tostring(hero:HasModifier("modifier_rpg_lich")))
			print("  mythic build: " .. tostring(hero.rpg and hero.rpg.build))
		end
	end
end, "Lich diagnostics", FCVAR_CHEAT)
