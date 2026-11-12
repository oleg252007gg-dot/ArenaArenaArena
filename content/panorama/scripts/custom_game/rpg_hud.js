"use strict";

function Q(id) { return $("#" + id); }

// ---- Волны ----
var g_lastLives = -1, g_lastMax = -1;

function SetBar(id, pct) {
	var p = Q(id);
	pct = Math.max(0, Math.min(100, pct));
	p.style.width = pct + "%";
}

function BuildLives(cur, max) {
	if (cur === g_lastLives && max === g_lastMax) return;
	g_lastLives = cur; g_lastMax = max;
	var row = Q("LivesRow");
	row.RemoveAndDeleteChildren();
	for (var i = 0; i < max; i++) {
		var l = $.CreatePanel("Panel", row, "");
		l.AddClass("Life");
		if (i >= cur) l.AddClass("LifeLost");
	}
}

GameEvents.Subscribe("rpg_wave_update", function (d) {
	var box = Q("WaveBox");
	if (d.state == "idle") { box.AddClass("Hidden"); return; }
	box.RemoveClass("Hidden");

	var isBreak = d.state == "break";
	Q("NextWaveButton").SetHasClass("Hidden", !isBreak || d.can_skip != 1);
	var isBoss = d.boss == 1;
	var shown = isBreak ? d.wave + 1 : d.wave;
	if (shown > d.final) shown = d.final;

	Q("WaveNum").text = shown;
	Q("WaveFinal").text = "/ " + d.final;
	box.SetHasClass("Boss", isBoss);
	box.SetHasClass("Break", isBreak);

	var tag = Q("WaveTag");
	if (isBoss) {
		tag.text = "БОСС: " + d.boss_name; tag.RemoveClass("Hidden");
	} else if (!isBreak && d.mod) {
		tag.text = d.mod; tag.RemoveClass("Hidden");
	} else {
		tag.AddClass("Hidden");
	}

	if (isBreak) {
		Q("WaveCaption").text = "ПОДГОТОВКА";
		Q("WaveInfo").text = "Старт через " + d.countdown + " с";
		SetBar("BarFill", d.break_total > 0 ? (d.countdown / d.break_total) * 100 : 0);
	} else if (d.state == "active") {
		Q("WaveCaption").text = isBoss ? "БОСС-ВОЛНА" : "ВОЛНА";
		var killed = Math.max(0, d.total - d.left);
		Q("WaveInfo").text = "Врагов: " + d.left + "  (убито " + killed + " / " + d.total + ")";
		SetBar("BarFill", d.total > 0 ? (killed / d.total) * 100 : 0);
	} else {
		Q("WaveCaption").text = "ИГРА ОКОНЧЕНА";
		Q("WaveInfo").text = "";
		SetBar("BarFill", 100);
	}

	// общий прогресс игры
	SetBar("GameBarFill", d.final > 0 ? ((isBreak ? d.wave : d.wave - 1 + (d.total > 0 ? (d.total - d.left) / d.total : 0)) / d.final) * 100 : 0);

	var nextBoss = Math.ceil(shown / 10) * 10;
	Q("NextBoss").text = (isBoss || nextBoss > d.final) ? "" : "Следующий босс: волна " + nextBoss;
	BuildLives(d.lives, d.max_lives);
});

function NextWave() {
	GameEvents.SendCustomGameEventToServer("rpg_next_wave", {});
}

// ---- Очки характеристик ----
function Spend(stat) {
	GameEvents.SendCustomGameEventToServer("rpg_spend_point", { stat: stat, amount: 1 });
}

var g_talentOpen = false;
var g_talentSignature = "";
function ToggleTalents() {
	g_talentOpen = !g_talentOpen;
	Q("TalentBox").SetHasClass("Hidden", !g_talentOpen);
}

function PickTalent(key) {
	GameEvents.SendCustomGameEventToServer("rpg_talent_pick", { key: key });
}

function BuildTalents(talents) {
	var signature = JSON.stringify(talents || {});
	if (signature == g_talentSignature) return;
	g_talentSignature = signature;
	var root = Q("TalentCards");
	root.RemoveAndDeleteChildren();
	var groups = {};
	for (var k in (talents || {})) {
		var t = talents[k];
		(groups[t.level] = groups[t.level] || []).push(t);
	}
	var levels = Object.keys(groups).map(function (lv) { return Number(lv); }).sort(function (a,b) { return a-b; });
	for (var i = 0; i < levels.length; i++) {
		var level = levels[i], row = $.CreatePanel("Panel", root, "");
		row.AddClass("TalentRow");
		var header = $.CreatePanel("Label", row, "");
		header.AddClass("TalentLevel"); header.text = "Уровень " + level;
		var options = groups[level] || [];
		for (var j = 0; j < options.length; j++) {
			(function (t) {
				var card = $.CreatePanel("Button", row, "");
				card.AddClass("TalentCard");
				card.SetHasClass("TalentSelected", t.learned == 1);
				card.SetHasClass("TalentUnavailable", !t.available && t.learned != 1);
				var label = $.CreatePanel("Label", card, "");
				label.text = t.name + (t.learned == 1 ? " — выбрано" : (t.selected == 1 ? " — выбор сделан" : ""));
				card.SetPanelEvent("onactivate", function () { if (t.available) PickTalent(t.key); });
			})(options[j]);
		}
	}
}

