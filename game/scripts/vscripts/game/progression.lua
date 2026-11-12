Progression = Progression or {}

local TALENTS = {
	axe = {
		{ key="5_as", level=5, name="+15% скорости атаки" }, { key="5_ms", level=5, name="+15% скорости передвижения" },
		{ key="10_call_armor", level=10, name="+20 брони от Berserker's Call" }, { key="10_hunger_damage", level=10, name="+10% урона Battle Hunger" },
		{ key="15_cull_duration", level=15, name="+3 секунды бонуса Culling Blade за убийство" }, { key="15_hunger_duration", level=15, name="+3 секунды Battle Hunger" },
		{ key="20_call_radius", level=20, name="+200 к радиусу Berserker's Call" }, { key="20_strength", level=20, name="+40 силы" },
		{ key="25_helix_agi", level=25, name="Counter Helix: +0,05% урона за ловкость" }, { key="25_hunger_int", level=25, name="Battle Hunger: +0,05% урона за интеллект" },
		{ key="30_agi", level=30, name="+150 ловкости" }, { key="30_int", level=30, name="+150 интеллекта" },
		{ key="35_call_strength", level=35, name="+1 к радиусу Call за силу" }, { key="35_magic_armor", level=35, name="+1% сопротивления магии за 5 брони" },
		{ key="40_hunger_charges", level=40, name="+3 заряда Battle Hunger" }, { key="40_cull_charges", level=40, name="+2 заряда Culling Blade" },
		{ key="45_cull_charges", level=45, name="+2 заряда Culling Blade" }, { key="45_boss_damage", level=45, name="Боссам: +50 чистого урона за каждые 100 макс. HP Axe" },
		{ key="50_boss_damage", level=50, name="Боссам: +50 чистого урона за каждые 100 макс. HP Axe" }, { key="50_helix_proc", level=50, name="Counter Helix: +50% урона раз в 7 секунд" },
		{ key="55_stub", level=55, name="В разработке", stub=true },
		{ key="60_stub", level=60, name="В разработке", stub=true },
		{ key="65_stub", level=65, name="В разработке", stub=true },
		{ key="70_stub", level=70, name="В разработке", stub=true },
		{ key="75_stub", level=75, name="В разработке", stub=true },
		{ key="80_stub", level=80, name="В разработке", stub=true },
		{ key="85_stub", level=85, name="В разработке", stub=true },
		{ key="90_stub", level=90, name="В разработке", stub=true },
		{ key="95_stub", level=95, name="В разработке", stub=true },
		{ key="100_stub", level=100, name="В разработке", stub=true },
	},
	lich = {
		{ key = "10_left", level = 10, name = "+400 к мане" },
		{ key = "10_right", level = 10, name = "+10% к силе умений" },
		{ key = "15_left", level = 15, name = "+4 к регенерации маны" },
		{ key = "15_right", level = 15, name = "+150 к урону Frost Blast" },
		{ key = "20_left", level = 20, name = "+350 к здоровью" },
		{ key = "20_right", level = 20, name = "+15% снижения урона Frost Shield" },
		{ key = "25_left", level = 25, name = "+400 к урону Chain Frost" },
		{ key = "25_right", level = 25, name = "+300 к урону Sinister Gaze в секунду" },
	},
	hoodwink = {},
}

local function hero_key(hero)
	local name = hero:GetUnitName()
	if name == "npc_dota_hero_axe" then return "axe" end
	if name == "npc_dota_hero_lich" then return "lich" end
	if name == "npc_dota_hero_hoodwink" then return "hoodwink" end
	if name == "npc_dota_hero_arc_warden" then return "arc_warden" end
	if name == "npc_dota_hero_sven" then return "sven" end
	return "generic"
end

-- Fill all five-level rows through level 100. Existing Axe/Lich abilities stay
-- connected to their current modifiers; generated choices grant RPG stats.
local function fill_talents(key, defs)
	local counts, kept = {}, {}
	for _, talent in ipairs(defs) do
		if not talent.stub then
			talent.legacy = (key == "axe" and talent.level <= 50)
				or (key == "lich" and talent.level >= 10 and talent.level <= 25)
			table.insert(kept, talent)
			counts[talent.level] = (counts[talent.level] or 0) + 1
		end
	end
	for level = 5, 100, 5 do
		if (counts[level] or 0) < 2 then
			table.insert(kept, { key=level.."_vitality", level=level,
				name="+125 к здоровью", stats={hp=125} })
			table.insert(kept, { key=level.."_might", level=level,
				name="+10 к урону, +4 к скорости атаки", stats={damage=10, as=4} })
		end
	end
	return kept
