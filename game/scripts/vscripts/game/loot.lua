Loot = Loot or {}

function Loot:IsGear(item)
	return item ~= nil and not item:IsNull() and RPG.GEAR[item:GetAbilityName()] ~= nil
end

-- Редкость купленного снаряжения: с ростом волны выше шанс эпиков и легенд
function Loot:RollRarity(wave, min_rarity, boost)
	boost = boost or 1
	local w = {
		math.max(15, 60 - wave * 1.2),
		25 + wave * 0.4,
		(11 + wave * 0.5) * boost,
		(4 + wave * 0.3) * boost,
	}
	local start = min_rarity or 1
	local total = 0
	for i = start, 4 do total = total + w[i] end
	local r = RandomFloat(0, total)
	for i = start, 4 do
		r = r - w[i]
		if r <= 0 then return i end
	end
	return 4
end

-- Генерация свойств предмета (хранятся в item.rpg)
function Loot:Roll(item, wave, rarity)
	local def = RPG.GEAR[item:GetAbilityName()]
	rarity = math.max(rarity or Loot:RollRarity(wave), def.min_rarity or 1)
	local rar = RPG.RARITY[rarity]

	local pool = {}
	for _, k in ipairs(def.pool) do table.insert(pool, k) end
	for i = #pool, 2, -1 do
		local j = RandomInt(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local data = { rarity = rarity, wave = wave, stats = {}, list = {} }
	for i = 1, math.min(rar.affixes, #pool) do
		local key = pool[i]
		local a = RPG.AFFIXES[key]
		local v = (a.base + a.step * wave) * rar.mult * RandomFloat(0.85, 1.15)
		v = math.floor(v * 10 + 0.5) / 10
		data.stats[key] = v
		table.insert(data.list, { key = key, value = v })
	end
	if rarity >= 3 then
		data.set = RPG.SET_IDS[RandomInt(1, #RPG.SET_IDS)]
	end
	item.rpg = data
	return data
end

-- Предметы из магазина получают свойства при первом пересчёте
function Loot:EnsureRolled(item)
	if item.rpg then return end
	local wave = math.max(1, (Waves and Waves.wave) or 1)
	Loot:Roll(item, wave, Loot:RollRarity(wave, 1, 0.5))
end

function Loot:Describe(item)
	Loot:EnsureRolled(item)
	local def = RPG.GEAR[item:GetAbilityName()]
	local rar = RPG.RARITY[item.rpg.rarity]
	local lines = {}
	for _, e in ipairs(item.rpg.list) do
		local a = RPG.AFFIXES[e.key]
		table.insert(lines, "+" .. e.value .. " " .. a.name)
	end
	local title = rar.name .. " " .. def.name
	if item.rpg.set then
		title = title .. " [" .. RPG.SETS[item.rpg.set].name .. "]"
	end
	return { name = title, color = rar.color, lines = table.concat(lines, ", ") }
end

-- Артефакты выпадают только с боссов: по одному на каждого игрока
function Loot:DropArtifacts(pos, list, count)
	local pool = {}
	for _, n in ipairs(list) do table.insert(pool, n) end
	for i = #pool, 2, -1 do
		local j = RandomInt(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for i = 1, count do
		local name = pool[((i - 1) % #pool) + 1]
		local item = CreateItem(name, nil, nil)
		CreateItemOnPositionSync(pos, item)
		item:LaunchLoot(false, 300, 0.7, pos + RandomVector(RandomInt(120, 260)))
		local info = RPG.ARTIFACTS[name]
		CustomGameEventManager:Send_ServerToAllClients("rpg_toast", {
			text = "★ Артефакт: " .. (info and info.name or name),
			color = "#ffd24a",
		})
	end
end