GameEvents.Subscribe("rpg_hero_state", function (d) {
	Q("PointsLabel").text = "Очки: " + d.points;
	Q("StrLabel").text = "+ Сила (" + d.str + ")";
	Q("AgiLabel").text = "+ Ловкость (" + d.agi + ")";
	Q("IntLabel").text = "+ Интеллект (" + d.int + ")";
	BuildTalents(d.talents);
});

// ---- Перки ----
function PickPerk(index) {
	GameEvents.SendCustomGameEventToServer("rpg_perk_pick", { index: index });
	Q("PerkBox").AddClass("Hidden");
}

GameEvents.Subscribe("rpg_perk_offer", function (d) {
	Q("PerkTitle").text = d.mythic ? "★ Мифический перк — выберите свой путь (один раз за игру) ★" : "Выберите улучшение";
	var cards = Q("PerkCards");
	cards.RemoveAndDeleteChildren();
	// Массивы из Lua приходят как объект с ключами "1", "2", ...
	for (var k in d.perks) {
		var p = d.perks[k];
		var idx = parseInt(k, 10);
		var card = $.CreatePanel("Button", cards, "");
		card.AddClass("PerkCard");
		card.AddClass("Rarity" + p.tier);

		var rar = $.CreatePanel("Label", card, ""); rar.AddClass("PerkRarity"); rar.text = p.rarity; rar.style.color = p.color;
		var name = $.CreatePanel("Label", card, ""); name.AddClass("PerkName"); name.text = p.name;
		if (p.build) {
			var b = $.CreatePanel("Label", card, ""); b.AddClass("PerkBuild"); b.text = "Путь: " + p.build;
		}
		var desc = $.CreatePanel("Label", card, ""); desc.AddClass("PerkDesc"); desc.text = p.desc;
		var cnt = $.CreatePanel("Label", card, ""); cnt.AddClass("PerkCount"); cnt.text = p.max > 10 ? ("Уровень: " + p.count) : ("Уровень: " + p.count + " / " + p.max);

		card.SetPanelEvent("onactivate", (function (i) { return function () { PickPerk(i); }; })(idx));
	}
	Q("PerkBox").RemoveClass("Hidden");
});

GameEvents.Subscribe("rpg_perk_close", function () {
	Q("PerkBox").AddClass("Hidden");
});

// ---- Всплывающие сообщения и лут ----
function ShowToast(text, color) {
	var l = $.CreatePanel("Label", Q("ToastBox"), "");
	l.AddClass("Toast");
	l.text = text;
	l.style.color = color;
	$.Schedule(6, function () { if (l && l.IsValid()) l.DeleteAsync(0); });
}

GameEvents.Subscribe("rpg_toast", function (d) { ShowToast(d.text, d.color); });
GameEvents.Subscribe("rpg_loot", function (d) { ShowToast("Выпало: " + d.name + " — " + d.lines, d.color); });

// ---- Панель «Снаряжение» ----
GameEvents.Subscribe("rpg_gear_update", function (d) {
	var list = Q("GearList");
	list.RemoveAndDeleteChildren();
	var any = false;
	for (var k in d.items) {
		any = true;
		var it = d.items[k];
		var n = $.CreatePanel("Label", list, ""); n.AddClass("GearName"); n.text = it.name; n.style.color = it.color;
		var l = $.CreatePanel("Label", list, ""); l.AddClass("GearLines"); l.text = it.lines;
	}
	if (!any) {
		var e = $.CreatePanel("Label", list, ""); e.AddClass("GearLines"); e.text = "Пока ничего не надето";
	}
	for (var s in d.sets) {
		var sl = $.CreatePanel("Label", list, ""); sl.AddClass("GearLines"); sl.text = d.sets[s]; sl.style.color = "#8fd3ff";
	}
	var tot = Q("TotalsList");
	tot.RemoveAndDeleteChildren();
	for (var t in d.totals) {
		var tl = $.CreatePanel("Label", tot, ""); tl.AddClass("TotalLine"); tl.text = d.totals[t];
	}
});