end
for key, defs in pairs(TALENTS) do TALENTS[key] = fill_talents(key, defs) end
for _, key in ipairs({"hoodwink", "arc_warden", "sven"}) do
	TALENTS[key] = TALENTS[key] or fill_talents(key, {})
end
local function talent_defs(hero)
	return TALENTS[hero_key(hero)] or TALENTS.axe
end

function Progression:Init()
	CustomGameEventManager:RegisterListener("rpg_spend_point", function(_, data) Progression:OnSpend(data) end)
	CustomGameEventManager:RegisterListener("rpg_perk_pick", function(_, data) Progression:OnPick(data) end)
	CustomGameEventManager:RegisterListener("rpg_talent_pick", function(_, data) Progression:OnTalentPick(data) end)
	GameRules:GetGameModeEntity():SetContextThink("rpg_progression", function()
		Progression:Think()
		return 1
	end, 1)
end

function Progression:InitHero(hero)
	if not hero or hero:IsNull() or hero.rpg then return end
	LinkLuaModifier("modifier_rpg_stats", "modifiers/modifier_rpg_stats", LUA_MODIFIER_MOTION_NONE)
	hero.rpg = {
		points = RPG.CFG.START_POINTS,
		level_seen = hero:GetLevel(),
		spent = { str = 0, agi = 0, int = 0 },
		perk_stats = Stats:Empty(),
		perk_count = {},
		talents = {},
		axe_bonus = {},      -- накопительные бонусы к способностям Axe и Lich
		hoodwink_bonus = {},
		arc_bonus = {},
		sven_bonus = {},
		build = nil,         -- выбранный билд (после мифического перка)
		offer = nil,
	}
	hero:AddNewModifier(hero, nil, "modifier_rpg_stats", {})
	Perks:Sync(hero)
	local def = RPG.HEROES[hero:GetUnitName()]
	if def and def.modifier then
		hero:AddNewModifier(hero, nil, def.modifier, {})
	end
	-- Special bonus abilities remain the value source for existing modifiers,
	-- but are hidden and learned only through the custom Talents tab.
	local key = hero_key(hero)
	for _, talent in ipairs(talent_defs(hero)) do
		local name = "special_bonus_rpg_" .. key .. "_" .. talent.key
		local ability = talent.legacy and (hero:FindAbilityByName(name) or hero:AddAbility(name))
		if ability then ability:SetLevel(0); ability:SetHidden(true); ability:SetActivated(false) end
	end
	self:EnsureStartingLevel(hero)
	hero:AddItemByName("item_rpg_potion")
	Stats:QueueRecalc(hero)
	self:SendState(hero)
end

function Progression:EnsureStartingLevel(hero)
	if not hero or hero:IsNull() then return end
	-- Preserve the engine-selected map spawn while granting the starting levels.
	local spawn_origin = hero:GetAbsOrigin()
	local player_id = hero:GetPlayerOwnerID()
	-- Explicitly award the five starting levels before the first wave.
	while hero:GetLevel() < 5 do hero:HeroLevelUp(false) end
	-- Repair a Tempest Double point spent during hero selection at level 1.
	if hero:GetUnitName() == "npc_dota_hero_arc_warden" and hero:GetLevel() < 6 then
		local ultimate = hero:FindAbilityByName("rpg_arc_warden_tempest_double")
		if ultimate and ultimate:GetLevel() > 0 then
			ultimate:SetLevel(0)
			hero:SetAbilityPoints(hero:GetAbilityPoints() + 1)
		end
	end
	-- Level-up callbacks can run other initialization code; never let it leave
	-- the selected hero at a script fallback position such as (0, 0, 128).
	local current_hero = player_id >= 0 and PlayerResource:GetSelectedHeroEntity(player_id) or hero
	if current_hero and not current_hero:IsNull() and current_hero:IsAlive()
		and (current_hero:GetAbsOrigin() - spawn_origin):Length2D() > 32 then
		FindClearSpaceForUnit(current_hero, spawn_origin, true)
	end
	if hero.rpg then hero.rpg.level_seen = hero:GetLevel() end
