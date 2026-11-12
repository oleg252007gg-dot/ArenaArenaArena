-- Сведение всех бонусов (экипировка + артефакты + перки + сеты) в модификатор героя.
-- Значения синхронизируются клиенту через NetTable "rpg_stats", поэтому HUD показывает реальные числа.
Stats = Stats or {}

function Stats:Empty()
	local t = {}
	for key in pairs(RPG.AFFIXES) do t[key] = 0 end
	return t
end

function Stats:Add(dst, src)
	for k, v in pairs(src) do dst[k] = (dst[k] or 0) + v end
end

function Stats:Init()
	-- Пересчёт тех, кому он понадобился (смена инвентаря и т.п.)
	GameRules:GetGameModeEntity():SetContextThink("rpg_stats_think", function()
		Stats._tick = (Stats._tick or 0) + 1
		for _, hero in ipairs(HeroList:GetAllHeroes()) do
			-- пересчёт по флагу и раз в ~2 с принудительно (страховка: инвентарь, уровни, любые побочные изменения)
			if hero.rpg and (hero.rpg_dirty or Stats._tick % 10 == 0) then Stats:Recalc(hero) end
		end
		return 0.2
	end, 0.2)

	-- Консольная команда для отладки: rpg_stats
	Convars:RegisterCommand("rpg_stats", function()
		for _, hero in ipairs(HeroList:GetAllHeroes()) do
			if hero.rpg then
				print("== " .. hero:GetUnitName() .. " (build: " .. tostring(hero.rpg.build) .. ")")
				print("  actual: dmg=" .. hero:GetAverageTrueAttackDamage(hero) .. " ms=" .. hero:GetIdealSpeed() .. " as=" .. hero:GetAttacksPerSecond(false) .. " hp=" .. hero:GetMaxHealth() .. " mana=" .. hero:GetMaxMana())
				for k, v in pairs(hero.rpg_totals or {}) do
					if v ~= 0 then print("  " .. k .. " = " .. v) end
				end
			end
		end
	end, "Print RPG stat totals", FCVAR_CHEAT)
end

function Stats:QueueRecalc(hero)
	if hero and not hero:IsNull() then hero.rpg_dirty = true end
end

function Stats:Recalc(hero)
	if not hero or hero:IsNull() or not hero.rpg then return end
	hero.rpg_dirty = false
	local ok, err = xpcall(function() Stats:DoRecalc(hero) end, debug.traceback)
	if not ok then print("[RPG] Stats:Recalc error: " .. tostring(err)) end
end

function Stats:DoRecalc(hero)
	local mod = hero:FindModifierByName("modifier_rpg_stats")
	if not mod then
		print("[RPG] modifier_rpg_stats not found on " .. hero:GetUnitName())
		return
	end

	local total = Stats:Empty()
	Stats:Add(total, hero.rpg.perk_stats)

	local sets, gear = {}, {}
	for slot = 0, 5 do
		local item = hero:GetItemInSlot(slot)
		if item then
			local name = item:GetAbilityName()
			if Loot:IsGear(item) then
				Loot:EnsureRolled(item)
				Stats:Add(total, item.rpg.stats)
				if item.rpg.set then sets[item.rpg.set] = (sets[item.rpg.set] or 0) + 1 end
				local d = Loot:Describe(item)
				table.insert(gear, { name = d.name, color = d.color, lines = d.lines })
			elseif RPG.ARTIFACTS[name] then
				local a = RPG.ARTIFACTS[name]
				table.insert(gear, { name = a.name, color = "#ffd24a", lines = a.lines })
			end
		end
	end

	local set_lines = {}
	for id, count in pairs(sets) do
		local def = RPG.SETS[id]
		if count >= 2 then Stats:Add(total, def.bonus2) end
		if count >= 3 then Stats:Add(total, def.bonus3) end
		table.insert(set_lines, "Сет «" .. def.name .. "»: " .. count .. " шт.")
	end

	hero.rpg_totals = total
	mod:SetStats(total)
	CustomNetTables:SetTableValue("rpg_stats", tostring(hero:entindex()), total)
	hero:CalculateStatBonus(true)
	self:SendGear(hero, gear, total, set_lines)
end

-- Панель «Снаряжение»: предметы, сеты и суммарные бонусы (перки + предметы)
function Stats:SendGear(hero, gear, total, set_lines)
	local player = PlayerResource:GetPlayer(hero:GetPlayerOwnerID())
	if not player then return end
	local totals = {}
	for _, key in ipairs(RPG.AFFIX_ORDER) do
		local v = total[key] or 0
		if v ~= 0 then
			totals[#totals + 1] = "+" .. (math.floor(v * 10 + 0.5) / 10) .. " " .. RPG.AFFIXES[key].name
		end
	end
	CustomGameEventManager:Send_ServerToPlayer(player, "rpg_gear_update", { items = gear, totals = totals, sets = set_lines })
end
