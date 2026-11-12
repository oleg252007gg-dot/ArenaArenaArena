-- Система перков (переписана под Axe).
--
-- 5 редкостей:  1 Обычное, 2 Редкое, 3 Эпическое, 4 Легендарное, 5 Мифическое.
-- После КАЖДОЙ волны игрок получает 3 перка на выбор (шансы редкости - RPG.CFG.PERK_CHANCE).
-- Мифический перк - один раз за игру, гарантированно после 10-й волны (после босса).
-- ЭПИЧЕСКИЕ и ЛЕГЕНДАРНЫЕ перки выпадают ТОЛЬКО после выбора мифического и только из его ветки (build).
-- Перки героя лежат в game/heroes/<hero>.lua (RPG.HEROES[unit].perks), универсальные обычные - здесь.
Perks = Perks or {}

Perks.RARITY = {
	{ id = "common",    name = "Обычное",     color = "#b8b8b8" },
	{ id = "rare",      name = "Редкое",      color = "#4a90e2" },
	{ id = "epic",      name = "Эпическое",   color = "#b050e0" },
	{ id = "legendary", name = "Легендарное", color = "#ff9a1e" },
	{ id = "mythic",    name = "Мифическое",  color = "#ff3d6e" },
}

-- ===== ОБЫЧНЫЕ (универсальные): здоровье, мана, скорость и т.п. =====
-- Сами по себе слабые, но копятся: max большой, чтобы хватило на 100 волн.
Perks.GENERIC = {
	{ id = "c_hp",     tier = 1, name = "Крепкое тело",     desc = "+150 к здоровью",              stats = { hp = 150 },        max = 99 },
	{ id = "c_mana",   tier = 1, name = "Запас маны",       desc = "+120 к мане",                  stats = { mana = 120 },      max = 99 },
	{ id = "c_ms",     tier = 1, name = "Лёгкий шаг",       desc = "+8 к скорости движения",       stats = { ms = 8 },          max = 25 },
	{ id = "c_regen",  tier = 1, name = "Живучесть",        desc = "+2 к регенерации здоровья",    stats = { hpregen = 2 },     max = 99 },
	{ id = "c_mregen", tier = 1, name = "Поток маны",       desc = "+1 к регенерации маны",        stats = { manaregen = 1 },   max = 99 },
	{ id = "c_armor",  tier = 1, name = "Толстая кожа",     desc = "+2 к броне",                   stats = { armor = 2 },       max = 99 },
	{ id = "c_dmg",    tier = 1, name = "Тяжёлая рука",     desc = "+10 к урону",                  stats = { damage = 10 },     max = 99 },
	{ id = "c_as",     tier = 1, name = "Быстрые руки",     desc = "+8 к скорости атаки",          stats = { as = 8 },          max = 99 },
	{ id = "c_hp_ms",  tier = 1, name = "Выносливость",     desc = "+100 к здоровью, +4 к скорости движения", stats = { hp = 100, ms = 4 }, max = 99 },
	{ id = "c_spellamp", tier = 1, name = "Чародей",         desc = "+3% к силе умений",            stats = { spellamp = 3 },    max = 99 },
	{ id = "c_cdr",    tier = 1, name = "Быстрая подготовка", desc = "+2% к снижению перезарядки",   stats = { cdr = 2 },         max = 25 },
	{ id = "c_mana_hp",tier = 1, name = "Баланс",           desc = "+80 к мане, +80 к здоровью",   stats = { mana = 80, hp = 80 }, max = 99 },
}

-- ===== Шанс редкости одного предложения =====
-- Проверяем сверху вниз: легендарное -> эпическое -> редкое -> иначе обычное.
function Perks:RollTier(hero, wave)
	local c = RPG.CFG.PERK_CHANCE
	local branch = hero.rpg and hero.rpg.build ~= nil     -- мифик уже выбран?
	if branch and wave >= RPG.CFG.PERK_LEGENDARY_MIN_WAVE and RandomFloat(0, 1) < c.legendary then return 4 end
	if branch and wave >= RPG.CFG.PERK_EPIC_MIN_WAVE and RandomFloat(0, 1) < c.epic then return 3 end
	if wave >= RPG.CFG.PERK_RARE_MIN_WAVE and RandomFloat(0, 1) < c.rare then return 2 end
	return 1
end

function Perks:Eligible(hero, p)
	local r = hero.rpg
	if p.stub and not RPG.CFG.SHOW_STUB_BUILDS then return false end                 -- заглушки скрыты
	if (r.perk_count[p.id] or 0) >= (p.max or 1) then return false end
	if p.tier == 5 and r.build then return false end                                  -- мифик: один на героя
	-- ЭПИКИ и ЛЕГЕНДАРКИ: только после мифика и только своей ветки
	if p.tier == 3 or p.tier == 4 then
		if not r.build or p.build ~= r.build then return false end
	end
	if p.requires_build and r.build ~= p.requires_build then return false end         -- нужна ветка (мифик)
	if p.requires_perk and (r.perk_count[p.requires_perk] or 0) <= 0 then return false end
	if p.build and r.build and p.build ~= r.build then return false end               -- чужие ветки закрыты
	return true