end

function Progression:GetPlayer(hero)
	return PlayerResource:GetPlayer(hero:GetPlayerOwnerID())
end

function Progression:SendState(hero)
	local player = self:GetPlayer(hero)
	if not player then return end
	CustomGameEventManager:Send_ServerToPlayer(player, "rpg_hero_state", {
		points = hero.rpg.points,
		str = hero.rpg.spent.str,
		agi = hero.rpg.spent.agi,
		int = hero.rpg.spent.int,
		talents = self:TalentState(hero),
	})
end

function Progression:TalentState(hero)
	local key = hero_key(hero)
	local out = {}
	for _, talent in ipairs(talent_defs(hero)) do
		local ability = talent.legacy and hero:FindAbilityByName("special_bonus_rpg_" .. key .. "_" .. talent.key) or nil
		out[#out + 1] = {
			key = talent.key, level = talent.level, name = talent.name,
			selected = hero.rpg.talents[talent.level] and 1 or 0,
			learned = (hero.rpg.talents[talent.level] == talent.key or (ability and ability:GetLevel() > 0)) and 1 or 0,
			available = hero:GetLevel() >= talent.level and not hero.rpg.talents[talent.level],
		}
	end
	return out
end

function Progression:OnTalentPick(data)
	local hero = PlayerResource:GetSelectedHeroEntity(data.PlayerID)
	if not hero or not hero.rpg or not hero:IsRealHero() then return end
	local key = tostring(data.key or "")
	local chosen
	for _, talent in ipairs(talent_defs(hero)) do if talent.key == key then chosen = talent; break end end
	if not chosen or hero:GetLevel() < chosen.level or hero.rpg.talents[chosen.level] then return end
	local key_name = hero_key(hero)
	local ability = chosen.legacy and hero:FindAbilityByName("special_bonus_rpg_" .. key_name .. "_" .. key) or nil
	if chosen.legacy and not ability then return end
	hero.rpg.talents[chosen.level] = key
	if ability then
		ability:SetLevel(1)
		hero:CalculateStatBonus(true)
	elseif chosen.stats then
		Stats:Add(hero.rpg.perk_stats, chosen.stats)
		Stats:Recalc(hero)
	end
	self:SendState(hero)
end

-- Очки за уровни (+ периодическая пересылка состояния, чтобы HUD не терял данные при загрузке)
function Progression:Think()
	self.tick = (self.tick or 0) + 1
	for _, hero in ipairs(HeroList:GetAllHeroes()) do
		if hero.rpg and not hero.rpg_is_tempest_double then
			local lvl = hero:GetLevel()
			if lvl > hero.rpg.level_seen then
				hero.rpg.points = hero.rpg.points + (lvl - hero.rpg.level_seen) * RPG.CFG.POINTS_PER_LEVEL
				hero.rpg.level_seen = lvl
				self:SendState(hero)
			elseif self.tick % 3 == 0 then
				self:SendState(hero)
			end
		end
	end
end

function Progression:OnSpend(data)
	local hero = PlayerResource:GetSelectedHeroEntity(data.PlayerID)
	if not hero or not hero.rpg then return end
	local amount = math.min(tonumber(data.amount) or 1, hero.rpg.points)
	if amount <= 0 then return end
	local gain = amount * RPG.CFG.STAT_GAIN

	if data.stat == "str" then hero:ModifyStrength(gain)
	elseif data.stat == "agi" then hero:ModifyAgility(gain)
	elseif data.stat == "int" then hero:ModifyIntellect(gain)
	else return end

	hero.rpg.points = hero.rpg.points - amount
	hero.rpg.spent[data.stat] = hero.rpg.spent[data.stat] + amount
	hero:CalculateStatBonus(true)
	self:SendState(hero)
end

-- Предложение перков (редкость и мифик - см. game/perks.lua)
function Progression:Offer(hero, skip_mythic)
	local list, mythic = Perks:Roll(hero, math.max(1, Waves.wave), RPG.CFG.PERK_CHOICES, skip_mythic)
	hero.rpg.offer = {}
	hero.rpg.offer_mythic = mythic or false
	-- после мифического выбора игрок получит и обычную тройку этой волны
	if mythic then hero.rpg.queue_regular = true end
	local payload = {}
	for i, p in ipairs(list) do
		hero.rpg.offer[i] = p.id
		payload[i] = Perks:Payload(hero, p)
	end
	local player = self:GetPlayer(hero)
	if player and #list > 0 then
		CustomGameEventManager:Send_ServerToPlayer(player, "rpg_perk_offer", { perks = payload, mythic = mythic and 1 or 0 })
	end
end

function Progression:OnPick(data)
	local hero = PlayerResource:GetSelectedHeroEntity(data.PlayerID)
	if not hero or not hero.rpg or not hero.rpg.offer then return end
	local id = hero.rpg.offer[tonumber(data.index)]
	if not id then return end
	hero.rpg.offer = nil
	hero.rpg.offer_mythic = false
	self:Apply(hero, Perks:Find(id))
	-- после мифика сразу даём обычное предложение за эту волну
	if hero.rpg.queue_regular then
		hero.rpg.queue_regular = false
		self:Offer(hero, true)
	end
end

-- Не выбравшие до начала волны получают случайный перк из предложенных.
-- Исключение: мифический выбор остаётся открытым, пока игрок не выберет свой путь.
function Progression:CloseOffers()
	for _, hero in ipairs(HeroList:GetAllHeroes()) do
		if hero.rpg and hero.rpg.offer and not hero.rpg.offer_mythic then
			local id = hero.rpg.offer[RandomInt(1, #hero.rpg.offer)]
			hero.rpg.offer = nil
			self:Apply(hero, Perks:Find(id))
			local player = self:GetPlayer(hero)
			if player then CustomGameEventManager:Send_ServerToPlayer(player, "rpg_perk_close", {}) end
		end
	end
end

function Progression:Apply(hero, perk)
	if not perk then return end
	local r = hero.rpg
	r.perk_count[perk.id] = (r.perk_count[perk.id] or 0) + 1
	if perk.stats then
		Stats:Add(r.perk_stats, perk.stats)
		Stats:Recalc(hero)
	end
	-- накопительные бонусы к способностям (axe = для Axe, bonus = для остальных героев; хранятся в одной таблице)
	-- ipairs stops at the first nil; most perks define only one of these tables.
	for k, v in pairs(perk.axe or {}) do r.axe_bonus[k] = (r.axe_bonus[k] or 0) + v end
	for k, v in pairs(perk.bonus or {}) do r.axe_bonus[k] = (r.axe_bonus[k] or 0) + v end
	for k, v in pairs(perk.hoodwink or {}) do r.hoodwink_bonus[k] = (r.hoodwink_bonus[k] or 0) + v end
	for k, v in pairs(perk.arc or {}) do r.arc_bonus[k] = (r.arc_bonus[k] or 0) + v end
	for k, v in pairs(perk.sven or {}) do r.sven_bonus[k] = (r.sven_bonus[k] or 0) + v end
	if perk.ability then
		self:GrantAbility(hero, perk.ability)
	end
	if perk.tier == 5 and perk.build then
		r.build = perk.build
	end
	if perk.id == "m_tempest_identity" then
		for _, name in ipairs({"rpg_arc_warden_flux", "rpg_arc_warden_magnetic_field", "rpg_arc_warden_spark_wraith"}) do
			local ability = hero:FindAbilityByName(name)
			if ability then ability:SetActivated(false); ability:SetHidden(true) end
		end
	end
	Perks:Sync(hero)
	local rar = Perks.RARITY[perk.tier]
	local who = PlayerResource:GetPlayerName(hero:GetPlayerOwnerID())
	CustomGameEventManager:Send_ServerToAllClients("rpg_toast", {
		text = (perk.tier == 5 and "★ " or "") .. who .. " [" .. rar.name .. "]: " .. perk.name,
		color = rar.color,
	})
end

-- Кастомная способность занимает скрытый слот (generic_hidden); повторный выбор повышает уровень
function Progression:GrantAbility(hero, name)
	local ab = hero:FindAbilityByName(name)
	if ab then
		if ab:GetLevel() < ab:GetMaxLevel() then ab:SetLevel(ab:GetLevel() + 1) end
		return
	end
	local hidden = hero:FindAbilityByName("generic_hidden")
	ab = hero:AddAbility(name)
	if not ab then return end
	ab:SetLevel(1)
	if hidden then
		hero:SwapAbilities("generic_hidden", name, false, true)
	end
end