end

function Perks:Pool(hero)
	local pool = {}
	for _, p in ipairs(Perks.GENERIC) do table.insert(pool, p) end
	local def = RPG.HEROES[hero:GetUnitName()]
	if def then
		for _, p in ipairs(def.perks) do table.insert(pool, p) end
	end
	return pool
end

-- Выбирает перк нужной редкости; если таких нет, сначала спускается ниже, потом поднимается выше
function Perks:Pick(hero, pool, tier, taken)
	local order = { tier }
	for t = tier - 1, 1, -1 do table.insert(order, t) end
	for t = tier + 1, 4 do table.insert(order, t) end
	for _, t in ipairs(order) do
		local cands, total = {}, 0
		for _, p in ipairs(pool) do
			if p.tier == t and not taken[p.id] and Perks:Eligible(hero, p) then
				local w = (p.build and hero.rpg.build == p.build) and 3 or 1   -- перки выбранной ветки втрое чаще
				table.insert(cands, { p = p, w = w })
				total = total + w
			end
		end
		if #cands > 0 then
			local r = RandomFloat(0, total)
			for _, c in ipairs(cands) do
				r = r - c.w
				if r <= 0 then return c.p end
			end
			return cands[#cands].p
		end
	end
	return nil
end

-- Возвращает список перков и флаг «мифический выбор».
-- skip_mythic: после выбора мифика сразу предлагаем обычную тройку этой же волны.
function Perks:Roll(hero, wave, count, skip_mythic)
	local pool = self:Pool(hero)

	-- Мифический выбор: гарантирован после MYTHIC_WAVE-й волны (босс), пока игрок не выберет ветку
	if not skip_mythic and not hero.rpg.build and wave >= RPG.CFG.MYTHIC_WAVE then
		local list = {}
		for _, p in ipairs(pool) do
			if p.tier == 5 and self:Eligible(hero, p) then table.insert(list, p) end
		end
		if #list > 0 then return list, true end
	end

	local taken, out = {}, {}
	for _ = 1, count do
		local p = self:Pick(hero, pool, self:RollTier(hero, wave), taken)
		if p then
			taken[p.id] = true
			table.insert(out, p)
		end
	end
	return out, false
end

-- Есть ли у героя перк. Работает и на сервере, и на клиенте (клиент читает NetTable rpg_perks)
function Perks:Has(hero, id)
	if not hero or hero:IsNull() then return false end
	if IsServer() then return hero.rpg ~= nil and (hero.rpg.perk_count[id] or 0) > 0 end
	local t = CustomNetTables:GetTableValue("rpg_perks", tostring(hero:entindex()))
	return t ~= nil and (t[id] or 0) > 0
end

-- Синхронизация набора перков клиенту (нужна способностям, у которых поведение зависит от перка)
function Perks:Sync(hero)
	if not hero or hero:IsNull() or not hero.rpg then return end
	local t = {}
	for id, n in pairs(hero.rpg.perk_count) do t[id] = n end
	for key, value in pairs(hero.rpg.axe_bonus or {}) do t["bonus_" .. key] = value end
	for key, value in pairs(hero.rpg.hoodwink_bonus or {}) do t["bonus_hoodwink_" .. key] = value end
	for key, value in pairs(hero.rpg.arc_bonus or {}) do t["bonus_arc_" .. key] = value end
	for key, value in pairs(hero.rpg.sven_bonus or {}) do t["bonus_sven_" .. key] = value end
	CustomNetTables:SetTableValue("rpg_perks", tostring(hero:entindex()), t)
end

function Perks:Find(id)
	if not self.index then
		self.index = {}
		for _, p in ipairs(Perks.GENERIC) do self.index[p.id] = p end
		for _, def in pairs(RPG.HEROES) do
			for _, p in ipairs(def.perks) do self.index[p.id] = p end
		end
	end
	return self.index[id]
end

function Perks:Payload(hero, p)
	local rar = Perks.RARITY[p.tier]
	local def = RPG.HEROES[hero:GetUnitName()]
	return {
		name = p.name, desc = p.desc, tier = p.tier, rarity = rar.name, color = rar.color,
		build = (p.build and def and def.builds and def.builds[p.build]) or "",
		count = hero.rpg.perk_count[p.id] or 0, max = p.max or 1,
	}
end

-- Вызывается при убийстве врага; передаёт событие модулю героя (если у него есть on_kill)
function Perks:OnKill(keys, victim)
	if not keys.entindex_attacker then return end
	local attacker = EntIndexToHScript(keys.entindex_attacker)
	if not attacker or attacker:IsNull() or not attacker.rpg then return end
	local def = RPG.HEROES[attacker:GetUnitName()]
	if def and def.on_kill then def.on_kill(attacker, keys, victim) end
end
